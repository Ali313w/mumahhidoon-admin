-- ═══════════════════════════════════════════════════════════════════
--  مكتبة ممهدون — إعداد قاعدة البيانات (Supabase)
--  شغّل هذا الملف كاملاً في SQL Editor. آمن للتشغيل أكثر من مرة.
-- ═══════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- ───────────────────────── 1) الجداول ─────────────────────────

create table if not exists public.categories (
  id          text primary key default ('cat_' || replace(gen_random_uuid()::text, '-', '')),
  name        text not null,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now()
);
alter table public.categories add column if not exists sort_order int not null default 0;

create table if not exists public.books (
  id            text primary key default ('bk_' || replace(gen_random_uuid()::text, '-', '')),
  title         text not null,
  author        text not null default '',
  category_id   text references public.categories(id) on update cascade on delete restrict,
  price         int  not null default 0,
  old_price     int,
  pages         int  not null default 0,
  description   text not null default '',
  cover_url     text,
  cover_path    text,
  cover_image   text,
  available     boolean not null default true,
  featured      boolean not null default false,
  is_new        boolean not null default false,
  best_seller   boolean not null default false,
  special_offer boolean not null default false,
  popularity    int  not null default 0,
  added_on      date not null default current_date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.books add column if not exists cover_url text;
alter table public.books add column if not exists cover_path text;
alter table public.books add column if not exists cover_image text;
alter table public.books add column if not exists available boolean not null default true;
alter table public.books add column if not exists best_seller boolean not null default false;
alter table public.books add column if not exists special_offer boolean not null default false;
create index if not exists books_category_idx on public.books(category_id);

create table if not exists public.orders (
  id             uuid primary key default gen_random_uuid(),
  order_number   text not null unique,
  customer_name  text not null,
  phone          text not null,
  governorate    text not null,
  address        text not null,
  landmark       text not null default '',
  notes          text not null default '',
  books_total    int  not null default 0,
  delivery_fee   int  not null default 0,
  grand_total    int  not null default 0,
  item_count     int  not null default 0,
  status         text not null default 'new',
  internal_note  text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists orders_created_idx on public.orders(created_at desc);
create index if not exists orders_status_idx on public.orders(status);
create index if not exists orders_phone_idx on public.orders(phone);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'orders_status_check') then
    alter table public.orders add constraint orders_status_check
      check (status in ('new', 'preparing', 'shipped', 'delivered', 'cancelled'));
  end if;
end $$;

create table if not exists public.order_items (
  id          bigserial primary key,
  order_id    uuid not null references public.orders(id) on delete cascade,
  book_id     text references public.books(id) on update cascade on delete set null,
  title       text not null,
  unit_price  int  not null,
  quantity    int  not null,
  line_total  int  not null,
  created_at  timestamptz not null default now()
);
create index if not exists order_items_order_idx on public.order_items(order_id);

create table if not exists public.order_status_history (
  id              bigserial primary key,
  order_id        uuid not null references public.orders(id) on delete cascade,
  from_status     text,
  to_status       text not null,
  changed_by      uuid,
  changed_by_name text not null default '',
  changed_at      timestamptz not null default now()
);
create index if not exists order_history_order_idx on public.order_status_history(order_id, changed_at);

create table if not exists public.settings (
  id                    int primary key default 1,
  whatsapp_number       text not null default '964XXXXXXXXXX',  -- ضع رقم واتساب المكتبة
  delivery_fee_najaf    int  not null default 3000,
  delivery_fee_other    int  not null default 5000,
  about_text            text not null default '',
  announcement          text not null default '',
  announcement_enabled  boolean not null default false,
  updated_at            timestamptz not null default now(),
  constraint settings_single_row check (id = 1)
);

create table if not exists public.staff (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  email       text not null default '',
  full_name   text not null default '',
  role        text,
  status      text not null default 'pending',
  created_at  timestamptz not null default now()
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'staff_role_check') then
    alter table public.staff add constraint staff_role_check
      check (role is null or role in ('super_admin', 'manager', 'orders_clerk'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'staff_status_check') then
    alter table public.staff add constraint staff_status_check
      check (status in ('pending', 'active', 'suspended'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'staff_active_has_role') then
    alter table public.staff add constraint staff_active_has_role
      check (status <> 'active' or role is not null);
  end if;
end $$;

create sequence if not exists public.order_number_seq start 1;

-- ───────────────────────── 2) الدوال المساعدة ─────────────────────────

-- هل المستخدم الحالي موظف فعّال؟
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.staff
    where user_id = auth.uid() and status = 'active' and role is not null
  );
$$;

-- هل المستخدم الحالي فعّال ويملك إحدى الصلاحيات؟
create or replace function public.has_role(roles text[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.staff
    where user_id = auth.uid() and status = 'active' and role = any(roles)
  );
$$;

-- صحيح عند التنفيذ من SQL Editor أو بمفتاح الخدمة (لا يوجد مستخدم من التطبيق).
create or replace function public._is_backend()
returns boolean language sql stable as $$
  select auth.uid() is null
     and coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '')
         not in ('anon', 'authenticated');
$$;

-- يحوّل الأرقام العربية والفارسية إلى إنجليزية ويحذف المسافات والشرطات.
create or replace function public._normalize_phone(p text)
returns text language sql immutable as $$
  select regexp_replace(
    translate(coalesce(p, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789'),
    '[^0-9]', '', 'g');
$$;

create or replace function public._touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists books_touch on public.books;
create trigger books_touch before update on public.books
  for each row execute function public._touch_updated_at();
drop trigger if exists orders_touch on public.orders;
create trigger orders_touch before update on public.orders
  for each row execute function public._touch_updated_at();
drop trigger if exists settings_touch on public.settings;
create trigger settings_touch before update on public.settings
  for each row execute function public._touch_updated_at();

-- ───────────────────────── 3) تسجيل الموظفين وحمايتهم ─────────────────────────

-- الطريقة الوحيدة لإنشاء صف في staff. كل حساب جديد يُنشأ معلّقاً بلا صلاحية،
-- والاستثناء الوحيد: إذا لم يوجد أي مدير رئيسي فعّال، يصبح أول حساب مديراً رئيسياً.
-- استدعاؤها مرة ثانية لا يغيّر الصف الموجود.
create or replace function public.register_staff(full_name text)
returns public.staff
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  uid        uuid := auth.uid();
  nm         text := left(btrim(coalesce(register_staff.full_name, '')), 80);
  em         text;
  r          public.staff;
  first_admin boolean;
begin
  if uid is null then
    raise exception using message = 'يجب تسجيل الدخول أولاً', errcode = '28000';
  end if;

  perform pg_advisory_xact_lock(hashtext('public.staff_admins'));

  select * into r from public.staff s where s.user_id = uid;
  if found then
    return r;
  end if;

  select u.email into em from auth.users u where u.id = uid;
  if nm = '' then
    nm := split_part(coalesce(em, ''), '@', 1);
  end if;

  first_admin := not exists (
    select 1 from public.staff s where s.role = 'super_admin' and s.status = 'active'
  );

  perform set_config('app.staff_insert', 'on', true);
  insert into public.staff (user_id, email, full_name, role, status)
  values (uid, coalesce(em, ''), nm,
          case when first_admin then 'super_admin' end,
          case when first_admin then 'active' else 'pending' end)
  returning * into r;
  perform set_config('app.staff_insert', 'off', true);
  return r;
end $$;

revoke all on function public.register_staff(text) from public, anon;
grant execute on function public.register_staff(text) to authenticated;

-- لا يغيّر الصلاحية أو الحالة إلا مدير رئيسي فعّال، ولا أحد يغيّر صلاحيته بنفسه،
-- ولا يمكن إيقاف أو تخفيض أو حذف آخر مدير رئيسي فعّال.
create or replace function public._staff_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  backend boolean := public._is_backend();
  other_admins int;
begin
  if tg_op = 'INSERT' then
    if not backend then
      if coalesce(current_setting('app.staff_insert', true), '') <> 'on' then
        raise exception using message = 'لا يمكن إنشاء موظف مباشرة', errcode = '42501';
      end if;
      perform pg_advisory_xact_lock(hashtext('public.staff_admins'));
      -- حساب فعّال يُقبل فقط كأول مدير رئيسي؛ أي شيء آخر يصبح معلّقاً بلا صلاحية.
      if new.role is distinct from 'super_admin' or new.status <> 'active'
         or exists (select 1 from public.staff where role = 'super_admin' and status = 'active') then
        new.role   := null;
        new.status := 'pending';
      end if;
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    new.user_id    := old.user_id;
    new.created_at := old.created_at;
    if not backend then
      new.email := old.email;
    end if;
    new.full_name := left(btrim(coalesce(new.full_name, '')), 80);
    if new.full_name = '' then
      new.full_name := old.full_name;
    end if;

    if new.role is distinct from old.role or new.status is distinct from old.status then
      if not backend then
        if not public.has_role(array['super_admin']) then
          raise exception using message = 'تغيير الصلاحية أو الحالة للمدير الرئيسي فقط', errcode = '42501';
        end if;
        if old.user_id = auth.uid() then
          raise exception using message = 'لا يمكنك تغيير صلاحيتك أو حالتك بنفسك', errcode = '42501';
        end if;
      end if;
      if old.role = 'super_admin' and old.status = 'active'
         and (new.role is distinct from 'super_admin' or new.status <> 'active') then
        perform pg_advisory_xact_lock(hashtext('public.staff_admins'));
        select count(*) into other_admins from public.staff
          where role = 'super_admin' and status = 'active' and user_id <> old.user_id;
        if other_admins = 0 then
          raise exception using message = 'لا يمكن إيقاف أو تغيير صلاحية آخر مدير رئيسي',
            errcode = 'P0001', hint = 'last_super_admin';
        end if;
      end if;
    end if;
    return new;
  end if;

  -- DELETE
  if not backend then
    if not public.has_role(array['super_admin']) then
      raise exception using message = 'حذف الحسابات للمدير الرئيسي فقط', errcode = '42501';
    end if;
    if old.user_id = auth.uid() then
      raise exception using message = 'لا يمكنك حذف حسابك بنفسك', errcode = '42501';
    end if;
  end if;
  if old.role = 'super_admin' and old.status = 'active' then
    perform pg_advisory_xact_lock(hashtext('public.staff_admins'));
    select count(*) into other_admins from public.staff
      where role = 'super_admin' and status = 'active' and user_id <> old.user_id;
    if other_admins = 0 then
      raise exception using message = 'لا يمكن حذف آخر مدير رئيسي', errcode = 'P0001', hint = 'last_super_admin';
    end if;
  end if;
  return old;
end $$;

drop trigger if exists staff_guard on public.staff;
create trigger staff_guard before insert or update or delete on public.staff
  for each row execute function public._staff_guard();

-- ───────────────────────── 4) الطلبات ─────────────────────────

-- الموظفون يغيّرون الحالة والملاحظة الداخلية فقط؛ بيانات الطلب ومبالغه ثابتة.
create or replace function public._orders_guard()
returns trigger language plpgsql as $$
begin
  if not public._is_backend() then
    new.id            := old.id;
    new.order_number  := old.order_number;
    new.customer_name := old.customer_name;
    new.phone         := old.phone;
    new.governorate   := old.governorate;
    new.address       := old.address;
    new.landmark      := old.landmark;
    new.notes         := old.notes;
    new.books_total   := old.books_total;
    new.delivery_fee  := old.delivery_fee;
    new.grand_total   := old.grand_total;
    new.item_count    := old.item_count;
    new.created_at    := old.created_at;
  end if;
  new.internal_note := left(coalesce(new.internal_note, ''), 2000);
  return new;
end $$;

drop trigger if exists orders_guard on public.orders;
create trigger orders_guard before update on public.orders
  for each row execute function public._orders_guard();

-- سجل الحالات: من غيّر، ومتى، ومن أي حالة إلى أي حالة.
create or replace function public._orders_history()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  who_name text := '';
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history (order_id, from_status, to_status, changed_by, changed_by_name)
    values (new.id, null, new.status, null, 'المشتري');
    return new;
  end if;
  if new.status is distinct from old.status then
    if auth.uid() is not null then
      select coalesce(nullif(s.full_name, ''), s.email, '') into who_name
        from public.staff s where s.user_id = auth.uid();
    end if;
    insert into public.order_status_history (order_id, from_status, to_status, changed_by, changed_by_name)
    values (new.id, old.status, new.status, auth.uid(), coalesce(who_name, ''));
  end if;
  return new;
end $$;

drop trigger if exists orders_history on public.orders;
create trigger orders_history after insert or update on public.orders
  for each row execute function public._orders_history();

-- إنشاء طلب من تطبيق المكتبة (متاح للزوار). الأسعار تُقرأ من جدول الكتب ولا تُقبل من المشتري.
-- payload = {"name","phone","governorate","address","landmark","notes",
--            "items":[{"book_id":"b01","quantity":2}, ...]}
create or replace function public.create_order(payload jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_name   text;
  v_phone  text;
  v_gov    text;
  v_addr   text;
  v_land   text;
  v_notes  text;
  v_items  jsonb;
  v_fee    int;
  v_najaf  int;
  v_other  int;
  v_books  int := 0;
  v_count  int := 0;
  v_order  public.orders;
  v_number text;
  v_lines  jsonb := '[]'::jsonb;
  it       record;
  bk       public.books;
  govs     text[] := array['النجف','بغداد','كربلاء','بابل','البصرة','الديوانية','واسط','ميسان','ذي قار',
                           'المثنى','ديالى','الأنبار','صلاح الدين','كركوك','نينوى','أربيل','دهوك','السليمانية'];
begin
  if payload is null or jsonb_typeof(payload) <> 'object' then
    raise exception using message = 'بيانات الطلب غير صحيحة', errcode = '22023', hint = 'invalid_payload';
  end if;

  v_name  := btrim(coalesce(payload ->> 'name', ''));
  v_phone := public._normalize_phone(payload ->> 'phone');
  v_gov   := btrim(coalesce(payload ->> 'governorate', ''));
  v_addr  := btrim(coalesce(payload ->> 'address', ''));
  v_land  := btrim(coalesce(payload ->> 'landmark', ''));
  v_notes := btrim(coalesce(payload ->> 'notes', ''));
  v_items := payload -> 'items';

  if char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception using message = 'الاسم مطلوب (من 2 إلى 80 حرفاً)', errcode = '22023', hint = 'invalid_name';
  end if;
  if v_phone !~ '^07[0-9]{9}$' then
    raise exception using message = 'رقم الهاتف يجب أن يتكون من 11 رقماً ويبدأ بـ 07',
      errcode = '22023', hint = 'invalid_phone';
  end if;
  if not (v_gov = any(govs)) then
    raise exception using message = 'اختر محافظة صحيحة', errcode = '22023', hint = 'invalid_governorate';
  end if;
  if char_length(v_addr) < 3 or char_length(v_addr) > 300 then
    raise exception using message = 'العنوان مطلوب (من 3 إلى 300 حرف)', errcode = '22023', hint = 'invalid_address';
  end if;
  if char_length(v_land) > 200 then
    raise exception using message = 'أقرب نقطة دالة طويلة جداً', errcode = '22023', hint = 'invalid_landmark';
  end if;
  if char_length(v_notes) > 500 then
    raise exception using message = 'الملاحظات طويلة جداً', errcode = '22023', hint = 'invalid_notes';
  end if;
  if v_items is null or jsonb_typeof(v_items) <> 'array'
     or jsonb_array_length(v_items) < 1 or jsonb_array_length(v_items) > 50 then
    raise exception using message = 'السلة فارغة أو فيها عدد كبير جداً من الكتب',
      errcode = '22023', hint = 'invalid_items';
  end if;
  if exists (select 1 from jsonb_array_elements(v_items) e
             where jsonb_typeof(e) <> 'object'
                or case when coalesce(e ->> 'quantity', '') ~ '^[0-9]{1,2}$'
                        then (e ->> 'quantity')::int < 1 else true end
                or char_length(coalesce(e ->> 'book_id', '')) not between 1 and 64) then
    raise exception using message = 'بيانات الكتب غير صحيحة', errcode = '22023', hint = 'invalid_items';
  end if;

  -- التحقق من كل كتاب (يُقبل المعرّف والكمية فقط)، مع دمج الكتب المكررة
  for it in
    select x.book_id, sum(x.qty)::int as qty
    from (
      select btrim(coalesce(e ->> 'book_id', '')) as book_id,
             case when (e ->> 'quantity') ~ '^[0-9]{1,3}$' then (e ->> 'quantity')::int else -1 end as qty
      from jsonb_array_elements(v_items) e
    ) x
    group by x.book_id
    order by x.book_id
  loop
    if it.qty < 1 or it.qty > 99 then
      raise exception using message = 'الكمية يجب أن تكون بين 1 و 99', errcode = '22023', hint = 'invalid_quantity';
    end if;
    select * into bk from public.books b where b.id = it.book_id;
    if not found then
      raise exception using message = 'أحد الكتب لم يعد موجوداً', errcode = '22023',
        hint = 'book_not_found', detail = it.book_id;
    end if;
    if not bk.available then
      raise exception using message = format('الكتاب «%s» غير متوفر حالياً', bk.title), errcode = '22023',
        hint = 'book_unavailable', detail = it.book_id;
    end if;
    v_books := v_books + bk.price * it.qty;
    v_count := v_count + it.qty;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'book_id', bk.id, 'title', bk.title, 'unit_price', bk.price,
      'quantity', it.qty, 'line_total', bk.price * it.qty));
  end loop;

  if v_count > 500 then
    raise exception using message = 'عدد النسخ كبير جداً', errcode = '22023', hint = 'too_many_copies';
  end if;

  select s.delivery_fee_najaf, s.delivery_fee_other into v_najaf, v_other
    from public.settings s where s.id = 1;
  v_fee := case when v_gov = 'النجف' then coalesce(v_najaf, 3000) else coalesce(v_other, 5000) end;

  v_number := 'MM-' || to_char(now() at time zone 'Asia/Baghdad', 'YYMMDD') || '-'
              || lpad(nextval('public.order_number_seq')::text, 4, '0');

  insert into public.orders (order_number, customer_name, phone, governorate, address, landmark, notes,
                             books_total, delivery_fee, grand_total, item_count, status)
  values (v_number, v_name, v_phone, v_gov, v_addr, v_land, v_notes,
          v_books, v_fee, v_books + v_fee, v_count, 'new')
  returning * into v_order;

  insert into public.order_items (order_id, book_id, title, unit_price, quantity, line_total)
  select v_order.id, l ->> 'book_id', l ->> 'title', (l ->> 'unit_price')::int,
         (l ->> 'quantity')::int, (l ->> 'line_total')::int
  from jsonb_array_elements(v_lines) l;

  return jsonb_build_object(
    'order_number', v_order.order_number,
    'created_at',   v_order.created_at,
    'governorate',  v_order.governorate,
    'books_total',  v_order.books_total,
    'delivery_fee', v_order.delivery_fee,
    'grand_total',  v_order.grand_total,
    'item_count',   v_order.item_count,
    'items',        v_lines
  );
end $$;

revoke all on function public.create_order(jsonb) from public;
grant execute on function public.create_order(jsonb) to anon, authenticated;

-- حالة طلبات المشتري: يُرجع رقم الطلب وحالته فقط، وبشرط تطابق رقم الهاتف.
create or replace function public.get_orders_status(order_numbers text[], phone text)
returns table (order_number text, status text)
language plpgsql stable security definer set search_path = public as $$
declare
  p text := public._normalize_phone($2);
begin
  if $1 is null or cardinality($1) = 0 or cardinality($1) > 50 or p !~ '^07[0-9]{9}$' then
    return;
  end if;
  return query
    select o.order_number, o.status from public.orders o
    where o.order_number = any($1) and o.phone = p;
end $$;

revoke all on function public.get_orders_status(text[], text) from public;
grant execute on function public.get_orders_status(text[], text) to anon, authenticated;

grant execute on function public.is_staff() to anon, authenticated;
grant execute on function public.has_role(text[]) to anon, authenticated;

-- ───────────────────────── 5) سياسات الأمان (RLS) ─────────────────────────

alter table public.categories           enable row level security;
alter table public.books                enable row level security;
alter table public.orders               enable row level security;
alter table public.order_items          enable row level security;
alter table public.order_status_history enable row level security;
alter table public.settings             enable row level security;
alter table public.staff                enable row level security;

-- الزائر: قراءة الكتب والأقسام والإعدادات فقط (الطلب عبر create_order).
revoke all on public.orders, public.order_items, public.order_status_history, public.staff from anon;
revoke insert, update, delete, truncate, references, trigger
  on public.categories, public.books, public.settings from anon;

-- المستخدم المسجّل: ما تسمح به سياسات RLS أدناه فقط.
revoke truncate, references, trigger
  on public.categories, public.books, public.settings, public.orders, public.order_items,
     public.order_status_history, public.staff from authenticated;
revoke insert, delete on public.settings from authenticated;
revoke insert, delete on public.orders from authenticated;
revoke insert, update, delete on public.order_items, public.order_status_history from authenticated;
revoke insert on public.staff from authenticated;

grant usage on schema public to anon, authenticated;
grant select on public.categories, public.books, public.settings to anon, authenticated;
grant insert, update, delete on public.categories, public.books to authenticated;
grant update on public.settings to authenticated;
grant select, update on public.orders to authenticated;
grant select on public.order_items, public.order_status_history to authenticated;
grant select, update, delete on public.staff to authenticated;

do $$
declare
  sq text;
begin
  foreach sq in array array['public.order_number_seq', 'public.order_items_id_seq', 'public.order_status_history_id_seq'] loop
    if to_regclass(sq) is not null then
      execute format('revoke all on sequence %s from anon, authenticated', sq);
    end if;
  end loop;
end $$;

-- تُحذف أي سياسة إضافية على جداول المكتبة (مثلاً أُنشئت من لوحة التحكم)،
-- لأن السياسات تُجمع بـ OR وأي سياسة متساهلة تفتح الجدول.

do $$
declare
  p record;
begin
  for p in
    select tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('categories', 'books', 'settings', 'orders', 'order_items',
                        'order_status_history', 'staff')
      and policyname not in ('categories_read', 'categories_insert', 'categories_update', 'categories_delete',
                             'books_read', 'books_insert', 'books_update', 'books_delete',
                             'settings_read', 'settings_update',
                             'orders_read', 'orders_update',
                             'order_items_read', 'order_history_read',
                             'staff_read_own', 'staff_read_admin', 'staff_update_own',
                             'staff_update_admin', 'staff_delete_admin')
  loop
    raise notice 'حذف سياسة غير معروفة: %.%', p.tablename, p.policyname;
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- الأقسام
drop policy if exists categories_read   on public.categories;
drop policy if exists categories_insert on public.categories;
drop policy if exists categories_update on public.categories;
drop policy if exists categories_delete on public.categories;
create policy categories_read   on public.categories for select to anon, authenticated using (true);
create policy categories_insert on public.categories for insert to authenticated
  with check (public.has_role(array['super_admin', 'manager']));
create policy categories_update on public.categories for update to authenticated
  using (public.has_role(array['super_admin', 'manager']))
  with check (public.has_role(array['super_admin', 'manager']));
create policy categories_delete on public.categories for delete to authenticated
  using (public.has_role(array['super_admin', 'manager']));

-- الكتب
drop policy if exists books_read   on public.books;
drop policy if exists books_insert on public.books;
drop policy if exists books_update on public.books;
drop policy if exists books_delete on public.books;
create policy books_read   on public.books for select to anon, authenticated using (true);
create policy books_insert on public.books for insert to authenticated
  with check (public.has_role(array['super_admin', 'manager']));
create policy books_update on public.books for update to authenticated
  using (public.has_role(array['super_admin', 'manager']))
  with check (public.has_role(array['super_admin', 'manager']));
create policy books_delete on public.books for delete to authenticated
  using (public.has_role(array['super_admin', 'manager']));

-- الإعدادات
drop policy if exists settings_read   on public.settings;
drop policy if exists settings_update on public.settings;
create policy settings_read   on public.settings for select to anon, authenticated using (true);
create policy settings_update on public.settings for update to authenticated
  using (public.has_role(array['super_admin']))
  with check (public.has_role(array['super_admin']));

-- الطلبات (لا إدراج مباشر لأحد؛ الإدراج عبر create_order فقط)
drop policy if exists orders_read   on public.orders;
drop policy if exists orders_update on public.orders;
create policy orders_read   on public.orders for select to authenticated using (public.is_staff());
create policy orders_update on public.orders for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- عناصر الطلب: قراءة فقط (لا يعدّل أحد الأسعار أو الكميات).
drop policy if exists order_items_read   on public.order_items;
drop policy if exists order_items_update on public.order_items;
create policy order_items_read on public.order_items for select to authenticated using (public.is_staff());

drop policy if exists order_history_read on public.order_status_history;
create policy order_history_read on public.order_status_history for select to authenticated
  using (public.is_staff());

-- الموظفون: كل مستخدم يقرأ صفه فقط (لمعرفة حالة طلبه)، والمدير الرئيسي يقرأ ويدير الجميع.
drop policy if exists staff_read_own    on public.staff;
drop policy if exists staff_read_admin  on public.staff;
drop policy if exists staff_update_own  on public.staff;
drop policy if exists staff_update_admin on public.staff;
drop policy if exists staff_delete_admin on public.staff;
create policy staff_read_own   on public.staff for select to authenticated using (user_id = auth.uid());
create policy staff_read_admin on public.staff for select to authenticated
  using (public.has_role(array['super_admin']));
-- تعديل الاسم لصاحب الحساب الفعّال فقط (المشغّل staff_guard يمنع تغيير الصلاحية والحالة)؛
-- المعلّق والموقوف لا يكتبان شيئاً.
create policy staff_update_own on public.staff for update to authenticated
  using (user_id = auth.uid() and public.is_staff())
  with check (user_id = auth.uid());
create policy staff_update_admin on public.staff for update to authenticated
  using (public.has_role(array['super_admin'])) with check (public.has_role(array['super_admin']));
create policy staff_delete_admin on public.staff for delete to authenticated
  using (public.has_role(array['super_admin']));

-- ───────────────────────── 6) تخزين الأغلفة ─────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('covers', 'covers', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists covers_read   on storage.objects;
drop policy if exists covers_insert on storage.objects;
drop policy if exists covers_update on storage.objects;
drop policy if exists covers_delete on storage.objects;
create policy covers_read on storage.objects for select to anon, authenticated
  using (bucket_id = 'covers');
create policy covers_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'covers' and public.has_role(array['super_admin', 'manager']));
create policy covers_update on storage.objects for update to authenticated
  using (bucket_id = 'covers' and public.has_role(array['super_admin', 'manager']))
  with check (bucket_id = 'covers' and public.has_role(array['super_admin', 'manager']));
create policy covers_delete on storage.objects for delete to authenticated
  using (bucket_id = 'covers' and public.has_role(array['super_admin', 'manager']));

-- ───────────────────────── 7) التحديث الفوري (Realtime) ─────────────────────────

do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  foreach t in array array['orders', 'staff', 'books', 'categories', 'settings'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ───────────────────────── 8) البيانات الأولية ─────────────────────────
-- لا تُستبدل البيانات الموجودة عند إعادة التشغيل (on conflict do nothing).

insert into public.settings (id, whatsapp_number, delivery_fee_najaf, delivery_fee_other, about_text,
                             announcement, announcement_enabled)
values (1, '964XXXXXXXXXX', 3000, 5000,  -- ضع رقم واتساب المكتبة بالصيغة الدولية بدون +
  'مكتبة ممهدون مكتبةٌ تؤمن بأن الكتاب الجيد رفيق العمر. نختار عناويننا بعناية في الفكر والعقيدة والتاريخ والأدب والتربية وكتب الأطفال، ونوصلها إلى بابك في جميع محافظات العراق، والدفع نقداً عند الاستلام.',
  '', false)
on conflict (id) do nothing;

insert into public.categories (id, name, sort_order) values
  ('thought',    'فكر وثقافة',   1),
  ('creed',      'عقيدة ومعارف', 2),
  ('history',    'تاريخ وسيرة',  3),
  ('literature', 'أدب وشعر',     4),
  ('family',     'تربية وأسرة',  5),
  ('kids',       'أطفال وناشئة', 6)
on conflict (id) do nothing;

insert into public.books (id, title, author, category_id, pages, price, old_price, description,
                          featured, is_new, best_seller, special_offer, popularity, added_on, available)
values
  ('b01', 'ضفاف الوعي', 'سالم الموسوي', 'thought', 264, 12000, 15000,
   'رحلة تأملية في أسئلة الإنسان المعاصر: كيف نفكر، ولماذا نختلف، وكيف نبني وعياً متوازناً وسط ضجيج المعلومات. يكتب المؤلف بلغة قريبة تجمع بين العمق والوضوح.',
   true, false, true, true, 95, '2026-09-02', true),
  ('b02', 'مدن الكلمات', 'هدى الشمّري', 'thought', 198, 9000, null,
   'مقالات قصيرة عن اللغة والهوية والقراءة، وعن الطريقة التي تصنع بها الكلمات عالمنا الداخلي قبل أن تصنع عالمنا الخارجي.',
   false, true, false, false, 60, '2026-10-20', true),
  ('b03', 'سؤال النهضة المؤجل', 'كاظم العبيدي', 'thought', 312, 14000, null,
   'قراءة هادئة في مشاريع النهوض الفكري خلال القرن الأخير، وما الذي نجح منها وما الذي تعثر، مع مقترحات عملية لجيل جديد من القرّاء.',
   false, false, false, false, 72, '2026-06-11', true),
  ('b04', 'رسائل إلى قارئ شاب', 'نزار الحسني', 'thought', 156, 7000, 9000,
   'رسائل دافئة لشاب يبدأ طريقه مع الكتب: ماذا يقرأ، وكيف يقرأ، وكيف يحوّل القراءة إلى عادة تصنع شخصيته.',
   false, false, true, true, 88, '2026-05-03', true),
  ('b05', 'نور اليقين', 'محمد باقر الطائي', 'creed', 240, 11000, null,
   'مدخل ميسّر إلى أصول المعرفة الدينية، يعرض المسائل الكبرى بأسلوب واضح يناسب الشباب والقرّاء الجدد، مع أسئلة للتأمل في نهاية كل فصل.',
   true, false, true, false, 98, '2026-08-15', true),
  ('b06', 'معالم الانتظار', 'علي الكعبي', 'creed', 288, 13000, null,
   'دراسة في معنى الانتظار الإيجابي وأثره في بناء الفرد والمجتمع، بعيداً عن السلبية، وقريباً من العمل والإصلاح والأمل.',
   true, true, true, false, 90, '2026-10-28', true),
  ('b07', 'دروس في الأخلاق العملية', 'حسن الجابري', 'creed', 176, 8000, 10000,
   'دروس قصيرة تربط القيم الأخلاقية بتفاصيل الحياة اليومية: في البيت والعمل والطريق، مع أمثلة وقصص من الواقع.',
   false, false, false, true, 80, '2026-04-19', true),
  ('b08', 'مفاتيح التدبر', 'زينب الحلّي', 'creed', 220, 10000, null,
   'منهج عملي للتدبر في النصوص، يبدأ من القراءة المتأنية وينتهي بأثرها في السلوك، مكتوب بلغة سهلة ومرتبة.',
   false, false, false, false, 66, '2026-07-07', true),
  ('b09', 'على خطى القوافل', 'عبد الأمير الربيعي', 'history', 356, 16000, null,
   'حكاية طرق التجارة والعلم التي عبرت مدن الرافدين، وكيف حملت القوافل الكتب والأفكار مع البضائع، في سرد ممتع يقترب من الرواية.',
   true, false, false, false, 77, '2026-08-30', true),
  ('b10', 'رجال في ذاكرة المدينة', 'جعفر النقّاش', 'history', 292, 13000, 16000,
   'سِيَر قصيرة لعلماء وحرفيين ومعلمين صنعوا روح مدينتهم، مستعادة من الذاكرة الشفهية والوثائق القديمة.',
   false, false, false, true, 70, '2026-03-12', true),
  ('b11', 'دفاتر الوراقين', 'مريم الأسدي', 'history', 210, 11000, null,
   'تاريخ صناعة الكتاب ونسخه وتجليده، وقصص الوراقين الذين حفظوا المعرفة بأيديهم قبل عصر المطابع.',
   false, true, false, false, 58, '2026-10-12', true),
  ('b12', 'سيرة النهر', 'فاضل الزبيدي', 'history', 410, 18000, null,
   'كتاب يروي تاريخ الحضارة من خلال النهر: القرى التي نشأت على ضفافه، والمواسم، والفيضانات، والأغاني التي ولدت من مائه.',
   false, false, false, false, 85, '2026-02-25', true),
  ('b13', 'قناديل المساء', 'رقية العامري', 'literature', 184, 9000, null,
   'رواية قصيرة عن عائلة تعيد اكتشاف نفسها في بيت قديم، حيث تتحول الحكايات المسائية إلى جسر بين الأجيال.',
   true, true, true, false, 92, '2026-11-01', true),
  ('b14', 'أوراق من نخيل', 'ياسر الخفاجي', 'literature', 128, 6000, 8000,
   'ديوان شعري يحتفي بالأرض والأم والمدينة، بقصائد عمودية وحرة تجمع الحنين بالأمل.',
   false, false, false, true, 64, '2026-05-21', true),
  ('b15', 'الطريق إلى البيت', 'أحمد المرشدي', 'literature', 336, 15000, null,
   'رواية عن رحلة عودة طويلة، يكتشف فيها البطل أن البيت ليس مكاناً فقط، بل أناس ووعود وذكريات.',
   false, false, false, false, 83, '2026-07-28', true),
  ('b16', 'همس الحروف', 'سارة البغدادي', 'literature', 144, 7000, null,
   'نصوص نثرية قصيرة عن الكتابة والصمت والانتظار، تُقرأ على مهل كما تُشرب القهوة في صباح هادئ.',
   false, true, false, false, 55, '2026-10-05', true),
  ('b17', 'بيت يتسع للجميع', 'إيمان الكربلائي', 'family', 232, 11000, 14000,
   'دليل عملي لبناء أسرة متماسكة: الحوار، وتوزيع المسؤوليات، وإدارة الخلاف بهدوء، مع تمارين أسبوعية للعائلة.',
   true, false, true, true, 89, '2026-06-30', true),
  ('b18', 'طفلك والشاشة', 'مصطفى الحيدري', 'family', 168, 8000, null,
   'كيف نوازن بين التقنية والطفولة؟ خطوات واضحة للأهل لتنظيم وقت الشاشة وصناعة بدائل ممتعة ومفيدة.',
   false, true, false, false, 75, '2026-10-18', true),
  ('b19', 'فن الإصغاء', 'نور الهدى السعدي', 'family', 152, 7000, null,
   'الإصغاء مهارة تُتعلم. يقدم الكتاب تمارين بسيطة لتحسين التواصل بين الزوجين وبين الأهل والأبناء.',
   false, false, false, false, 62, '2026-03-30', true),
  ('b20', 'مراهقة بلا صراع', 'حيدر الشريفي', 'family', 248, 12000, null,
   'فهم مرحلة المراهقة من الداخل، وطرق بناء الثقة مع الأبناء، والتعامل مع التحديات بحكمة ومحبة.',
   false, false, false, false, 81, '2026-08-09', true),
  ('b21', 'مغامرات نجمة الصغيرة', 'ليلى الفتلاوي', 'kids', 48, 5000, null,
   'قصة مصوّرة عن نجمة صغيرة تبحث عن مكانها في السماء، وتتعلم أن لكل واحد منا نوراً خاصاً به.',
   true, true, false, false, 87, '2026-10-25', true),
  ('b22', 'حكايات جدي الحكيم', 'عباس المياحي', 'kids', 96, 6000, 7500,
   'عشر حكايات قصيرة يرويها الجد لأحفاده، في كل حكاية قيمة جميلة ودرس لطيف.',
   false, false, false, true, 79, '2026-04-04', true),
  ('b23', 'رحلة إلى مكتبة الغيوم', 'دعاء الحسيني', 'kids', 72, 5500, null,
   'خيال جميل لصبي يصعد إلى مكتبة فوق الغيوم، فيكتشف أن كل كتاب باب لعالم جديد.',
   false, false, false, false, 68, '2026-09-14', true),
  ('b24', 'دفتر العالم الصغير', 'منتظر العزاوي', 'kids', 120, 8000, null,
   'تجارب علمية بسيطة وآمنة للناشئة يمكن تنفيذها في البيت، مع شرح مبسّط لما يحدث في كل تجربة.',
   false, false, false, false, 73, '2026-07-16', true)
on conflict (id) do nothing;

-- انتهى الإعداد ✓
