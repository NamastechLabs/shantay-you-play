-- =============================================================================
-- Migration: one absolute winner in runways with a group category
--
-- Until now the Top 3 of the week (votes table) and the final ranking of the group
-- category (cross vote + jury vote + band bonus) were two separate rankings, so the
-- podium shown in the reveal could differ from the results table.
--
-- Now the group ranking also counts the Top 3 of the week and the reveal podium
-- comes from that same ranking:
--
--   top3_score  = Top 3 points of the queen (3/2/1) / (3 * ballots actually cast)
--                 Only the ballots that exist count: whoever did not vote (or could
--                 not) does not lower anybody's score. 0 when nobody voted.
--   group_score = weight_cross * cross_score + weight_jury * jury_score + band_bonus
--   total       = weight_group * group_score + weight_top3 * top3_score
--
-- Runways WITHOUT a group category are unchanged: same Top 3, same final ranking.
-- In a runway with one, queens that are not in a band are listed after the band
-- members in runway_ranking (they have no group score), ordered by their Top 3 points.
--
-- The weights are named constants at the top of category_ranking_core; change them
-- there and in app/utils/groupRanking.ts.
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- category_ranking_core: the computation, with NO visibility rules.
-- Internal: only the SECURITY DEFINER functions below call it.
-- -----------------------------------------------------------------------------
create function public.category_ranking_core(p_category_id uuid)
returns table (
  participant_id uuid,
  group_id       uuid,
  cross_score    numeric,
  jury_score     numeric,
  band_bonus     numeric,
  top3_points    integer,
  top3_score     numeric,
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
      0.5::numeric as weight_cross,   -- inside the group score
      0.5::numeric as weight_jury,    -- inside the group score
      0.2::numeric as band_bonus_value,
      0.5::numeric as weight_group,   -- group score (cross + jury + bonus) in the total
      0.5::numeric as weight_top3     -- Top 3 of the week in the total
  ),
  members as (
    select m.participant_id, m.group_id
    from public.category_group_members m
    where m.category_id = p_category_id
  ),
  runway as (
    select c.runway_id from public.categories c where c.id = p_category_id
  ),
  -- Value of every ranking vote, normalized by the size of its ballot
  ranking_votes as (
    select
      v.stage,
      v.participant_id,
      (count(*) over (partition by v.stage, v.voter_id) - v.rank + 1)::numeric
        / count(*) over (partition by v.stage, v.voter_id) as value
    from public.category_ranking_votes v
    where v.category_id = p_category_id
  ),
  -- Top 3 of the week: one ballot per voter, 3/2/1 points
  ballots as (
    select count(*)::integer as n
    from public.votes v
    where v.runway_id = (select r.runway_id from runway r)
  ),
  top3 as (
    select k.participant_id, sum(k.points)::integer as points
    from (
      select v.top_1_participant_id as participant_id, 3 as points from public.votes v where v.runway_id = (select r.runway_id from runway r)
      union all
      select v.top_2_participant_id, 2 from public.votes v where v.runway_id = (select r.runway_id from runway r)
      union all
      select v.top_3_participant_id, 1 from public.votes v where v.runway_id = (select r.runway_id from runway r)
    ) k
    group by k.participant_id
  ),
  scores as (
    select
      m.participant_id,
      m.group_id,
      coalesce(round((select avg(x.value) from ranking_votes x where x.stage = 'cross' and x.participant_id = m.participant_id), 6), 0) as cross_score,
      coalesce(round((select avg(x.value) from ranking_votes x where x.stage = 'jury'  and x.participant_id = m.participant_id), 6), 0) as jury_score,
      coalesce((select r.is_winner from public.category_group_result(p_category_id) r where r.group_id = m.group_id), false) as is_winner,
      coalesce(t.points, 0) as top3_points,
      case when b.n = 0 then 0::numeric else round(coalesce(t.points, 0)::numeric / (3 * b.n), 6) end as top3_score
    from members m
    cross join ballots b
    left join top3 t on t.participant_id = m.participant_id
  ),
  totals as (
    select
      s.participant_id,
      s.group_id,
      s.cross_score,
      s.jury_score,
      s.is_winner,
      s.top3_points,
      s.top3_score,
      case when s.is_winner then c.band_bonus_value else 0::numeric end as band_bonus,
      round(
        c.weight_group * (
          c.weight_cross * s.cross_score + c.weight_jury * s.jury_score
          + case when s.is_winner then c.band_bonus_value else 0::numeric end
        ) + c.weight_top3 * s.top3_score,
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
    t.top3_points,
    t.top3_score,
    t.total,
    (rank() over (order by t.total desc, t.is_winner desc, t.jury_score desc))::integer as "position"
  from totals t;
$$;

revoke execute on function public.category_ranking_core(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- category_ranking_result: final ranking of a group category (adds top3_score),
-- visible only once the runway shows its results
-- -----------------------------------------------------------------------------
drop function public.category_ranking_result(uuid);

create function public.category_ranking_result(p_category_id uuid)
returns table (
  participant_id uuid,
  group_id       uuid,
  cross_score    numeric,
  jury_score     numeric,
  band_bonus     numeric,
  top3_score     numeric,
  total          numeric,
  "position"     integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.participant_id,
    r.group_id,
    r.cross_score,
    r.jury_score,
    r.band_bonus,
    r.top3_score,
    r.total,
    r."position"
  from public.category_ranking_core(p_category_id) r
  where exists (
    select 1
    from public.categories c
    where c.id = p_category_id
      and public.runway_results_visible(c.runway_id)
  )
  order by r."position", r.participant_id;
$$;

revoke execute on function public.category_ranking_result(uuid) from public, anon;
grant  execute on function public.category_ranking_result(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- runway_standings: the ranking of the queens of a runway, with NO visibility rules.
--   Runway with a group category and any vote on it: band members by the group
--   ranking (`position`), then the other queens by their Top 3 points.
--   Any other runway: the Top 3 ranking, exactly as before.
-- total_points is always the queen's Top 3 points.
-- Internal: only runway_top_three and runway_ranking call it.
-- -----------------------------------------------------------------------------
create function public.runway_standings(p_runway_id uuid)
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
  ),
  -- Only one group category per runway is supported
  band as (
    select r.participant_id, r."position", r.cross_score, r.jury_score, r.top3_points
    from public.category_ranking_core((
      select c.id
      from public.categories c
      where c.runway_id = p_runway_id and c.kind = 'group'
      order by c.created_at, c.id
      limit 1
    )) r
  ),
  use_band as (
    select exists (select 1 from band b where b.cross_score > 0 or b.jury_score > 0 or b.top3_points > 0) as yes
  ),
  ordered as (
    -- Band members, by the group ranking
    select b.participant_id, 0 as bucket, b."position" as band_position,
           coalesce(t.total_points, 0) as total_points, coalesce(t.firsts, 0) as firsts, coalesce(t.seconds, 0) as seconds
    from band b
    left join totals t on t.participant_id = b.participant_id
    where (select u.yes from use_band u)
    union all
    -- Everybody else (everybody, when there is no group ranking), by their Top 3 points
    select t.participant_id, 1, 0, t.total_points, t.firsts, t.seconds
    from totals t
    where not (select u.yes from use_band u)
       or not exists (select 1 from band b where b.participant_id = t.participant_id)
  )
  select
    o.participant_id,
    (row_number() over (
      order by o.bucket, o.band_position, o.total_points desc, o.firsts desc, o.seconds desc, p.created_at, o.participant_id
    ))::integer as place,
    o.total_points
  from ordered o
  join public.participants p on p.id = o.participant_id
  order by place;
$$;

revoke execute on function public.runway_standings(uuid) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Top 3 of the week (reveal) and full ranking (closed): same signatures and rules
-- as before, now fed by runway_standings
-- -----------------------------------------------------------------------------
create or replace function public.runway_top_three(p_runway_id uuid)
returns table (participant_id uuid, place integer, total_points integer)
language sql
stable
security definer
set search_path = ''
as $$
  select s.participant_id, s.place, s.total_points
  from public.runway_standings(p_runway_id) s
  -- Nothing is returned before the Top 3 is revealed, nor for a runway the caller cannot access
  where s.place <= 3
    and public.runway_results_visible(p_runway_id)
    and public.can_access_runway(p_runway_id)
  order by s.place;
$$;

create or replace function public.runway_ranking(p_runway_id uuid)
returns table (participant_id uuid, place integer, total_points integer)
language sql
stable
security definer
set search_path = ''
as $$
  select s.participant_id, s.place, s.total_points
  from public.runway_standings(p_runway_id) s
  where public.runway_has_status(p_runway_id, array['closed']::public.runway_status[])
    and public.can_access_runway(p_runway_id)
  order by s.place;
$$;

commit;
