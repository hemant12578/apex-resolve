begin;
alter table public.issues
 add column affected_party_type text not null default 'unknown' check(affected_party_type in ('me','another','multiple','unknown')),
 add column affected_user_ids uuid[] not null default '{}',
 add column verification_requested_by uuid references public.profiles,
 add column verification_request_id uuid,
 add column legacy_review_required boolean not null default false;
alter table public.resolution_verifications add column request_id uuid unique;

-- Recover the last recorded request for existing pending reviews.
update public.issues i set verification_requested_by=a.actor_id,verification_request_id=a.id
from (select distinct on(issue_id) issue_id,actor_id,id from public.audit_events
 where action='verification_requested' order by issue_id,created_at desc,id desc) a
where i.id=a.issue_id and i.status='PENDING_VERIFICATION';

-- Preserve historical decisions. Mark currently resolved records needing a new review.
with latest as (
 select distinct on(issue_id) issue_id,verifier_id,created_at from public.resolution_verifications
 where approved order by issue_id,created_at desc,id desc
)
update public.issues i set legacy_review_required=true from latest v
where i.status='VERIFIED_RESOLVED' and v.issue_id=i.id and (
 v.verifier_id=i.assignee_id or v.verifier_id is not distinct from
 (select a.actor_id from public.audit_events a where a.issue_id=i.id and a.action='verification_requested'
 and a.created_at<=v.created_at order by a.created_at desc,a.id desc limit 1)
 or not exists (select 1 from public.evidence e where e.issue_id=i.id and e.created_at<=v.created_at and e.uploader_id<>v.verifier_id)
);

-- Replace the published entry point atomically. Only the guarded wrapper may call the old implementation.
alter function public.transition_issue(uuid,text,text,text[]) set schema resolve_private;
revoke all on function resolve_private.transition_issue(uuid,text,text,text[]) from public,anon,authenticated;
create function public.transition_issue(p_issue_id uuid,p_action text,p_notes text default '',p_tags text[] default '{}',p_request_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare i public.issues; actor uuid:=auth.uid(); membership text;
begin
 if actor is null or not public.can_access_issue(p_issue_id) then raise exception 'Room access required'; end if;
 select * into strict i from public.issues where id=p_issue_id for update;
 select role into membership from public.workspace_members where workspace_id=i.workspace_id and user_id=actor for share;
 if membership is null or membership='guest' then raise exception 'Team membership required'; end if;
 if p_action in ('approve','reject','withdraw') then
   if i.status<>'PENDING_VERIFICATION' then raise exception 'Invalid issue transition'; end if;
   if p_action<>'withdraw' and membership not in ('admin','verifier') then raise exception 'Role cannot perform this transition'; end if;
   if i.verification_request_id is null or i.verification_request_id is distinct from p_request_id then raise exception 'Review request changed. Reload the issue.'; end if;
   if p_action='withdraw' then
     if i.verification_requested_by is distinct from actor then raise exception 'Only the requester can withdraw'; end if;
     update public.issues set status='IN_PROGRESS',verification_request_id=null,verification_requested_by=null where id=i.id;
     perform resolve_private.event(i.id,'verification_withdrawn',jsonb_build_object('request_id',p_request_id));
     return;
   end if;
   if i.verification_requested_by is null or actor in (i.verification_requested_by,i.assignee_id)
     or not exists(select 1 from public.evidence where issue_id=i.id and uploader_id<>actor)
   then raise exception 'An independent reviewer is required'; end if;
 end if;
 perform resolve_private.transition_issue(p_issue_id,p_action,p_notes,p_tags);
 if p_action='start' then
   update public.issues set assignee_id=coalesce(assignee_id,actor) where id=i.id;
 elsif p_action='request' then
   update public.issues set verification_requested_by=actor,verification_request_id=gen_random_uuid() where id=i.id;
 elsif p_action in ('approve','reject') then
   update public.resolution_verifications set request_id=p_request_id where id=(
     select id from public.resolution_verifications where issue_id=i.id and verifier_id=actor
     order by created_at desc,id desc limit 1);
   if p_action='approve' then update public.issues set legacy_review_required=false where id=i.id; end if;
 end if;
end $$;
revoke all on function public.transition_issue(uuid,text,text,text[],uuid) from public,anon;
grant execute on function public.transition_issue(uuid,text,text,text[],uuid) to authenticated;

create function public.file_issue(p_workspace_id uuid,p_title text,p_description text,p_priority text,p_assignee_id uuid,p_id uuid,p_party text,p_people uuid[])
returns uuid language plpgsql security definer set search_path='' as $$
declare ids uuid[]; result uuid; existing public.issues;
begin
 if p_party is null or p_party not in ('me','another','multiple','unknown') then raise exception 'Choose who is affected'; end if;
 select coalesce(array_agg(distinct x order by x),'{}') into ids from unnest(p_people) x;
 if p_party='me' then ids:=array[auth.uid()]; end if;
 if (p_party='another' and (cardinality(ids)<>1 or auth.uid()=any(ids))) or
    (p_party='multiple' and cardinality(ids)<2) or (p_party='unknown' and cardinality(ids)<>0)
 then raise exception 'Select the affected people'; end if;
 if exists(select 1 from unnest(ids) x where not exists(select 1 from public.workspace_members where workspace_id=p_workspace_id and user_id=x)) then raise exception 'Select people in this workspace'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into existing from public.issues where id=p_id;
 result:=public.create_issue(p_workspace_id,p_title,p_description,p_priority,p_assignee_id,p_id);
 if existing.id is null then update public.issues set affected_party_type=p_party,affected_user_ids=ids where id=result;
 elsif existing.affected_party_type<>p_party or existing.affected_user_ids<>ids then raise exception 'Issue creation conflict'; end if;
 return result;
end $$;
revoke all on function public.file_issue(uuid,text,text,text,uuid,uuid,text,uuid[]) from public,anon;
grant execute on function public.file_issue(uuid,text,text,text,uuid,uuid,text,uuid[]) to authenticated;
commit;
