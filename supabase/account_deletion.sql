create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from storage.objects
  where bucket_id = 'washdesk-backups'
    and (storage.foldername(name))[1] = 'manager'
    and (storage.foldername(name))[2] = current_user_id::text;

  delete from auth.users
  where id = current_user_id;
end;
$$;

revoke all on function public.delete_current_user() from public;
grant execute on function public.delete_current_user() to authenticated;
