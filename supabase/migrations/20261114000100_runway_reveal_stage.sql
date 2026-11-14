-- =============================================================================
-- Migration: staged reveal for runways with a group category (DRG-8)
--
-- In 'reveal', a runway with a group category is revealed in two stages:
--   1. the winning band (category_group_result, public from 'reveal' as before);
--   2. the Top 3 of the week, when a judge presses the reveal button.
--
-- runways.top_three_revealed marks stage 2. Until it is true, the functions that
-- return the Top 3 of the week and the final ranking of the group category return
-- nothing, so the winner cannot be read early from the API or from other pages.
-- Runways without a group category are not staged: their Top 3 is visible as
-- soon as the status is 'reveal', exactly as before. 'closed' shows everything.
--
-- The flag resets whenever the status changes, so going back to 'voting' (or
-- re-opening a closed runway) starts a clean reveal.
-- =============================================================================
begin;

alter table public.runways
  add column top_three_revealed boolean not null default false;

-- -----------------------------------------------------------------------------
-- The flag only lives for the status it was set in
-- -----------------------------------------------------------------------------
create or replace function public.reset_top_three_revealed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    new.top_three_revealed := false;
  end if;
  return new;
end;
$$;

create trigger runways_reset_top_three_revealed
  before update of status on public.runways
  for each row execute function public.reset_top_three_revealed();

-- -----------------------------------------------------------------------------
-- Can the Top 3 and the final rankings of this runway be shown now?
-- -----------------------------------------------------------------------------
create or replace function public.runway_results_visible(p_runway_id uuid)
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
      and (
        r.status = 'closed'
        or (
          r.status = 'reveal'
          and (
            r.top_three_revealed
            or not exists (
              select 1 from public.categories c where c.runway_id = r.id and c.kind = 'group'
            )
          )
        )
      )
  );
$$;

revoke execute on function public.runway_results_visible(uuid) from public, anon;
grant  execute on function public.runway_results_visible(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Judges move a runway in 'reveal' to the Top 3 stage
-- -----------------------------------------------------------------------------
create or replace function public.reveal_runway_top_three(p_runway_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not (select public.is_jurado()) then
    raise exception 'Only judges can reveal the Top 3' using errcode = '42501';
  end if;

  update public.runways r
  set top_three_revealed = true
  where r.id = p_runway_id
    and r.status = 'reveal';

  if not found then
    raise exception 'The runway is not in reveal' using errcode = '22023';
  end if;
end;
$$;

revoke execute on function public.reveal_runway_top_three(uuid) from public, anon;
grant  execute on function public.reveal_runway_top_three(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Top 3 of the week: same as 20261107000100_runway_guests.sql, but gated by the stage
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
  -- Nothing is returned before the Top 3 is revealed, nor for a runway the caller cannot access
  where public.runway_results_visible(p_runway_id)
    and public.can_access_runway(p_runway_id)
  order by place
  limit 3;
$$;

-- -----------------------------------------------------------------------------
-- Final ranking of a group category: same as 20261114000000_group_ranking_votes.sql,
-- but only once the runway shows its results (the band winner stays public from 'reveal')
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
  where exists (
    select 1
    from public.categories c
    where c.id = p_category_id
      and public.runway_results_visible(c.runway_id)
  )
  order by "position", t.participant_id;
$$;

commit;
