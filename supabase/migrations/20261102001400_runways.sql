-- =============================================================================
-- Migration: runways (a night on the catwalk) group 1..N categories
--
-- Before: a category was the week (week_number + status) and ballots ranked
-- looks of that category.
-- Now:    a runway is the week (week_number, runway_date, status). Categories
--         belong to a runway and only carry title + intro. Each queen has one
--         look per category; a voter ranks a Top 3 of QUEENS per runway.
--
-- Existing data: every category becomes a runway with the SAME id, so looks,
-- jury looks and storage paths stay valid, and old look-based ballots map
-- 1:1 to queen-based ballots.
-- =============================================================================
begin;

-- The lifecycle enum now describes a runway
alter type public.category_status rename to runway_status;

-- -----------------------------------------------------------------------------
-- runways
-- -----------------------------------------------------------------------------
create table public.runways (
  id           uuid        primary key default gen_random_uuid(),
  week_number  integer     not null check (week_number > 0),
  runway_date  date        not null default current_date,
  status       public.runway_status not null default 'draft',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint runways_week_number_key unique (week_number)
);

create index runways_status_idx on public.runways (status);

create trigger runways_set_updated_at before update on public.runways
  for each row execute function public.set_updated_at();

insert into public.runways (id, week_number, runway_date, status, created_at, updated_at)
select c.id, c.week_number, c.created_at::date, c.status, c.created_at, c.updated_at
from public.categories c;

-- -----------------------------------------------------------------------------
-- categories: belong to a runway, lose week_number / status
-- -----------------------------------------------------------------------------
alter table public.categories
  add column runway_id uuid references public.runways (id) on delete cascade;

update public.categories set runway_id = id;

alter table public.categories alter column runway_id set not null;

create index categories_runway_id_idx on public.categories (runway_id);

-- The old policy reads categories.status
drop policy categories_select on public.categories;

alter table public.categories
  drop column status,
  drop column week_number;

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
create or replace function public.runway_has_status(
  p_runway_id uuid,
  p_statuses  public.runway_status[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.runways r
    where r.id = p_runway_id
      and r.status = any (p_statuses)
  );
$$;

-- Same signature as before, so the looks / jury_looks policies keep working:
-- the status of a category is the status of its runway
create or replace function public.category_has_status(
  p_category_id uuid,
  p_statuses    public.runway_status[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.categories c
    join public.runways r on r.id = c.runway_id
    where c.id = p_category_id
      and r.status = any (p_statuses)
  );
$$;

-- A valid pick has a look in at least one category of the runway
create or replace function public.is_runway_contestant(
  p_runway_id     uuid,
  p_participant_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.looks l
    join public.categories c on c.id = l.category_id
    where c.runway_id = p_runway_id
      and l.participant_id = p_participant_id
  );
$$;

revoke execute on function public.runway_has_status(uuid, public.runway_status[])  from public, anon;
revoke execute on function public.is_runway_contestant(uuid, uuid)                 from public, anon;
grant  execute on function public.runway_has_status(uuid, public.runway_status[])  to authenticated;
grant  execute on function public.is_runway_contestant(uuid, uuid)                 to authenticated;

-- -----------------------------------------------------------------------------
-- runways: privileges + RLS (drafts are only visible to judges)
-- -----------------------------------------------------------------------------
revoke all on public.runways from anon, authenticated;
grant select, insert, update, delete on public.runways to authenticated;

alter table public.runways enable row level security;

create policy runways_select on public.runways
  for select to authenticated
  using (status <> 'draft' or (select public.is_jurado()));

create policy runways_insert_jurado on public.runways
  for insert to authenticated
  with check ((select public.is_jurado()));

create policy runways_update_jurado on public.runways
  for update to authenticated
  using      ((select public.is_jurado()))
  with check ((select public.is_jurado()));

create policy runways_delete_jurado on public.runways
  for delete to authenticated
  using ((select public.is_jurado()));

-- categories: visible with their runway
create policy categories_select on public.categories
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.runway_has_status(runway_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
  );

-- -----------------------------------------------------------------------------
-- votes: now a Top 3 of queens per runway (rebuilt; old ballots are converted)
-- -----------------------------------------------------------------------------
create temporary table votes_old on commit drop as
select
  v.category_id          as runway_id,
  v.voter_id,
  l1.participant_id      as top_1_participant_id,
  l2.participant_id      as top_2_participant_id,
  l3.participant_id      as top_3_participant_id,
  v.created_at,
  v.updated_at
from public.votes v
join public.looks l1 on l1.id = v.top_1_look_id
join public.looks l2 on l2.id = v.top_2_look_id
join public.looks l3 on l3.id = v.top_3_look_id;

drop function public.category_top_three(uuid);
drop function public.category_ranking(uuid);
drop table public.votes;

create table public.votes (
  id                    uuid        primary key default gen_random_uuid(),
  runway_id             uuid        not null references public.runways (id) on delete cascade,
  voter_id              uuid        not null references public.participants (id) on delete cascade,
  top_1_participant_id  uuid        not null references public.participants (id) on delete cascade,
  top_2_participant_id  uuid        not null references public.participants (id) on delete cascade,
  top_3_participant_id  uuid        not null references public.participants (id) on delete cascade,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  -- One ballot per voter per runway
  constraint votes_runway_voter_key unique (runway_id, voter_id),
  -- The three picks must be different queens
  constraint votes_distinct_picks_check check (
    top_1_participant_id <> top_2_participant_id
    and top_1_participant_id <> top_3_participant_id
    and top_2_participant_id <> top_3_participant_id
  )
);

-- runway_id is covered by the leading column of votes_runway_voter_key
create index votes_voter_id_idx            on public.votes (voter_id);
create index votes_top_1_participant_idx   on public.votes (top_1_participant_id);
create index votes_top_2_participant_idx   on public.votes (top_2_participant_id);
create index votes_top_3_participant_idx   on public.votes (top_3_participant_id);

create trigger votes_set_updated_at before update on public.votes
  for each row execute function public.set_updated_at();

insert into public.votes (
  runway_id, voter_id, top_1_participant_id, top_2_participant_id, top_3_participant_id, created_at, updated_at
)
select runway_id, voter_id, top_1_participant_id, top_2_participant_id, top_3_participant_id, created_at, updated_at
from votes_old;

-- Voters may only change their picks, never the ballot owner or runway
revoke all on public.votes from anon, authenticated;
grant select, insert on public.votes to authenticated;
grant update (top_1_participant_id, top_2_participant_id, top_3_participant_id) on public.votes to authenticated;

alter table public.votes enable row level security;

-- Your own ballot is always visible; everyone's ballots are visible once closed
create policy votes_select on public.votes
  for select to authenticated
  using (
    voter_id = (select public.current_participant_id())
    or public.runway_has_status(runway_id, array['closed']::public.runway_status[])
  );

-- Cast a ballot only while voting is open, never for yourself, and only for
-- queens who walked this runway
create policy votes_insert_own on public.votes
  for insert to authenticated
  with check (
    voter_id = (select public.current_participant_id())
    and public.runway_has_status(runway_id, array['voting']::public.runway_status[])
    and (select public.current_participant_id()) not in (top_1_participant_id, top_2_participant_id, top_3_participant_id)
    and public.is_runway_contestant(runway_id, top_1_participant_id)
    and public.is_runway_contestant(runway_id, top_2_participant_id)
    and public.is_runway_contestant(runway_id, top_3_participant_id)
  );

create policy votes_update_own on public.votes
  for update to authenticated
  using (
    voter_id = (select public.current_participant_id())
    and public.runway_has_status(runway_id, array['voting']::public.runway_status[])
  )
  with check (
    voter_id = (select public.current_participant_id())
    and public.runway_has_status(runway_id, array['voting']::public.runway_status[])
    and (select public.current_participant_id()) not in (top_1_participant_id, top_2_participant_id, top_3_participant_id)
    and public.is_runway_contestant(runway_id, top_1_participant_id)
    and public.is_runway_contestant(runway_id, top_2_participant_id)
    and public.is_runway_contestant(runway_id, top_3_participant_id)
  );

-- No delete policy on votes: ballots can be changed while voting, not withdrawn.

-- -----------------------------------------------------------------------------
-- Results per runway. Scoring: 1st pick = 3 points, 2nd = 2, 3rd = 1. Ties are
-- broken by more 1st-place picks, then more 2nd-place picks, then the queen
-- who registered first.
--   runway_top_three: available from 'reveal' (individual ballots stay private)
--   runway_ranking:   every voted queen, only once 'closed'
-- -----------------------------------------------------------------------------
create or replace function public.runway_top_three(p_runway_id uuid)
returns table (participant_id uuid, place integer, total_points integer)
language sql
stable
security definer
set search_path = ''
as $$
  with picks as (
    select v.top_1_participant_id as participant_id, 1 as place, 3 as points from public.votes v where v.runway_id = p_runway_id
    union all
    select v.top_2_participant_id, 2, 2 from public.votes v where v.runway_id = p_runway_id
    union all
    select v.top_3_participant_id, 3, 1 from public.votes v where v.runway_id = p_runway_id
  ),
  totals as (
    select
      k.participant_id,
      sum(k.points)::integer              as total_points,
      count(*) filter (where k.place = 1) as firsts,
      count(*) filter (where k.place = 2) as seconds
    from picks k
    group by k.participant_id
  )
  select
    t.participant_id,
    (row_number() over (order by t.total_points desc, t.firsts desc, t.seconds desc, p.created_at, t.participant_id))::integer as place,
    t.total_points
  from totals t
  join public.participants p on p.id = t.participant_id
  -- Nothing is returned before the reveal
  where public.runway_has_status(p_runway_id, array['reveal', 'closed']::public.runway_status[])
  order by place
  limit 3;
$$;

create or replace function public.runway_ranking(p_runway_id uuid)
returns table (participant_id uuid, place integer, total_points integer)
language sql
stable
security definer
set search_path = ''
as $$
  with picks as (
    select v.top_1_participant_id as participant_id, 1 as place, 3 as points from public.votes v where v.runway_id = p_runway_id
    union all
    select v.top_2_participant_id, 2, 2 from public.votes v where v.runway_id = p_runway_id
    union all
    select v.top_3_participant_id, 3, 1 from public.votes v where v.runway_id = p_runway_id
  ),
  totals as (
    select
      k.participant_id,
      sum(k.points)::integer              as total_points,
      count(*) filter (where k.place = 1) as firsts,
      count(*) filter (where k.place = 2) as seconds
    from picks k
    group by k.participant_id
  )
  select
    t.participant_id,
    (row_number() over (order by t.total_points desc, t.firsts desc, t.seconds desc, p.created_at, t.participant_id))::integer as place,
    t.total_points
  from totals t
  join public.participants p on p.id = t.participant_id
  where public.runway_has_status(p_runway_id, array['closed']::public.runway_status[])
  order by place;
$$;

revoke execute on function public.runway_top_three(uuid) from public, anon;
revoke execute on function public.runway_ranking(uuid)   from public, anon;
grant  execute on function public.runway_top_three(uuid) to authenticated;
grant  execute on function public.runway_ranking(uuid)   to authenticated;

-- -----------------------------------------------------------------------------
-- Realtime: clients now follow the runway's status
-- -----------------------------------------------------------------------------
alter publication supabase_realtime add table public.runways;
alter publication supabase_realtime drop table public.categories;

commit;
