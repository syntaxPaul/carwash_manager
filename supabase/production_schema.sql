-- WashDesk production backend foundation.
--
-- Run this after storage_policies.sql and account_deletion.sql.
-- It adds multi-tenant business records, subscription entitlements, purchase
-- event logging, and authenticated RPCs used by the mobile app.

create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  business_name text not null,
  owner_name text not null,
  email text not null,
  trial_start_at timestamptz not null default now(),
  trial_end_at timestamptz not null default now() + interval '5 days',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_businesses_owner
  on public.businesses(owner_user_id);

create table if not exists public.subscription_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete cascade,
  product_id text not null,
  status text not null check (
    status in (
      'active',
      'trialing',
      'expired',
      'billing_retry',
      'grace_period',
      'revoked',
      'pending_verification'
    )
  ),
  source text not null default 'app_store',
  environment text,
  original_transaction_id text,
  transaction_id text,
  expires_at timestamptz,
  auto_renew_status text,
  last_notification_type text,
  last_notification_subtype text,
  raw_payload jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists idx_subscription_entitlements_business
  on public.subscription_entitlements(business_id);

create index if not exists idx_subscription_entitlements_status
  on public.subscription_entitlements(status, expires_at);

create table if not exists public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  business_id uuid references public.businesses(id) on delete set null,
  product_id text,
  purchase_id text,
  original_transaction_id text,
  transaction_id text,
  verification_source text,
  verification_data text,
  status text not null default 'received',
  environment text,
  notification_type text,
  notification_subtype text,
  raw_payload jsonb,
  event_at timestamptz not null default now()
);

create index if not exists idx_subscription_events_user
  on public.subscription_events(user_id, event_at desc);

create index if not exists idx_subscription_events_original_tx
  on public.subscription_events(original_transaction_id, event_at desc);

create table if not exists public.backup_health (
  user_id uuid primary key references auth.users(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete cascade,
  last_backup_at timestamptz,
  last_restore_at timestamptz,
  size_bytes bigint,
  status text not null default 'unknown' check (
    status in ('ok', 'failed', 'restored', 'unknown')
  ),
  error_message text,
  updated_at timestamptz not null default now()
);

create index if not exists idx_backup_health_status
  on public.backup_health(status, updated_at desc);

create index if not exists idx_backup_health_business
  on public.backup_health(business_id);

create table if not exists public.app_error_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  business_id uuid references public.businesses(id) on delete set null,
  severity text not null default 'error' check (
    severity in ('info', 'warning', 'error', 'fatal')
  ),
  context text,
  message text not null,
  stack_trace text,
  app_version text,
  platform text,
  raw_payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_app_error_events_user
  on public.app_error_events(user_id, created_at desc);

create index if not exists idx_app_error_events_severity
  on public.app_error_events(severity, created_at desc);

create index if not exists idx_app_error_events_business
  on public.app_error_events(business_id, created_at desc);

create table if not exists public.admin_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete cascade,
  email text not null unique,
  created_at timestamptz not null default now()
);

create index if not exists idx_admin_users_email
  on public.admin_users(lower(email));

alter table public.businesses enable row level security;
alter table public.subscription_entitlements enable row level security;
alter table public.subscription_events enable row level security;
alter table public.backup_health enable row level security;
alter table public.app_error_events enable row level security;
alter table public.admin_users enable row level security;

drop policy if exists "Users read own business" on public.businesses;
drop policy if exists "Users update own business" on public.businesses;
drop policy if exists "Users read own entitlement" on public.subscription_entitlements;
drop policy if exists "Users read own subscription events" on public.subscription_events;
drop policy if exists "Users read own backup health" on public.backup_health;
drop policy if exists "Users read own app errors" on public.app_error_events;
drop policy if exists "Admins read admin users" on public.admin_users;

create policy "Users read own business"
on public.businesses
for select
to authenticated
using (owner_user_id = auth.uid());

create policy "Users update own business"
on public.businesses
for update
to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

create policy "Users read own entitlement"
on public.subscription_entitlements
for select
to authenticated
using (user_id = auth.uid());

create policy "Users read own subscription events"
on public.subscription_events
for select
to authenticated
using (user_id = auth.uid());

create policy "Users read own backup health"
on public.backup_health
for select
to authenticated
using (user_id = auth.uid());

create policy "Users read own app errors"
on public.app_error_events
for select
to authenticated
using (user_id = auth.uid());

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.admin_users au
    where au.user_id = auth.uid()
      or lower(au.email) = lower(coalesce(auth.email(), ''))
  );
$$;

create policy "Admins read admin users"
on public.admin_users
for select
to authenticated
using (public.is_admin());

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists businesses_touch_updated_at on public.businesses;
create trigger businesses_touch_updated_at
before update on public.businesses
for each row execute function public.touch_updated_at();

create or replace function public.upsert_manager_profile(
  business_name text,
  owner_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  current_email text := coalesce(auth.email(), '');
  existing_business public.businesses;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.businesses (
    owner_user_id,
    business_name,
    owner_name,
    email
  )
  values (
    current_user_id,
    nullif(trim(business_name), ''),
    nullif(trim(owner_name), ''),
    current_email
  )
  on conflict (owner_user_id)
  do update set
    business_name = excluded.business_name,
    owner_name = excluded.owner_name,
    email = excluded.email,
    deleted_at = null
  returning * into existing_business;

  return public.get_manager_access_state();
end;
$$;

create or replace function public.record_app_store_purchase(
  product_id text,
  purchase_id text,
  verification_source text,
  verification_data text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  business public.businesses;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into business
  from public.businesses
  where owner_user_id = current_user_id
  limit 1;

  insert into public.subscription_events (
    user_id,
    business_id,
    product_id,
    purchase_id,
    original_transaction_id,
    transaction_id,
    verification_source,
    verification_data,
    status
  )
  values (
    current_user_id,
    business.id,
    product_id,
    purchase_id,
    purchase_id,
    purchase_id,
    verification_source,
    verification_data,
    'pending_verification'
  );

  -- The app can optimistically unlock after StoreKit success, but production
  -- entitlement should be finalized by the Apple notification/verification
  -- function in supabase/functions/app-store-notifications.
  insert into public.subscription_entitlements (
    user_id,
    business_id,
    product_id,
    status,
    source,
    original_transaction_id,
    transaction_id,
    updated_at
  )
  values (
    current_user_id,
    business.id,
    product_id,
    'pending_verification',
    verification_source,
    purchase_id,
    purchase_id,
    now()
  )
  on conflict (user_id)
  do update set
    business_id = excluded.business_id,
    product_id = excluded.product_id,
    status = excluded.status,
    source = excluded.source,
    original_transaction_id = coalesce(
      public.subscription_entitlements.original_transaction_id,
      excluded.original_transaction_id
    ),
    transaction_id = excluded.transaction_id,
    updated_at = now();

  return public.get_manager_access_state();
end;
$$;

create or replace function public.record_backup_health(
  status text,
  size_bytes bigint default null,
  error_message text default null,
  event_kind text default 'backup'
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  business public.businesses;
  normalized_status text := lower(trim(status));
  now_at timestamptz := now();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if normalized_status not in ('ok', 'failed', 'restored', 'unknown') then
    raise exception 'Invalid backup status';
  end if;

  select * into business
  from public.businesses
  where owner_user_id = current_user_id
  limit 1;

  insert into public.backup_health (
    user_id,
    business_id,
    last_backup_at,
    last_restore_at,
    size_bytes,
    status,
    error_message,
    updated_at
  )
  values (
    current_user_id,
    business.id,
    case when event_kind = 'restore' then null else now_at end,
    case when event_kind = 'restore' then now_at else null end,
    size_bytes,
    normalized_status,
    nullif(trim(error_message), ''),
    now_at
  )
  on conflict (user_id)
  do update set
    business_id = excluded.business_id,
    last_backup_at = coalesce(
      excluded.last_backup_at,
      public.backup_health.last_backup_at
    ),
    last_restore_at = coalesce(
      excluded.last_restore_at,
      public.backup_health.last_restore_at
    ),
    size_bytes = coalesce(excluded.size_bytes, public.backup_health.size_bytes),
    status = excluded.status,
    error_message = excluded.error_message,
    updated_at = now_at;
end;
$$;

create or replace function public.record_app_error(
  severity text,
  context text,
  message text,
  stack_trace text default null,
  app_version text default null,
  platform text default null,
  raw_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  business public.businesses;
  normalized_severity text := lower(trim(coalesce(severity, 'error')));
begin
  if current_user_id is null then
    return;
  end if;

  if normalized_severity not in ('info', 'warning', 'error', 'fatal') then
    normalized_severity := 'error';
  end if;

  select * into business
  from public.businesses
  where owner_user_id = current_user_id
  limit 1;

  insert into public.app_error_events (
    user_id,
    business_id,
    severity,
    context,
    message,
    stack_trace,
    app_version,
    platform,
    raw_payload
  )
  values (
    current_user_id,
    business.id,
    normalized_severity,
    nullif(trim(context), ''),
    left(coalesce(message, 'Unknown error'), 4000),
    left(stack_trace, 12000),
    nullif(trim(app_version), ''),
    nullif(trim(platform), ''),
    raw_payload
  );
end;
$$;

create or replace function public.get_manager_access_state()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  business public.businesses;
  entitlement public.subscription_entitlements;
  admin_access boolean := public.is_admin();
  computed_status text;
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into business
  from public.businesses
  where owner_user_id = current_user_id
  limit 1;

  if business.id is null then
    return jsonb_build_object('status', 'missing_profile');
  end if;

  select * into entitlement
  from public.subscription_entitlements
  where user_id = current_user_id
  limit 1;

  if admin_access then
    computed_status := 'active';
  elsif entitlement.status in ('active', 'trialing', 'grace_period') and
     (entitlement.expires_at is null or entitlement.expires_at > now()) then
    computed_status := 'active';
  else
    computed_status := 'expired';
  end if;

  return jsonb_build_object(
    'business_id', business.id,
    'business_name', business.business_name,
    'owner_name', business.owner_name,
    'email', business.email,
    'trial_start_ts', floor(extract(epoch from business.trial_start_at) * 1000),
    'trial_end_ts', floor(extract(epoch from business.trial_end_at) * 1000),
    'subscription_status', computed_status,
    'entitlement_status', entitlement.status,
    'admin_access', admin_access,
    'subscription_product_id', entitlement.product_id,
    'subscription_purchase_id', entitlement.transaction_id,
    'subscription_updated_ts', floor(extract(epoch from entitlement.updated_at) * 1000),
    'expires_at', entitlement.expires_at
  );
end;
$$;

revoke all on function public.upsert_manager_profile(text, text) from public;
revoke all on function public.record_app_store_purchase(text, text, text, text) from public;
revoke all on function public.get_manager_access_state() from public;
revoke all on function public.record_backup_health(text, bigint, text, text) from public;
revoke all on function public.record_app_error(text, text, text, text, text, text, jsonb) from public;

grant execute on function public.upsert_manager_profile(text, text) to authenticated;
grant execute on function public.record_app_store_purchase(text, text, text, text) to authenticated;
grant execute on function public.get_manager_access_state() to authenticated;
grant execute on function public.record_backup_health(text, bigint, text, text) to authenticated;
grant execute on function public.record_app_error(text, text, text, text, text, text, jsonb) to authenticated;

create or replace view public.admin_business_overview as
select
  b.id as business_id,
  b.business_name,
  b.owner_name,
  b.email,
  b.created_at,
  b.trial_end_at,
  coalesce(se.status, 'none') as entitlement_status,
  se.product_id,
  se.expires_at,
  se.updated_at as entitlement_updated_at,
  coalesce(bh.status, 'unknown') as backup_status,
  bh.last_backup_at,
  bh.last_restore_at,
  bh.size_bytes as backup_size_bytes,
  bh.error_message as backup_error,
  bh.updated_at as backup_updated_at
from public.businesses b
left join public.subscription_entitlements se
  on se.user_id = b.owner_user_id
left join public.backup_health bh
  on bh.user_id = b.owner_user_id
where b.deleted_at is null;

create or replace view public.admin_attention_overview as
select
  b.id as business_id,
  b.business_name,
  b.email,
  case
    when se.status in ('expired', 'billing_retry', 'revoked') then 'subscription'
    when bh.status = 'failed' then 'backup'
    when bh.last_backup_at is null then 'backup'
    when bh.last_backup_at < now() - interval '7 days' then 'backup'
    when exists (
      select 1
      from public.app_error_events e
      where e.business_id = b.id
        and e.severity in ('error', 'fatal')
        and e.created_at > now() - interval '24 hours'
    ) then 'app_error'
    else 'ok'
  end as attention_type,
  coalesce(se.status, 'none') as entitlement_status,
  se.expires_at,
  coalesce(bh.status, 'unknown') as backup_status,
  bh.last_backup_at,
  bh.error_message as backup_error,
  (
    select count(*)
    from public.app_error_events e
    where e.business_id = b.id
      and e.severity in ('error', 'fatal')
      and e.created_at > now() - interval '24 hours'
  ) as errors_24h
from public.businesses b
left join public.subscription_entitlements se
  on se.user_id = b.owner_user_id
left join public.backup_health bh
  on bh.user_id = b.owner_user_id
where b.deleted_at is null;

create or replace function public.admin_get_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  stats jsonb;
  attention jsonb;
  businesses jsonb;
  recent_errors jsonb;
  recent_subscription_events jsonb;
begin
  if not public.is_admin() then
    raise exception 'Not authorized';
  end if;

  select jsonb_build_object(
    'businesses_total', count(*),
    'subscriptions_active', count(*) filter (
      where entitlement_status in ('active', 'grace_period')
    ),
    'subscriptions_pending_verification', count(*) filter (
      where entitlement_status = 'pending_verification'
    ),
    'subscriptions_expired_or_retry', count(*) filter (
      where entitlement_status in ('expired', 'billing_retry', 'revoked')
    ),
    'trials_running', count(*) filter (
      where entitlement_status in ('none', 'pending_verification')
        and trial_end_at > now()
    ),
    'trials_expired_without_subscription', count(*) filter (
      where entitlement_status in ('none', 'pending_verification')
        and trial_end_at <= now()
    ),
    'backup_failed', count(*) filter (where backup_status = 'failed'),
    'backup_missing_or_stale', count(*) filter (
      where last_backup_at is null
        or last_backup_at < now() - interval '7 days'
    ),
    'errors_24h', (
      select count(*)
      from public.app_error_events e
      where e.severity in ('error', 'fatal')
        and e.created_at > now() - interval '24 hours'
    )
  )
  into stats
  from public.admin_business_overview;

  select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb)
  into attention
  from (
    select *
    from public.admin_attention_overview
    where attention_type <> 'ok'
    order by
      case attention_type
        when 'subscription' then 1
        when 'app_error' then 2
        when 'backup' then 3
        else 4
      end,
      business_name
    limit 100
  ) a;

  select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb)
  into businesses
  from (
    select *
    from public.admin_business_overview
    order by created_at desc
    limit 200
  ) b;

  select coalesce(jsonb_agg(to_jsonb(e)), '[]'::jsonb)
  into recent_errors
  from (
    select
      e.id,
      e.business_id,
      b.business_name,
      b.email,
      e.severity,
      e.context,
      e.message,
      e.app_version,
      e.platform,
      e.created_at
    from public.app_error_events e
    left join public.businesses b
      on b.id = e.business_id
    order by e.created_at desc
    limit 100
  ) e;

  select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
  into recent_subscription_events
  from (
    select
      se.id,
      se.business_id,
      b.business_name,
      b.email,
      se.product_id,
      se.status,
      se.environment,
      se.notification_type,
      se.notification_subtype,
      se.event_at
    from public.subscription_events se
    left join public.businesses b
      on b.id = se.business_id
    order by se.event_at desc
    limit 100
  ) s;

  return jsonb_build_object(
    'generated_at', now(),
    'stats', stats,
    'attention', attention,
    'businesses', businesses,
    'recent_errors', recent_errors,
    'recent_subscription_events', recent_subscription_events
  );
end;
$$;

revoke all on function public.is_admin() from public;
revoke all on function public.admin_get_dashboard() from public;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.admin_get_dashboard() to authenticated;
