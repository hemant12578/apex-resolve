begin;
create schema if not exists resolve_private;
revoke all on schema resolve_private from public, anon, authenticated;
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null check(length(trim(display_name)) between 1 and 100),
  created_at timestamptz not null default now()
);
create function resolve_private.make_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id,display_name) values(new.id,coalesce(nullif(left(trim(new.raw_user_meta_data->>'display_name'),100),''),'Team member'));
  return new;
end $$;
create trigger apex_profile_created after insert on auth.users for each row execute function resolve_private.make_profile();
insert into public.profiles(id,display_name)
select id,coalesce(nullif(left(trim(raw_user_meta_data->>'display_name'),100),''),'Team member') from auth.users;

create table public.workspaces (
  id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 100),
  description text not null default '' check(length(description)<=4000), owner_id uuid not null references public.profiles,
  created_at timestamptz not null default now()
);
create table public.workspace_members (
  workspace_id uuid references public.workspaces on delete cascade, user_id uuid references public.profiles on delete cascade,
  role text not null check(role in ('admin','verifier','member','guest')), primary key(workspace_id,user_id),
  created_at timestamptz not null default now()
);
create index workspace_members_by_user on public.workspace_members(user_id);
create table public.issues (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces on delete cascade,
  title text not null check(length(trim(title)) between 1 and 180), description text not null check(length(description)<=10000),
  priority text not null check(priority in ('low','medium','high','critical')), reporter_id uuid not null references public.profiles,
  assignee_id uuid references public.profiles, channel_id text unique,
  status text not null default 'OPEN' check(status in ('OPEN','IN_PROGRESS','PENDING_VERIFICATION','VERIFIED_RESOLVED')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),unique(workspace_id,id)
);
create index issues_by_workspace on public.issues(workspace_id,updated_at desc);
create table public.issue_participants (
  issue_id uuid references public.issues on delete cascade, user_id uuid references public.profiles on delete cascade,
  primary key(issue_id,user_id)
);
create table public.workspace_invitations (
  id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces on delete cascade,
  role text not null check(role in ('admin','verifier','member','guest')),issue_id uuid,
  foreign key(workspace_id,issue_id) references public.issues(workspace_id,id) on delete cascade,
  check ((role='guest')=(issue_id is not null)),token_hash bytea not null unique,
  invited_by uuid not null references public.profiles, expires_at timestamptz not null default (now()+interval '24 hours'),
  accepted_by uuid references public.profiles, created_at timestamptz not null default now()
);
create table public.tasks (
  id uuid primary key default gen_random_uuid(), issue_id uuid not null references public.issues on delete cascade,
  title text not null check(length(trim(title)) between 1 and 180),description text not null check(length(description)<=4000),
  assignee_id uuid references public.profiles,status text not null check(status in ('TODO','IN_PROGRESS','DONE')),
  ai_generated boolean not null default false,created_at timestamptz not null default now(),completed_at timestamptz
);
create index tasks_by_issue on public.tasks(issue_id);
create table public.evidence (
  id uuid primary key default gen_random_uuid(), issue_id uuid not null references public.issues on delete cascade,
  uploader_id uuid not null references public.profiles, kind text not null check(kind in ('note','url','file')),
  description text not null check(length(trim(description)) between 1 and 4000),value text check(length(value)<=2048),
  created_at timestamptz not null default now(),
  check(case kind when 'note' then value is null when 'url' then value is not null and value ~ '^https://[A-Za-z0-9-]+([.][A-Za-z0-9-]+)*(:[0-9]+)?([/?#][^[:space:]]*)?$' else value is not null end)
);
create index evidence_by_issue on public.evidence(issue_id);
create table public.resolution_verifications (
 id uuid primary key default gen_random_uuid(),issue_id uuid not null references public.issues on delete cascade,
 verifier_id uuid not null references public.profiles, approved boolean not null,notes text not null,created_at timestamptz not null default now()
);
create index verifications_by_issue on public.resolution_verifications(issue_id);
create table public.knowledge_entries (
 id uuid primary key default gen_random_uuid(),workspace_id uuid not null,issue_id uuid not null unique,
 foreign key(workspace_id,issue_id) references public.issues(workspace_id,id) on delete cascade,
 title text not null,description text not null,summary text not null,tags text[] not null,verified_at timestamptz not null
);
create table public.audit_events (
 id uuid primary key default gen_random_uuid(),issue_id uuid not null references public.issues on delete cascade,
 actor_id uuid not null references public.profiles, action text not null, metadata jsonb not null, created_at timestamptz not null default now()
);
create index audit_by_issue on public.audit_events(issue_id,created_at desc);
create table public.outbox_events (
 id uuid primary key references public.audit_events on delete cascade,issue_id uuid not null references public.issues on delete cascade,
 action text not null,payload jsonb not null,created_at timestamptz not null default now(),published_at timestamptz
);
create index outbox_pending on public.outbox_events(created_at) where published_at is null;

create function resolve_private.workspace_role(w uuid) returns text language sql stable security definer set search_path='' as $$
 select role from public.workspace_members where workspace_id=w and user_id=auth.uid()
$$;
create function public.can_access_issue(p_issue_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.issues i join public.workspace_members m on m.workspace_id=i.workspace_id
 where i.id=p_issue_id and m.user_id=auth.uid() and (m.role<>'guest' or exists(
 select 1 from public.issue_participants p where p.issue_id=i.id and p.user_id=m.user_id)))
$$;
create function resolve_private.can_read_profile(target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select target=auth.uid() or exists(select 1 from public.workspace_members a join public.workspace_members b using(workspace_id)
 where a.user_id=auth.uid() and a.role<>'guest' and b.user_id=target)
$$;

alter table public.profiles enable row level security;
create policy profiles_visible on public.profiles for select to authenticated using(resolve_private.can_read_profile(id));
alter table public.workspaces enable row level security;
create policy workspaces_visible on public.workspaces for select to authenticated using(resolve_private.workspace_role(id) is not null);
alter table public.workspace_members enable row level security;
create policy members_visible on public.workspace_members for select to authenticated using(user_id=auth.uid() or resolve_private.workspace_role(workspace_id) in ('admin','verifier','member'));
alter table public.issues enable row level security;
create policy issues_visible on public.issues for select to authenticated using(public.can_access_issue(id));
alter table public.workspace_invitations enable row level security;
alter table public.outbox_events enable row level security;
do $$
declare t text;
begin
 foreach t in array array['tasks','evidence','knowledge_entries','issue_participants','audit_events','resolution_verifications'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy issue_scoped on public.%I for select to authenticated using(public.can_access_issue(issue_id))',t);
 end loop;
 foreach t in array array['profiles','workspaces','workspace_members','issues','tasks','evidence','knowledge_entries','issue_participants','audit_events','resolution_verifications','outbox_events','workspace_invitations'] loop
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 if t not in ('outbox_events','workspace_invitations') then execute format('grant select on public.%I to authenticated',t); end if;
 end loop;
end $$;

create function resolve_private.event(i uuid, a text, data jsonb default '{}'::jsonb) returns void language plpgsql set search_path='' as $$
declare ev uuid;
begin
 insert into public.audit_events(issue_id,actor_id,action,metadata) values(i,auth.uid(),a,data) returning id into ev;
 insert into public.outbox_events(id,issue_id,action,payload) values(ev,i,a,data || jsonb_build_object('actor_id',auth.uid(),'event_id',ev));
 update public.issues set updated_at=now() where id=i;
end $$;

create function public.update_profile(p_display_name text) returns void language sql security definer set search_path='' as $$
 update public.profiles set display_name=trim(p_display_name) where id=auth.uid()
$$;
create function public.create_workspace(p_name text,p_description text) returns uuid language plpgsql security definer set search_path='' as $$
declare w uuid;
begin
 insert into public.workspaces(name,description,owner_id) values(trim(p_name),p_description,auth.uid()) returning id into w;
 insert into public.workspace_members(workspace_id,user_id,role) values(w,auth.uid(),'admin'); return w;
end $$;
create function public.update_workspace(p_workspace_id uuid,p_name text,p_description text) returns void language plpgsql security definer set search_path='' as $$
begin
 if resolve_private.workspace_role(p_workspace_id) is distinct from 'admin' then raise exception 'Workspace admin required'; end if;
 update public.workspaces set name=trim(p_name),description=p_description where id=p_workspace_id;
end $$;
-- Team role changes preserve room membership. Changing a guest's scope
-- requires an explicit invitation through the issue-sharing workflow.
create function public.set_member_role(p_workspace_id uuid,p_user_id uuid,p_role text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.workspaces where id=p_workspace_id for update;
 if resolve_private.workspace_role(p_workspace_id) is distinct from 'admin' then raise exception 'Workspace admin required'; end if;
 if exists(select 1 from public.workspaces where id=p_workspace_id and owner_id=p_user_id) then raise exception 'The workspace owner retains the admin role'; end if;
 if p_role is null or p_role not in ('member','admin','verifier') then raise exception 'Choose a team role'; end if;
 update public.workspace_members set role=p_role where workspace_id=p_workspace_id and user_id=p_user_id and role<>'guest';
 if not found then raise exception 'Team member unavailable'; end if;
end $$;
create function public.create_invitation(p_workspace_id uuid,p_role text,p_issue_id uuid default null) returns text language plpgsql security definer set search_path='' as $$
declare token text:=replace(gen_random_uuid()::text || gen_random_uuid()::text,'-','');
begin
 if resolve_private.workspace_role(p_workspace_id) is distinct from 'admin' then raise exception 'Workspace admin required'; end if;
 insert into public.workspace_invitations(workspace_id,role,issue_id,token_hash,invited_by)
 values(p_workspace_id,p_role,p_issue_id,sha256(convert_to(token,'UTF8')),auth.uid()); return token;
end $$;
create function public.accept_invitation(p_token text) returns uuid language plpgsql security definer set search_path='' as $$
declare inv public.workspace_invitations; prior_role text;
begin
 select * into inv from public.workspace_invitations where token_hash=sha256(convert_to(p_token,'UTF8')) and expires_at>now() and accepted_by is null for update;
 if inv.id is null or auth.uid() is null then raise exception 'Invitation is invalid or expired'; end if;
 insert into public.workspace_members(workspace_id,user_id,role) values(inv.workspace_id,auth.uid(),inv.role) on conflict do nothing;
 select role into prior_role from public.workspace_members where workspace_id=inv.workspace_id and user_id=auth.uid();
 if prior_role='guest' and inv.role<>'guest' then update public.workspace_members set role=inv.role where workspace_id=inv.workspace_id and user_id=auth.uid(); end if;
 if inv.issue_id is not null then insert into public.issue_participants values(inv.issue_id,auth.uid()) on conflict do nothing; end if;
 update public.workspace_invitations set accepted_by=auth.uid() where id=inv.id; return inv.workspace_id;
end $$;

create function public.create_issue(p_workspace_id uuid,p_title text,p_description text,p_priority text,p_assignee_id uuid default null,p_id uuid default gen_random_uuid()) returns uuid language plpgsql security definer set search_path='' as $$
declare inserted uuid;
begin
 if coalesce(resolve_private.workspace_role(p_workspace_id),'') not in ('member','admin','verifier') then raise exception 'Workspace membership required'; end if;
 if p_assignee_id is not null and not exists(select 1 from public.workspace_members where workspace_id=p_workspace_id and user_id=p_assignee_id and role<>'guest') then raise exception 'Assignee must belong to this workspace'; end if;
 insert into public.issues(id,workspace_id,title,description,priority,reporter_id,assignee_id) values(p_id,p_workspace_id,trim(p_title),p_description,p_priority,auth.uid(),p_assignee_id) on conflict do nothing returning id into inserted;
 if inserted is null then
 if not exists(select 1 from public.issues where id=p_id and workspace_id=p_workspace_id and reporter_id=auth.uid() and title=trim(p_title) and description=p_description and priority=p_priority and assignee_id is not distinct from p_assignee_id) then raise exception 'Issue creation conflict'; end if;
 else perform resolve_private.event(p_id,'issue_created',jsonb_build_object('title',p_title)); end if;
 return p_id;
end $$;

create function resolve_private.mutable_issue(i uuid, allow_guest boolean default false) returns public.issues language plpgsql set search_path='' as $$
declare rec public.issues;
begin
 if not public.can_access_issue(i) then raise exception 'Room access required'; end if;
 select * into strict rec from public.issues where id=i for update;
 if not allow_guest and resolve_private.workspace_role(rec.workspace_id)='guest' then raise exception 'Team membership required'; end if;
 if rec.status in ('VERIFIED_RESOLVED','PENDING_VERIFICATION') then raise exception 'Review or reopen the issue before changing work'; end if;
 return rec;
end $$;

create function public.save_task(p_issue_id uuid,p_title text,p_description text,p_status text,p_assignee_id uuid default null,p_id uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
declare i public.issues; tid uuid; previous text;
begin
 i:=resolve_private.mutable_issue(p_issue_id);
 if p_assignee_id is not null and not exists(select 1 from public.workspace_members where workspace_id=i.workspace_id and user_id=p_assignee_id and role<>'guest') then raise exception 'Assignee must belong to this workspace'; end if;
 if p_id is null then
 insert into public.tasks(issue_id,title,description,status,assignee_id,completed_at) values(i.id,trim(p_title),p_description,p_status,p_assignee_id,case when p_status='DONE' then now() end) returning id into tid;
 else
 select status into previous from public.tasks where issue_id=i.id and id=p_id;
 update public.tasks set title=trim(p_title),description=p_description,status=p_status,assignee_id=p_assignee_id,
 completed_at=case when p_status='DONE' then coalesce(completed_at,now()) end where id=p_id and issue_id=i.id returning id into tid;
 if tid is null then raise exception 'Task unavailable'; end if;
 end if;
 perform resolve_private.event(i.id,case when p_status='DONE' and previous is distinct from p_status then 'task_completed' when p_id is null then 'task_approved' else 'task_updated' end,jsonb_build_object('task_id',tid,'title',p_title,'status',p_status,'assignee_id',p_assignee_id));
 return tid;
end $$;
create function public.delete_task(p_issue_id uuid,p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform resolve_private.mutable_issue(p_issue_id);
 delete from public.tasks where id=p_id and issue_id=p_issue_id;
 if not found then raise exception 'Task unavailable'; end if;
 perform resolve_private.event(p_issue_id,'task_deleted',jsonb_build_object('task_id',p_id));
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('evidence','evidence',false,4194304,array['image/png','image/jpeg','image/webp','application/pdf','text/plain']);
create policy apex_evidence_read on storage.objects for select to authenticated using(
 bucket_id='evidence' and exists(select 1 from public.evidence e where e.kind='file' and e.value=name and public.can_access_issue(e.issue_id))
);
create unique index evidence_files on public.evidence(value) where kind='file';

create function public.add_evidence(p_issue_id uuid,p_kind text,p_description text,p_value text default null,p_id uuid default gen_random_uuid()) returns uuid language plpgsql security definer set search_path='' as $$
begin
 perform resolve_private.mutable_issue(p_issue_id,true);
 if p_kind='file' and not exists(select 1 from storage.objects o where o.bucket_id='evidence' and o.name=p_value
 and p_value ~ ('^'||p_issue_id::text||'/'||p_id::text||'[.](png|jpg|jpeg|webp|pdf|txt|log)$')
 and o.user_metadata->>'uploader_id'=auth.uid()::text) then raise exception 'Validated upload required'; end if;
 insert into public.evidence(id,issue_id,uploader_id,kind,description,value) values(p_id,p_issue_id,auth.uid(),p_kind,trim(p_description),p_value)
 on conflict(id) do nothing;
 if found then perform resolve_private.event(p_issue_id,'evidence_attached',jsonb_build_object('evidence_id',p_id,'kind',p_kind));
 elsif not exists(select 1 from public.evidence where id=p_id and issue_id=p_issue_id and uploader_id=auth.uid() and kind=p_kind and description=trim(p_description) and value is not distinct from p_value) then raise exception 'Evidence creation conflict'; end if;
 return p_id;
end $$;
create function public.transition_issue(p_issue_id uuid,p_action text,p_notes text default '',p_tags text[] default '{}') returns void language plpgsql security definer set search_path='' as $$
declare i public.issues; r text; next_status text; event_name text; summary_text text;
begin
 if not public.can_access_issue(p_issue_id) then raise exception 'Room access required'; end if;
 select * into strict i from public.issues where id=p_issue_id for update;
 r:=resolve_private.workspace_role(i.workspace_id);
 if r='guest' or (p_action in ('approve','reject','reopen') and r not in ('verifier','admin')) then raise exception 'Role cannot perform this transition'; end if;
 if p_notes is null or length(p_notes)>4000 or p_tags is null or cardinality(p_tags)>10 or exists(select 1 from unnest(p_tags) tag where length(tag)>40 or nullif(trim(tag),'') is null) then raise exception 'Review notes or tags exceed allowed limits'; end if;
 case
 when p_action='start' and i.status='OPEN' then next_status:='IN_PROGRESS';event_name:='issue_started';
 when p_action='request' and i.status='IN_PROGRESS' then next_status:='PENDING_VERIFICATION';event_name:='verification_requested';
 when p_action='approve' and i.status='PENDING_VERIFICATION' then next_status:='VERIFIED_RESOLVED';event_name:='verification_approved';
 when p_action='reject' and i.status='PENDING_VERIFICATION' then
 if trim(p_notes)='' then raise exception 'A rejection reason is required'; end if;
 next_status:='IN_PROGRESS';event_name:='verification_rejected';
 when p_action='reopen' and i.status='VERIFIED_RESOLVED' then next_status:='IN_PROGRESS';event_name:='issue_reopened';
 else raise exception 'Invalid issue transition';
 end case;
 if p_action in ('approve','request') and not exists(select 1 from public.evidence where issue_id=i.id) then raise exception 'Attach evidence before requesting verification'; end if;
 if p_action in ('approve','reject') then insert into public.resolution_verifications(issue_id,verifier_id,approved,notes) values(i.id,auth.uid(),p_action='approve',trim(p_notes)); end if;
 if p_action='approve' then
 select coalesce(nullif(trim(p_notes),''),description) into summary_text from public.evidence where issue_id=i.id order by created_at desc,id limit 1;
 insert into public.knowledge_entries(workspace_id,issue_id,title,description,summary,tags,verified_at) values(i.workspace_id,i.id,i.title,i.description,summary_text,p_tags,now())
 on conflict(issue_id) do update set title=excluded.title,description=excluded.description,summary=excluded.summary,tags=excluded.tags,verified_at=excluded.verified_at;
 elsif p_action='reopen' then delete from public.knowledge_entries where issue_id=i.id;
 end if;
 update public.issues set status=next_status where id=i.id;
 perform resolve_private.event(i.id,event_name,jsonb_build_object('from',i.status,'to',next_status,'notes',trim(p_notes)));
end $$;

-- PostgreSQL grants PUBLIC execution by default. Limit the affected objects to this application.
revoke all on all functions in schema resolve_private from public,anon,authenticated;
grant execute on function resolve_private.workspace_role(uuid),resolve_private.can_read_profile(uuid) to authenticated;
do $$
declare f regprocedure;
begin
 foreach f in array array[
 'public.can_access_issue(uuid)'::regprocedure,'public.update_profile(text)'::regprocedure,
 'public.create_workspace(text,text)'::regprocedure,'public.update_workspace(uuid,text,text)'::regprocedure,
 'public.set_member_role(uuid,uuid,text)'::regprocedure,'public.create_invitation(uuid,text,uuid)'::regprocedure,'public.accept_invitation(text)'::regprocedure,
 'public.create_issue(uuid,text,text,text,uuid,uuid)'::regprocedure,'public.save_task(uuid,text,text,text,uuid,uuid)'::regprocedure,
 'public.delete_task(uuid,uuid)'::regprocedure,'public.add_evidence(uuid,text,text,text,uuid)'::regprocedure,
 'public.transition_issue(uuid,text,text,text[])'::regprocedure
 ] loop
 execute format('revoke all on function %s from public,anon,authenticated',f);
 execute format('grant execute on function %s to authenticated',f);
 end loop;
end $$;
commit;
