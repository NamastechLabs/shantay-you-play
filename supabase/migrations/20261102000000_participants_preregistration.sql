-- =============================================================================
-- Migration: pre-registered participants
--
-- Judges register participants (name + email) before they ever sign in. The first
-- Google sign-in with a matching email links the login (auth.users) to that record.
--
--   participants.id       own uuid, referenced by looks / votes (existing ids are kept)
--   participants.user_id  auth.users id; null until the person signs in for the first time
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- Decouple participants.id from auth.users
-- -----------------------------------------------------------------------------
alter table public.participants drop constraint if exists participants_id_fkey;
alter table public.participants alter column id set default gen_random_uuid();

alter table public.participants
  add column user_id uuid references auth.users (id) on delete set null;

-- Existing participants are all signed-in users, and their id already equals their auth id
update public.participants set user_id = id;

create unique index participants_user_id_key on public.participants (user_id);

-- -----------------------------------------------------------------------------
-- Emails: stored lowercase and unique, so first-login matching is exact
-- -----------------------------------------------------------------------------
update public.participants set email = lower(trim(email));

alter table public.participants drop constraint participants_email_key;
alter table public.participants
  add constraint participants_email_normalized_check check (email = lower(trim(email)));
create unique index participants_email_key on public.participants (email);

-- -----------------------------------------------------------------------------
-- Helpers: map the signed-in login to its participant row
-- -----------------------------------------------------------------------------
create or replace function public.current_participant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.participants p
  where p.user_id = (select auth.uid());
$$;

revoke execute on function public.current_participant_id() from public, anon;
grant  execute on function public.current_participant_id() to authenticated;

create or replace function public.is_jurado()
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
      and p.role = 'jurado'
  );
$$;

-- -----------------------------------------------------------------------------
-- First sign-in: link to the pre-registered participant with the same email,
-- or create a new contestant profile when nobody registered this email.
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(new.email));
begin
  update public.participants
  set user_id = new.id
  where email = v_email
    and user_id is null;

  if not found then
    insert into public.participants (user_id, name, email)
    values (
      new.id,
      left(
        coalesce(
          nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
          nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
          split_part(v_email, '@', 1)
        ),
        100
      ),
      v_email
    )
    on conflict do nothing;
  end if;

  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- participants: policies + privileges
-- -----------------------------------------------------------------------------
drop policy participants_update_own on public.participants;

create policy participants_update_own on public.participants
  for update to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Judges can fix names/drag names of anyone (column grant from earlier migrations: name, drag_name)
create policy participants_update_jurado on public.participants
  for update to authenticated
  using      ((select public.is_jurado()))
  with check ((select public.is_jurado()));

-- Judges register participants; user_id is never client-writable (no column grant)
create policy participants_insert_jurado on public.participants
  for insert to authenticated
  with check ((select public.is_jurado()) and user_id is null);

-- Only people who haven't signed in yet can be removed
create policy participants_delete_jurado on public.participants
  for delete to authenticated
  using ((select public.is_jurado()) and user_id is null);

grant insert (name, email, drag_name, role) on public.participants to authenticated;
grant delete on public.participants to authenticated;

-- -----------------------------------------------------------------------------
-- looks / votes: ownership now goes through participants.id instead of auth.uid()
-- -----------------------------------------------------------------------------
alter table public.looks alter column uploaded_by set default public.current_participant_id();

drop policy looks_insert_jurado on public.looks;

create policy looks_insert_jurado on public.looks
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and uploaded_by = (select public.current_participant_id())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
    and exists (
      select 1
      from public.participants p
      where p.id = looks.participant_id
        and p.role = 'concursante'
    )
  );

drop policy votes_select     on public.votes;
drop policy votes_insert_own on public.votes;
drop policy votes_update_own on public.votes;

create policy votes_select on public.votes
  for select to authenticated
  using (
    voter_id = (select public.current_participant_id())
    or public.category_has_status(category_id, array['closed']::public.category_status[])
  );

create policy votes_insert_own on public.votes
  for insert to authenticated
  with check (
    voter_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['voting']::public.category_status[])
    and not exists (
      select 1
      from public.looks l
      where l.id in (votes.top_1_look_id, votes.top_2_look_id, votes.top_3_look_id)
        and l.participant_id = (select public.current_participant_id())
    )
  );

create policy votes_update_own on public.votes
  for update to authenticated
  using (
    voter_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['voting']::public.category_status[])
  )
  with check (
    voter_id = (select public.current_participant_id())
    and public.category_has_status(category_id, array['voting']::public.category_status[])
    and not exists (
      select 1
      from public.looks l
      where l.id in (votes.top_1_look_id, votes.top_2_look_id, votes.top_3_look_id)
        and l.participant_id = (select public.current_participant_id())
    )
  );

commit;
