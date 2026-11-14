# إدارة ممهدون — تطبيق إدارة مكتبة ممهدون

تطبيق Flutter لمالك **مكتبة ممهدون** وموظفيه: متابعة الطلبات، وإدارة الكتب والأقسام وإعدادات المكتبة والموظفين.
يتصل بقاعدة بيانات Supabase نفسها التي يستخدمها تطبيق المتجر ([mumahhidoon-store](https://github.com/Ali313w/mumahhidoon-store)).

## الميزات

- **الحسابات والصلاحيات:** تسجيل دخول وإنشاء حساب بالبريد الإلكتروني. كل حساب جديد ينتظر موافقة المدير الرئيسي، ولا يرى أي بيانات قبلها. ثلاث صلاحيات: مدير رئيسي، ومدير، وموظف طلبات. الصلاحيات مفروضة في قاعدة البيانات (Row Level Security ومشغّلات)، لا في التطبيق فقط.
- **الرئيسية:** الطلبات الجديدة، وطلبات اليوم ومبيعاته، ومبيعات الشهر، وعدد الكتب والكتب غير المتوفرة، ورسم مبيعات آخر ثلاثين يوماً، وآخر الطلبات، وأكثر الكتب طلباً.
- **الطلبات:** قائمة فورية (Realtime) مع تنبيه صوتي وشريط عند وصول طلب جديد، وتغيير الحالة مع سجل من غيّرها ومتى، وملاحظة داخلية، والاتصال بالمشتري أو مراسلته على واتساب، وطباعة الوصولات أو مشاركتها بحجم A5 (طلب واحد أو عدة طلبات).
- **الكتب:** إضافة وتعديل وحذف، ورفع الغلاف من المعرض أو الكاميرا مع ضغطه تلقائياً، وتحديد التوفر والعلامات (مميز، جديد، الأكثر مبيعاً، عرض خاص).
- **الأقسام:** إضافة وإعادة تسمية وترتيب بالسحب وحذف، مع نقل كتب القسم إلى قسم آخر قبل حذفه.
- **إعدادات المكتبة:** رقم واتساب، وأجور التوصيل، ونبذة «عن المكتبة»، وشريط إعلان في تطبيق المتجر.
- **المديرون** (للمدير الرئيسي): الموافقة على الطلبات مع اختيار الصلاحية أو رفضها، وتغيير الصلاحية، والإيقاف وإعادة التفعيل، والحذف. يبقى دائماً مدير رئيسي فعّال واحد على الأقل.
- **حسابي:** تعديل الاسم، وتغيير كلمة المرور، ووضع فاتح وداكن.

## التشغيل

1. ثبّت [Flutter](https://docs.flutter.dev/get-started/install) (Dart 3.10 أو أحدث).
2. أنشئ ملف الإعدادات المحلية بنسخ المثال:
   ```bash
   cp lib/config/local_config.example.dart lib/config/local_config.dart
   ```
   ثم املأ فيه:
   - `supabaseUrl` و`supabasePublishableKey`: من لوحة Supabase ← Project Settings ← API (المفتاح العام `sb_publishable_` فقط، **وليس** مفتاح `service_role` أو `sb_secret_`).
   - `whatsappNumber`: رقم واتساب المكتبة بالصيغة الدولية بدون `+` (قيمة افتراضية حتى تُقرأ الإعدادات).

   الملف `local_config.dart` مستثنى من git ولا يُرفع.
3. قاعدة البيانات: في Supabase ← SQL Editor شغّل `supabase_setup.sql` كاملاً لتثبيت جديد. أما `supabase_security_fix.sql` فهو إصلاح أمان لقاعدة أُنشئت بنسخة سابقة من ملف الإعداد. ضع رقم واتساب المكتبة مكان `964XXXXXXXXXX` قبل التشغيل، أو عدّله لاحقاً من شاشة الإعدادات.
4. أول حساب يُنشأ في قاعدة لا يوجد فيها مدير رئيسي فعّال يصبح المدير الرئيسي، وكل حساب بعده ينتظر موافقته.
5. شغّل التطبيق:
   ```bash
   flutter pub get
   flutter run
   ```

## التقنيات

Flutter وDart، وSupabase (المصادقة، وPostgreSQL مع Row Level Security ودوال RPC، والتحديث الفوري Realtime، والتخزين Storage لأغلفة الكتب)، وprovider، وshared_preferences، وpdf وprinting، وimage_picker وimage، وaudioplayers، وurl_launcher.

## الحقوق

© مكتبة ممهدون. جميع الحقوق محفوظة.
الكود منشور للاطلاع فقط، ولا يُمنح أي ترخيص لاستخدامه أو نسخه أو تعديله أو توزيعه.

---

# Mumahhidoon Admin — Mumahhidoon Bookstore Management App

A Flutter app for the owner and staff of **Mumahhidoon Bookstore**: follow orders and manage books, categories, store settings and staff.
It uses the same Supabase database as the store app ([mumahhidoon-store](https://github.com/Ali313w/mumahhidoon-store)).

## Features

- **Accounts and roles:** email sign-in and sign-up. Every new account waits for approval by the main manager and sees no data until then. Three roles: main manager (super admin), manager and orders clerk. Permissions are enforced in the database (Row Level Security and triggers), not only in the app.
- **Dashboard:** new orders, today's orders and sales, this month's sales, number of books and unavailable books, a 30-day sales chart, latest orders and most-ordered books.
- **Orders:** live list (Realtime) with a chime and a banner for each new order, status changes with a history of who changed what and when, an internal note, call or WhatsApp the buyer, and print or share A5 receipts (one order or several).
- **Books:** add, edit and delete; upload a cover from the gallery or camera with automatic compression; availability and labels (featured, new, best seller, special offer).
- **Categories:** add, rename, drag to reorder and delete, moving a category's books to another category before deleting it.
- **Store settings:** WhatsApp number, delivery fees, "About the store" text and an announcement bar shown in the store app.
- **Staff** (main manager only): approve requests with a chosen role or reject them, change roles, suspend and reactivate, and remove accounts. There is always at least one active main manager.
- **My account:** change name and password, light and dark themes.

## Running it

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (Dart 3.10 or newer).
2. Create the local config file from the example:
   ```bash
   cp lib/config/local_config.example.dart lib/config/local_config.dart
   ```
   and fill in:
   - `supabaseUrl` and `supabasePublishableKey`: from Supabase → Project Settings → API (the public `sb_publishable_` key only, **never** the `service_role` or `sb_secret_` key).
   - `whatsappNumber`: the store's WhatsApp number in international format without `+` (a default until settings load).

   `local_config.dart` is git-ignored and never committed.
3. Database: for a new installation, run `supabase_setup.sql` in full in Supabase → SQL Editor. `supabase_security_fix.sql` is a security fix for databases created with an earlier version of the setup file. Replace `964XXXXXXXXXX` with the store's WhatsApp number before running, or change it later from the settings screen.
4. The first account created in a database with no active main manager becomes the main manager; every later account waits for their approval.
5. Run:
   ```bash
   flutter pub get
   flutter run
   ```

## Technologies

Flutter and Dart, Supabase (Auth, PostgreSQL with Row Level Security and RPC functions, Realtime, and Storage for book covers), provider, shared_preferences, pdf and printing, image_picker and image, audioplayers, url_launcher.

## Rights

© Mumahhidoon Bookstore. All rights reserved.
The source code is published for viewing only. No license is granted to use, copy, modify or distribute it.
