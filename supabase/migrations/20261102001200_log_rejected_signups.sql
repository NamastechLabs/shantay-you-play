-- =============================================================================
-- Migration: log the email of rejected sign-ups
--
-- Rolled-back inserts can't be stored in a table, but RAISE LOG still reaches the
-- Postgres logs (Dashboard > Logs > Postgres Logs; search "signup rejected").
-- The exception message also includes the email so it comes back in the redirect's
-- error_description.
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
    raise log 'signup rejected: email not verified (%)', v_email;
    raise exception 'El correo electrónico no está verificado (%)', v_email;
  end if;

  update public.participants
  set user_id = new.id
  where email = v_email
    and user_id is null;

  if not found then
    raise log 'signup rejected: email not in participants (%)', v_email;
    raise exception 'Tu correo no está en la lista de participantes (%)', v_email;
  end if;

  return new;
end;
$$;

commit;
