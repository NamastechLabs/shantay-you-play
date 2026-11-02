-- =============================================================================
-- Migration: full ranking of a closed category
--
-- Same scoring and tie-breaks as category_top_three (3/2/1 points; ties by more
-- 1st-place picks, then 2nd-place picks, then the earlier look), but for every
-- voted look. Only available once the category is 'closed': during 'reveal'
-- only the Top 3 is public.
-- =============================================================================
begin;

create or replace function public.category_ranking(p_category_id uuid)
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
      sum(p.points)::integer              as total_points,
      count(*) filter (where p.place = 1) as firsts,
      count(*) filter (where p.place = 2) as seconds
    from picks p
    group by p.look_id
  )
  select
    t.look_id,
    (row_number() over (order by t.total_points desc, t.firsts desc, t.seconds desc, l.created_at, t.look_id))::integer as place,
    t.total_points
  from totals t
  join public.looks l on l.id = t.look_id
  where public.category_has_status(p_category_id, array['closed']::public.category_status[])
  order by place;
$$;

revoke execute on function public.category_ranking(uuid) from public, anon;
grant  execute on function public.category_ranking(uuid) to authenticated;

commit;
