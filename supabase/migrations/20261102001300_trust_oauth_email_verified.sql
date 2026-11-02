-- =============================================================================
-- Migration: accept the OAuth provider's email_verified claim
--
-- Some OAuth sign-ins (seen on iOS) reach the auth.users insert with
-- email_confirmed_at still null even though the provider verified the address, so
-- the check rejected valid people. Now the email counts as verified when either
-- email_confirmed_at is set, or the login comes from Google/Microsoft and that
-- provider reports email_verified = true. Email/password sign-ups still need
-- email_confirmed_at, because their metadata is user-controlled.
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
  v_provider text := new.raw_app_meta_data ->> 'provider';
  v_verified boolean;
begin
  if v_email is null or v_email = '' then
    raise exception 'El proveedor de acceso no devolvió un correo electrónico';
  end if;

  -- Linking is by email, so the provider must have verified it
  v_verified := new.email_confirmed_at is not null
    or (v_provider in ('google', 'azure')
        and coalesce(new.raw_user_meta_data ->> 'email_verified', 'false') = 'true');

  if not v_verified then
    raise log 'signup rejected: email not verified (%), provider %, email_verified %',
      v_email, v_provider, new.raw_user_meta_data ->> 'email_verified';
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
