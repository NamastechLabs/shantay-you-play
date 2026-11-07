-- =============================================================================
-- Migration: special guests of the jury (runway_guests)
--
-- A judge invites a participant with role 'invitado' to one or more runways.
-- While the invitation is active the guest can, for THAT runway only:
--   * see the runway, its categories, looks and jury looks (normal status rules)
--   * upload their own jury look per category (up to 4 photos + intro), in
--     'werk_room' and 'runway'
--   * vote a Top 3 like any participant (same weight, ballot stays anonymous)
-- A guest sees nothing about runways they were not invited to.
--
-- Active window: from the invitation (runway_guests.created_at) until the end of
-- the runway day (Europe/Madrid, the time zone the app uses for runway dates).
-- Runway dates changed later move the window with them.
-- Depends on 20261107000000_participant_role_invitado.sql (the enum value).
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- runway_guests
-- -----------------------------------------------------------------------------
create table public.runway_guests (
  id              uuid        primary key default gen_random_uuid(),
  runway_id       uuid        not null references public.runways (id) on delete cascade,
  participant_id  uuid        not null references public.participants (id) on delete cascade,
  invited_by      uuid        default public.current_participant_id() references public.participants (id) on delete set null,
  created_at      timestamptz not null default now(),
  -- A guest is invited once per runway
  constraint runway_guests_runway_participant_key unique (runway_id, participant_id)
);

-- runway_id is covered by the leading column of runway_guests_runway_participant_key
create index runway_guests_participant_id_idx on public.runway_guests (participant_id);
create index runway_guests_invited_by_idx     on public.runway_guests (invited_by);

-- -----------------------------------------------------------------------------
-- Helpers (security definer: they read tables the caller has no direct access to)
-- -----------------------------------------------------------------------------

-- Is the signed-in user a special guest?
create or replace function public.is_guest()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.participants p
    where p.user_id = (select auth.uid())
      and p.role = 'invitado'
  );
$$;

-- Is this participant a special guest? (used to keep guest ballots anonymous)
create or replace function public.participant_is_guest(p_participant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.participants p
    where p.id = p_participant_id
      and p.role = 'invitado'
  );
$$;

-- Does the signed-in guest have an active invitation to this runway?
create or replace function public.is_active_runway_guest(p_runway_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.runway_guests g
    join public.participants p on p.id = g.participant_id
    join public.runways r      on r.id = g.runway_id
    where g.runway_id = p_runway_id
      and p.user_id = (select auth.uid())
      and p.role = 'invitado'
      and now() >= g.created_at
      -- until midnight (Europe/Madrid) at the end of the runway day
      and now() < (((r.runway_date at time zone 'Europe/Madrid')::date + 1)::timestamp at time zone 'Europe/Madrid')
  );
$$;

-- Everyone except guests reaches every runway; a guest only the ones they are
-- actively invited to.
create or replace function public.can_access_runway(p_runway_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not public.is_guest() or public.is_active_runway_guest(p_runway_id);
$$;

create or replace function public.can_access_category(p_category_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select public.can_access_runway(c.runway_id)
      from public.categories c
      where c.id = p_category_id
    ),
    false
  );
$$;

-- Is the signed-in guest actively invited to the runway of this category?
create or replace function public.is_active_category_guest(p_category_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select public.is_active_runway_guest(c.runway_id)
      from public.categories c
      where c.id = p_category_id
    ),
    false
  );
$$;

revoke execute on function public.is_guest()                         from public, anon;
revoke execute on function public.participant_is_guest(uuid)         from public, anon;
revoke execute on function public.is_active_runway_guest(uuid)       from public, anon;
revoke execute on function public.can_access_runway(uuid)            from public, anon;
revoke execute on function public.can_access_category(uuid)          from public, anon;
revoke execute on function public.is_active_category_guest(uuid)     from public, anon;
grant  execute on function public.is_guest()                         to authenticated;
grant  execute on function public.participant_is_guest(uuid)         to authenticated;
grant  execute on function public.is_active_runway_guest(uuid)       to authenticated;
grant  execute on function public.can_access_runway(uuid)            to authenticated;
grant  execute on function public.can_access_category(uuid)          to authenticated;
grant  execute on function public.is_active_category_guest(uuid)     to authenticated;

-- -----------------------------------------------------------------------------
-- runway_guests: privileges + RLS
-- Judges manage invitations; a guest only sees their own (never anyone else's).
-- There is no update: to change an invitation, delete it and invite again.
-- -----------------------------------------------------------------------------
revoke all on public.runway_guests from anon, authenticated;
grant select, insert, delete on public.runway_guests to authenticated;

alter table public.runway_guests enable row level security;

create policy runway_guests_select on public.runway_guests
  for select to authenticated
  using (
    (select public.is_jurado())
    or participant_id = (select public.current_participant_id())
  );

-- Only participants registered as 'invitado' can be invited
create policy runway_guests_insert_jurado on public.runway_guests
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and invited_by = (select public.current_participant_id())
    and public.participant_is_guest(participant_id)
  );

create policy runway_guests_delete_jurado on public.runway_guests
  for delete to authenticated
  using ((select public.is_jurado()));

-- -----------------------------------------------------------------------------
-- Reading: a guest only reaches the runways they are invited to
-- -----------------------------------------------------------------------------
drop policy runways_select on public.runways;

create policy runways_select on public.runways
  for select to authenticated
  using (
    (status <> 'draft' or (select public.is_jurado()))
    and public.can_access_runway(id)
  );

drop policy categories_select on public.categories;

create policy categories_select on public.categories
  for select to authenticated
  using (
    (
      (select public.is_jurado())
      or public.runway_has_status(runway_id, array['werk_room', 'runway', 'voting', 'reveal', 'closed']::public.runway_status[])
    )
    and public.can_access_runway(runway_id)
  );

drop policy looks_select on public.looks;

create policy looks_select on public.looks
  for select to authenticated
  using (
    (
      (select public.is_jurado())
      or participant_id = (select public.current_participant_id())
      or public.category_has_status(category_id, array['runway', 'voting', 'reveal', 'closed']::public.runway_status[])
    )
    and public.can_access_category(category_id)
  );

drop policy jury_looks_select on public.jury_looks;

-- A guest also sees their own look while it is still being prepared
create policy jury_looks_select on public.jury_looks
  for select to authenticated
  using (
    (
      (select public.is_jurado())
      or participant_id = (select public.current_participant_id())
      or public.category_has_status(category_id, array['runway', 'voting', 'reveal', 'closed']::public.runway_status[])
    )
    and public.can_access_category(category_id)
  );

-- -----------------------------------------------------------------------------
-- Guests upload their own jury look (rows in public.jury_looks)
-- Judges keep managing every jury look through the existing *_jurado policies;
-- policies are permissive, so both sets apply side by side.
-- -----------------------------------------------------------------------------
create policy jury_looks_insert_guest on public.jury_looks
  for insert to authenticated
  with check (
    participant_id = (select public.current_participant_id())
    and uploaded_by = (select public.current_participant_id())
    and public.is_active_category_guest(category_id)
    and public.category_has_status(category_id, array['werk_room', 'runway']::public.runway_status[])
  );

create policy jury_looks_update_guest on public.jury_looks
  for update to authenticated
  using (
    participant_id = (select public.current_participant_id())
    and public.is_active_category_guest(category_id)
    and public.category_has_status(category_id, array['werk_room', 'runway']::public.runway_status[])
  )
  with check (
    participant_id = (select public.current_participant_id())
    and public.is_active_category_guest(category_id)
    and public.category_has_status(category_id, array['werk_room', 'runway']::public.runway_status[])
  );

create policy jury_looks_delete_guest on public.jury_looks
  for delete to authenticated
  using (
    participant_id = (select public.current_participant_id())
    and public.is_active_category_guest(category_id)
    and public.category_has_status(category_id, array['werk_room', 'runway']::public.runway_status[])
  );

-- -----------------------------------------------------------------------------
-- Storage: a guest manages the files in {category_id}/{their participant id}/
-- A malformed folder name fails the uuid cast, which rejects the request.
-- -----------------------------------------------------------------------------
create policy runway_looks_insert_guest on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[2] = (select public.current_participant_id())::text
    and public.is_active_category_guest(((storage.foldername(name))[1])::uuid)
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room', 'runway']::public.runway_status[])
  );

create policy runway_looks_delete_guest on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[2] = (select public.current_participant_id())::text
    and public.is_active_category_guest(((storage.foldername(name))[1])::uuid)
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room', 'runway']::public.runway_status[])
  );

-- The queens' self-upload policies (werk_room) must not let a guest write into a
-- runway they are not invited to
drop policy runway_looks_insert_own on storage.objects;
drop policy runway_looks_delete_own on storage.objects;

create policy runway_looks_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[2] = (select public.current_participant_id())::text
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room']::public.runway_status[])
    and public.can_access_category(((storage.foldername(name))[1])::uuid)
  );

create policy runway_looks_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'runway-looks'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[2] = (select public.current_participant_id())::text
    and public.category_has_status(((storage.foldername(name))[1])::uuid, array['werk_room']::public.runway_status[])
    and public.can_access_category(((storage.foldername(name))[1])::uuid)
  );

-- -----------------------------------------------------------------------------
-- votes: guests vote inside their window; their ballots stay anonymous
--   * insert/update: only for runways the guest can access (active invitation)
--   * select: once a runway is closed, ballots are readable by everyone EXCEPT
--     guest ballots, which only the guest sees (decision: anonymous for now)
-- -----------------------------------------------------------------------------
drop policy votes_select     on public.votes;
drop policy votes_insert_own on public.votes;
drop policy votes_update_own on public.votes;

create policy votes_select on public.votes
  for select to authenticated
  using (
    voter_id = (select public.current_participant_id())
    or (
      public.runway_has_status(runway_id, array['closed']::public.runway_status[])
      and not public.participant_is_guest(voter_id)
      and public.can_access_runway(runway_id)
    )
  );

create policy votes_insert_own on public.votes
  for insert to authenticated
  with check (
    voter_id = (select public.current_participant_id())
    and public.can_access_runway(runway_id)
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
    and public.can_access_runway(runway_id)
    and public.runway_has_status(runway_id, array['voting']::public.runway_status[])
  )
  with check (
    voter_id = (select public.current_participant_id())
    and public.can_access_runway(runway_id)
    and public.runway_has_status(runway_id, array['voting']::public.runway_status[])
    and (select public.current_participant_id()) not in (top_1_participant_id, top_2_participant_id, top_3_participant_id)
    and public.is_runway_contestant(runway_id, top_1_participant_id)
    and public.is_runway_contestant(runway_id, top_2_participant_id)
    and public.is_runway_contestant(runway_id, top_3_participant_id)
  );

-- -----------------------------------------------------------------------------
-- Results: guest ballots count with the same weight (3/2/1), but a guest only
-- gets results for runways they can access.
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
  -- Nothing is returned before the reveal, nor for a runway the caller cannot access
  where public.runway_has_status(p_runway_id, array['reveal', 'closed']::public.runway_status[])
    and public.can_access_runway(p_runway_id)
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
    and public.can_access_runway(p_runway_id)
  order by place;
$$;

commit;
