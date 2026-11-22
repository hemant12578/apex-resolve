begin;
-- A trigger maintains the text vector because array_to_string is not immutable.
alter table public.knowledge_entries add column search_vector tsvector;
create function resolve_private.index_knowledge() returns trigger language plpgsql set search_path='' as $$
begin
 new.search_vector:=setweight(to_tsvector('simple',new.title),'A')
 ||setweight(to_tsvector('simple',array_to_string(new.tags,' ')),'A')
 ||to_tsvector('simple',new.description||' '||new.summary);
 return new;
end $$;
revoke all on function resolve_private.index_knowledge() from public,anon,authenticated;
create trigger index_verified_knowledge before insert or update of title,description,summary,tags on public.knowledge_entries
 for each row execute function resolve_private.index_knowledge();
update public.knowledge_entries set title=title;
create index knowledge_search on public.knowledge_entries using gin(search_vector);

create table public.ai_analyses (
 id uuid primary key default gen_random_uuid(),
 issue_id uuid not null references public.issues on delete cascade,
 user_id uuid not null references public.profiles on delete cascade,
 context_hash text not null check(context_hash ~ '^[0-9a-f]{64}$'),
 state text not null default 'reserved' check(state in ('reserved','complete','failed')),
 allow_fallback boolean not null,
 created_at timestamptz not null default now(),
 completed_at timestamptz,
 provider text check(provider in ('gemini','openrouter')),
 result jsonb,
 error_code text check(error_code ~ '^[a-zA-Z0-9_-]{1,64}$')
);
create index ai_cache on public.ai_analyses(user_id,issue_id,context_hash,allow_fallback,created_at desc);
create table public.ai_usage (
 analysis_id uuid primary key references public.ai_analyses on delete cascade,
 user_id uuid not null references public.profiles on delete cascade,
 usage_day date not null,
 reserved_micros bigint not null check(reserved_micros>=0),
 input_tokens integer check(input_tokens>=0),
 output_tokens integer check(output_tokens>=0)
);
create index ai_daily_usage on public.ai_usage(usage_day,user_id);
alter table public.ai_analyses enable row level security;
alter table public.ai_usage enable row level security;
revoke all on public.ai_analyses,public.ai_usage from public,anon,authenticated;
grant select on public.ai_analyses to authenticated;
grant all on public.ai_analyses,public.ai_usage to service_role;
create policy own_issue_analysis on public.ai_analyses for select to authenticated using(user_id=auth.uid() and public.can_access_issue(issue_id));

-- This service-only entry point receives a verified Supabase subject from the server.
-- One short transaction serializes each day's budget decisions across all users.
-- Keep the entire maximum reservation even on timeouts: a provider may still bill.
create function public.begin_ai_analysis(p_user uuid,p_issue uuid,p_context_hash text,p_daily_limit int,p_daily_budget_micros bigint,p_reserve_micros bigint,p_allow_fallback boolean)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare d date := (now() at time zone 'UTC')::date; prev public.ai_analyses; rid uuid; used bigint; spent numeric;
begin
 if not exists(select 1 from public.issues i join public.workspace_members m on m.workspace_id=i.workspace_id
 where i.id=p_issue and m.user_id=p_user and (m.role<>'guest' or exists(select 1 from public.issue_participants p where p.issue_id=i.id and p.user_id=p_user))) then
 raise exception 'Room access required'; end if;
 if p_context_hash is null or p_context_hash !~ '^[0-9a-f]{64}$' or p_allow_fallback is null
 or p_daily_limit is null or p_daily_limit<1 or p_reserve_micros is null or p_reserve_micros<1
 or p_daily_budget_micros is null or p_daily_budget_micros<0 then raise exception 'Invalid analysis limits'; end if;
 perform pg_advisory_xact_lock(841672,d-date '2000-01-01');
 select * into prev from public.ai_analyses where user_id=p_user and issue_id=p_issue and context_hash=p_context_hash
 and allow_fallback=p_allow_fallback and created_at>now()-interval '24 hours' and state='complete' order by created_at desc limit 1;
 if found then return jsonb_build_object('id',prev.id,'state','cached','result',prev.result,'provider',prev.provider); end if;
 if exists(select 1 from public.ai_analyses where user_id=p_user and issue_id=p_issue and context_hash=p_context_hash
 and allow_fallback=p_allow_fallback and created_at>now()-interval '3 minutes' and state='reserved') then raise exception 'Analysis already in progress'; end if;
 select count(*) filter(where user_id=p_user),coalesce(sum(reserved_micros),0) into used,spent from public.ai_usage where usage_day=d;
 if used>=p_daily_limit then raise exception 'Daily analysis limit reached'; end if;
 if spent+p_reserve_micros>p_daily_budget_micros then raise exception 'Daily spending limit reached'; end if;
 insert into public.ai_analyses(issue_id,user_id,context_hash,allow_fallback) values(p_issue,p_user,p_context_hash,p_allow_fallback) returning id into rid;
 insert into public.ai_usage(analysis_id,user_id,usage_day,reserved_micros) values(rid,p_user,d,p_reserve_micros);
 return jsonb_build_object('id',rid,'state','reserved');
end $$;

create function public.finish_ai_analysis(p_id uuid,p_user uuid,p_provider text,p_result jsonb,p_error text,p_input_tokens int,p_output_tokens int)
returns void language plpgsql security invoker set search_path='' as $$
declare analysis public.ai_analyses;
begin
 select * into analysis from public.ai_analyses where id=p_id and user_id=p_user and state='reserved' for update;
 if not found then raise exception 'Analysis reservation unavailable'; end if;
 if p_provider='openrouter' and not analysis.allow_fallback then raise exception 'Fallback consent required'; end if;
 if (p_result is null)=(p_error is null) then raise exception 'Expected analysis result or failure'; end if;
 if p_result is not null and (p_provider is null or jsonb_typeof(p_result->'tasks') is distinct from 'array'
 or octet_length(p_result::text)>64000) then raise exception 'Invalid analysis result'; end if;
 update public.ai_analyses set provider=p_provider,result=p_result,state=case when p_error is null then 'complete' else 'failed' end,
 error_code=p_error,completed_at=now() where id=p_id;
 update public.ai_usage set input_tokens=p_input_tokens,output_tokens=p_output_tokens where analysis_id=p_id;
end $$;

-- Retain the source even after a resulting task is removed, so retrying an approval
-- cannot regenerate a task that someone deliberately deleted.
create table resolve_private.approved_suggestions (
 analysis_id uuid references public.ai_analyses on delete cascade, suggestion_index int, task_id uuid references public.tasks on delete set null,
 primary key(analysis_id,suggestion_index)
);
create function public.approve_ai_task(p_analysis_id uuid,p_index int,p_title text,p_description text,p_assignee_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare a public.ai_analyses; tid uuid;
begin
 select * into a from public.ai_analyses where id=p_analysis_id and user_id=auth.uid() and state='complete' for update;
 if not found or not public.can_access_issue(a.issue_id) then raise exception 'Analysis unavailable'; end if;
 if p_index is null or p_index<0 or p_index>=jsonb_array_length(a.result->'tasks') then raise exception 'Suggestion unavailable'; end if;
 select task_id into tid from resolve_private.approved_suggestions where analysis_id=a.id and suggestion_index=p_index;
 if found then
 if tid is null then raise exception 'The approved task was deleted'; end if;
 return tid; end if;
 tid:=public.save_task(a.issue_id,p_title,p_description,'TODO',p_assignee_id,null);
 update public.tasks set ai_generated=true where id=tid;
 insert into resolve_private.approved_suggestions values(a.id,p_index,tid);
 return tid;
end $$;
revoke all on function public.begin_ai_analysis(uuid,uuid,text,int,bigint,bigint,boolean),
 public.finish_ai_analysis(uuid,uuid,text,jsonb,text,int,int),public.approve_ai_task(uuid,int,text,text,uuid)
 from public,anon,authenticated;
grant execute on function public.begin_ai_analysis(uuid,uuid,text,int,bigint,bigint,boolean),
 public.finish_ai_analysis(uuid,uuid,text,jsonb,text,int,int) to service_role;
grant execute on function public.approve_ai_task(uuid,int,text,text,uuid) to authenticated;
commit;
