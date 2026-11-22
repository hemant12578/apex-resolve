create table resolve_private.contact_pins (
  owner_id uuid primary key references public.profiles(id) on delete cascade,
  pin text unique not null default upper(left(replace(gen_random_uuid()::text,'-',''),12))
);
create table public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  sender uuid not null references public.profiles(id) on delete cascade,
  recipient uuid not null references public.profiles(id) on delete cascade,
  status text not null check(status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  check(sender <> recipient)
);
create unique index contact_pair on public.contact_requests(least(sender,recipient),greatest(sender,recipient));
alter table public.contact_requests enable row level security;
revoke all on public.contact_requests from public, anon, authenticated;
grant select on public.contact_requests to authenticated;
create policy participants on public.contact_requests for select to authenticated using(auth.uid() in (sender,recipient));
create function public.my_contact_pin() returns text language plpgsql security definer set search_path='' as $$
declare result text;
begin
  insert into resolve_private.contact_pins(owner_id) values(auth.uid()) on conflict(owner_id) do nothing;
  select pin into result from resolve_private.contact_pins where owner_id=auth.uid();
  return result;
end $$;
create function public.contact_action(peer uuid, operation text, supplied_pin text default '') returns text language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); item public.contact_requests; next_status text;
begin
  if me is null or peer=me or not exists(select 1 from public.profiles where id=peer) then raise exception 'Member unavailable'; end if;
  perform pg_advisory_xact_lock(hashtextextended(least(me,peer)::text || greatest(me,peer)::text,0));
  select * into item from public.contact_requests where least(sender,recipient)=least(me,peer) and greatest(sender,recipient)=greatest(me,peer);
  if item.status='accepted' then return 'accepted'; end if;
  if operation in ('accept','decline') then
    if item.recipient is distinct from me or item.status <> 'pending' then raise exception 'Request unavailable'; end if;
    next_status:=case when operation='accept' then 'accepted' else 'declined' end;
  elsif operation='pin' then
    if not exists(select 1 from resolve_private.contact_pins where owner_id=peer and pin=upper(trim(supplied_pin))) then return 'invalid'; end if;
    next_status:='accepted';
  elsif operation='request' then
    if item.id is not null then return item.status; end if;
    next_status:='pending';
  else raise exception 'Invalid operation';
  end if;
  if item.id is null then
    insert into public.contact_requests(sender,recipient,status) values(me,peer,next_status);
  else
    update public.contact_requests set status=next_status where id=item.id;
  end if;
  return next_status;
end $$;
revoke all on function public.my_contact_pin(),public.contact_action(uuid,text,text) from public,anon;
grant execute on function public.my_contact_pin(),public.contact_action(uuid,text,text) to authenticated;
