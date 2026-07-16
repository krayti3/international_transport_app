# 📊 تقرير الحالة الحالية للمشروع (International Transport App)

> ⚠️ **ملاحظة مهمة:** هذا التقرير مبني على **فحص الملفات البرمجية فعلياً** من داخل المشروع (`D:\trans\international_transport_app`)، وليس على تشغيل التطبيق. لا يمكنني التأكد من العمل في وقت التشغيل (Runtime) إلا بعد تنفيذ `flutter run`. لذلك تم وضع علامة ⚠️ بجانب النقاط التي تحتاج تشغيلاً للتأكيد.

---

## 📁 1. ملفات الأكواد الحالية (Dart Files)
*تم فحص المجلد `lib/` والمجلدات الفرعية:*

- [x] ملف `main.dart` (يحتوي على إعدادات Supabase ونظام التوجيه عبر `StreamBuilder` + `RealtimeNotifications`): **نعم — موجود (52 سطر)**
- [x] ملف `login_screen.dart` (شاشة تسجيل الدخول + زر إنشاء حساب): **نعم — موجود (133 سطر)**
- [x] ملف `home_screen.dart` (الشاشة الرئيسية والقائمة): **نعم — موجود (208 سطر)**
- [x] ملف `drivers_screen.dart` (شاشة إدارة السائقين): **نعم — موجود**
- [⚠️] ملف `trips_screen.dart` (شاشة إدارة الرحلات والعُهد): **ملف بهذا الاسم غير موجود؛ الوظيفة مقسّمة على ملفات:**
  - `advances_screen.dart` → إدارة العُهد (الرحلات)
  - `trip_orders_screen.dart` → طلبات الرحلات
  - `trip_form_screen.dart` → تسليم عهدة وتأكيد سفر
  - `international_trip_screen.dart` → رحلة نقل دولي
  - `current_trips_screen.dart` → الرحلات الجارية
- [x] واجهة صاحب العمل (متابعة الصندوق): **موجودة عبر عدة ملفات:**
  - `owner_dashboard_screen.dart` (لوحة صاحب العمل)
  - `treasury_screen.dart` (الخزينة/الصندوق)
  - `treasury_management_screen.dart` (إدارة الخزينة)
  - `admin_dashboard_screen.dart` (لوحة الأدمن)
  - ⚠️ لا يوجد ملف اسمه حرفياً `cashbox_screen.dart`

**ملفات إضافية مكتملة موجودة (أكثر مما في القالب):**
- `clients_screen.dart`, `client_reports_screen.dart`, `client_statement_screen.dart`
- `invoices_screen.dart`, `outstanding_invoices_screen.dart`, `overdue_reminders_screen.dart`, `aging_report_screen.dart`
- `trucks_screen.dart`, `truck_documents_screen.dart`, `truck_maintenance_screen.dart`, `truck_tracking_screen.dart`, `fleet_alerts_screen.dart`
- `driver_salary_screen.dart`, `driver_screen.dart`
- `system_settings_screen.dart`, `company_profit_report_screen.dart`, `signup_screen.dart`, `main_screen.dart`
- **المجلد `models/`**: 16 موديل (client, driver, trip, trailer, truck, invoice, payment, advance, treasury_transaction, user, ...)
- **المجلد `services/`**: `supabase_service.dart` (خدمة ضخمة فيها كل عمليات CRUD والصلاحيات RBAC والحسابات المالية), `notification_service`, `pdf_service`, `location_service`, `ml_text_recognition_service`
- **المجلد `widgets/`**: `realtime_notifications`, `responsive_layout`, `summary_card`, `status_chip`, `simple_bar_chart`, `expense_row`

---

## 🗄️ 2. حالة قاعدة البيانات (Supabase Database)
*تم فحص مجلد `supabase/migrations/` (13 ملف مايغرايشن):*

- [⚠️] جدول الملفات الشخصية والصلاحيات (`profiles`): **مُعرّف كجدول `users` (id, email, role) في `20240101000000_fix_schema.sql` — السياسة المعتمدة هي `users` وليس `profiles`. يحتاج تنفيذ المايغرايشن في Supabase.**
- [⚠️] جدول السائقين (`drivers`) (الاسم، الهاتف، الشاحنة، base_salary, bonus_percentage, user_id): **مُعرّف في المايغرايشن. يحتاج تنفيذ.**
- [⚠️] جدول الرحلات والعُهد: **مُقسّم فعلياً إلى جدولين:**
  - `advances` (العُهد: driver_id, amount_given, amount_spent, status, is_deleted) — `20240101000001_advances.sql`
  - `trip_orders` (الرحلات: price, status, departure_date, ...)
  - مرتبطان ببعض عبر عمود `trip_id`. يحتاج تنفيذ.
- [⚠️] جدول تتبع حركة الصندوق (`treasury_transactions`): **مُعرّف في `20240101000007_treasury_tva.sql` (type, amount, description, receipt_url, created_at). يحتاج تنفيذ.**
- **جداول إضافية مُعرّفة في المايغرايشن:** `clients`, `trucks`, `trailers`, `documents`, `invoices`, `payments`, `payment_invoice_allocations`, `truck_maintenance`, `truck_documents`, `notifications`, `app_settings` (إعدادات TVA).

> ⚠️ **تنبيه حاسم:** المايغرايشنات مكتوبة في المشروع، لكن لا يمكنني التأكد من أنها **نُفّذت بالفعل** في مشروع Supabase الخاص بك. يجب فتح Supabase SQL Editor ولصق محتويات `supabase/migrations/*.sql` وتشغيلها للتأكد من وجود الجداول.

---

## 🔄 3. سير العمل والأزرار (Workflow & Functionality)
*الأكواد البرمجية مكتوبة لهذه العمليات، لكن التشغيل الفعلي غير مُتحقق منه (يحتاج `flutter run`):*

- [⚠️] التطبيق يفتح على صفحة تسجيل الدخول إذا لم يكن المستخدم مسجلاً: **الكود موجود في `main.dart` عبر `onAuthStateChange`، لكن غير مُتحقق منه وقت التشغيل.**
- [⚠️] زر تسجيل الدخول يعمل وينقل المستخدم للرئيسية: **الكود في `login_screen.dart` يستدعي `signInWithPassword`، غير مُتحقق.**
- [⚠️] الأزرار في الرئيسية تنقل للشاشات الفرعية: **الكود موجود (`home_screen.dart`)، غير مُتحقق.**
- [⚠️] زر "تسليم عهدة جديدة" يحفظ في Supabase ويحوّل الحالة: **الكود في `trip_form_screen.dart` + `addAdvance`/`syncAdvanceTreasury` في `supabase_service.dart`، غير مُتحقق.**
- [⚠️] زر "إغلاق رحلة" يحسب المصاريف ويحدث البيانات: **الكود موجود (`syncAdvanceTreasury` يفرق بين pending/settled)، غير مُتحقق.**
- [⚠️] واجهة صاحب العمل تعرض إجمالي الصندوق والأموال في الطريق: **الكود موجود (`owner_dashboard_screen.dart` + `getTreasuryBalance`)، غير مُتحقق.**

> 💡 **ملاحظة ذكية في الكود:** `supabase_service.dart` يحتوي على كاتب صفوف "متسامح" (`_writeRow`) يعالج اختلاف المخطط (schema drift) تلقائياً — يزيل الأعمدة المجهولة (PGRST204) ويعبّئ أعمدة NOT NULL. هذا يقلل أخطاء الحفظ إن كان هناك اختلاف بين الكود وقاعدة البيانات.

---

## ❌ 4. المشاكل أو الأخطاء الحالية (Current Errors)
*لم يتم تشغيل المشروع (`flutter run`) ضمن جلستي، لذلك لا توجد لدي رسائل خطأ فعلية من Debug Console. النقاط المحتملة التي يجب فحصها عند التشغيل:*

### ✅ أخطاء برمجية تم إصلاحها في الكود
1. **`main.dart` — تهيئة Hive مفقودة (تم الإصلاح):** كان `Hive` يُستخدم في `l10n/locale_provider.dart` (عبر `Hive.openBox`) لكن `HiveFlutter.init()` لم يكن يُستدعى أبداً في `main()`، ما كان سيُسبب فشل حفظ/قراءة اللغة. تمت إضافة `import 'package:hive_flutter/hive_flutter.dart';` واستدعاء `await HiveFlutter.init();` قبل `runApp(const MyApp());`.
2. **`lib/services/pdf_service.dart` — استخدام `PdfGoogleFonts` بدون البادئة (تم الإصلاح):** كانت الحزمة مستوردة كـ `package:pdf/widgets.dart as pw;` لكن `PdfGoogleFonts` كان يُستخدم بدون بادئة `pw.` في 10 مواضع، ما يُسبب خطأ تصريف (Undefined name). تم تحويل جميع المواضع الـ10 إلى `pw.PdfGoogleFonts`.
3. **`test/widget_test.dart` — اختبار العدّاد الافتراضي لا يطابق المشروع (تم الإصلاح):** استُبدل اختبار العدّاد (counter) الافتراضي باختبار Smoke test بسيط يبني التطبيق (`MyApp`) ويتحقق من وجود عناصر شاشة تسجيل الدخول الأساسية (أيقونة الشاحنة + حقول الإدخال + زر الدخول).

### ⚠️ خطوات متبقية عند التشغيل
4. **تنفيذ المايغرايشن في Supabase (خطوة متبقية مطلوبة):** يجب فتح Supabase SQL Editor ولصق محتوى الملف المُوحّد الجديد **`supabase/migrations_run_me.sql`** (يجمع كل ملفات `supabase/migrations/*.sql` بالترتيب الصحيح والمتوافق مع التبعيات) وتشغيله. بدون ذلك سيظهر خطأ `relation "X" does not exist` عند أول عملية قراءة/كتابة. (الملف idempotent وآمن لإعادة التشغيل).
5. **اختلاف أسماء الجداول بين القالب والواقع:** القالب يذكر `profiles` لكن الكود يستخدم `users`؛ والقالب يذكر `trips` لكن الكود يستخدم `advances` + `trip_orders`. هذا لا يسبب خطأ طالما المايغرايشن مطابقة للكود.
6. (يُملأ لاحقاً بعد التشغيل) __________________________________________________

---

## ✅ الخلاصة
- **الواجهات البرمجية (Frontend): مكتملة تقريباً** — أكثر من 30 شاشة وموديل وخدمة مكتوبة.
- **هيكل قاعدة البيانات: مكتوب كـ migrations لكنه يحتاج تنفيذاً في Supabase للتأكد.**
- **التشغيل الفعلي: غير مُتحقق** — الخطوة التالية هي تنفيذ المايغرايشن ثم تشغيل `flutter run` لمراقبة Debug Console وأي أخطاء.
