-- =============================================================================
-- Migration: multi-provider sign-in (Google + Microsoft/Azure)
--
-- handle_new_user() fires once per auth.users row. Supabase links a second
-- provider with the same verified email to the existing user, so it does not
-- run again for it.
--
-- Security: linking a login to a pre-registered participant (which may be a
-- judge) is by email, so it must only happen when the provider verified that
-- email. Azure "common" tenants can return unverified emails; without this
-- check someone could claim a judge's address.
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

  -- Link to the pre-registered participant, only with a verified email
  if new.email_confirmed_at is not null then
    update public.participants
    set user_id = new.id
    where email = v_email
      and user_id is null;
  end if;

  if not found or new.email_confirmed_at is null then
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

commit;
