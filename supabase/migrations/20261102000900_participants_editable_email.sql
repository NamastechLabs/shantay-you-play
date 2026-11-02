-- =============================================================================
-- Judges can fix the email of a participant who has not signed in yet
-- =============================================================================
-- Once user_id is set (first sign-in linked the login) the email is frozen.

grant update (email) on public.participants to authenticated;

create or replace function public.guard_participant_email()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.email is distinct from old.email
     and (old.user_id is not null or not (select public.is_jurado())) then
    raise exception 'El correo no se puede cambiar' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger participants_guard_email
  before update of email on public.participants
  for each row execute function public.guard_participant_email();
