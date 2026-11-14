-- =============================================================================
-- Local seed data (runs on `supabase start` and `supabase db reset`).
-- Never applied to the live project: `supabase db push` ignores this file.
--
-- Generated from a snapshot of the live project (2026-11-14): same participants,
-- runways, categories, looks, groups and votes, with the same ids. Only two things are faked:
--   * emails: every participant gets `<first name>@local.test`;
--   * authentication: no Google/Azure identities. Every account is an email + password
--     user (password `password123`) that reuses the live `user_id`, so all references match.
-- Photos keep pointing at the live Storage bucket (public URLs), so you need internet to see them.
--
-- Accounts (all @local.test, password `password123`, or use the "Dev: entrar como…" widget):
--   jurado      fran@local.test        Javi Puta
--   concursante participante@local.test Test Drag
--   concursante daniel@local.test      Elektra Heart
--   concursante toni@local.test        Tonica Saya
--   jurado      carlos@local.test      Charly Namastech
--   concursante victor@local.test      Vicky D'Mentia
--   concursante luis@local.test        Fentanila
--   concursante matthew@local.test     La Matt Adora
--   concursante paula@local.test       Margot Montblanc
--   invitado    carol@local.test       Lolita Montiel
-- =============================================================================

-- Rows are inserted with explicit ids and links, so skip triggers (handle_new_user,
-- updated_at) and FK ordering for this session only.
set session_replication_role = replica;

-- Auth users: email + password login (the impersonation widget uses magic links).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select
  '00000000-0000-0000-0000-000000000000',
  p.user_id,
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
from (values
  ('788f1b12-4e19-4d0d-a75c-6b1d67a04dec'::uuid, 'fran@local.test', 'Fran Mellado'),
  ('e80cc44e-f27a-4f50-a046-0169c6c779d2'::uuid, 'participante@local.test', 'Participante de Test'),
  ('9c61f4d9-1714-4783-8341-f28d01d33a54'::uuid, 'daniel@local.test', 'Daniel Martinez'),
  ('71378784-663d-4ded-ab4d-fa04d055238d'::uuid, 'toni@local.test', 'Toni Celedonio'),
  ('7678809f-7f06-4574-a48c-52d6cbf91a7c'::uuid, 'carlos@local.test', 'Carlos Lorca'),
  ('87982a6f-ee21-42eb-9993-c1356a7b9afc'::uuid, 'victor@local.test', 'Victor'),
  ('c62dc0b7-3df1-4dcd-ab85-a822eff80c25'::uuid, 'luis@local.test', 'Luis'),
  ('497fb747-a74b-449d-b5ce-e63d0d909a7c'::uuid, 'matthew@local.test', 'Matthew'),
  ('5d3482f0-b54a-46a6-b1dc-b1a2ae4e04b5'::uuid, 'paula@local.test', 'Paula'),
  ('9487616e-5bbf-43a5-bd7e-bb8c5ee8ab1c'::uuid, 'carol@local.test', 'Carol')
) as p(user_id, email, name);

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

-- Participants (fake emails, live ids and user_id links)
insert into public.participants (id, name, email, role, created_at, updated_at, drag_name, user_id, avatar_url)
values
  ('360de907-a60e-4909-9ad2-7a4d97ee1de6', 'Fran Mellado', 'fran@local.test', 'jurado', '2026-11-02T15:00:14.814029+00:00', '2026-11-03T16:24:24.966146+00:00', 'Javi Puta', '788f1b12-4e19-4d0d-a75c-6b1d67a04dec', null),
  ('52d9b726-3ceb-4b6d-ae80-d1782e5837ff', 'Participante de Test', 'participante@local.test', 'concursante', '2026-11-03T18:59:18.199877+00:00', '2026-11-03T18:59:45.802653+00:00', 'Test Drag', 'e80cc44e-f27a-4f50-a046-0169c6c779d2', null),
  ('c6b93764-df06-460a-891f-a0712f72b98c', 'Daniel Martinez', 'daniel@local.test', 'concursante', '2026-11-02T14:53:09.469094+00:00', '2026-11-04T07:43:30.437566+00:00', 'Elektra Heart', '9c61f4d9-1714-4783-8341-f28d01d33a54', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/participant-avatars/c6b93764-df06-460a-891f-a0712f72b98c/84c8a35a-dce8-4315-a581-7f55d260f3b4.jpg'),
  ('703c4d74-d961-402d-9a00-8d3fc931be3f', 'Toni Celedonio', 'toni@local.test', 'concursante', '2026-11-02T08:08:10.298007+00:00', '2026-11-04T18:11:18.533122+00:00', 'Tonica Saya', '71378784-663d-4ded-ab4d-fa04d055238d', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/participant-avatars/703c4d74-d961-402d-9a00-8d3fc931be3f/7ae58781-c82a-455b-bcdc-fb22af0773da.jpg'),
  ('7678809f-7f06-4574-a48c-52d6cbf91a7c', 'Carlos Lorca', 'carlos@local.test', 'jurado', '2026-11-01T15:55:18.823202+00:00', '2026-11-04T22:15:49.883844+00:00', 'Charly Namastech', '7678809f-7f06-4574-a48c-52d6cbf91a7c', null),
  ('a95e88bf-eb83-42fe-b00a-805050e363d4', 'Victor', 'victor@local.test', 'concursante', '2026-11-02T14:53:43.708133+00:00', '2026-11-05T19:19:14.848629+00:00', 'Vicky D''Mentia', '87982a6f-ee21-42eb-9993-c1356a7b9afc', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/participant-avatars/a95e88bf-eb83-42fe-b00a-805050e363d4/75c80a99-e24f-4fe0-9535-42d1d89d3fdc.jpg'),
  ('f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'Luis', 'luis@local.test', 'concursante', '2026-11-02T14:53:27.870476+00:00', '2026-11-06T15:52:48.596997+00:00', 'Fentanila', 'c62dc0b7-3df1-4dcd-ab85-a822eff80c25', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/participant-avatars/f818ac1f-14dc-4e79-92dc-58838ec8fe98/695aec03-e335-45f2-8aff-6136df265f25.jpg'),
  ('41ef1912-ee14-4c99-a4c8-194eee4171ef', 'Matthew', 'matthew@local.test', 'concursante', '2026-11-02T14:54:05.528073+00:00', '2026-11-06T17:03:06.977617+00:00', 'La Matt Adora', '497fb747-a74b-449d-b5ce-e63d0d909a7c', null),
  ('d9678daa-27fd-46b8-9527-c029d5ba3054', 'Paula', 'paula@local.test', 'concursante', '2026-11-02T14:54:29.841151+00:00', '2026-11-07T15:01:40.188985+00:00', 'Margot Montblanc', '5d3482f0-b54a-46a6-b1dc-b1a2ae4e04b5', null),
  ('13a31e3e-704e-4363-bc98-f6c2ce422651', 'Carol', 'carol@local.test', 'invitado', '2026-11-07T14:18:08.183809+00:00', '2026-11-07T17:00:02.981115+00:00', 'Lolita Montiel', '9487616e-5bbf-43a5-bd7e-bb8c5ee8ab1c', null);

-- runways
INSERT INTO "public"."runways" ("id", "week_number", "runway_date", "status", "created_at", "updated_at", "top_three_revealed") VALUES
	('70d7201c-645f-4b78-9f4b-41b2d6dcbb9b', 3, '2026-10-11 09:00:00+00', 'closed', '2026-11-03 16:12:09.021822+00', '2026-11-03 19:34:51.940876+00', false),
	('42467692-4510-4147-b84c-f8147b4ba12d', 4, '2026-10-19 18:00:00+00', 'closed', '2026-11-02 19:57:31.841957+00', '2026-11-03 19:36:37.800935+00', false),
	('db8fefbe-e6f0-4bc9-af4b-d852b573d65d', 5, '2026-10-25 10:00:00+00', 'closed', '2026-11-02 15:43:08.938502+00', '2026-11-03 19:37:59.776637+00', false),
	('a4764bee-62cc-40c1-8045-9e5cb0b2eb69', 7, '2026-11-08 10:00:00+00', 'closed', '2026-11-03 17:23:06.025725+00', '2026-11-12 23:06:17.127629+00', false),
	('73471a75-6101-4d06-b4ad-02eb45b25e8d', 8, '2026-11-15 10:00:00+00', 'werk_room', '2026-11-08 17:27:55.307707+00', '2026-11-12 23:06:21.885782+00', false),
	('143ca48e-0702-483c-8db0-b77dc6f732e4', 2, '2026-10-04 10:00:00+00', 'closed', '2026-11-03 16:11:14.591205+00', '2026-11-03 19:42:02.479669+00', false),
	('0d9e8ce9-024e-4207-a792-3023a4aaa482', 6, '2026-11-01 10:00:00+00', 'closed', '2026-11-02 07:44:41.511548+00', '2026-11-04 18:47:19.138222+00', false),
	('bee91d18-609a-4823-987a-d21198734411', 1, '2026-09-29 17:00:00+00', 'closed', '2026-11-03 16:10:37.851641+00', '2026-11-03 19:30:07.452103+00', false);

-- categories
INSERT INTO "public"."categories" ("id", "title", "intro_text", "created_at", "updated_at", "runway_id", "kind") VALUES
	('83f2dfca-4a03-450a-b3e2-ae3d014efed9', 'El Termómetro Personal: Calor Infernal vs. Friso Polar', 'Cada reina debe demostrar su maestría y sello de identidad defendiendo su bando en solitario. Buscamos creatividad desbordante, acabados impecables y una personalidad arrolladora que conquiste el plató, manteniendo la opción de un pequeño reveal o toque sorpresa sin alterar la base del vestuario.', '2026-11-08 17:29:35.59021+00', '2026-11-13 15:01:47.335161+00', '73471a75-6101-4d06-b4ad-02eb45b25e8d', 'group'),
	('db8fefbe-e6f0-4bc9-af4b-d852b573d65d', 'Tu mejor Pokémon', 'La categoría de esta semana en nuestra pasarela más traicionera es... ¡Tu mejor Pokémon!', '2026-11-02 15:43:08.938502+00', '2026-11-02 19:52:37.776652+00', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', 'individual'),
	('0d9e8ce9-024e-4207-a792-3023a4aaa482', 'Apañatelas como puedas', 'A ver cómo convierten cuatro trapos de saldo, basura industrial y desesperación en algo que no parezca un crimen contra la moda.', '2026-11-02 07:44:41.511548+00', '2026-11-02 19:52:37.776652+00', '0d9e8ce9-024e-4207-a792-3023a4aaa482', 'individual'),
	('4237f337-ac93-4298-9764-0236b48849df', 'Eleganza Extravaganza en la Ópera', 'Eleganza Extravaganza con la obra maestra Una Noche en la Ópera de 1935 en la que derrochéis elegancia para asistir al estreno de “il trovatore“', '2026-11-02 19:58:35.504985+00', '2026-11-02 19:58:35.504985+00', '42467692-4510-4147-b84c-f8147b4ba12d', 'individual'),
	('34c7c35b-8364-470a-bf4f-dbb4bf5224bf', 'Los chicos de la banda (1970)', 'Empezamos por una tarde entretenida con las amiguis en un tardeo inspirado en la película de 1970, Los Chicos de la Banda… que vuele vuestra imaginación en un derroche de tardeo y colegueo…', '2026-11-02 19:57:57.770831+00', '2026-11-02 20:11:25.659747+00', '42467692-4510-4147-b84c-f8147b4ba12d', 'individual'),
	('7a38683d-6abf-41cd-8619-da2278ad1b0a', 'Resacón en Las Vegas', 'Finalmente amaneceréis con un look haute couture (elegante pero informal) después de una noche de desmadre como la de “Resacón en Las Vegas” después 2009 que tendréis que diseñar desde 0 si o si con estos objetos (podéis utilizar vuestra ropa interior, calzado y pelucas!!', '2026-11-02 19:59:07.494796+00', '2026-11-02 20:11:31.498419+00', '42467692-4510-4147-b84c-f8147b4ba12d', 'individual'),
	('fc6e5ce4-a589-450f-8a8a-893268a95fcd', 'Circo Deluxe', NULL, '2026-11-03 16:10:45.950922+00', '2026-11-03 16:10:45.950922+00', 'bee91d18-609a-4823-987a-d21198734411', 'individual'),
	('52a7b82b-0010-49d3-8bb0-1b7b01186d0c', 'Mis fobias no me definen', NULL, '2026-11-03 16:11:19.859911+00', '2026-11-03 16:11:19.859911+00', '143ca48e-0702-483c-8db0-b77dc6f732e4', 'individual'),
	('a61a4c4f-2002-4796-baf8-58a87c2bace4', 'Mi horóscopo', NULL, '2026-11-03 16:12:12.482196+00', '2026-11-03 16:12:26.484006+00', '70d7201c-645f-4b78-9f4b-41b2d6dcbb9b', 'individual'),
	('281ed98b-5f2c-4133-a212-0a022c52a9fa', 'Mi ascendente', NULL, '2026-11-03 16:12:33.770539+00', '2026-11-03 16:12:33.770539+00', '70d7201c-645f-4b78-9f4b-41b2d6dcbb9b', 'individual'),
	('d42ae9c4-1a37-4155-8a91-34dc89243a9c', 'Los 7 pecados capitales', 'Esta semana, nuestras reinas van a confesar todos sus pecados... ¡y la verdadera penitencia va a ser ver sus trajes! En este reto de diseño, les hemos pedido que encarnen los 7 pecados capitales y los transformen en pura alta costura.', '2026-11-03 17:23:23.241907+00', '2026-11-03 18:21:45.104388+00', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', 'individual');

-- category_groups
INSERT INTO "public"."category_groups" ("id", "category_id", "position", "name", "created_at", "updated_at", "intro") VALUES
	('58a12ace-f79f-4276-bbd7-e61d7330b88f', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', 1, 'Calor Infernal', '2026-11-13 15:02:39.181064+00', '2026-11-13 15:02:39.181064+00', NULL),
	('bda42460-cc73-48e8-9f71-82f881067dac', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', 2, 'Frio Polar', '2026-11-13 15:02:39.181064+00', '2026-11-13 15:02:39.181064+00', NULL);

-- category_group_members
INSERT INTO "public"."category_group_members" ("id", "category_id", "group_id", "participant_id", "created_at") VALUES
	('f8c43063-ab33-4211-958f-b3a3c11810bf', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', '58a12ace-f79f-4276-bbd7-e61d7330b88f', 'a95e88bf-eb83-42fe-b00a-805050e363d4', '2026-11-13 15:02:39.276472+00'),
	('628ea009-075a-4cb8-ac1b-25a4d040da3e', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', 'bda42460-cc73-48e8-9f71-82f881067dac', 'd9678daa-27fd-46b8-9527-c029d5ba3054', '2026-11-13 15:03:44.333676+00'),
	('17313803-0e9a-4689-a2cd-f2e54fbfe67a', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', '58a12ace-f79f-4276-bbd7-e61d7330b88f', '41ef1912-ee14-4c99-a4c8-194eee4171ef', '2026-11-13 15:09:42.188037+00'),
	('6434a7c6-b229-4b30-9f14-43b7a1a13976', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', '58a12ace-f79f-4276-bbd7-e61d7330b88f', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '2026-11-13 15:09:42.188037+00'),
	('e68ae04d-01f2-4212-a147-483c78aa55a4', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', 'bda42460-cc73-48e8-9f71-82f881067dac', 'c6b93764-df06-460a-891f-a0712f72b98c', '2026-11-13 15:09:42.188037+00'),
	('1da7c1db-f2d9-4de1-b652-f96b52af948a', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', 'bda42460-cc73-48e8-9f71-82f881067dac', '703c4d74-d961-402d-9a00-8d3fc931be3f', '2026-11-13 15:09:42.188037+00');

-- looks
INSERT INTO "public"."looks" ("id", "category_id", "participant_id", "image_url", "intro", "uploaded_by", "created_at", "updated_at", "image2_url", "image3_url", "image4_url") VALUES
	('08b482ea-feaf-4189-8572-a19a6ae62dda', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/c6b93764-df06-460a-891f-a0712f72b98c/b27eed97-e1a8-4571-bc09-2dd899964060.webp', 'Mi Pokémon es Toxtricity, una criatura eléctrica y venenosa que convierte el caos en música y la rebeldía en poder. ⚡💜

Y si hay alguien capaz de compartir esa energía, esa soy yo: Elektra Heart. Un corazón que late a ritmo de rock, una descarga que no pide permiso y una actitud que no entiende de límites.

Pero hasta la electricidad más salvaje tiene un origen… y el mío es Toxel, esa pequeña criatura que llevaba una tormenta dentro antes de convertirse en una auténtica bestia del rock.

Hoy no', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:45:20.951533+00', '2026-11-02 15:45:34.13218+00', NULL, NULL, NULL),
	('72a6ab30-c32e-47ac-b2be-f293785cf14a', '0d9e8ce9-024e-4207-a792-3023a4aaa482', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/a95e88bf-eb83-42fe-b00a-805050e363d4/dcaeeb7e-0cff-4b58-ad99-76551e81a552.webp', 'El precio de la belleza.
Mi look representa la belleza envasada al vacío:
He transformado el plástico y el celofán en alta costura porque, en esta sociedad, hasta para ser guapa hay que venir bien empaquetada.
Mi silueta es la de una transformación: la de quien quiere dejar de sentirse como un patito feo para ser un cisne. Pero todo cambio tiene un precio: alguna que otra herida, plumas arrancadas y parte de la esencia perdida para encajar en un ideal que nunca fue suyo. Ya no hay sonrisa.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 14:55:28.284505+00', '2026-11-02 14:55:28.284505+00', NULL, NULL, NULL),
	('153d7551-1c63-40ab-a10d-51d66eea2436', '0d9e8ce9-024e-4207-a792-3023a4aaa482', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/d9678daa-27fd-46b8-9527-c029d5ba3054/07ecb481-5dbe-4792-bdf2-f866003dbbc6.webp', 'Me quitaron las paredes, las puertas y hasta las llaves de mi hogar.
Me dejaron sin techo, pero jamás consiguieron dejarme sin corona.
De los vaqueros que un día vistieron mi vida, he reconstruido mi reino. Cada costura guarda una herida, cada retal cuenta una historia y cada llave representa una puerta que ya nadie podrá cerrarme.
Porque podrán desahuciarme de una casa, podrán arrebatarme cuatro paredes…pero jamás podrán desalojar a Margot Montblanc de ser una auténtica reina.
Hoy, de las ruin', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 14:56:18.487583+00', '2026-11-02 14:56:18.487583+00', NULL, NULL, NULL),
	('55db0e8d-e06c-4741-806e-a967359b4019', '0d9e8ce9-024e-4207-a792-3023a4aaa482', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/41ef1912-ee14-4c99-a4c8-194eee4171ef/3ff051bc-1c38-4f39-8124-2528e0286926.webp', 'Desde otra galaxia llega La Matt Adora, una criatura de elegancia extraterrestre que convierte los desechos del universo en alta costura. Su look está inspirado en las mantas térmicas metálicas, transformadas en una armadura de destellos dorados y plateados, con una silueta escultórica, afilada y futurista.
Una melena perfectamente integrada en su corona alienígena, orejas puntiagudas y una mirada radiactiva completan esta fantasía intergaláctica.
Porque La Matt Adora no viene de este mundo: v', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 14:56:24.054383+00', '2026-11-02 14:56:24.054383+00', NULL, NULL, NULL),
	('bf097772-90a7-4b00-a755-98179161fbd8', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/f818ac1f-14dc-4e79-92dc-58838ec8fe98/c36ed702-f26e-4a48-9f63-c7eee52fd19f.webp', 'Hoy en pasarela os traigo a Mewtwo en su mega evolución Y :un Pokémon creado genéticamente en un laboratorio, igual que yo llegué al mundo gracias a la fecundación in vitro.
Mewtwo nació de la ciencia, y mi historia también comenzó gracias a ella.

Al principio Mewtwo sentía que no encajaba y durante mucho tiempo, yo también me sentí así. Intentaba entender quién era, qué sentía y por qué me costaba tanto encontrarme a mí mismo. 

 Al final comprendí que no necesitaba parecerme a nadie, ni cumpl', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:45:59.35559+00', '2026-11-02 15:46:09.743105+00', NULL, NULL, NULL),
	('041527aa-3d1a-4c4f-bddf-d38b3cf9b141', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/41ef1912-ee14-4c99-a4c8-194eee4171ef/b323992f-81da-4bde-a460-dbca416646d7.webp', 'Elegí a Gengar para representar esa parte de mí que quiero liberar: una versión de mí mismo más atrevida, poderosa, caótica y completamente libre.

En mi día a día, me considero una persona independiente, empática, intuitiva y observadora. Suelo fijarme en los pequeños detalles, percibir las emociones de los demás y analizar demasiado las situaciones, hasta el punto de que, a veces, mis propios pensamientos terminan frenándome.

Este look representa el contraste entre quién soy y quién quiero ll', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:46:23.743372+00', '2026-11-02 15:46:32.391183+00', NULL, NULL, NULL),
	('d5fd003d-f09e-4738-8d3c-7c7d62e5f4bb', '0d9e8ce9-024e-4207-a792-3023a4aaa482', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/c6b93764-df06-460a-891f-a0712f72b98c/2c4f6207-925d-4cef-8554-d241ba30c8cc.webp', 'Esta noche, cariño, no vengo a buscar la absolución. Vengo a representar todos vuestros pecados.
He transformado el cuero en una segunda piel, una armadura de poder y sensualidad, con volúmenes arquitectónicos, espinas doradas y un corazón sagrado que late entre las sombras.
Mi halo no es símbolo de santidad, sino de superioridad. Mis púas no protegen mi inocencia: advierten de mi peligro.
Soy la devoción hecha tentación, el pecado convertido en arte y la prueba de que hasta los ángeles puede', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 14:57:07.576398+00', '2026-11-03 19:39:15.271062+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/c6b93764-df06-460a-891f-a0712f72b98c/9fa324cc-b655-4a4c-8872-f521ce144ce9.webp', NULL, NULL),
	('30eb557c-be06-4e3e-a08d-5050466bc2ae', '0d9e8ce9-024e-4207-a792-3023a4aaa482', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/f818ac1f-14dc-4e79-92dc-58838ec8fe98/3c9031c7-10ba-480c-9626-df72d1cee297.webp', '‘Las flores de esta ciudad no huelen a na’ ¿Porque será?’ 🎶 (by Rosalía)
Pues porque son de papel cariño.
¿Qué hay más frágil que el papel y la flor de sakura?
Hoy os traigo un vestido íntegramente de papel y cartón. 
Detrás llevo un gran capullo apunto de florecer y flores de sakura hechas con la técnica milenaria de origami.
El papel puede rasgarse y destruirse con facilidad, igual que los delicados pétalos de la flor de cerezo.
Mi look es un homenaje a la fragilidad, porque incluso aquello', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 14:57:08.662344+00', '2026-11-03 19:39:24.80459+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/f818ac1f-14dc-4e79-92dc-58838ec8fe98/f25c66d6-0663-453e-9716-5d1dcc99c92a.webp', NULL, NULL),
	('68fa0a8a-2854-4dd8-9861-42cbc3a74334', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/a95e88bf-eb83-42fe-b00a-805050e363d4/d79ecda0-e21b-49aa-90c4-431d7c7cf715.webp', 'Soy fuerte contra el veneno… pero tengo una debilidad: los bichos y los fantasmas. Y, por lo que veo, esta pasarela está plagada de ellos. Así que sí, cariño, por primera vez Vicky D’Mentia está en peligro.

Os presento a Jynx, una deidad del hielo y la mente. Extraña, magnética y poderosa; capaz de hechizarte con una mirada y congelarte con un beso.

He elegido a Jynx porque, como ella, nunca he querido borrar aquello que me hace diferente. Mi bigote, mis rasgos masculinos, mi manera de jugar c', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:47:04.257022+00', '2026-11-02 15:47:12.465505+00', NULL, NULL, NULL),
	('d65271e9-6e1f-4ac4-86b1-c40435beb6c9', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/703c4d74-d961-402d-9a00-8d3fc931be3f/5dd1ad25-aae0-465c-a4a2-6ca819aea406.webp', 'Nací entre sombras, aprendí a resistir, con mil cicatrices que oculté al mundo; pero ni el dolor me impidió seguir, ni apagó mi luz en lo más profundo.

Como Diancie, fui cristal por forjar, princesa de un reino de sueños heridos; hice de mis grietas diamantes de amar, y abrí nuevos caminos jamás recorridos.

Hoy vengo de rosa, diamante y pasión, con corona de reina y destellos de gloria; Tonica Saya convierte en creación cada piedra del camino de su historia.

¡Que tiemble la pasarela, que bril', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:47:23.141874+00', '2026-11-02 15:47:30.746379+00', NULL, NULL, NULL),
	('3163e90c-8d70-426b-94ea-4271a5b2350c', '34c7c35b-8364-470a-bf4f-dbb4bf5224bf', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/34c7c35b-8364-470a-bf4f-dbb4bf5224bf/703c4d74-d961-402d-9a00-8d3fc931be3f/9e3dc568-c71a-40f1-930a-7e40bc4b1982.webp', 'Por la tarde, con las chicas, arranca el guateque,
martini, ligoteo y algún que otro magreo en el retrete.
Con tanto meneíto y tanto macho alrededor,
¡Tonica acaba coronada como reina del calentón!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:00:36.688609+00', '2026-11-02 20:00:44.270686+00', NULL, NULL, NULL),
	('5fc5c04f-a230-47e3-b284-a246ab903162', '4237f337-ac93-4298-9764-0236b48849df', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/4237f337-ac93-4298-9764-0236b48849df/703c4d74-d961-402d-9a00-8d3fc931be3f/18b6eb8d-eb86-477e-8262-00b5bbaf3dee.webp', 'De largo llega la Femme Fatale, ¡qué diva tan divina!,
entra en la Ópera y hasta la orquesta se arrodilla.
Entre arias, abanicos y algún galán descarriado,
¡Tonica roba el espectáculo y deja al tenor afónico y enamorado!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:01:00.669386+00', '2026-11-02 20:01:09.818469+00', NULL, NULL, NULL),
	('4120c95b-1034-4e2d-bb70-f35d7301c9ee', '7a38683d-6abf-41cd-8619-da2278ad1b0a', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/7a38683d-6abf-41cd-8619-da2278ad1b0a/703c4d74-d961-402d-9a00-8d3fc931be3f/f5cb7845-95f4-40c4-b689-d1d20e8cea84.webp', 'Amanece en Las Vegas: despeinada y sin memoria,
con la peluca hecha un cuadro y un tatuaje de otra historia.
No sabe de quién es el condón, ni dónde está el sujetador,
¡pero hasta en plena resaca sigue siendo la mejor!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:01:20.347771+00', '2026-11-02 20:01:28.270195+00', NULL, NULL, NULL),
	('7c3d2e16-aedd-4595-9873-30a129c18199', '34c7c35b-8364-470a-bf4f-dbb4bf5224bf', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/34c7c35b-8364-470a-bf4f-dbb4bf5224bf/a95e88bf-eb83-42fe-b00a-805050e363d4/cbbd76dc-6715-4e0b-9822-a36ef73ba92d.webp', 'Tres looks, tres películas y una sola protagonista. Setenta, psicodelia y amigas. 
Cariñas, hemos quedado para un tardeo… y yo traigo el estampado, el volumen y la personalidad. Vosotras traéis ansiedad y un vestido de rebajas.
¡Paz, amor y mucho veneno, perras!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:06:03.892193+00', '2026-11-02 20:06:16.34305+00', NULL, NULL, NULL),
	('0f796907-2d4c-450a-b748-05dc82d0acc6', '4237f337-ac93-4298-9764-0236b48849df', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/4237f337-ac93-4298-9764-0236b48849df/d9678daa-27fd-46b8-9527-c029d5ba3054/5de3c267-a1c2-4a33-9300-92328f300d71.webp', 'Inspirado en el glamour de Hollywood y la estética Art Déco de 1935, este look evoca a la Margot Montblanc que acudiría en esa época al estreno de Il trovatore. El satén champán, la estola de pelo, los guantes largos y las ondas esculpidas reflejan la elegancia y sofisticación de la época. Porque ella no va a ver el espectáculo: ella ES el espectáculo.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:02:22.622029+00', '2026-11-02 20:02:31.154981+00', NULL, NULL, NULL),
	('e6d2547d-3479-458d-8b12-b3e18abe5829', '34c7c35b-8364-470a-bf4f-dbb4bf5224bf', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/34c7c35b-8364-470a-bf4f-dbb4bf5224bf/d9678daa-27fd-46b8-9527-c029d5ba3054/984064e0-4cc3-4404-a9a7-57b149f27c7a.webp', 'Mi look está inspirado en los años 70 recuperando la sastrería masculina, los pantalones acampanados y una sensualidad elegante y nocturna.

He querido llevarlo hacia una estética andrógina y lesbiana, haciendo que mi propia identidad también forme parte del look. Para mí, la masculinidad puede ser sexy, sofisticada y queer. No quería simplemente representar una época, sino reinterpretarla desde quien soy, reivindicando esa forma de expresión en la que lo masculino y lo femenino conviven sin pedir permiso.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:01:48.526137+00', '2026-11-02 20:05:40.925813+00', NULL, NULL, NULL),
	('b7bd4d9e-f375-43a9-9cb1-56026c84356c', '7a38683d-6abf-41cd-8619-da2278ad1b0a', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/7a38683d-6abf-41cd-8619-da2278ad1b0a/d9678daa-27fd-46b8-9527-c029d5ba3054/a7f727ce-63aa-4968-8440-5745b182bdee.webp', 'Hoy Margot Montblanc se convierte en la santa de la última copa.
Una resaca convertida en alta costura. Naipes afilados, botellas de alcohol, una dentadura postiza como joya central y los restos de una noche desenfrenada construyen una armadura de exceso y decadencia. El preservativo usado y el tatuaje completan la historia de una noche en Las Vegas que nadie recuerda, pero que mi look jamás permitirá olvidar.
Porque después de una noche de caos, el verdadero lujo es desfilar como si nada hubiera pasado.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:02:42.627342+00', '2026-11-02 20:05:20.931562+00', NULL, NULL, NULL),
	('0d3ee710-4b60-4cac-a858-bf8f8525aa2c', '4237f337-ac93-4298-9764-0236b48849df', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/4237f337-ac93-4298-9764-0236b48849df/a95e88bf-eb83-42fe-b00a-805050e363d4/abaa4a37-324e-4a56-8c86-67cc75394f91.webp', 'Después del tardeo, una dama de mi categoría no se va a casa. Se va a la ópera, cariño. Concretamente, a Una noche en la ópera, porque para escuchar desafinar ya tengo a algunas de mis compañeras intentando defender sus looks.
Esto es Hollywood de 1935: elegancia, misterio y una cantidad obscena de dinero imaginario.
Y recordad, muñecas: el glamour no se compra… aunque viendo algunos de vuestros outfits, tampoco se alquila.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:06:27.908697+00', '2026-11-02 20:06:35.319847+00', NULL, NULL, NULL),
	('8918fa6e-c6c9-494d-8e45-bc81f80c080b', '7a38683d-6abf-41cd-8619-da2278ad1b0a', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/7a38683d-6abf-41cd-8619-da2278ad1b0a/a95e88bf-eb83-42fe-b00a-805050e363d4/4a38a18b-c8a1-4527-9473-667c72e1a7a4.webp', 'Y después de la ópera… Las Vegas, cariño. Porque hasta las divas necesitamos tomar malas decisiones para tener algo de lo que hablar en el confesionario.
No recuerdo el final de la noche, pero sí recuerdo que alguien perdió la dignidad. Elektra me debe la tintorería, aunque no es la primera vez que me vomita encima.
Yo he vuelto con las botas manchadas, el maquillaje derretido, cartas pegadas al vestido y un bolso que tiene más lengua que todas vosotras juntas.
¿Que si me arrepiento? ¡Cariña, me arrepiento de no haber apostado por mí antes!
¡Que pase la siguiente, que necesito ver si alguien ha traído un look o solamente una excusa!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:06:45.246827+00', '2026-11-02 20:07:08.928591+00', NULL, NULL, NULL),
	('0555e9da-fccf-48e0-90ba-95ef2975273d', '34c7c35b-8364-470a-bf4f-dbb4bf5224bf', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/34c7c35b-8364-470a-bf4f-dbb4bf5224bf/41ef1912-ee14-4c99-a4c8-194eee4171ef/b7259258-9260-46ec-b621-98f7ef13fa1c.webp', '“No words. Just hangover.” 💅�', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:07:24.277825+00', '2026-11-02 20:07:38.5973+00', NULL, NULL, NULL),
	('7882f15b-1d4c-4c8e-97b0-c6ab45b67594', '4237f337-ac93-4298-9764-0236b48849df', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/4237f337-ac93-4298-9764-0236b48849df/41ef1912-ee14-4c99-a4c8-194eee4171ef/f3220950-b5c2-4280-b355-d49444bf4ebd.webp', 'No words. Just hangover.” 💅�', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:07:48.175101+00', '2026-11-02 20:07:57.411975+00', NULL, NULL, NULL),
	('e9b55bcd-b8a9-4900-a1ca-4eec20896f0d', '7a38683d-6abf-41cd-8619-da2278ad1b0a', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/7a38683d-6abf-41cd-8619-da2278ad1b0a/41ef1912-ee14-4c99-a4c8-194eee4171ef/9950ebe2-7232-4ed2-ac40-50e93232b276.webp', '“No words. Just hangover.” 💅�', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:08:06.764477+00', '2026-11-02 20:08:14.625981+00', NULL, NULL, NULL),
	('1951d402-ba92-479a-8e46-699a0ee612c4', '34c7c35b-8364-470a-bf4f-dbb4bf5224bf', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/34c7c35b-8364-470a-bf4f-dbb4bf5224bf/c6b93764-df06-460a-891f-a0712f72b98c/f72ee413-0a1a-4eb9-b398-a2c33b6ec7eb.webp', 'Del pecado pasamos al palco, porque una auténtica diva no se conforma con ser mirada: exige ser adorada.

El negro es mi misterio, las plumas mi dramatismo y el burdeos la pasión que ni los años ni los desengaños han conseguido apagar. Mi corazón tiene sus mecanismos de seguridad, pero mi ambición no conoce límites.

Recordad, queridos: mi corazón puede tener sus fallos; mi entrada triunfal, jamás.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:08:31.952891+00', '2026-11-02 20:08:43.622197+00', NULL, NULL, NULL),
	('dc775c72-3e14-4ff8-a100-7b24cb6777bb', '4237f337-ac93-4298-9764-0236b48849df', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/4237f337-ac93-4298-9764-0236b48849df/c6b93764-df06-460a-891f-a0712f72b98c/cf781640-7320-4006-8fcd-770beced49fa.webp', 'No words', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:08:53.759376+00', '2026-11-02 20:09:54.622017+00', NULL, NULL, NULL),
	('0464b718-5d84-424b-86a8-db0ac5dcfb3a', '7a38683d-6abf-41cd-8619-da2278ad1b0a', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/7a38683d-6abf-41cd-8619-da2278ad1b0a/c6b93764-df06-460a-891f-a0712f72b98c/03302042-f0eb-4244-a4fe-fa4933c7dbaa.webp', 'Y después de tanta elegancia… llegó Las Vegas. Cariño, tengo lagunas mentales, el maquillaje en otra zona horaria y una dentadura que no sé si es mía.
Las cartas están sobre la bata, los tacones han dimitido y mi corazón pide agua. Pero aquí sigo: despeinada, descalza y con el burdeos puesto, porque una puede perder la dignidad durante una noche… pero jamás el protagonismo.
I’m not your mother! Soy Elektra Heart, y si la vida me da descargas… ¡yo le devuelvo el electrocardiodrama!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:09:13.730127+00', '2026-11-02 20:09:31.212562+00', NULL, NULL, NULL),
	('b24207e3-ae0b-4f24-be86-8ab54dbb3366', '34c7c35b-8364-470a-bf4f-dbb4bf5224bf', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/34c7c35b-8364-470a-bf4f-dbb4bf5224bf/f818ac1f-14dc-4e79-92dc-58838ec8fe98/ba667869-5679-4e85-b8de-ef8fd5185487.webp', 'Los años 70 fueron mucho más que pantalones de campana, colores vibrantes y música disco. Fueron años de lucha, de revolución y de personas que se atrevieron a reclamar el derecho a ser ellas mismas.
Hoy en pasarela rindo homenaje con la bandera LGTBIQ+ hecha cuerdas en mi chaqueta a todas aquellas personas del colectivo gay y trans que alzaron la voz cuando el mundo todavía intentaba silenciarlas.
Porque gracias a que esas personas caminaron en su día, hoy podemos correr.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:10:04.592044+00', '2026-11-02 20:10:16.383508+00', NULL, NULL, NULL),
	('e39fd5aa-bfb5-425b-af6b-444f40dcfda6', '7a38683d-6abf-41cd-8619-da2278ad1b0a', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/7a38683d-6abf-41cd-8619-da2278ad1b0a/f818ac1f-14dc-4e79-92dc-58838ec8fe98/7a242e14-81fb-4426-b22f-4d4a15b28fde.webp', '¡Para noches de desenfreno, mañanas de ibuprofeno!  
¡Puta resaca…..madre mía anoche iba volando!
No me acuerdo si me puse el condón, creo recordar que me acosté con 2 abuelos porque se han dejado la dentadura en la mesilla de noche….', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:10:54.03273+00', '2026-11-02 20:11:01.746504+00', NULL, NULL, NULL),
	('7d81fa85-293d-4850-b3e1-80c5a7945008', 'fc6e5ce4-a589-450f-8a8a-893268a95fcd', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/c6b93764-df06-460a-891f-a0712f72b98c/b817d184-f511-4cc5-9cca-9d775fc02b46.webp', 'Yo esta semana soy el circo, lo soy todo y dentro os contengo a cada uno de vosotros porque una parte de vosotros vive siempre en mí. 
Es mi forma de daros las gracias por formar parte de mi vida. Gracias perras!!!', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:20:26.400722+00', '2026-11-03 16:22:43.633966+00', NULL, NULL, NULL),
	('d978b966-3adc-45dd-b519-5aa22d6d71bc', 'fc6e5ce4-a589-450f-8a8a-893268a95fcd', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/f818ac1f-14dc-4e79-92dc-58838ec8fe98/ec5d289d-ad86-4332-8317-7c709ee9fe73.webp', 'El circo representa un mundo de luces, colores y seguridad, pero detrás de todo ese espectáculo puede esconderse una realidad oscura. Esta idea también refleja una parte de mí: exteriormente puedo parecer una persona segura, fuerte y llena de confianza, pero detrás de esa apariencia hay una persona insegura y vulnerable. Por eso, he elegido como inspiración una carpa de circo: grande, llamativa y espectacular por fuera, pero cuando entramos en ella, descubrimos que realmente es mucho más pequeña', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:20:42.400221+00', '2026-11-03 16:23:03.221589+00', NULL, NULL, NULL),
	('56490edd-ea81-43e2-b9c1-b5e3746e6264', '4237f337-ac93-4298-9764-0236b48849df', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/4237f337-ac93-4298-9764-0236b48849df/f818ac1f-14dc-4e79-92dc-58838ec8fe98/8866aab1-f174-4b5f-adf2-d271753f7863.webp', NULL, '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 20:10:26.387585+00', '2026-11-03 19:36:11.120996+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/4237f337-ac93-4298-9764-0236b48849df/f818ac1f-14dc-4e79-92dc-58838ec8fe98/7b4434ec-5907-46a8-a4a8-ce882b371a14.webp', NULL, NULL),
	('4fe3bc9e-f9b8-4218-8cf3-2fb8b9e4787b', 'fc6e5ce4-a589-450f-8a8a-893268a95fcd', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/41ef1912-ee14-4c99-a4c8-194eee4171ef/0b1519b7-2b76-46fa-ab3b-3a14aac5c04a.webp', 'Nos pintamos el rostro, nos ponemos nuestros disfraces y aprendemos nuestros guiones. Como mimos, contamos historias enteras sin pronunciar una sola palabra. Fingimos que las paredes invisibles son reales, sonreímos en medio del silencio y nos convencemos de que el papel que interpretamos es realmente quienes somos.

Pero detrás de cada expresión pintada hay una persona preguntándose dónde termina la actuación y dónde comienza la realidad.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:21:36.092204+00', '2026-11-03 19:28:30.762395+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/41ef1912-ee14-4c99-a4c8-194eee4171ef/8a5cc7de-c8b5-454a-9bbf-22d3420a86e6.webp', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/41ef1912-ee14-4c99-a4c8-194eee4171ef/2f660e97-0936-48a8-af97-2ee8fb998ded.webp', NULL),
	('af1255dc-4a74-4b64-b229-7498879a877e', '52a7b82b-0010-49d3-8bb0-1b7b01186d0c', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/703c4d74-d961-402d-9a00-8d3fc931be3f/6010ba55-a260-47c6-a56a-8d7290cc925e.webp', 'Tengo amaxofobia, pero hoy vengo sin frenos, entre curvas peligrosas y tacones asesinos.
El peligro al volante me ponía de los nervios, ¡pero a las perras en el catwalk las atropello con mis sueños!
Mis fobias no me definen, me definen mis curvas,
vosotras sois señales de peligro… además de perras y putas…
Y cuando Tonica Saya pisa el acelerador…
¡Que todas las zorras que se aparten, que aquí viene el terror!', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:29:57.660605+00', '2026-11-03 19:32:11.862033+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/703c4d74-d961-402d-9a00-8d3fc931be3f/ed4770b7-3e7d-404b-8fe4-b55fb9651835.webp', NULL, NULL),
	('84d9a083-a76d-40b7-adbd-2ec1505b384e', '52a7b82b-0010-49d3-8bb0-1b7b01186d0c', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/d9678daa-27fd-46b8-9527-c029d5ba3054/0f76845a-ba11-4dc0-ba9a-f248de60cb12.webp', 'Capricornio es ambición, disciplina y poder. Es un signo de tierra, asociado a la constancia, la resistencia y a esa necesidad de avanzar hasta llegar a la cúspide. 
Por eso he convertido mi signo en una criatura de alta montaña: una falda monumental que representa la roca y las montañas, y unos cuernos inspirados en la cabra montesa, símbolo ligado al signo.
El cuerpo se transforma en una armadura dominatrix representando la fuerza, la seguridad y el carácter dominante de un signo que sabe perfectamente lo que quiere y no se detiene hasta conseguirlo.
Si Capricornio representa mi parte más terrenal, ambiciosa y oscura, Libra representa la imagen que proyecto al mundo: tranquilidad, equilibrio y sofisticación.
Para este look he querido llevar la esencia de libra al extremo, y he querido convertirla en una auténtica balanza humana, con los cristales y las piezas laterales simbolizando los dos platos.
Ya sé que es complicado elegir, pero con qué versión de Margot os quedáis? ✨', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:29:41.783185+00', '2026-11-03 16:41:47.216337+00', NULL, NULL, NULL),
	('1c34d0fb-de14-493d-95a9-ff050d8387c1', 'a61a4c4f-2002-4796-baf8-58a87c2bace4', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/a61a4c4f-2002-4796-baf8-58a87c2bace4/c6b93764-df06-460a-891f-a0712f72b98c/c4aa706e-2651-4001-96f5-52f28aee2a5f.webp', 'Tauro me dio la fuerza. Libra me dio el glamour.
Y la vida me dio un corazón con mucha historia.
Así que hoy no traigo dos signos, cariño…
traigo las dos caras de Elektra Heart.
Una te planta cara.
La otra te deja sin palabras.
Y juntas… provocan la descarga', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:32:48.839557+00', '2026-11-03 16:44:29.484915+00', NULL, NULL, NULL),
	('4a29d980-4885-4a6e-abed-875e171f3186', 'a61a4c4f-2002-4796-baf8-58a87c2bace4', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/a61a4c4f-2002-4796-baf8-58a87c2bace4/f818ac1f-14dc-4e79-92dc-58838ec8fe98/0e9da43d-8042-4060-8c65-bddee4fb40d4.webp', 'Soy Cáncer, un signo de agua gobernado por la Luna.
Soy una persona que siente demasiado, que se entrega de corazón y a la que las palabras y los gestos pueden herir más de lo que demuestra.
Por eso, a veces me muestro borde, distante o a la defensiva. 
No porque no tenga sentimientos, sino porque tengo tantos que cuando me hacen daño, mi primera reacción es protegerme.
Porque detrás de esta coraza hay un corazón que siente y aunque lo hayan herido, nunca deja de latir.
Soy Cáncer: puedo parecer una amenaza por fuera, pero por dentro soy un universo de emociones y muy muy sensible.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:33:11.309344+00', '2026-11-03 16:44:50.526837+00', NULL, NULL, NULL),
	('370baa1e-cdca-475f-aec4-f4c449984449', 'a61a4c4f-2002-4796-baf8-58a87c2bace4', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/a61a4c4f-2002-4796-baf8-58a87c2bace4/41ef1912-ee14-4c99-a4c8-194eee4171ef/581bab2d-d89e-4755-aa9b-0dd64ba6242b.webp', 'Mi esencia es Libra: la elegancia convertida en arte, la seducción hecha movimiento y la armonía elevada a espectáculo. 
Tengo el encanto de quien sabe atraer sin perseguir, el ojo de quien encuentra belleza donde otros no miran y la sensibilidad de quien entiende que cada detalle puede cambiarlo todo.
 Pero no confundas mi dulzura con debilidad: sé perfectamente quién soy y lo que merezco maricones.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:34:12.540192+00', '2026-11-03 16:45:17.758001+00', NULL, NULL, NULL),
	('94d7ea13-de20-4763-bc7f-5406c73c8e07', '281ed98b-5f2c-4133-a212-0a022c52a9fa', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/281ed98b-5f2c-4133-a212-0a022c52a9fa/c6b93764-df06-460a-891f-a0712f72b98c/a1fe027b-391c-459f-b356-666b85a42895.webp', 'Tauro me dio la fuerza. Libra me dio el glamour.
Y la vida me dio un corazón con mucha historia.
Así que hoy no traigo dos signos, cariño…
traigo las dos caras de Elektra Heart.
Una te planta cara.
La otra te deja sin palabras.
Y juntas… provocan la descarga', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:32:59.754327+00', '2026-11-03 16:50:18.060229+00', NULL, NULL, NULL),
	('6657abbb-9f6c-42ca-8bce-6b545ee16fc9', 'fc6e5ce4-a589-450f-8a8a-893268a95fcd', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/703c4d74-d961-402d-9a00-8d3fc931be3f/e273943d-29b0-4c97-be03-6994f99ff5ce.webp', 'Entra Tonica Saya, ¡que se abran los telones!,
que las otras putas y cabronas feas se escondan detrás del decorado;
unas traen cuatro plumas o sombreros bien cutres, otras, malas intenciones,
pero ninguna trae el coño tan bien coronado.

Soy la dueña del Circo, la reina del pecado,
con cetro, tacón y un escote criminal;
vosotras sois teloneras de un número ya anunciado:
cuando Saya entra en pista… ¡el resto es atrezzo y nada más!', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:22:03.556902+00', '2026-11-03 19:28:50.517115+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/703c4d74-d961-402d-9a00-8d3fc931be3f/ec86af7b-9b04-409f-8afe-9c02961aaa19.webp', NULL, NULL),
	('dbd14265-8f68-4263-89c8-c505f7873702', 'a61a4c4f-2002-4796-baf8-58a87c2bace4', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/a61a4c4f-2002-4796-baf8-58a87c2bace4/d9678daa-27fd-46b8-9527-c029d5ba3054/c45a2e82-c796-4c0a-9638-7f34b8788a30.webp', 'Capricornio es ambición, disciplina y poder. Es un signo de tierra, asociado a la constancia, la resistencia y a esa necesidad de avanzar hasta llegar a la cúspide. 
Por eso he convertido mi signo en una criatura de alta montaña: una falda monumental que representa la roca y las montañas, y unos cuernos inspirados en la cabra montesa, símbolo ligado al signo.
El cuerpo se transforma en una armadura dominatrix representando la fuerza, la seguridad y el carácter dominante de un signo que sabe perfectamente lo que quiere y no se detiene hasta conseguirlo.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:34:47.260928+00', '2026-11-03 19:34:23.688479+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/a61a4c4f-2002-4796-baf8-58a87c2bace4/d9678daa-27fd-46b8-9527-c029d5ba3054/55aafdd2-e4e8-4ec7-a134-8f43fc66358a.webp', NULL, NULL),
	('707e6c42-c4cd-4e9b-a085-b20cc92ab79e', '52a7b82b-0010-49d3-8bb0-1b7b01186d0c', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/41ef1912-ee14-4c99-a4c8-194eee4171ef/dc6b9e85-d36a-493b-b6da-d33ee34cd649.webp', 'Hay noches en las que el miedo a la muerte pesa más. Cuando estoy sola y todo queda en silencio, ese miedo parece acercarse y apretar más fuerte, intentando convencerme de que no puedo escapar de sus pensamientos. Pero no me define ni me vence.
Porque, incluso en esos momentos, hay algo dentro de mí que el miedo no puede apagar. La vida, con sus pequeños momentos, las personas que quiero, las risas, los abrazos, la luz de un nuevo día y todas las cosas bonitas que aún quedan por vivir, me recuerdan que estoy aquí.
Y entonces, poco a poco, vuelvo a respirar. Me suelto de las manos del miedo y vuelvo a elegir la vida. Porque puedo sentir miedo y, aun así, seguir viviendo, amando y esperando con esperanza.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:29:31.162109+00', '2026-11-03 16:40:41.820062+00', NULL, NULL, NULL),
	('288c9bdd-fb51-4b58-9f25-fca5fa4fd750', '52a7b82b-0010-49d3-8bb0-1b7b01186d0c', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/f818ac1f-14dc-4e79-92dc-58838ec8fe98/5af5de1b-f3fa-4cfc-90b5-ed2851ab5b5d.webp', 'Mi fobia tiene nombre y tiene rostro: mi padre.
Él es cazador, y desde pequeño he visto cómo la vida de un animal puede terminar en sus manos.
Para mí, el bosque siempre ha sido refugio, pero también un lugar donde la muerte puede estar esperando.
Por eso hoy me convierto en aquello que él persigue: un ciervo.
Mitad mujer, mitad animal.
Mi cuerpo de ciervo representa a todos esos animales que no pueden defenderse.
Hoy no huyo de mi fobia: camino hacia él y lo convierto en arte.
Porque mi fobia puede formar parte de mi historia, pero nunca decidir quien soy.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:29:01.042292+00', '2026-11-03 16:40:48.764493+00', NULL, NULL, NULL),
	('541a8728-dc05-42b0-93dd-dbbeda9dcbb5', '281ed98b-5f2c-4133-a212-0a022c52a9fa', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/281ed98b-5f2c-4133-a212-0a022c52a9fa/41ef1912-ee14-4c99-a4c8-194eee4171ef/3460fa76-edd5-4c6b-a230-66724b6ec424.webp', 'Mi presencia es Escorpio: intensa, magnética e imposible de ignorar. Hay algo en mí que no necesita explicaciones, algo que despierta curiosidad, provoca miradas y deja preguntas sin respuesta.
No vine a pasar desapercibido; vine a dejar huella. Soy profundidad bajo el brillo, fuego bajo la seda y poder detrás de cada mirada. Sé transformarme, renacer y convertir cada versión de mí en una declaración de fuerza.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:33:54.453862+00', '2026-11-03 16:45:26.498361+00', NULL, NULL, NULL),
	('cc29762f-d0fb-4b2a-9a56-f764712db8be', '281ed98b-5f2c-4133-a212-0a022c52a9fa', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/281ed98b-5f2c-4133-a212-0a022c52a9fa/d9678daa-27fd-46b8-9527-c029d5ba3054/36b0ef38-e90c-4c99-9823-61553f9fcf4d.webp', 'Si Capricornio representa mi parte más terrenal, ambiciosa y oscura, Libra representa la imagen que proyecto al mundo: tranquilidad, equilibrio y sofisticación.
Para este look he querido llevar la esencia de libra al extremo, y he querido convertirla en una auténtica balanza humana, con los cristales y las piezas laterales simbolizando los dos platos.
Ya sé que es complicado elegir, pero con qué versión de Margot os quedáis? ✨', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:34:57.846006+00', '2026-11-03 16:45:55.611292+00', NULL, NULL, NULL),
	('0fbca2a3-a6fa-496b-a601-7971a2da4640', '281ed98b-5f2c-4133-a212-0a022c52a9fa', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/281ed98b-5f2c-4133-a212-0a022c52a9fa/f818ac1f-14dc-4e79-92dc-58838ec8fe98/565a3809-2c21-4eea-9e03-6a451763d942.webp', 'Mi ascendente es Capricornio, un signo de tierra marcado por la disciplina y la fortaleza.
Aunque soy Cáncer y siento todo con mucha intensidad, Capricornio me aporta carácter y determinación.
No siempre muestro lo que siento, porque tiendo a proteger mi lado más vulnerable.
Hoy vengo a demostrar que puedo ser dulce, poderosa, vulnerable y segura a la vez.
Porque si Cáncer es mi corazón, Capricornio es la armadura que lo protege y por eso este lookazo armadura. 🛡️', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:33:25.651087+00', '2026-11-03 19:33:24.702329+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/281ed98b-5f2c-4133-a212-0a022c52a9fa/f818ac1f-14dc-4e79-92dc-58838ec8fe98/633dbfc8-a0a5-492b-a8d0-b04c6b42c0bf.webp', NULL, NULL),
	('84f59dba-f9de-4161-8a45-e8a34d409c7f', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/d9678daa-27fd-46b8-9527-c029d5ba3054/9353939c-dcae-4103-8307-bc3a21959524.webp', 'El pokemon en el que está inspirado mi primer look es Meowth, y cuando me quito mi imponente abrigo, evoluciono a Persian. 
Representa mi manera de avanzar por la vida: con estrategia, ambición y los pies siempre en la tierra. Como buena Capricornio, soy una persona trabajadora, perseverante y racional; no necesito correr para llegar antes, porque sé que la constancia es lo que realmente me lleva a conseguir mis objetivos.
Meowth simboliza esa versión de mí que observa, calcula y sabe perfectame', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:46:43.589264+00', '2026-11-03 19:37:39.415996+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/d9678daa-27fd-46b8-9527-c029d5ba3054/8329dd64-c447-40a4-b2fe-4ec0fafb447d.webp', NULL, NULL),
	('86c6e010-66c6-4398-b583-3e27bfa4535f', '0d9e8ce9-024e-4207-a792-3023a4aaa482', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/703c4d74-d961-402d-9a00-8d3fc931be3f/04c45889-125d-4047-b4f5-c11652a594f8.webp', 'Espuma de embalaje convertida en armadura, relleno industrial transformado en volúmenes monstruosos, polietileno esculpido en alta costura, malla técnica como símbolo de resistencia y detalles metálicos que convierten mis cicatrices en joyas.

Mis competidoras me dejaron los desperdicios; yo los convertí en arte. 

Porque hasta de las cenizas y los escombros puede resurgir una reina, más bella, más fuerte y más poderosa que nunca.

¡La basura de unas, la alta costura de Tonica Saya!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 08:11:51.967015+00', '2026-11-03 19:39:08.335029+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/703c4d74-d961-402d-9a00-8d3fc931be3f/0d61d27d-e6f2-4bf9-8b20-2e716c602e3e.webp', NULL, NULL),
	('f47ca22d-7bdc-4dd9-a46f-c1f58308f162', 'a61a4c4f-2002-4796-baf8-58a87c2bace4', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/a61a4c4f-2002-4796-baf8-58a87c2bace4/703c4d74-d961-402d-9a00-8d3fc931be3f/d0157078-78b5-423f-a5b0-3d73588c81c4.webp', 'Nací cuando España despertaba de una dictadura pero mi infancia conoció muy pronto la oscuridad.
El divorcio separó mi casa y mi familia, y durante más de quince años perdí a mi madre y mis hermanas.
En la escuela aprendí demasiado pronto la crueldad y el maltrato y entre burlas y silencios tuve que aprender a resistir.
Mi padre enfermó, luchó y finalmente se marchó, y siendo todavía joven, me tocó cuidar de mi hermano.
Pero dicen que yo nací bajo un Dragón de Fuego. Y ahora entiendo que aquel fuego nunca vino a quemarme: vino a enseñarme que incluso cuando todo parece perdido, uno puede convertir las cenizas en una nueva vida.
Descubrí que me gustaban los chicos y tardé años en poder decirlo; pero cuando finalmente dejé de esconderme, empecé a vivir.
Viajé, trabajé lejos de casa, construí mi independencia y, ya en mi segunda juventud, encontré al hombre con quien sigo soñando, quien me da la vida y es mi razón para continuar.
Y entonces viajé al Tíbet. Allí descubrí el Dharma y compre', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:35:15.906076+00', '2026-11-03 16:47:14.244717+00', NULL, NULL, NULL),
	('edc4a258-6001-4351-8b71-48d2ce423e51', '281ed98b-5f2c-4133-a212-0a022c52a9fa', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/281ed98b-5f2c-4133-a212-0a022c52a9fa/703c4d74-d961-402d-9a00-8d3fc931be3f/00e62122-52fb-4c37-941f-7c208f1bd89a.webp', 'Dicen que nací bajo el rugido del Tigre, y quizá por eso nunca tuve miedo de marchar. Dejé atrás mi tierra, crucé fronteras y océanos, y en tierras extrañas aprendí a luchar por mi lugar. 
Trabajé duro cuando nadie conocía mi nombre,aprendí idiomas, costumbres y nuevas maneras de vivir; porque un Tigre no espera que el mundo le abra la puerta: aprende a abrirla con sus propias garras y a seguir. 
Durante dos décadas entregué mi fuerza a una multinacional, sobreviviendo a un mundo laboral que muchas veces quiso apagarme. Hasta que un día aquella puerta se cerró de golpe y un despido injusto me obligó a empezar otra vez.
Pensé que había perdido mi camino… pero el Tigre no conoce la palabra derrota.
Cuando una senda desaparece, despierta otra, y de aquellas cenizas nació una nueva Tonica.
Me reinventé. Volví a estudiar, volví a empezar, y terminé encontrando mi lugar al servicio de los demás.
Hoy trabajo en un Ayuntamiento donde descubrí algo que ningún sueldo puede comprar: la felicidad', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:35:29.848128+00', '2026-11-03 16:47:31.125748+00', NULL, NULL, NULL),
	('982fe900-da28-4b3f-8b06-7a82538cf26c', '281ed98b-5f2c-4133-a212-0a022c52a9fa', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/281ed98b-5f2c-4133-a212-0a022c52a9fa/a95e88bf-eb83-42fe-b00a-805050e363d4/49e0e583-0954-4669-8899-6a28f062da3a.webp', 'No me hizo falta estudiar las estrellas para entender a Cáncer. Solo tuve que mirar a mi hermana.
A ella le apasionan las sirenas. Y, como Cáncer es el cangrejo, quise convertirme en Sebastián: ese amigo travesti incondicional que siempre está al lado de Ariel para cuidarla y guiarla.
Porque detrás de este cangrejo hay algo mucho más importante que una fantasía marina: hay una historia de amor, de lealtad y de familia.
Si el primer look cuenta cómo aquel niño encontró su valor, este segundo cuenta quién estuvo a su lado mientras aprendía a tenerlo.
El Sol representa quién conseguí ser. La Luna representa a quienes me acompañaron y sostuvieron esa luz cuando yo todavía no sabía cómo hacerlo.
El León aprendió a rugir. El Cangrejo aprendió a proteger a su familia.
Son dos caras de una misma historia: el niño que un día tuvo miedo de ser visto y la drag queen que hoy exige que todo el mundo la mire.
Leo me enseñó a brillar. Cáncer me enseñó que, incluso cuando encandilas con tu luz, necesi', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:35:57.909052+00', '2026-11-03 16:50:21.716484+00', NULL, NULL, NULL),
	('adb440cb-074b-4955-9a92-5c5b25d5e39e', 'a61a4c4f-2002-4796-baf8-58a87c2bace4', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/a61a4c4f-2002-4796-baf8-58a87c2bace4/a95e88bf-eb83-42fe-b00a-805050e363d4/ffe743cb-7e52-4670-8b2a-2b7f51fb51c8.webp', 'Para este primer look me he inspirado en el León Cobarde de Oz.
Durante mucho tiempo hubo un niño que tenía miedo de ocupar un espacio.
Un niño que aprendió demasiado pronto que ser diferente podía dar miedo. Que había cosas de sí mismo que era mejor esconder. Que, a veces, era más seguro hacerse pequeño que arriesgarse a ser visto.
Pero ese niño creció.
Por eso, este look representa ese to be continued del León de Oz.
Porque mi León ya no es cobarde. Ahora devora.
El León ha encontrado su valor. Y cuando un león descubre quién es, no vuelve a pedir permiso para brillar. Se convierte en el Sol.
Para construir este look, el León arrancó las baldosas amarillas que pretendían dirigirlo hacia el camino correcto y se esculpió un corsé con ellas. Le arrancó los tacones a Dorothy y hoy devora el presente desfilando con absoluto orgullo.
Porque ya no necesito que nadie me diga cuál es el camino correcto. Ahora soy yo quien decide hacia dónde caminar.
Pero ningún león llega hasta aquí completam', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:35:45.197393+00', '2026-11-03 16:50:26.163113+00', NULL, NULL, NULL),
	('78ba5211-ef44-44f0-a444-1c8f0e89467a', 'fc6e5ce4-a589-450f-8a8a-893268a95fcd', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/a95e88bf-eb83-42fe-b00a-805050e363d4/02677e28-ca06-4c00-83a5-ad872ab7eb14.webp', 'Chicas, sé que soy maga… pero tampoco hago milagros. Vuestros looks necesitan más que una varita.

Y decidme una cosa: ¿qué hay más icónico que una maga?
Un conejo.

Porque una buena chistera siempre guarda un secreto…
y a mí me gustan los secretos grandes, peludos y con sorpresa.

Así que preparadas, porque hoy… el conejo sale de la chistera', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:22:18.619358+00', '2026-11-03 19:29:29.124023+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/fc6e5ce4-a589-450f-8a8a-893268a95fcd/a95e88bf-eb83-42fe-b00a-805050e363d4/490c111b-9e12-48a4-be79-cc8f83b39b96.webp', NULL, NULL),
	('d9f9ec6f-cb63-4b8f-96f3-8ee366a2ea2d', '52a7b82b-0010-49d3-8bb0-1b7b01186d0c', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/a95e88bf-eb83-42fe-b00a-805050e363d4/caaa43ee-5fb9-4f90-a404-8b1fafb5abc7.webp', 'Hay un miedo que me acompaña desde hace mucho tiempo: el miedo a no saber qué hay debajo de mí.
Cuando estoy en el agua y dejo de tocar el suelo… empieza la película en mi cabeza.
Yo puedo estar perfectamente tranquilo, nadando, respirando… hasta que miro hacia abajo y veo ese azul oscuro.
Y mi cerebro dice: ‘¿Sabes qué estaría bien ahora? Imaginar absolutamente todo lo que puede haber ahí abajo.’
Y aunque sé nadar. Y sé nadar muy bien.
Mi cuerpo no entiende de lógica cuando aparece el miedo.
En el Algarve llegué a vivirlo de verdad. Un día estuve a punto de ahogarme. No porque no supiera nadar, sino porque el miedo me puso completamente rígido.
Y ahí entendí algo: a veces no es lo que hay debajo lo que nos hunde. Es lo que nuestra cabeza imagina que hay.
Por eso esta noche mi capa representa ese océano que me encanta, pero me aterra.
Algo enorme. Transparente. Precioso.
Pero lleno de formas que no puedo identificar.
Me quito esta capa… y no escapo del océano.
Me convierto en él.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:30:23.976197+00', '2026-11-03 19:31:31.534208+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/a95e88bf-eb83-42fe-b00a-805050e363d4/f37bf97e-266f-4191-aee6-3c1a73701f92.webp', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/a95e88bf-eb83-42fe-b00a-805050e363d4/0f6109fe-9842-496a-9fbf-e52612c8951a.webp', NULL),
	('6051a42e-9a75-4181-b339-7e251eaf4b26', '52a7b82b-0010-49d3-8bb0-1b7b01186d0c', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/c6b93764-df06-460a-891f-a0712f72b98c/7804834e-e722-4a11-bffd-7403f7d77bac.webp', 'Buenas noches, criaturas de baja tensión…
Soy Elektra Heart, y hoy vengo a hablaros de mi mayor miedo: la electricidad.
Porque sí, cariño… últimamente las descargas me dan bastante más miedo que una mala crítica con cinco estrellas.
Pero aquí viene el electrodrama:
¿Cómo puede ser que aquello que temo sea también aquello que me mantiene viva?
Mi corazón y la electricidad tienen una relación complicada.
Es tóxica, intensa, llena de chispazos… vamos, una relación de alto voltaje.
Y mientras yo pienso: «¡Dios mío, una descarga!», mi corazón contesta: «Cariño, precisamente eso es lo que necesitamos».
Así que hoy no he venido a esconderme de mis miedos.
He venido vestida de ellos.
Porque puedo tener miedo a una descarga.
Puedo tener miedo a la medicina.
Puedo tener miedo a lo que no controlo.
Pero ninguno de esos miedos decide quién soy.
Mis fobias no me definen.
Me define seguir caminando aunque tenga miedo.
Me define reírme de mi propio electrodrama.
Y me define convertir aquello que un d', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-03 16:28:48.602891+00', '2026-11-03 19:41:44.161784+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/c6b93764-df06-460a-891f-a0712f72b98c/61c3edae-38be-45c7-bdf0-beaa5aa2c299.webp', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/52a7b82b-0010-49d3-8bb0-1b7b01186d0c/c6b93764-df06-460a-891f-a0712f72b98c/c3c96faa-d1b1-4179-bab0-7097b7cbf501.webp', NULL),
	('4ca60bfa-7544-43cf-81c2-69a331aeabd8', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/703c4d74-d961-402d-9a00-8d3fc931be3f/fffabec3-6b78-4753-b634-99606b679dca.jpg', 'TONICA SAYA — LA SOBERBIA
Siete pecados despiertan, siete coronas de maldad,
pero uno reina sobre todos, vestido de majestad.
Con alas de serafín y el orgullo por bandera,
¡Tonica Saya abre sus alas y hasta el cielo se arrodilla ante ella!
No busco vuestra aprobación, ni compito por grandeza;
si Dios creó el Paraíso… ¡yo vine a ponerle la realeza!
Soy principio, fin y gloria, soy divina perfección…
¡La Soberbia tiene nombre propio: TONICA SAYA, vuestra perdición!', '703c4d74-d961-402d-9a00-8d3fc931be3f', '2026-11-05 19:12:19.680396+00', '2026-11-06 14:55:06.029981+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/703c4d74-d961-402d-9a00-8d3fc931be3f/9aeffe91-adbb-4fa1-9a16-b6448033b8e2.jpg', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/703c4d74-d961-402d-9a00-8d3fc931be3f/b8d6df73-6b30-4fb4-bb3d-73fc62badbd9.jpg', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/703c4d74-d961-402d-9a00-8d3fc931be3f/fa1ec533-6c50-4f8e-b6c6-101f41d08aa0.jpg'),
	('c2b23fed-ba8a-46bf-8542-2c2b33335f9f', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/f818ac1f-14dc-4e79-92dc-58838ec8fe98/3bf05401-89e3-4969-b598-cee486f6b502.jpg', '*¡ PURSE FIRST !* 👜 
Hoy en pasarela os traigo uno de los 7 pecados capitales: LA AVARICIA. Simboliza ese deseo de querer siempre más y más, sin saber cuándo es suficiente. 
Llevo un vestido verde esmeralda, adornado con joyas, tesoros y detalles dorados y champán que representan la riqueza y el lujo. En la cabeza luzco una aureola llena de monedas de inspiración barroca y religiosa, porque no hay más avaricia y tesoros que en la iglesia. 

Mi bolso se rompe y deja caer cientos de billetes, recordándonos que la ambición desmedida puede tener consecuencias. 
Porque, al final, ¡la avaricia rompe el Louisvi! 💰', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '2026-11-08 10:06:15.25139+00', '2026-11-08 10:06:15.25139+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/f818ac1f-14dc-4e79-92dc-58838ec8fe98/098da6bf-1ce3-42cc-88bc-2875fb9798ed.jpg', NULL, NULL),
	('baac3156-b4f1-459d-bb03-554e8759719d', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/41ef1912-ee14-4c99-a4c8-194eee4171ef/d0db0c0e-bb39-4050-949a-3f8377022412.jpg', '¡Cuidado, que ha llegado la envidia y viene más divina que nunca! 💚🐍 Mi look es una fantasía serpentina de alta costura, donde el verde venenoso, el morado y el negro se mezclan entre escamas, joyas y unas espectaculares alas de pavo real repletas de ojos. Cada ojo representa esa mirada indiscreta que no puede evitar fijarse en lo que tienen los demás. Las garras simbolizan el deseo de arrebatárselo y la silueta asimétrica refleja una belleza tan retorcida como irresistible. Porque yo no quiero lo que tienes… ¡quiero que quieras ser yo! Y si la envidia es un pecado, cariño, que me manden directa al infierno, pero por la alfombra roja. 💅✨', '41ef1912-ee14-4c99-a4c8-194eee4171ef', '2026-11-08 10:08:33.279205+00', '2026-11-08 10:08:33.279205+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/41ef1912-ee14-4c99-a4c8-194eee4171ef/dfc0df61-4f53-4368-b9c3-fff6d21e9b67.jpg', NULL, NULL),
	('3f41e935-d1bf-4f3e-be2d-d18a74ccc0a3', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/d9678daa-27fd-46b8-9527-c029d5ba3054/bb19ac91-1d80-4da0-b9b4-de0377898846.jpg', 'La lujuria es el deseo convertido en poder: la tentación de aquello que sabemos que no deberíamos desear, pero a lo que jamás queremos resistirnos.

Mi corsé negro adornado con rosas rojas brillantes representa el romance y la pasión; las cadenas de mis ligas, el placer de dejarse llevar. Sobre mi cuerpo, una serpiente esmeralda con destellos rosa intenso simboliza la tentación, mientras que la manzana roja nos recuerda que todo pecado comienza con un deseo.

Envuelta en el terciopelo burdeos de mi cola escultórica, no vengo a pedir perdón por mis pecados…

Así que, amores, caed en la tentación… que yo me encargo del resto 🐍 🍎 🫦', 'd9678daa-27fd-46b8-9527-c029d5ba3054', '2026-11-07 15:02:43.973673+00', '2026-11-07 15:02:43.973673+00', NULL, NULL, NULL),
	('36bf407d-5964-43cb-897e-82090e1e1c5b', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', 'c6b93764-df06-460a-891f-a0712f72b98c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/c6b93764-df06-460a-891f-a0712f72b98c/6d728a26-135d-4788-b507-9432ebc4f0ea.jpg', '«Dicen que el tiempo es oro, cariño. Por eso yo llevo siglos sin moverme: no pienso desperdiciar mi energía en algo que no pueda comprar.
Soy el lujo que se marchita, la belleza que se abandona y la reina de un imperio donde hasta levantarse de la cama es demasiado esfuerzo.
Soy Elektra Heart y hoy mi único talento es no hacer absolutamente nada… ¡pero hacerlo en alta costura!»', 'c6b93764-df06-460a-891f-a0712f72b98c', '2026-11-04 07:56:08.244004+00', '2026-11-08 09:51:04.689736+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/c6b93764-df06-460a-891f-a0712f72b98c/dfc3199c-8d49-4625-a69b-fbc1898d536c.jpg', NULL, NULL),
	('18bbf5d3-31c5-4059-8e46-a5161460bec7', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/a95e88bf-eb83-42fe-b00a-805050e363d4/bbe14b4a-a887-45d3-8f5d-292e2168a6ef.jpg', 'Hay heridas que ya no sangran, pero siguen doliendo.

Yo no nací con este pecado.

Mi ira nace del dolor, del rechazo y de todas esas veces que me hicieron sentir que ser yo mismo estaba mal.

Muchos sabemos lo que es crecer sintiéndonos diferentes, aprendiendo a escondernos para encajar en un mundo que nos condena por ser quienes somos.

Y poco a poco, te rompen.

¿Qué reina no ha tenido que reconstruirse entre las cenizas de lo que otros destruyeron?

Pero cuidado… La ira no necesita gritar para destruirlo todo. A veces basta con sonreír y esperar.

Por delante, las grietas representan las heridas que aprendí a esconder. Por detrás, el fuego representa años de silencios, lágrimas y rabia contenida.

Hasta que un día dejas de pedir perdón por existir.

Y si ser yo mismo es un pecado, que mi ira sea vuestra condena.

Nunca volveré a avergonzarme de quién soy. Que arda el mundo.', 'a95e88bf-eb83-42fe-b00a-805050e363d4', '2026-11-08 10:09:32.749166+00', '2026-11-08 10:09:32.749166+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/a95e88bf-eb83-42fe-b00a-805050e363d4/caefc356-4cb9-4766-8048-695c2654c27e.jpg', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/a95e88bf-eb83-42fe-b00a-805050e363d4/693f5de4-d719-430e-949f-c3e726e22156.jpg', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/a95e88bf-eb83-42fe-b00a-805050e363d4/ee661257-0b94-46f2-94d4-7a5c2acc6e56.jpg'),
	('7c49f9d4-8da9-44af-9c85-664fd048a25a', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/83f2dfca-4a03-450a-b3e2-ae3d014efed9/d9678daa-27fd-46b8-9527-c029d5ba3054/1db4e0e5-d069-41b0-bd46-48c6c55380b0.jpg', '*The 80’s iceskater* 🛼 ❄️ 

Una interpretación del patinaje artístico sobre hielo llevada al extremo de la haute couture y la estética ochentera: siluetas arquitectónicas, hombros XL, volúmenes dramáticos, brillos y una fantasía glacial que convierte la pista de hielo en una pasarela.
Mis hermanas han elegido otras disciplinas de invierno, pero compartimos una misma esencia: tres deportes, tres interpretaciones y una identidad común, unificada por una paleta de azules helados, rosa hielo, blancos y plateados.

Tres atletas, tres disciplinas y una misma temperatura. Así es el equipo de las 80’s frozen bitches.', 'd9678daa-27fd-46b8-9527-c029d5ba3054', '2026-11-13 06:09:28.618833+00', '2026-11-13 06:09:28.618833+00', NULL, NULL, NULL),
	('6cdc6908-d501-44e1-85f8-e046daa8b452', '83f2dfca-4a03-450a-b3e2-ae3d014efed9', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/83f2dfca-4a03-450a-b3e2-ae3d014efed9/a95e88bf-eb83-42fe-b00a-805050e363d4/86094d78-94a5-45f0-9ad9-d2537cc24396.jpg', '¡Apartad las chanclas, que ha llegado la piscina más puta de la urbanización!

No soy una piscina infantil, cariño. Soy para mayores de 18. Soy hinchable, juguetona y tengo más aire que vergüenza.

¡Y AHORA… SPLAAAAASH! ¡LA ESCALERA A TOMAR POR CULO… !

Creíais que aquí hacíais pie? ¡PUES AGARRAOS, QUE ESTO ES PROFUNDO! 

Me llaman LA TOI: TOTALLY OBSCENE INFLATABLE. ¿Que qué significa? ¡Idiomas, queridas! Que una es una fantasía internacional, pero no una puta academia de Cambridge.

¡Menuda hostia! Pero no os preocupéis, que la hago con descaro. 
Si me veis boca abajo, no paréis al socorrista… ¡que me hago la muerta porque mi culo quiere pista!

¡Soy Vicky D’Mentia y esto no es una piscina… es una PUTA OBSESIÓN!', 'a95e88bf-eb83-42fe-b00a-805050e363d4', '2026-11-10 20:22:48.876365+00', '2026-11-13 18:06:06.238677+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/83f2dfca-4a03-450a-b3e2-ae3d014efed9/a95e88bf-eb83-42fe-b00a-805050e363d4/d8490c10-7d7b-480b-8764-ea607de7176a.jpg', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/83f2dfca-4a03-450a-b3e2-ae3d014efed9/a95e88bf-eb83-42fe-b00a-805050e363d4/53470c3b-14b7-4109-abcf-cfa6fb4040ff.jpg', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/83f2dfca-4a03-450a-b3e2-ae3d014efed9/a95e88bf-eb83-42fe-b00a-805050e363d4/ab1ee511-1135-4674-ad19-a41a51412796.jpg');

-- jury_looks
INSERT INTO "public"."jury_looks" ("id", "category_id", "participant_id", "image_url", "intro", "uploaded_by", "created_at", "updated_at", "image2_url", "image3_url", "image4_url") VALUES
	('b7e4c07f-fc2f-43d0-8269-1579ecf9332b', '0d9e8ce9-024e-4207-a792-3023a4aaa482', '360de907-a60e-4909-9ad2-7a4d97ee1de6', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/360de907-a60e-4909-9ad2-7a4d97ee1de6/2b0982d8-c747-467d-bdcf-b34494f2bcbe.webp', 'La Javi puta', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:00:46.475894+00', '2026-11-02 15:00:46.475894+00', NULL, NULL, NULL),
	('ec51290c-bb85-4942-9450-5534b24d882a', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', '360de907-a60e-4909-9ad2-7a4d97ee1de6', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/360de907-a60e-4909-9ad2-7a4d97ee1de6/265d11a2-619f-4205-a3d0-76703772f85e.webp', '¡Bienvenidas, bienvenidos y bienvenides a la pasarela! 🎮✨ Esta noche el escenario se convierte en la Liga Pokémon, y cada look viene a demostrar que no hay que atraparlos a todos, sino lucirlos a todos. Hay tacones, hay pelucas más verdes que una Bulbasaur en primavera y hay maquillaje que va a dejar a Team Rocket sin palabras. Que gane la mejor, y que la peor se vaya con un Sashay en la mochila. ¡Que empiece el duelo!', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:44:04.457959+00', '2026-11-02 15:44:40.764892+00', NULL, NULL, NULL),
	('1d52ea89-1646-44e7-b4df-d0a303db1311', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', '7678809f-7f06-4574-a48c-52d6cbf91a7c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/db8fefbe-e6f0-4bc9-af4b-d852b573d65d/7678809f-7f06-4574-a48c-52d6cbf91a7c/3a935ecb-c721-4036-9038-66b0569bec7d.webp', 'Bienvenidas a la pasarela más traicionera de la temporada. Hoy la categoría es... ¡Tu mejor Pokémon! Y rezo para que ninguna se haya plantado un mono amarillo de plástico del Primark creyendo que por llevar las orejas puntiagudas ya es Pikachu, porque con el presupuesto que se manejan, lo más probable es que parezcan un Magikarp agonizando en una acera de Chueca.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 15:44:28.221711+00', '2026-11-02 15:45:02.692172+00', NULL, NULL, NULL),
	('cd19367c-adbd-4a27-8a3d-6419a167d1f8', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', '360de907-a60e-4909-9ad2-7a4d97ee1de6', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/360de907-a60e-4909-9ad2-7a4d97ee1de6/bc4ddda7-7636-472c-8d29-2edda3a1d882.webp', 'Bienvenidos al Séptimo Círculo. Esta noche no vengo a juzgar vuestros pecados... vengo a puntuarlos.', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '2026-11-06 16:09:44.000314+00', '2026-11-06 16:09:44.000314+00', NULL, NULL, NULL),
	('f44a4b53-721a-4feb-9ff4-b21e83dee1a1', '0d9e8ce9-024e-4207-a792-3023a4aaa482', '7678809f-7f06-4574-a48c-52d6cbf91a7c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/0d9e8ce9-024e-4207-a792-3023a4aaa482/7678809f-7f06-4574-a48c-52d6cbf91a7c/ca21e920-325f-4799-ba6c-ff8d57a1661b.webp', 'A ver quién consigue no parecer un accidente de tráfico en hora punta', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-02 12:03:24.749025+00', '2026-11-06 16:34:06.842488+00', NULL, NULL, NULL),
	('99ccc2e9-fce3-4148-b985-64f0262c3bfd', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', '7678809f-7f06-4574-a48c-52d6cbf91a7c', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/7678809f-7f06-4574-a48c-52d6cbf91a7c/cce0ce75-d7bc-427e-a56c-dfd91839c89b.webp', 'Bienvenidos al Séptimo Círculo. Esta noche no vengo a juzgar vuestros pecados... vengo a puntuarlos.', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-04 22:07:13.97321+00', '2026-11-06 17:05:54.205532+00', NULL, NULL, NULL),
	('5c84ab22-7c4c-4221-81e6-cf6ba9d72936', 'd42ae9c4-1a37-4155-8a91-34dc89243a9c', '13a31e3e-704e-4363-bc98-f6c2ce422651', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/13a31e3e-704e-4363-bc98-f6c2ce422651/97b50bcf-8b04-4e25-aef4-55e0823f06a7.jpg', 'Como algunos ya sabíais y otros no podíais intuir… aquí está la mismísima Lolita Montiel, hija de una larga estirpe de señoritas Montiel. Y vengo desde el mismísimo infierno para juzgar vuestros looks de pecadoras… os quiero hoy bien diablas. He venido con la moto bien cargada de gasolina para que le prendáis fuego… ¿Quién será la reina que nos traiga hoy más chispas? 🔥🔥🔥🔥', '13a31e3e-704e-4363-bc98-f6c2ce422651', '2026-11-07 17:20:29.359946+00', '2026-11-07 17:20:29.359946+00', 'https://nilcyadkxqhwrqzeersg.supabase.co/storage/v1/object/public/runway-looks/d42ae9c4-1a37-4155-8a91-34dc89243a9c/13a31e3e-704e-4363-bc98-f6c2ce422651/8a0dba53-2f85-4e48-bf36-e53b4b13bfc1.jpg', NULL, NULL);

-- runway_guests
INSERT INTO "public"."runway_guests" ("id", "runway_id", "participant_id", "invited_by", "created_at") VALUES
	('e2b86027-239d-42c0-9743-06f3123dd990', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', '13a31e3e-704e-4363-bc98-f6c2ce422651', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '2026-11-07 14:18:31.930612+00');

-- votes
INSERT INTO "public"."votes" ("id", "runway_id", "voter_id", "top_1_participant_id", "top_2_participant_id", "top_3_participant_id", "created_at", "updated_at") VALUES
	('630fbcb7-6ae5-4bac-8069-fd5204e16e89', '0d9e8ce9-024e-4207-a792-3023a4aaa482', '360de907-a60e-4909-9ad2-7a4d97ee1de6', '41ef1912-ee14-4c99-a4c8-194eee4171ef', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'a95e88bf-eb83-42fe-b00a-805050e363d4', '2026-11-02 15:29:51.938051+00', '2026-11-02 15:29:51.938051+00'),
	('880359c7-d633-45f6-a2ad-1a3eca693bf5', 'db8fefbe-e6f0-4bc9-af4b-d852b573d65d', '7678809f-7f06-4574-a48c-52d6cbf91a7c', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'c6b93764-df06-460a-891f-a0712f72b98c', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '2026-11-02 15:51:58.243177+00', '2026-11-02 18:59:45.542122+00'),
	('7a726d8b-78f9-465d-ae23-879a193c779a', '42467692-4510-4147-b84c-f8147b4ba12d', '7678809f-7f06-4574-a48c-52d6cbf91a7c', 'c6b93764-df06-460a-891f-a0712f72b98c', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '2026-11-02 20:20:32.021222+00', '2026-11-02 20:20:32.021222+00'),
	('25b37be9-dec8-46c6-8e8e-35c6198e7c3f', 'bee91d18-609a-4823-987a-d21198734411', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '703c4d74-d961-402d-9a00-8d3fc931be3f', '2026-11-03 16:53:48.383599+00', '2026-11-03 16:53:48.383599+00'),
	('21c104e7-8184-4872-8ac2-16ec89ff2d25', '143ca48e-0702-483c-8db0-b77dc6f732e4', '7678809f-7f06-4574-a48c-52d6cbf91a7c', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'c6b93764-df06-460a-891f-a0712f72b98c', '2026-11-03 16:54:24.559291+00', '2026-11-03 16:54:24.559291+00'),
	('63a168fe-2547-40c7-9e68-55b9ba12e026', '70d7201c-645f-4b78-9f4b-41b2d6dcbb9b', '7678809f-7f06-4574-a48c-52d6cbf91a7c', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'a95e88bf-eb83-42fe-b00a-805050e363d4', '2026-11-03 16:54:59.96505+00', '2026-11-03 16:54:59.96505+00'),
	('3687c23f-ff9c-4d43-8e63-ea5a061ebdb2', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', '703c4d74-d961-402d-9a00-8d3fc931be3f', 'c6b93764-df06-460a-891f-a0712f72b98c', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'd9678daa-27fd-46b8-9527-c029d5ba3054', '2026-11-08 10:52:49.886361+00', '2026-11-08 10:52:49.886361+00'),
	('e7596667-dad8-4a74-a96e-0f598e505779', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', 'd9678daa-27fd-46b8-9527-c029d5ba3054', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'c6b93764-df06-460a-891f-a0712f72b98c', '2026-11-08 10:52:55.031005+00', '2026-11-08 10:52:55.031005+00'),
	('e4d0aa5b-bbcc-4f3c-bfb2-db69c59fdeb6', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', 'a95e88bf-eb83-42fe-b00a-805050e363d4', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'c6b93764-df06-460a-891f-a0712f72b98c', '2026-11-08 10:55:08.388701+00', '2026-11-08 10:55:08.388701+00'),
	('d6fb4442-1f8d-4f48-98ec-6a1269c966a3', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'd9678daa-27fd-46b8-9527-c029d5ba3054', '41ef1912-ee14-4c99-a4c8-194eee4171ef', '2026-11-08 10:55:38.761508+00', '2026-11-08 10:55:38.761508+00'),
	('73465ff9-dea0-4939-a851-05b4b2c74ae8', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', '7678809f-7f06-4574-a48c-52d6cbf91a7c', 'c6b93764-df06-460a-891f-a0712f72b98c', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '2026-11-08 10:56:19.204884+00', '2026-11-08 10:56:19.204884+00'),
	('a28e77b9-039c-4b59-86e8-061776d305ed', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', '41ef1912-ee14-4c99-a4c8-194eee4171ef', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'c6b93764-df06-460a-891f-a0712f72b98c', '2026-11-08 10:56:39.900374+00', '2026-11-08 10:56:39.900374+00'),
	('2e9e509e-7ed7-47d5-96f4-12196dd6b714', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', '360de907-a60e-4909-9ad2-7a4d97ee1de6', 'c6b93764-df06-460a-891f-a0712f72b98c', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '2026-11-08 10:56:52.110033+00', '2026-11-08 10:56:52.110033+00'),
	('4d9c80e9-8dfb-4a41-9d96-76b63895b452', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', 'c6b93764-df06-460a-891f-a0712f72b98c', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', '703c4d74-d961-402d-9a00-8d3fc931be3f', '2026-11-08 10:57:00.56586+00', '2026-11-08 10:57:00.56586+00'),
	('937dc680-d1bb-46ba-a87c-9191a432c33b', 'a4764bee-62cc-40c1-8045-9e5cb0b2eb69', '13a31e3e-704e-4363-bc98-f6c2ce422651', 'a95e88bf-eb83-42fe-b00a-805050e363d4', 'f818ac1f-14dc-4e79-92dc-58838ec8fe98', 'c6b93764-df06-460a-891f-a0712f72b98c', '2026-11-08 11:00:20.973322+00', '2026-11-08 11:00:25.857798+00');

set session_replication_role = origin;
