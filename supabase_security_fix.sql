-- ═══════════════════════════════════════════════════════════════════
--  مكتبة ممهدون — إصلاح أمان حسابات الموظفين (يُشغَّل مرة واحدة على القاعدة الحية)
--  شغّل هذا الملف كاملاً في Supabase ← SQL Editor.
--
--  • لا يحذف ولا يعدّل أي طلب أو كتاب أو قسم أو إعداد.
--  • الموظفون الفعّالون يحتفظون بصلاحياتهم الحالية.
--  • الحسابات المعلّقة تبقى معلّقة بلا صلاحية.
--  • آمن للتشغيل أكثر من مرة.
-- ═══════════════════════════════════════════════════════════════════

begin;

-- ───────────────── 1) الدوال المساعدة (بلا تغيير في السلوك) ─────────────────

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.staff
    where user_id = auth.uid() and status = 'active' and role is not null
  );
$$;

create or replace function public.has_role(roles text[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.staff
    where user_id = auth.uid() and status = 'active' and role = any(roles)
  );
$$;

-- ───────────────── 2) تسجيل الموظفين: كل حساب جديد معلّق ─────────────────
-- الاستثناء الوحيد: إذا لم يوجد أي مدير رئيسي فعّال إطلاقاً، يصبح أول حساب مديراً رئيسياً.
-- القفل يمنع حسابين متزامنين من أن يصبحا مديرين معاً.

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

-- الحسابات المعلّقة تبقى معلّقة وبلا صلاحية (لا ترقية لأحد).
update public.staff set role = null where status = 'pending' and role is not null;

-- ───────────────── 3) حماية جدول الموظفين ─────────────────
-- • الإدراج عبر register_staff فقط، ولا يُقبل حساب فعّال إلا إذا لم يوجد مدير رئيسي فعّال.
-- • تغيير الصلاحية أو الحالة أو الحذف: للمدير الرئيسي الفعّال فقط، وليس على حسابه هو.
-- • يبقى دائماً مدير رئيسي فعّال واحد على الأقل (مع قفل يمنع التزامن).

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

-- ───────────────── 4) الصلاحيات على الجداول ─────────────────

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

-- ───────────────── 5) سياسات RLS ─────────────────
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

-- الأقسام والكتب: القراءة للجميع، والإدارة للمدير الرئيسي والمدير.
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

-- الإعدادات: القراءة للجميع، والتعديل للمدير الرئيسي.
drop policy if exists settings_read   on public.settings;
drop policy if exists settings_update on public.settings;
create policy settings_read   on public.settings for select to anon, authenticated using (true);
create policy settings_update on public.settings for update to authenticated
  using (public.has_role(array['super_admin']))
  with check (public.has_role(array['super_admin']));

-- الطلبات: للموظف الفعّال ذي الصلاحية فقط. المشغّل orders_guard يسمح بتغيير الحالة والملاحظة فقط.
drop policy if exists orders_read   on public.orders;
drop policy if exists orders_update on public.orders;
create policy orders_read   on public.orders for select to authenticated using (public.is_staff());
create policy orders_update on public.orders for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- عناصر الطلب وسجل الحالات: قراءة فقط (لا يعدّل أحد الأسعار أو الكميات).
drop policy if exists order_items_read   on public.order_items;
drop policy if exists order_items_update on public.order_items;
create policy order_items_read on public.order_items for select to authenticated using (public.is_staff());

drop policy if exists order_history_read on public.order_status_history;
create policy order_history_read on public.order_status_history for select to authenticated
  using (public.is_staff());

-- الموظفون: كل مستخدم يقرأ صفه فقط (لمعرفة حالة طلبه)، والمدير الرئيسي يقرأ ويدير الجميع.
-- تعديل الاسم لصاحب الحساب الفعّال فقط؛ المعلّق والموقوف لا يكتبان شيئاً.
drop policy if exists staff_read_own     on public.staff;
drop policy if exists staff_read_admin   on public.staff;
drop policy if exists staff_update_own   on public.staff;
drop policy if exists staff_update_admin on public.staff;
drop policy if exists staff_delete_admin on public.staff;
create policy staff_read_own   on public.staff for select to authenticated using (user_id = auth.uid());
create policy staff_read_admin on public.staff for select to authenticated
  using (public.has_role(array['super_admin']));
create policy staff_update_own on public.staff for update to authenticated
  using (user_id = auth.uid() and public.is_staff())
  with check (user_id = auth.uid());
create policy staff_update_admin on public.staff for update to authenticated
  using (public.has_role(array['super_admin'])) with check (public.has_role(array['super_admin']));
create policy staff_delete_admin on public.staff for delete to authenticated
  using (public.has_role(array['super_admin']));

-- ───────────────── 6) تخزين الأغلفة: القراءة للجميع، والكتابة للمدير الرئيسي والمدير ─────────────────

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

-- ───────────────── 7) تنبيه: جداول في public بلا RLS ─────────────────

do $$
declare
  t record;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  loop
    raise notice 'تنبيه: الجدول public.% بلا RLS — راجعه', t.relname;
  end loop;
end $$;

commit;

-- انتهى الإصلاح ✓
--
-- ───────────────── للمراجعة بعد التشغيل (أزل علامة التعليق وشغّل كل استعلام وحده) ─────────────────
--
-- 1) كل حسابات الموظفين — أوقف أو احذف أي حساب لا تعرفه:
-- select s.email, s.full_name, s.role, s.status, s.created_at, u.last_sign_in_at
--   from public.staff s left join auth.users u on u.id = s.user_id
--   order by s.created_at;
--
-- 2) مستخدمو Authentication بلا صف موظف (حسابات أُنشئت ولم تُسجَّل):
-- select u.email, u.created_at, u.last_sign_in_at
--   from auth.users u left join public.staff s on s.user_id = u.id
--   where s.user_id is null order by u.created_at;
--
-- 3) كل سياسات التخزين — يجب ألا توجد سياسة كتابة لغير المدير:
-- select policyname, cmd, roles, qual, with_check from pg_policies
--   where schemaname = 'storage' and tablename = 'objects';
--
-- 4) إيقاف حساب مشبوه (من SQL Editor مسموح حتى لو كان مديراً رئيسياً، بشرط بقاء مدير آخر):
-- update public.staff set status = 'suspended' where email = 'EMAIL_HERE';
