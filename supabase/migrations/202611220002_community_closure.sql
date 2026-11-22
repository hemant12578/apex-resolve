-- A closed community retains its workspace, resolution rooms and evidence.
alter table public.workspaces add column if not exists community_state text
  not null default 'active' check (community_state in ('active','closing','deleted'));
