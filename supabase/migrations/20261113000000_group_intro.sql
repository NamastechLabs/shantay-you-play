-- =============================================================================
-- Migration: intro text for groups
--
-- category_groups.intro is a free text presentation of the group. It is edited
-- by the members of the group from the Werk Room modal, only while the runway
-- is in 'werk_room'. Members cannot update category_groups directly (that stays
-- judge-only, so they cannot rename the group), so they go through
-- set_group_intro, which touches nothing but this column.
-- =============================================================================
begin;

alter table public.category_groups
  add column intro text check (intro is null or char_length(intro) <= 1000);

create or replace function public.set_group_intro(p_group_id uuid, p_intro text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category_id uuid;
begin
  select g.category_id into v_category_id
  from public.category_groups g
  where g.id = p_group_id;

  if v_category_id is null
     or public.participant_group_id(v_category_id, public.current_participant_id()) is distinct from p_group_id
     or not public.category_has_status(v_category_id, array['werk_room']::public.runway_status[]) then
    raise exception 'Not allowed to edit this group' using errcode = '42501';
  end if;

  update public.category_groups
  set intro = nullif(trim(p_intro), '')
  where id = p_group_id;
end;
$$;

revoke execute on function public.set_group_intro(uuid, text) from public, anon;
grant  execute on function public.set_group_intro(uuid, text) to authenticated;

commit;
