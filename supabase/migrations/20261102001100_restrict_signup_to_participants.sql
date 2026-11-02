-- =============================================================================
-- Migration: restrict sign-up to pre-registered participants
--
-- Previously an unmatched email got a new `concursante` profile. Now the sign-up
-- is rejected: raising here aborts the insert into auth.users, so no login is
-- created. Only an email that a judge registered in public.participants (and that
-- no login has claimed yet) can sign in for the first time.
--
-- Bootstrapping: the first judge must be inserted manually (SQL Editor) before
-- their first sign-in, e.g.
--   insert into public.participants (name, email, role)
--   values ('Name', 'judge@example.com', 'jurado');
-- =============================================================================
begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(new.email));
begin
  if v_email is null or v_email = '' then
    raise exception 'El proveedor de acceso no devolvió un correo electrónico';
  end if;

  -- Linking is by email, so the provider must have verified it
  if new.email_confirmed_at is null then
    raise exception 'El correo electrónico no está verificado';
  end if;

  update public.participants
  set user_id = new.id
  where email = v_email
    and user_id is null;

  if not found then
    raise exception 'Tu correo no está en la lista de participantes';
  end if;

  return new;
end;
$$;

commit;
