-- =============================================================================
-- Migration: reveal stage support
--
-- During 'reveal' individual ballots stay private (votes_select only opens at
-- 'closed'), but everyone must be able to see the Top 3 of the category. A
-- SECURITY DEFINER function computes it so no ballot is exposed.
--
-- Scoring: 1st pick = 3 points, 2nd = 2, 3rd = 1. Ties are broken by more
-- 1st-place picks, then more 2nd-place picks, then the earlier look.
-- =============================================================================
begin;

-- Looks stay visible while the Top 3 is revealed
drop policy looks_select on public.looks;

create policy looks_select on public.looks
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.category_has_status(category_id, array['runway', 'voting', 'reveal', 'closed']::public.category_status[])
  );

create or replace function public.category_top_three(p_category_id uuid)
returns table (look_id uuid, place integer, total_points integer)
language sql
stable
security definer
set search_path = ''
as $$
  with picks as (
    select v.top_1_look_id as look_id, 1 as place, 3 as points from public.votes v where v.category_id = p_category_id
    union all
    select v.top_2_look_id, 2, 2 from public.votes v where v.category_id = p_category_id
    union all
    select v.top_3_look_id, 3, 1 from public.votes v where v.category_id = p_category_id
  ),
  totals as (
    select
      p.look_id,
      sum(p.points)::integer                 as total_points,
      count(*) filter (where p.place = 1)    as firsts,
      count(*) filter (where p.place = 2)    as seconds
    from picks p
    group by p.look_id
  )
  select
    t.look_id,
    (row_number() over (order by t.total_points desc, t.firsts desc, t.seconds desc, l.created_at, t.look_id))::integer as place,
    t.total_points
  from totals t
  join public.looks l on l.id = t.look_id
  -- Nothing is returned before the reveal
  where public.category_has_status(p_category_id, array['reveal', 'closed']::public.category_status[])
  order by place
  limit 3;
$$;

revoke execute on function public.category_top_three(uuid) from public, anon;
grant  execute on function public.category_top_three(uuid) to authenticated;

commit;
