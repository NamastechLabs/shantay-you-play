-- =============================================================================
-- Migration: jury_looks (the judges' own runway look + intro per category)
--
-- Judges walk the runway too, but their looks are never voted on, so they live
-- in their own table instead of `looks`: votes, rankings and the Top 3 are
-- untouched. The homepage shows them while a category is in 'runway'.
-- Images reuse the 'runway-looks' bucket ({category_id}/{participant_id}/...).
-- =============================================================================
begin;

create table public.jury_looks (
  id              uuid        primary key default gen_random_uuid(),
  category_id     uuid        not null references public.categories (id) on delete cascade,
  participant_id  uuid        not null references public.participants (id) on delete cascade,
  image_url       text        not null,
  intro           text        not null check (char_length(trim(intro)) between 1 and 500),
  uploaded_by     uuid        default public.current_participant_id() references public.participants (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- A judge walks the runway once per category
  constraint jury_looks_category_participant_key unique (category_id, participant_id)
);

-- category_id is covered by the leading column of jury_looks_category_participant_key
create index jury_looks_participant_id_idx on public.jury_looks (participant_id);
create index jury_looks_uploaded_by_idx    on public.jury_looks (uploaded_by);

create trigger jury_looks_set_updated_at before update on public.jury_looks
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- Privileges: judges may only edit the photo/intro of an existing row
-- -----------------------------------------------------------------------------
revoke all on public.jury_looks from anon, authenticated;
grant select, insert, delete on public.jury_looks to authenticated;
grant update (image_url, intro) on public.jury_looks to authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.jury_looks enable row level security;

-- Visible once the category leaves 'draft' (same rule as looks)
create policy jury_looks_select on public.jury_looks
  for select to authenticated
  using (
    (select public.is_jurado())
    or public.category_has_status(category_id, array['runway', 'voting', 'reveal', 'closed']::public.category_status[])
  );

-- Only judges write, only for judges, and only before voting opens
create policy jury_looks_insert_jurado on public.jury_looks
  for insert to authenticated
  with check (
    (select public.is_jurado())
    and uploaded_by = (select public.current_participant_id())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
    and exists (
      select 1
      from public.participants p
      where p.id = jury_looks.participant_id
        and p.role = 'jurado'
    )
  );

create policy jury_looks_update_jurado on public.jury_looks
  for update to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
  )
  with check (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
  );

create policy jury_looks_delete_jurado on public.jury_looks
  for delete to authenticated
  using (
    (select public.is_jurado())
    and public.category_has_status(category_id, array['draft', 'runway']::public.category_status[])
  );

commit;
