-- =============================================================================
-- Migration: group categories (DRG-5)
--
-- A category is either 'individual' (default) or 'group'. A group category has
-- exactly two groups (position 1 and 2); the judges assign contestants to them.
--
-- Voting in a group category (separate from the runway Top 3 of queens):
--   * Group vote: only judges vote, one group per judge. The group(s) with the
--     most votes win; on a draw both groups win.
--   * Queen vote: a contestant of one group votes ONE queen (her Top 1) of the
--     rival group. The most voted queen(s) win; on a draw they share the win.
--
-- Teammates can see each other's looks while the runway is in 'werk_room'.
-- Individual ballots stay private; only the results are public (from 'reveal').
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- categories.kind
-- -----------------------------------------------------------------------------
create type public.category_kind as enum ('individual', 'group');

alter table public.categories
  add column kind public.category_kind not null default 'individual';

-- -----------------------------------------------------------------------------
-- category_groups: the two teams of a group category
-- -----------------------------------------------------------------------------
create table public.category_groups (
  id           uuid        primary key default gen_random_uuid(),
  category_id  uuid        not null references public.categories (id) on delete cascade,
  position     smallint    not null check (position in (1, 2)),
  name         text        not null check (char_length(trim(name)) > 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- At most two groups per category
  constraint category_groups_category_position_key unique (category_id, position),
  -- Target for the composite FKs below (a group belongs to the same category)
  constraint category_groups_id_category_key unique (id, category_id)
);

create trigger category_groups_set_updated_at before update on public.category_groups
  for each row execute function public.set_updated_at();

-- Only group categories have groups
create or replace function public.enforce_group_category()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.categories c where c.id = new.category_id and c.kind = 'group'
  ) then
    raise exception 'The category is not a group category' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger category_groups_enforce_group_category
  before insert or update of category_id on public.category_groups
  for each row execute function public.enforce_group_category();

-- A group category cannot go back to individual while it has groups
create or replace function public.protect_category_kind()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind = 'individual' and old.kind = 'group'
     and exists (select 1 from public.category_groups g where g.category_id = new.id) then
    raise exception 'Delete the groups of the category before making it individual' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger categories_protect_kind
  before update of kind on public.categories
  for each row execute function public.protect_category_kind();

-- -----------------------------------------------------------------------------
-- category_group_members: a contestant is in one group per category
-- -----------------------------------------------------------------------------
create table public.category_group_members (
  id              uuid        primary key default gen_random_uuid(),
  category_id     uuid        not null,
  group_id        uuid        not null,
  participant_id  uuid        not null references public.participants (id) on delete cascade,
  created_at      timestamptz not null default now(),
  constraint category_group_members_group_fkey foreign key (group_id, category_id)
    references public.category_groups (id, category_id) on delete cascade,
  constraint category_group_members_category_participant_key unique (category_id, participant_id)
);

create index category_group_members_group_id_idx       on public.category_group_members (group_id);
create index category_group_members_participant_id_idx on public.category_group_members (participant_id);

-- -----------------------------------------------------------------------------
-- Helpers (SECURITY DEFINER so policies do not recurse into their own tables)
-- -----------------------------------------------------------------------------

-- The group of a participant in a category, or null
create or replace function public.participant_group_id(p_category_id uuid, p_participant_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.group_id
  from public.category_group_members m
  where m.category_id = p_category_id
    and m.participant_id = p_participant_id;
$$;

-- Are both participants in the same group of the category?
create or replace function public.are_teammates(p_category_id uuid, p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    public.participant_group_id(p_category_id, p_a) = public.participant_group_id(p_category_id, p_b),
    false
  );
$$;

-- Are the two participants in different groups of the category?
create or replace function public.are_rivals(p_category_id uuid, p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    public.participant_group_id(p_category_id, p_a) <> public.participant_group_id(p_category_id, p_b),
    false
  );
$$;

revoke execute on function public.participant_group_id(uuid, uuid) from public, anon;
revoke execute on function public.are_teammates(uuid, uuid, uuid)   from public, anon;
revoke execute on function public.are_rivals(uuid, uuid, uuid)      from public, anon;
grant  execute on function public.participant_group_id(uuid, uuid) to authenticated;
grant  execute on function public.are_teammates(uuid, uuid, uuid)   to authenticated;
grant  execute on function public.are_rivals(uuid, uuid, uuid)      to authenticated;

-- -----------------------------------------------------------------------------
-- Votes
-- -----------------------------------------------------------------------------

-- Jury vote: one group per judge per category
create table public.category_group_votes (
  id           uuid        primary key default gen_random_uuid(),
  category_id  uuid        not null,
  voter_id     uuid        not null references public.participants (id) on delete cascade,
  group_id     uuid        not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint category_group_votes_group_fkey foreign key (group_id, category_id)
    references public.category_groups (id, category_id) on delete cascade,
  constraint category_group_votes_category_voter_key unique (category_id, voter_id)
);

create index category_group_votes_voter_id_idx on public.category_group_votes (voter_id);
create index category_group_votes_group_id_idx on public.category_group_votes (group_id);

create trigger category_group_votes_set_updated_at before update on public.category_group_votes
  for each row execute function public.set_updated_at();

-- Queen vote: a contestant's Top 1 among the queens of the rival group
create table public.category_queen_votes (
  id           uuid        primary key default gen_random_uuid(),
  category_id  uuid        not null references public.categories (id) on delete cascade,
  voter_id     uuid        not null references public.participants (id) on delete cascade,
  queen_id     uuid        not null references public.participants (id) on delete cascade,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint category_queen_votes_category_voter_key unique (category_id, voter_id),
  constraint category_queen_votes_not_self_check check (voter_id <> queen_id)
);

create index category_queen_votes_voter_id_idx on public.category_queen_votes (voter_id);
create index category_queen_votes_queen_id_idx on public.category_queen_votes (queen_id);

create trigger category_queen_votes_set_updated_at before update on public.category_queen_votes
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Privileges
-- -----------------------------------------------------------------------------
revoke all on public.category_groups, public.category_group_members,
              public.category_group_votes, public.category_queen_votes from anon, authenticated;

grant select, insert, update, delete on public.category_groups        to authenticated;
grant select, insert, delete         on public.category_group_members to authenticated;
grant select, insert                 on public.category_group_votes   to authenticated;
grant update (group_id)              on public.category_group_votes   to authenticated;
grant select, insert                 on public.category_queen_votes   to authenticated;
grant update (queen_id)              on public.category_queen_votes   to authenticated;

alter table public.category_groups        enable row level security;
alter table public.category_group_members enable row level security;
alter table public.category_group_votes   enable row level security;
alter table public.category_queen_votes   enable row level security;

-- -----------------------------------------------------------------------------
-- RLS: groups and members are managed by judges and readable wherever the
-- category is readable
-- -----------------------------------------------------------------------------
create policy category_groups_select on public.category_groups
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.category_has_status(category_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
  );

create policy category_groups_insert_jurado on public.category_groups
  for insert to authenticated
  with check ((select public.is_jurado()));

create policy category_groups_update_jurado on public.category_groups
  for update to authenticated
  using      ((select public.is_jurado()))
  with check ((select public.is_jurado()));

create policy category_groups_delete_jurado on public.category_groups
  for delete to authenticated
  using ((select public.is_jurado()));

create policy category_group_members_select on public.category_group_members
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.category_has_status(category_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
  );

-- Only concursantes can be assigned to a group
create policy category_group_members_insert_jurado on public.category_group_members
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and exists (
      select 1
      from public.participants p
      where p.id = category_group_members.participant_id
        and p.role = 'concursante'
    )
  );

create policy category_group_members_delete_jurado on public.category_group_members
  for delete to authenticated
  using ((select public.is_jurado()));

-- -----------------------------------------------------------------------------
-- RLS: ballots. Your own is always visible; everyone's once 'closed'.
-- -----------------------------------------------------------------------------
create policy category_group_votes_select on public.category_group_votes
  for select to authenticated
  using (
    voter_id = (select public.current_participant_id())
    or public.category_has_status(category_id, array['closed']::public.runway_status[])
  );

create policy category_group_votes_insert_jurado on public.category_group_votes
  for insert to authenticated
  with check (
    voter_id = (select public.current_participant_id())
    and (select public.is_jurado())
    and public.category_has_status(category_id, array['voting']::public.runway_status[])
  );

create policy category_group_votes_update_jurado on public.category_group_votes
  for update to authenticated
  using (
    voter_id = (select public.current_participant_id())
    and (select public.is_jurado())
    and public.category_has_status(category_id, array['voting']::public.runway_status[])
  )
  with check (
    voter_id = (select public.current_participant_id())
    and (select public.is_jurado())
    and public.category_has_status(category_id, array['voting']::public.runway_status[])
  );

create policy category_queen_votes_select on public.category_queen_votes
  for select to authenticated
  using (
    voter_id = (select public.current_participant_id())
    or public.category_has_status(category_id, array['closed']::public.runway_status[])
  );

-- Voter and queen must be in different groups of the category
create policy category_queen_votes_insert_own on public.category_queen_votes
  for insert to authenticated
  with check (
    voter_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['voting']::public.runway_status[])
    and public.are_rivals(category_id, voter_id, queen_id)
  );

create policy category_queen_votes_update_own on public.category_queen_votes
  for update to authenticated
  using (
    voter_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['voting']::public.runway_status[])
  )
  with check (
    voter_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['voting']::public.runway_status[])
    and public.are_rivals(category_id, voter_id, queen_id)
  );

-- -----------------------------------------------------------------------------
-- Looks: teammates can see each other's looks while preparing them (werk_room).
-- Same policy as 20261109000000_looks_hidden_until_voting.sql plus the teammate rule.
-- -----------------------------------------------------------------------------
drop policy looks_select on public.looks;

create policy looks_select on public.looks
  for select to authenticated
  using (
    (
      (select public.is_jurado())
      or participant_id = (select public.current_participant_id())
      or public.category_has_status(category_id, array['voting', 'reveal', 'closed']::public.runway_status[])
      or (
        public.category_has_status(category_id, array['werk_room']::public.runway_status[])
        and public.are_teammates(category_id, participant_id, (select public.current_participant_id()))
      )
    )
    and public.can_access_category(category_id)
  );

-- -----------------------------------------------------------------------------
-- Results (public from 'reveal'; ballots stay private)
--   category_group_result: votes per group and whether it won (draw: both win)
--   category_queen_result: the most voted queen(s) (draw: they share the win)
-- -----------------------------------------------------------------------------
create or replace function public.category_group_result(p_category_id uuid)
returns table (group_id uuid, total_votes integer, is_winner boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with totals as (
    select g.id as group_id, count(v.id)::integer as total_votes
    from public.category_groups g
    left join public.category_group_votes v on v.group_id = g.id
    where g.category_id = p_category_id
    group by g.id
  )
  select t.group_id, t.total_votes, (t.total_votes > 0 and t.total_votes = max(t.total_votes) over ())
  from totals t
  where public.category_has_status(p_category_id, array['reveal', 'closed']::public.runway_status[]);
$$;

create or replace function public.category_queen_result(p_category_id uuid)
returns table (participant_id uuid, total_votes integer)
language sql
stable
security definer
set search_path = ''
as $$
  with totals as (
    select v.queen_id, count(*)::integer as total_votes
    from public.category_queen_votes v
    where v.category_id = p_category_id
    group by v.queen_id
  )
  select t.queen_id, t.total_votes
  from totals t
  where t.total_votes = (select max(x.total_votes) from totals x)
    and public.category_has_status(p_category_id, array['reveal', 'closed']::public.runway_status[])
  order by t.queen_id;
$$;

revoke execute on function public.category_group_result(uuid) from public, anon;
revoke execute on function public.category_queen_result(uuid) from public, anon;
grant  execute on function public.category_group_result(uuid) to authenticated;
grant  execute on function public.category_queen_result(uuid) to authenticated;

commit;
