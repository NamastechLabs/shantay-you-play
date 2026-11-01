-- =============================================================================
-- Migration: initial schema (participants, categories, looks, votes) + RLS
-- =============================================================================
begin;

-- -----------------------------------------------------------------------------
-- Enum types
-- -----------------------------------------------------------------------------
create type public.participant_role as enum ('jurado', 'concursante');
create type public.category_status  as enum ('draft', 'runway', 'voting', 'closed');

-- -----------------------------------------------------------------------------
-- Shared trigger: keep updated_at current on every UPDATE
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- participants: 1:1 profile for each auth.users row
-- -----------------------------------------------------------------------------
create table public.participants (
  id          uuid        primary key references auth.users (id) on delete cascade,
  name        text        not null check (char_length(trim(name)) between 1 and 100),
  email       text        not null,
  role        public.participant_role not null default 'concursante',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint participants_email_key unique (email)
);

create index participants_role_idx on public.participants (role);

-- -----------------------------------------------------------------------------
-- categories: one weekly theme
-- -----------------------------------------------------------------------------
create table public.categories (
  id           uuid        primary key default gen_random_uuid(),
  week_number  integer     not null check (week_number > 0),
  title        text        not null check (char_length(trim(title)) > 0),
  intro_text   text,
  status       public.category_status not null default 'draft',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint categories_week_number_key unique (week_number)
);

create index categories_status_idx on public.categories (status);

-- -----------------------------------------------------------------------------
-- looks: one runway photo per contestant per category, uploaded by a judge
-- -----------------------------------------------------------------------------
create table public.looks (
  id              uuid        primary key default gen_random_uuid(),
  category_id     uuid        not null references public.categories (id) on delete cascade,
  participant_id  uuid        not null references public.participants (id) on delete cascade,
  image_url       text        not null,
  intro           text,
  uploaded_by     uuid        default auth.uid() references public.participants (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- A contestant walks the runway once per category
  constraint looks_category_participant_key unique (category_id, participant_id),
  -- Target for the composite FKs in votes (guarantees a voted look belongs to the voted category)
  constraint looks_id_category_key unique (id, category_id)
);

-- category_id is covered by the leading column of looks_category_participant_key
create index looks_participant_id_idx on public.looks (participant_id);
create index looks_uploaded_by_idx    on public.looks (uploaded_by);

-- -----------------------------------------------------------------------------
-- votes: a voter's Top 3 for a category
-- -----------------------------------------------------------------------------
create table public.votes (
  id             uuid        primary key default gen_random_uuid(),
  category_id    uuid        not null references public.categories (id) on delete cascade,
  voter_id       uuid        not null references public.participants (id) on delete cascade,
  top_1_look_id  uuid        not null,
  top_2_look_id  uuid        not null,
  top_3_look_id  uuid        not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- One ballot per voter per category
  constraint votes_category_voter_key unique (category_id, voter_id),
  -- The three picks must be different looks
  constraint votes_distinct_looks_check check (
    top_1_look_id <> top_2_look_id
    and top_1_look_id <> top_3_look_id
    and top_2_look_id <> top_3_look_id
  ),
  -- Composite FKs: each pick must be a look from this same category
  constraint votes_top_1_look_fkey foreign key (top_1_look_id, category_id)
    references public.looks (id, category_id) on delete cascade,
  constraint votes_top_2_look_fkey foreign key (top_2_look_id, category_id)
    references public.looks (id, category_id) on delete cascade,
  constraint votes_top_3_look_fkey foreign key (top_3_look_id, category_id)
    references public.looks (id, category_id) on delete cascade
);

-- category_id is covered by the leading column of votes_category_voter_key
create index votes_voter_id_idx   on public.votes (voter_id);
create index votes_top_1_look_idx on public.votes (top_1_look_id, category_id);
create index votes_top_2_look_idx on public.votes (top_2_look_id, category_id);
create index votes_top_3_look_idx on public.votes (top_3_look_id, category_id);

-- -----------------------------------------------------------------------------
-- updated_at triggers
-- -----------------------------------------------------------------------------
create trigger participants_set_updated_at before update on public.participants
  for each row execute function public.set_updated_at();
create trigger categories_set_updated_at before update on public.categories
  for each row execute function public.set_updated_at();
create trigger looks_set_updated_at before update on public.looks
  for each row execute function public.set_updated_at();
create trigger votes_set_updated_at before update on public.votes
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Auto-create a participant profile when a user signs in with Google for the
-- first time. Everyone starts as 'concursante'; judges are promoted manually.
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.participants (id, name, email)
  values (
    new.id,
    left(
      coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
        split_part(new.email, '@', 1)
      ),
      100
    ),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- RLS helper functions (SECURITY DEFINER so they can read tables without
-- recursing into the policies that call them)
-- -----------------------------------------------------------------------------
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
    where p.id = (select auth.uid())
      and p.role = 'jurado'
  );
$$;

create or replace function public.category_has_status(
  p_category_id uuid,
  p_statuses    public.category_status[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.categories c
    where c.id = p_category_id
      and c.status = any (p_statuses)
  );
$$;

revoke execute on function public.is_jurado()                                          from public, anon;
revoke execute on function public.category_has_status(uuid, public.category_status[]) from public, anon;
grant  execute on function public.is_jurado()                                          to authenticated;
grant  execute on function public.category_has_status(uuid, public.category_status[]) to authenticated;

-- -----------------------------------------------------------------------------
-- Column-level privileges: block privilege escalation and immutable-field edits
-- -----------------------------------------------------------------------------
-- Profiles are created by the trigger; users can only rename themselves (not change role/email)
revoke insert, update, delete on public.participants from anon, authenticated;
grant  update (name)          on public.participants to authenticated;

-- Judges may only edit the photo/intro of an existing look
revoke update on public.looks from anon, authenticated;
grant  update (image_url, intro) on public.looks to authenticated;

-- Voters may only change their picks, never the ballot owner or category
revoke update on public.votes from anon, authenticated;
grant  update (top_1_look_id, top_2_look_id, top_3_look_id) on public.votes to authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.participants enable row level security;
alter table public.categories   enable row level security;
alter table public.looks        enable row level security;
alter table public.votes        enable row level security;

-- participants -----------------------------------------------------------------
create policy participants_select_authenticated on public.participants
  for select to authenticated
  using (true);

create policy participants_update_own on public.participants
  for update to authenticated
  using      (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- categories -------------------------------------------------------------------
-- Drafts are only visible to judges
create policy categories_select on public.categories
  for select to authenticated
  using (status <> 'draft' or (select public.is_jurado()));

create policy categories_insert_jurado on public.categories
  for insert to authenticated
  with check ((select public.is_jurado()));

create policy categories_update_jurado on public.categories
  for update to authenticated
  using      ((select public.is_jurado()))
  with check ((select public.is_jurado()));

create policy categories_delete_jurado on public.categories
  for delete to authenticated
  using ((select public.is_jurado()));

-- looks ------------------------------------------------------------------------
-- Looks become visible once their category leaves 'draft'
create policy looks_select on public.looks
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.category_has_status(category_id, array['runway', 'voting', 'closed']::public.category_status[])
  );

-- Only judges upload, only for contestants, only before voting opens
create policy looks_insert_jurado on public.looks
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and uploaded_by = (select auth.uid())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
    and exists (
      select 1
      from public.participants p
      where p.id = looks.participant_id
        and p.role = 'concursante'
    )
  );

create policy looks_update_jurado on public.looks
  for update to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
  )
  with check (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
  );

-- Deleting after voting opens would cascade-delete ballots, so it is blocked
create policy looks_delete_jurado on public.looks
  for delete to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
  );

-- votes ------------------------------------------------------------------------
-- Your own ballot is always visible; everyone's ballots are visible once closed
create policy votes_select on public.votes
  for select to authenticated
  using (
    voter_id = (select auth.uid())
    or public.category_has_status(category_id, array['closed']::public.category_status[])
  );

-- Cast a ballot only while voting is open, and never for your own look
create policy votes_insert_own on public.votes
  for insert to authenticated
  with check (
    voter_id = (select auth.uid())
    and public.category_has_status(category_id, array['voting']::public.category_status[])
    and not exists (
      select 1
      from public.looks l
      where l.id in (votes.top_1_look_id, votes.top_2_look_id, votes.top_3_look_id)
        and l.participant_id = (select auth.uid())
    )
  );

create policy votes_update_own on public.votes
  for update to authenticated
  using (
    voter_id = (select auth.uid())
    and public.category_has_status(category_id, array['voting']::public.category_status[])
  )
  with check (
    voter_id = (select auth.uid())
    and public.category_has_status(category_id, array['voting']::public.category_status[])
    and not exists (
      select 1
      from public.looks l
      where l.id in (votes.top_1_look_id, votes.top_2_look_id, votes.top_3_look_id)
        and l.participant_id = (select auth.uid())
    )
  );

-- No delete policy on votes: ballots can be changed while voting, not withdrawn.

commit;
