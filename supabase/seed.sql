-- =============================================================================
-- Local seed data (runs on `supabase start` and `supabase db reset`).
-- Never applied to the live project: `supabase db push` ignores this file.
--
-- Every account signs in with the password `password123`, or with the
-- "Dev: entrar como…" widget. Images are seeded placeholders from picsum.photos.
--
--   jurado       ana@local.test, bea@local.test
--   concursante  carla@, dani@, eva@, fran@, gina@, hugo@ (all @local.test)
--
-- Runways: week 1 is closed (with votes), week 2 is in `runway` (jury looks and
-- queen looks visible, ready to open voting). Use /admin to move any runway to
-- another status and test voting, reveal and closing.
-- =============================================================================

-- Participants first (no login yet); the auth.users insert below links each
-- one through the `handle_new_user` trigger, which requires a confirmed email.
insert into public.participants (id, name, drag_name, email, role)
values
  ('00000000-0000-4000-8000-000000000001', 'Ana',   'Ana Conda',          'ana@local.test',   'jurado'),
  ('00000000-0000-4000-8000-000000000002', 'Bea',   'Bea Utiful',         'bea@local.test',   'jurado'),
  ('00000000-0000-4000-8000-000000000011', 'Carla', 'Carla Brillante',    'carla@local.test', 'concursante'),
  ('00000000-0000-4000-8000-000000000012', 'Dani',  'Dani Glitter',       'dani@local.test',  'concursante'),
  ('00000000-0000-4000-8000-000000000013', 'Eva',   'Eva Nescente',       'eva@local.test',   'concursante'),
  ('00000000-0000-4000-8000-000000000014', 'Fran',  'Fran Tasía',         'fran@local.test',  'concursante'),
  ('00000000-0000-4000-8000-000000000015', 'Gina',  'Gina Tónica',        'gina@local.test',  'concursante'),
  ('00000000-0000-4000-8000-000000000016', 'Hugo',  'Hugo Boss Queen',    'hugo@local.test',  'concursante');

-- Auth users (email + password login, magic links for the impersonation widget).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  p.email,
  crypt('password123', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', p.name),
  now(),
  now(),
  '', '', '', ''
from public.participants p
where p.email like '%@local.test';

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select
  gen_random_uuid(),
  u.id,
  u.id::text,
  'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  now(),
  now(),
  now()
from auth.users u
where u.email like '%@local.test';

-- Runways and categories
insert into public.runways (id, week_number, runway_date, status)
values
  ('10000000-0000-4000-8000-000000000001', 1, now() - interval '7 days', 'closed'),
  ('10000000-0000-4000-8000-000000000002', 2, now(),                      'runway');

insert into public.categories (id, runway_id, title, intro_text)
values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Cuento de hadas',  'Un clásico, pero con mucha purpurina.'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'Futuro plateado', 'Cromo, látex y mucha actitud galáctica.');

-- Queen looks: every contestant walks both runways (1–4 photos each).
insert into public.looks (category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro, uploaded_by)
select
  c.id,
  p.id,
  'https://picsum.photos/seed/' || c.id || p.id || '-1/600/800',
  case when n % 2 = 0 then 'https://picsum.photos/seed/' || c.id || p.id || '-2/600/800' end,
  case when n % 3 = 0 then 'https://picsum.photos/seed/' || c.id || p.id || '-3/600/800' end,
  case when n % 6 = 0 then 'https://picsum.photos/seed/' || c.id || p.id || '-4/600/800' end,
  'Look de ' || p.drag_name || ' para ' || c.title || '.',
  p.id
from public.categories c
cross join (
  select p.*, row_number() over (order by p.email) as n
  from public.participants p
  where p.role = 'concursante'
) p;

-- Jury looks: each judge shows one per category, with 1–4 photos.
insert into public.jury_looks (category_id, participant_id, image_url, image2_url, image3_url, image4_url, intro, uploaded_by)
select
  c.id,
  p.id,
  'https://picsum.photos/seed/jury-' || c.id || p.id || '-1/600/800',
  case when p.email = 'ana@local.test' then 'https://picsum.photos/seed/jury-' || c.id || p.id || '-2/600/800' end,
  case when p.email = 'ana@local.test' then 'https://picsum.photos/seed/jury-' || c.id || p.id || '-3/600/800' end,
  case when p.email = 'ana@local.test' then 'https://picsum.photos/seed/jury-' || c.id || p.id || '-4/600/800' end,
  'Mi interpretación de ' || c.title || ': elegancia, drama y cero miedo.',
  p.id
from public.categories c
cross join public.participants p
where p.role = 'jurado';

-- Week 1 votes (closed): contestants vote for three other queens.
insert into public.votes (runway_id, voter_id, top_1_participant_id, top_2_participant_id, top_3_participant_id)
values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000014'),
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000015'),
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000011'),
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000016'),
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000015', '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000014'),
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000013');
