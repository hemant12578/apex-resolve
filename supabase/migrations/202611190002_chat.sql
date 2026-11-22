-- Only the server can lease outbox records or count token requests.
alter table public.outbox_events add column lease_until timestamptz, add column lease_id uuid;
create table public.chat_session_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  started_at timestamptz not null, requests int not null
);
alter table public.chat_session_limits enable row level security;
revoke all on public.chat_session_limits from public, anon, authenticated;
grant all on public.chat_session_limits to service_role;
create function public.take_chat_session(p_user uuid) returns boolean
language sql security invoker set search_path='' as $$
  with taken as (
    insert into public.chat_session_limits as l values(p_user, now(), 1)
    on conflict(user_id) do update set
      requests=case when l.started_at <= now()-interval '1 minute' then 1 else l.requests+1 end,
      started_at=case when l.started_at <= now()-interval '1 minute' then now() else l.started_at end
    where l.requests < 12 or l.started_at <= now()-interval '1 minute' returning 1
  ) select exists(select from taken)
$$;
create function public.claim_chat_events(p_issue uuid,p_lease uuid)
returns table(event_id uuid, channel text, event_action text, details jsonb)
language sql security invoker set search_path='' as $$
  with picked as (
    select e.id,i.channel_id from public.outbox_events e join public.issues i on e.issue_id=i.id
    where e.published_at is null and i.channel_id is not null and
      (e.lease_until is null or e.lease_until <= now()) and (p_issue is null or e.issue_id=p_issue)
    order by e.created_at,e.id limit 10 for update of e skip locked
  )
  update public.outbox_events e set lease_id=p_lease,lease_until=now()+interval '2 minutes'
  from picked p where p.id=e.id returning e.id,p.channel_id,e.action,e.payload
$$;
revoke all on function public.take_chat_session(uuid),public.claim_chat_events(uuid,uuid) from public,anon,authenticated;
grant execute on function public.take_chat_session(uuid),public.claim_chat_events(uuid,uuid) to service_role;

-- Optional signed webhook mirror. Keep only the latest 50 records per issue.
create table public.room_context (
  issue_id uuid not null references public.issues(id) on delete cascade,
  message_id text not null, sent_at bigint not null, body text check(length(body)<=2000),
  primary key(issue_id,message_id)
);
create index context_by_issue_time on public.room_context(issue_id,sent_at desc,message_id);
alter table public.room_context enable row level security;
revoke all on public.room_context from public,anon,authenticated;
grant select on public.room_context to authenticated;
grant all on public.room_context to service_role;
create policy room_context_read on public.room_context for select to authenticated using(public.can_access_issue(issue_id));
create function public.record_room_message(p_channel text,p_id text,p_time bigint,p_body text)
returns void language plpgsql security invoker set search_path='' as $$
declare room uuid;
begin
 select id into room from public.issues where channel_id=p_channel for update;
 if room is null then return; end if;
 insert into public.room_context(issue_id,message_id,sent_at,body) values(room,p_id,p_time,p_body)
 on conflict(issue_id,message_id) do update set body=null where excluded.body is null;
 delete from public.room_context where issue_id=room and message_id in
   (select message_id from public.room_context where issue_id=room order by sent_at desc,message_id desc offset 50);
end $$;
revoke all on function public.record_room_message(text,text,bigint,text) from public,anon,authenticated;
grant execute on function public.record_room_message(text,text,bigint,text) to service_role;

create table public.chat_webhook_receipts (
  identity text primary key, digest text not null, created_at timestamptz not null default now()
);
create index chat_receipts_by_age on public.chat_webhook_receipts(created_at);
alter table public.chat_webhook_receipts enable row level security;
revoke all on public.chat_webhook_receipts from public,anon,authenticated;
grant all on public.chat_webhook_receipts to service_role;
create function public.bind_chat_webhook(p_identity text,p_digest text)
returns boolean language plpgsql security invoker set search_path='' as $$
declare retained text;
begin
 delete from public.chat_webhook_receipts where created_at < now()-interval '11 minutes';
 insert into public.chat_webhook_receipts(identity,digest) values(p_identity,p_digest)
 on conflict(identity) do nothing;
 select digest into retained from public.chat_webhook_receipts where identity=p_identity;
 return retained=p_digest;
end $$;
revoke all on function public.bind_chat_webhook(text,text) from public,anon,authenticated;
grant execute on function public.bind_chat_webhook(text,text) to service_role;
