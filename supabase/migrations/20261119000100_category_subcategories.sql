-- =============================================================================
-- Migration: sub-categories of an individual category (DRG-14)
--
-- The winner of the previous week sets sub-categories for the week's category;
-- the admin enters them. While the runway is in 'werk_room' each queen picks
-- ONE of the remaining sub-categories, in the order of the ranking of the
-- previous week's runway (the best ranked queen picks first). Queens without a
-- ranking there (e.g. week 1) are ordered alphabetically by drag name, after the
-- ranked ones.
--
--   * Sub-categories are optional and only exist in individual categories
--     (group categories do not support them).
--   * A queen picks once; a sub-category can be taken by one queen only.
--   * A judge can assign a sub-category to any queen (or free a pick) at any time.
--   * Everyone who can read the category sees the sub-categories and the picks.
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- category_subcategories
-- -----------------------------------------------------------------------------
create table public.category_subcategories (
  id           uuid        primary key default gen_random_uuid(),
  category_id  uuid        not null references public.categories (id) on delete cascade,
  name         text        not null check (char_length(trim(name)) > 0),
  position     smallint    not null default 1,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- Target for the composite FK of the picks (a pick belongs to the same category)
  constraint category_subcategories_id_category_key unique (id, category_id)
);

create index category_subcategories_category_id_idx on public.category_subcategories (category_id, position);
create unique index category_subcategories_category_name_key on public.category_subcategories (category_id, lower(trim(name)));

create trigger category_subcategories_set_updated_at before update on public.category_subcategories
  for each row execute function public.set_updated_at();

-- Only individual categories have sub-categories
create or replace function public.enforce_individual_category()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.categories c where c.id = new.category_id and c.kind = 'individual'
  ) then
    raise exception 'Group categories do not have sub-categories' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger category_subcategories_enforce_individual
  before insert or update of category_id on public.category_subcategories
  for each row execute function public.enforce_individual_category();

-- An individual category cannot become a group one while it has sub-categories
create or replace function public.protect_category_kind_subcategories()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind = 'group' and old.kind = 'individual'
     and exists (select 1 from public.category_subcategories s where s.category_id = new.id) then
    raise exception 'Delete the sub-categories of the category before making it a group category' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger categories_protect_kind_subcategories
  before update of kind on public.categories
  for each row execute function public.protect_category_kind_subcategories();

-- -----------------------------------------------------------------------------
-- category_subcategory_picks: which queen has which sub-category
-- -----------------------------------------------------------------------------
create table public.category_subcategory_picks (
  id              uuid        primary key default gen_random_uuid(),
  category_id     uuid        not null,
  subcategory_id  uuid        not null,
  participant_id  uuid        not null references public.participants (id) on delete cascade,
  created_at      timestamptz not null default now(),
  constraint category_subcategory_picks_subcategory_fkey foreign key (subcategory_id, category_id)
    references public.category_subcategories (id, category_id) on delete cascade,
  -- A sub-category goes to one queen and a queen has one sub-category
  constraint category_subcategory_picks_subcategory_key unique (subcategory_id),
  constraint category_subcategory_picks_category_participant_key unique (category_id, participant_id)
);

create index category_subcategory_picks_participant_id_idx on public.category_subcategory_picks (participant_id);

-- -----------------------------------------------------------------------------
-- Privileges and RLS
--   * Judges manage the sub-categories and can free a pick directly.
--   * Picks are created ONLY by the functions below (turn order is enforced there).
-- -----------------------------------------------------------------------------
revoke all on public.category_subcategories, public.category_subcategory_picks from anon, authenticated;

grant select, insert, update, delete on public.category_subcategories     to authenticated;
grant select, delete                 on public.category_subcategory_picks to authenticated;
grant select on public.category_subcategories, public.category_subcategory_picks to service_role;

alter table public.category_subcategories     enable row level security;
alter table public.category_subcategory_picks enable row level security;

create policy category_subcategories_select on public.category_subcategories
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.category_has_status(category_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
  );

create policy category_subcategories_insert_jurado on public.category_subcategories
  for insert to authenticated
  with check ((select public.is_jurado()));

create policy category_subcategories_update_jurado on public.category_subcategories
  for update to authenticated
  using      ((select public.is_jurado()))
  with check ((select public.is_jurado()));

create policy category_subcategories_delete_jurado on public.category_subcategories
  for delete to authenticated
  using ((select public.is_jurado()));

create policy category_subcategory_picks_select on public.category_subcategory_picks
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.category_has_status(category_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
  );

create policy category_subcategory_picks_delete_jurado on public.category_subcategory_picks
  for delete to authenticated
  using ((select public.is_jurado()));

-- -----------------------------------------------------------------------------
-- subcategory_turn_order: the queens in the order they pick (turn 1 picks first)
--
-- Ranking of the previous week's runway (the one with the highest week number
-- below this one) when it is closed; queens without a place there come after,
-- alphabetically by drag name.
-- -----------------------------------------------------------------------------
create or replace function public.subcategory_turn_order(p_category_id uuid)
returns table (participant_id uuid, turn integer)
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
    ))::integer as turn
  from public.participants p
  left join standings st on st.participant_id = p.id
  where p.role = 'concursante'
    and public.can_access_category(p_category_id)
  order by turn;
$$;

revoke execute on function public.subcategory_turn_order(uuid) from public, anon;
grant  execute on function public.subcategory_turn_order(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- pick_subcategory: a queen picks a sub-category on her turn (Werk Room only)
-- -----------------------------------------------------------------------------
create or replace function public.pick_subcategory(p_subcategory_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me       uuid := (select public.current_participant_id());
  v_category uuid;
  v_next     uuid;
begin
  select s.category_id into v_category
  from public.category_subcategories s
  where s.id = p_subcategory_id;

  if v_category is null then
    raise exception 'The sub-category does not exist' using errcode = 'P0002';
  end if;
  if not public.category_has_status(v_category, array['werk_room']::public.runway_status[]) then
    raise exception 'Sub-categories can only be picked in the Werk Room' using errcode = '22023';
  end if;

  -- Serialize the picks of a category so two queens cannot take the same turn
  perform 1 from public.categories c where c.id = v_category for update;

  if not exists (select 1 from public.subcategory_turn_order(v_category) o where o.participant_id = v_me) then
    raise exception 'Only contestants can pick a sub-category' using errcode = '42501';
  end if;
  if exists (select 1 from public.category_subcategory_picks k where k.category_id = v_category and k.participant_id = v_me) then
    raise exception 'You already picked a sub-category' using errcode = '23505';
  end if;

  -- The next one to pick is the first queen in the order without a sub-category
  select o.participant_id into v_next
  from public.subcategory_turn_order(v_category) o
  where not exists (
    select 1 from public.category_subcategory_picks k
    where k.category_id = v_category and k.participant_id = o.participant_id
  )
  order by o.turn
  limit 1;

  if v_next is distinct from v_me then
    raise exception 'It is not your turn to pick' using errcode = '22023';
  end if;

  begin
    insert into public.category_subcategory_picks (category_id, subcategory_id, participant_id)
    values (v_category, p_subcategory_id, v_me);
  exception when unique_violation then
    raise exception 'That sub-category is already taken' using errcode = '23505';
  end;
end;
$$;

revoke execute on function public.pick_subcategory(uuid) from public, anon;
grant  execute on function public.pick_subcategory(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- assign_subcategory: a judge gives a sub-category to a queen (replacing hers)
-- -----------------------------------------------------------------------------
create or replace function public.assign_subcategory(p_subcategory_id uuid, p_participant_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_category uuid;
begin
  if not (select public.is_jurado()) then
    raise exception 'Only judges can assign a sub-category' using errcode = '42501';
  end if;

  select s.category_id into v_category
  from public.category_subcategories s
  where s.id = p_subcategory_id;
  if v_category is null then
    raise exception 'The sub-category does not exist' using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from public.participants p where p.id = p_participant_id and p.role = 'concursante'
  ) then
    raise exception 'Only contestants can have a sub-category' using errcode = '22023';
  end if;

  perform 1 from public.categories c where c.id = v_category for update;

  delete from public.category_subcategory_picks k
  where k.category_id = v_category and k.participant_id = p_participant_id;

  begin
    insert into public.category_subcategory_picks (category_id, subcategory_id, participant_id)
    values (v_category, p_subcategory_id, p_participant_id);
  exception when unique_violation then
    raise exception 'That sub-category is already taken: free it first' using errcode = '23505';
  end;
end;
$$;

revoke execute on function public.assign_subcategory(uuid, uuid) from public, anon;
grant  execute on function public.assign_subcategory(uuid, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Realtime: the homepage shows whose turn it is the moment somebody picks
-- -----------------------------------------------------------------------------
-- Full replica identity so DELETE events (a freed pick) can be filtered by category_id
alter table public.category_subcategories     replica identity full;
alter table public.category_subcategory_picks replica identity full;

alter publication supabase_realtime add table public.category_subcategories, public.category_subcategory_picks;

commit;
