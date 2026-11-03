-- =============================================================================
-- Migration: link an existing login when a participant is registered
--
-- handle_new_user links a login to its participant, but only when the login is
-- CREATED. If the person already had a login (signed in before being registered,
-- or their participant row was deleted and registered again), user_id stayed null
-- and the app could not find their profile. Now registering a participant, or
-- changing its email, links the existing login with that email, under the same
-- rule as sign-up: the email must be verified, and the login must not belong to
-- another participant already.
-- =============================================================================
begin;

create or replace function public.link_existing_login()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.user_id is not null then
    return new;
  end if;

  select u.id
  into new.user_id
  from auth.users u
  where lower(u.email) = new.email
    and (
      u.email_confirmed_at is not null
      or (u.raw_app_meta_data ->> 'provider' in ('google', 'azure')
          and coalesce(u.raw_user_meta_data ->> 'email_verified', 'false') = 'true')
    )
    and not exists (select 1 from public.participants p where p.user_id = u.id)
  limit 1;

  return new;
end;
$$;

revoke execute on function public.link_existing_login() from public, anon, authenticated;

create trigger participants_link_existing_login
  before insert or update of email on public.participants
  for each row execute function public.link_existing_login();

-- Existing participants that were left unlinked
update public.participants p
set user_id = u.id
from auth.users u
where p.user_id is null
  and lower(u.email) = p.email
  and (
    u.email_confirmed_at is not null
    or (u.raw_app_meta_data ->> 'provider' in ('google', 'azure')
        and coalesce(u.raw_user_meta_data ->> 'email_verified', 'false') = 'true')
  )
  and not exists (select 1 from public.participants other where other.user_id = u.id);

commit;
