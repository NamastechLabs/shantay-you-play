-- =============================================================================
-- Migration: ranking votes for group categories (DRG-8)
--
-- Group categories are decided in three votes plus a band bonus:
--   1. Bands (jury): category_group_votes / category_group_result (DRG-5, reused as is).
--   2. Cross vote ('cross'): each contestant ranks ALL the members of the rival band.
--   3. Jury runway ('jury'): each judge ranks ALL the contestants of the category.
--   4. Final ranking = weight_cross * cross + weight_jury * jury + band bonus.
--
-- Additive only: category_queen_votes and category_queen_result stay as legacy
-- (old Top 1 votes cannot be migrated: they are not complete ballots). Individual
-- categories and their tables (votes, ...) are untouched.
--
-- Only `rank` is stored; points are computed when reading, normalized so that
-- bands of different sizes are comparable: one vote is worth (N - rank + 1) / N,
-- with N = candidates on that ballot, and scores are AVERAGES across voters.
--
-- The weights and the band bonus are named constants at the top of
-- category_ranking_result; change them there and in app/utils/groupRanking.ts.
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- Stage of a ranking ballot
-- -----------------------------------------------------------------------------
create type public.ranking_stage as enum ('cross', 'jury');

-- -----------------------------------------------------------------------------
-- category_ranking_votes: one row per ranked candidate of a ballot
-- -----------------------------------------------------------------------------
create table public.category_ranking_votes (
  id              uuid                 primary key default gen_random_uuid(),
  category_id     uuid                 not null references public.categories (id) on delete cascade,
  stage           public.ranking_stage not null,
  voter_id        uuid                 not null references public.participants (id) on delete cascade,
  participant_id  uuid                 not null references public.participants (id) on delete cascade,
  rank            smallint             not null check (rank > 0),
  created_at      timestamptz          not null default now(),
  updated_at      timestamptz          not null default now(),
  constraint category_ranking_votes_category_stage_voter_rank_key
    unique (category_id, stage, voter_id, rank),
  constraint category_ranking_votes_category_stage_voter_participant_key
    unique (category_id, stage, voter_id, participant_id),
  constraint category_ranking_votes_not_self_check check (voter_id <> participant_id)
);

create index category_ranking_votes_voter_id_idx       on public.category_ranking_votes (voter_id);
create index category_ranking_votes_participant_id_idx on public.category_ranking_votes (participant_id);

create trigger category_ranking_votes_set_updated_at before update on public.category_ranking_votes
  for each row execute function public.set_updated_at();

-- Only group categories accept ranking ballots
create trigger category_ranking_votes_enforce_group_category
  before insert or update of category_id on public.category_ranking_votes
  for each row execute function public.enforce_group_category();

-- -----------------------------------------------------------------------------
-- Privileges and RLS: read only. Your own ballot is always visible; everyone's
-- once the category is 'closed'. Writes go through submit_ranking_ballot.
-- -----------------------------------------------------------------------------
revoke all on public.category_ranking_votes from anon, authenticated;
grant select on public.category_ranking_votes to authenticated;

alter table public.category_ranking_votes enable row level security;

create policy category_ranking_votes_select on public.category_ranking_votes
  for select to authenticated
  using (
    voter_id = (select public.current_participant_id())
    or public.category_has_status(category_id, array['closed']::public.runway_status[])
  );

-- -----------------------------------------------------------------------------
-- submit_ranking_ballot: validates and replaces the caller's ballot in one
-- transaction. rank = position in the array (1-based).
--   cross: the caller is a concursante of a band and ranks exactly the rival band.
--   jury:  the caller is a jurado and ranks exactly all the contestants in bands.
-- -----------------------------------------------------------------------------
create or replace function public.submit_ranking_ballot(
  p_category_id     uuid,
  p_stage           public.ranking_stage,
  p_participant_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_voter_id    uuid := (select public.current_participant_id());
  v_role        public.participant_role;
  v_voter_group uuid;
  v_expected    uuid[];
begin
  if v_voter_id is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.categories c where c.id = p_category_id and c.kind = 'group'
  ) then
    raise exception 'The category is not a group category' using errcode = '22023';
  end if;

  if not public.category_has_status(p_category_id, array['voting']::public.runway_status[]) then
    raise exception 'Voting is not open for this category' using errcode = '42501';
  end if;

  select p.role into v_role from public.participants p where p.id = v_voter_id;

  if p_stage = 'cross' then
    if v_role is distinct from 'concursante' then
      raise exception 'Only contestants cast the cross vote' using errcode = '42501';
    end if;

    v_voter_group := public.participant_group_id(p_category_id, v_voter_id);
    if v_voter_group is null then
      raise exception 'You are not assigned to a band in this category' using errcode = '42501';
    end if;

    select coalesce(array_agg(m.participant_id), '{}')
    into v_expected
    from public.category_group_members m
    where m.category_id = p_category_id
      and m.group_id <> v_voter_group;
  else
    if v_role is distinct from 'jurado' then
      raise exception 'Only judges cast the jury vote' using errcode = '42501';
    end if;

    select coalesce(array_agg(m.participant_id), '{}')
    into v_expected
    from public.category_group_members m
    where m.category_id = p_category_id;
  end if;

  -- Complete ballot: exactly the expected candidates, no duplicates, no nulls
  if p_participant_ids is null
     or cardinality(v_expected) = 0
     or cardinality(p_participant_ids) <> cardinality(v_expected)
     or (select count(distinct x.id) from unnest(p_participant_ids) as x(id)) <> cardinality(p_participant_ids)
     or exists (
       select 1
       from unnest(p_participant_ids) as x(id)
       where x.id is null or not (x.id = any (v_expected))
     )
  then
    raise exception 'The ballot must rank every candidate exactly once' using errcode = '22023';
  end if;

  delete from public.category_ranking_votes v
  where v.category_id = p_category_id
    and v.stage = p_stage
    and v.voter_id = v_voter_id;

  insert into public.category_ranking_votes (category_id, stage, voter_id, participant_id, rank)
  select p_category_id, p_stage, v_voter_id, x.id, x.ord::smallint
  from unnest(p_participant_ids) with ordinality as x(id, ord);
end;
$$;

revoke execute on function public.submit_ranking_ballot(uuid, public.ranking_stage, uuid[]) from public, anon;
grant  execute on function public.submit_ranking_ballot(uuid, public.ranking_stage, uuid[]) to authenticated;

-- -----------------------------------------------------------------------------
-- category_ranking_result: final ranking, visible from 'reveal'
--   value of a vote  = (N - rank + 1) / N, N = candidates on that ballot
--   cross_score      = average over the voters of the rival band who voted
--   jury_score       = average over the judges who voted
--   band_bonus       = band_bonus_value if the band won phase 1, else 0
--   total            = weight_cross * cross_score + weight_jury * jury_score + band_bonus
-- Order of `position`: total desc, winning band first, higher jury_score; if
-- still tied they share the position. Scores are rounded to 6 decimals so that
-- equal fractions (e.g. 2/3) compare as equal.
-- -----------------------------------------------------------------------------
create or replace function public.category_ranking_result(p_category_id uuid)
returns table (
  participant_id uuid,
  group_id       uuid,
  cross_score    numeric,
  jury_score     numeric,
  band_bonus     numeric,
  total          numeric,
  "position"     integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with constants as (
    -- Change these values to tune the competition (keep app/utils/groupRanking.ts in sync)
    select
      0.5::numeric as weight_cross,
      0.5::numeric as weight_jury,
      0.2::numeric as band_bonus_value
  ),
  members as (
    select m.participant_id, m.group_id
    from public.category_group_members m
    where m.category_id = p_category_id
  ),
  -- Value of every vote, normalized by the size of its ballot
  votes as (
    select
      v.stage,
      v.participant_id,
      (count(*) over (partition by v.stage, v.voter_id) - v.rank + 1)::numeric
        / count(*) over (partition by v.stage, v.voter_id) as value
    from public.category_ranking_votes v
    where v.category_id = p_category_id
  ),
  scores as (
    select
      m.participant_id,
      m.group_id,
      coalesce(round((select avg(x.value) from votes x where x.stage = 'cross' and x.participant_id = m.participant_id), 6), 0) as cross_score,
      coalesce(round((select avg(x.value) from votes x where x.stage = 'jury'  and x.participant_id = m.participant_id), 6), 0) as jury_score,
      coalesce((select r.is_winner from public.category_group_result(p_category_id) r where r.group_id = m.group_id), false) as is_winner
    from members m
  ),
  totals as (
    select
      s.participant_id,
      s.group_id,
      s.cross_score,
      s.jury_score,
      s.is_winner,
      case when s.is_winner then c.band_bonus_value else 0::numeric end as band_bonus,
      round(
        c.weight_cross * s.cross_score + c.weight_jury * s.jury_score
        + case when s.is_winner then c.band_bonus_value else 0::numeric end,
        6
      ) as total
    from scores s
    cross join constants c
  )
  select
    t.participant_id,
    t.group_id,
    t.cross_score,
    t.jury_score,
    t.band_bonus,
    t.total,
    (rank() over (order by t.total desc, t.is_winner desc, t.jury_score desc))::integer as "position"
  from totals t
  where public.category_has_status(p_category_id, array['reveal', 'closed']::public.runway_status[])
  order by "position", t.participant_id;
$$;

revoke execute on function public.category_ranking_result(uuid) from public, anon;
grant  execute on function public.category_ranking_result(uuid) to authenticated;

commit;
