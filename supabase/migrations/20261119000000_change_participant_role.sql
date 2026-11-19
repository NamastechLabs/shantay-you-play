-- =============================================================================
-- Migration: promote a special guest ('invitado') to queen ('concursante')
--
-- The role column has no client UPDATE grant, so it could not be changed from the
-- app. This adds a judge-only function that changes ONE thing: the role of a
-- participant who is currently 'invitado', to 'concursante'.
--
-- Nothing is deleted or moved. Everything the person did as a guest points to
-- participants.id (not to the role), so it stays exactly as it was:
--   * runway_guests: their invitations (history of the runways they attended)
--   * jury_looks:    their looks and intros stay jury looks (not copied to looks)
--   * votes:         the ballots they cast as a guest (they stop being anonymous
--                    once the person is a queen; accepted decision)
-- Other role changes are not supported yet.
-- =============================================================================
begin;

create or replace function public.promote_guest_to_contestant(p_participant_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not (select public.is_jurado()) then
    raise exception 'Only judges can change a role' using errcode = '42501';
  end if;

  update public.participants
  set role = 'concursante'
  where id = p_participant_id
    and role = 'invitado';

  if not found then
    raise exception 'Only a special guest can become a contestant' using errcode = '22023';
  end if;
end;
$$;

revoke execute on function public.promote_guest_to_contestant(uuid) from public, anon;
grant  execute on function public.promote_guest_to_contestant(uuid) to authenticated;

commit;
