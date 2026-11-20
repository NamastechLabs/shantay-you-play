-- =============================================================================
-- Migration: hide the sub-categories already chosen from the other queens
--
-- Queens only see the sub-categories that are still free plus their own; the
-- jury still sees every sub-category and who took it. Queens keep knowing whose
-- turn it is through `subcategory_turn_order`, which now says who has picked
-- (not what).
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- Is the sub-category visible to the current user (free, or taken by them)?
-- Security definer: the picks table is no longer readable by other queens.
-- -----------------------------------------------------------------------------
create or replace function public.subcategory_visible_to_me(p_subcategory_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.category_subcategory_picks k
    where k.subcategory_id = p_subcategory_id
      and k.participant_id is distinct from (select public.current_participant_id())
  );
$$;

revoke execute on function public.subcategory_visible_to_me(uuid) from public, anon;
grant  execute on function public.subcategory_visible_to_me(uuid) to authenticated;

drop policy category_subcategories_select on public.category_subcategories;
create policy category_subcategories_select on public.category_subcategories
  for select to authenticated
  using (
    (select public.is_jurado())
    or (
      public.category_has_status(category_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
      and public.subcategory_visible_to_me(id)
    )
  );

drop policy category_subcategory_picks_select on public.category_subcategory_picks;
create policy category_subcategory_picks_select on public.category_subcategory_picks
  for select to authenticated
  using (
    (select public.is_jurado())
    or (
      participant_id = (select public.current_participant_id())
      and public.category_has_status(category_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
    )
  );

-- -----------------------------------------------------------------------------
-- subcategory_turn_order: now also tells whether each queen has picked
-- -----------------------------------------------------------------------------
drop function public.subcategory_turn_order(uuid);

create function public.subcategory_turn_order(p_category_id uuid)
returns table (participant_id uuid, turn integer, has_picked boolean)
language sql
stable
security definer
set search_path = ''
as $$
  with this_week as (
    select r.week_number
    from public.categories c
    join public.runways r on r.id = c.runway_id
    where c.id = p_category_id
  ),
  previous as (
    select r.id
    from public.runways r, this_week w
    where r.week_number < w.week_number
      and r.status = 'closed'
    order by r.week_number desc
    limit 1
  ),
  standings as (
    select s.participant_id, s.place
    from public.runway_standings((select p.id from previous p)) s
  )
  select
    p.id as participant_id,
    (row_number() over (
      order by st.place nulls last, lower(coalesce(nullif(trim(p.drag_name), ''), p.name)), p.id
    ))::integer as turn,
    exists (
      select 1 from public.category_subcategory_picks k
      where k.category_id = p_category_id and k.participant_id = p.id
    ) as has_picked
  from public.participants p
  left join standings st on st.participant_id = p.id
  where p.role = 'concursante'
    and public.can_access_category(p_category_id)
  order by turn;
$$;

revoke execute on function public.subcategory_turn_order(uuid) from public, anon;
grant  execute on function public.subcategory_turn_order(uuid) to authenticated;

commit;
