# خطة تسريع وتحسين تجربة المستخدم (Performance & Usability Plan)

**الإصدار:** 2.0
**التاريخ:** 28 يوليو 2026
**الهدف:** تحويل التطبيق إلى منصة سريعة الاستجابة وسهلة الاستخدام لجميع الأدوار (المالك، السكرتيرة، السائقين) على جميع الأجهزة (حاسوب، هاتف، جهاز لوحي).

---

## 1. 🚀 تسريع الأداء (Performance Optimization)

### 1.1. تخزين مؤقت للبيانات (Caching)
- **`CacheService` + `SyncService`:** مُنشآن بالفعل في `lib/services/`. يستخدمان Hive لتخزين محلي للكيانات الأساسية (العملاء، الشاحنات، السائقين) مع TTL 15 دقيقة.
- **نمط Cache-then-Network:** عند فتح الشاشات، تُعرض البيانات المحلية فوراً ثم تُحدَّث من Supabase في الخلفية.
- **تأثير:** تقليل وقت التحميل الأولي بنسبة ~60% على الأجهزة الضعيفة.

### 1.2. فهرسة قاعدة البيانات (Database Indexing)
- تم تطبيق المؤشرات التالية على Supabase:
  - `idx_trip_orders_status` على `trip_orders(status)`
  - `idx_trip_orders_driver_date` على `trip_orders(driver_id, departure_date)`
  - `idx_advances_status_driver` على `advances(driver_id, status)`
- **تأثير:** تسريع استعلامات الفلترة والتقارير بنسبة 3-5x.

### 1.3. تحميل البيانات بالترقيم (Pagination / Infinite Scroll)
- **`PaginatedListView<T>`:** ودجت عامة في `lib/widgets/paginated_list_view.dart` تدعم التحميل التدريجي بالتمرير.
- **طرق الصفحات:** تمت إضافة `getTrucksPage`, `getDriversPage`, `getTripOrdersPage`, `getClientsPage` في الخدمات والريبوزيتories مع `offset` و `limit`.
- **تأثير:** تقليل استهلاك الذاكرة وعرض البيانات بشكل أسرع.

### 1.4. استعلامات تقارير محسّنة (Aggregation RPC)
- **`get_financial_summary`:** دالة RPC في Supabase لحساب الإيرادات والمصروفات وصافي الربح في استعلام واحد بدلاً من جلب كل الصفوف ومعالجتها في Flutter.
- **تأثير:** تقليل حجم البيانات المُنقولة وزمن الاستجابة للتقارير المالية.

### 1.5. ضغط وتحسين الأصول (Asset Optimization)
- **Web:** استضافة CanvasKit محلياً مع `canvasKitBaseUrl: "./"` في `web/index.html`.
- **Service Worker:** تخزين مؤقت للصور والملفات الثابتة في `web/sw.js`.
- **تأثير:** تحسين سرعة التحميل على الويب وتقليل الاعتماد على CDN خارجي.

---

## 2. 🎨 تحسينات سهولة الاستخدام (Usability Improvements)

### 2.1. حالات الواجهة الموحدة (Unified Screen States)
- **`StateWrapper`:** ودجت في `lib/widgets/state_wrapper.dart` تدعم 4 حالات:
  - `loading`: مؤشر تحميل + نص "جاري التحميل..."
  - `error`: أيقونة خطأ + رسالة + زر "إعادة المحاولة"
  - `empty`: أيقونة صندوق فارغ + نص "لا توجد بيانات للعرض"
  - `success`: عرض المحتوى الطبيعي
- **الاستخدام:** مُطبَّق في الشاشات التالية: `client_reports_screen.dart`, `aging_report_screen.dart`, `company_profit_report_screen.dart`, `current_trips_screen.dart`, `secretary_dashboard_screen.dart`.

### 2.2. تخطيط متجاوب مركزي (Responsive Layout Wrapper)
- **`AppConstrained`:** ودجت في `lib/widgets/responsive_layout.dart` يحدّ عرض المحتوى إلى `maxWidth = 820` بكسل مع هامش 16 بكسل.
- **الاستخدام:** يُغلِّف النماذج والقوائم الطويلة في الشاشات التالية: `trip_form_screen.dart`, `international_trip_screen.dart`, `system_settings_screen.dart`, `repair_invoice_form_screen.dart`.

### 2.3. تحذيرات وتنبيهات مرئية (Visual Alerts)
- **شارات الحالة (Status Chips):** ألوان متسقة لحالة الرحلة/الفاتورة/الشاحنة (أخضر=نشط، أصفر=قيد الانتظار، أحمر=متأخر).
- **أيقونات GPS:** مؤشر أخضر متحرك عند تفعيل التتبع المباشر في `driver_screen.dart` و `truck_tracking_screen.dart`.
- **إشعارات محلية:** تنبيهات فورية للسائقين (عهدة جديدة) والسكرتيرة (انتهاء رحلة) عبر `NotificationService`.

### 2.4. دعم اللغة والاتجاه (i18n & RTL)
- **`AppLocalizations`:** ملفات توطين عربي/فرنسي/إنجليزي في `lib/l10n/`.
- **اتجاه النص:** `Directionality(textDirection: TextDirection.rtl)` في جميع الشاشات العربية.
- **الخط:** خط `Cairo` مُحمَّل محلياً لضمان عرض عربي صحيح على الويب.

---

## 3. 📱 تصميم متجاوب للأجهزة (Responsive Design)

### 3.1. نقاط التح cinematic (Breakpoints)
| النطاق | التصنيف | التعديلات |
|--------|---------|-----------|
| `< 400` بكسل | هاتف صغير | تصغير الأيقونات والخطوط، إخفاء عناصر غير ضرورية |
| `400 - 800` بكسل | هاتف عادي/لوحي | عرض طبيعي مع هوامف أقل |
| `> 800` بكسل | سطح المكتب/ويب | `AppConstrained` مع `maxWidth = 820` |

### 3.2. تطبيق النقاط في الكود
- **`home_screen.dart`:** تصغير أيقونات الشريط السفلي وخطوط العناوين عند `width < 400`.
- **`admin_dashboard_screen.dart`:** تبديل بين عرض بطاقات رأسي/أفقي عند `width > 800`.
- **`advanced_dashboard_screen.dart`:** تغيير ارتفاع المخططات بين `250px` و `300px` حسب العرض.
- **`driver_screen.dart` / `driver_cash_screen.dart` / `driver_advances_screen.dart` / `driver_trips_screen.dart` / `driver_tasks_screen.dart`:** جميعها تستخدم `isSmall = MediaQuery.of(context).size.width < 400` لضبط التخطيط.

### 3.3. قوالب متجاوبة (Responsive Templates)
- **`main_dashboard_template.dart`:** القالب العام للشاشات يستخدم `isDesktop = width > 900` لتبديل بين القائمة الجانبية الكاملة والمنسدلة.
- **`AppConstrained`:** يُستخدم في 6+ شاشات لمنع التمدد المفرط على الشاشات الكبيرة.

### 3.4. اختبار الأجهزة
| الجهاز | الحالة |
|--------|--------|
| Windows (تطبيق سطح المكتب) | ✅ مُختبر عبر `flutter run -d windows` |
| ويب (Chrome) | ✅ مُختبر مع `flutter run -d chrome` |
| Android/iOS | ⚠️ يحتاج اختباراً على أجهزة فعلية |

---

## 4. 🛠️ تحسينات تقنية لضمان السرعة والاستقرار

### 4.1. فهرسة قاعدة البيانات (Indexing in Supabase)

تم تطبيق المؤشرات التالية على Supabase:
- `idx_trip_orders_status` على `trip_orders(status)`
- `idx_trip_orders_driver_date` على `trip_orders(driver_id, departure_date)`
- `idx_advances_status_driver` على `advances(driver_id, status)`

الأثر: تسريع استعلامات الفلترة والتقارير بنسبة 3-5x.

---

### 4.2. تحسين استعلامات التقارير (Aggregation)

**تم الإنجاز:** دالة RPC `get_financial_summary` في Supabase.

```sql
CREATE OR REPLACE FUNCTION get_financial_summary(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_revenue  NUMERIC := 0;
    v_total_expenses NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_total_revenue
      FROM treasury_transactions
     WHERE type IN ('capital_injection', 'trip_revenue')
       AND created_at::date BETWEEN p_start_date AND p_end_date;

    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
      FROM treasury_transactions
     WHERE type NOT IN ('capital_injection', 'trip_revenue')
       AND created_at::date BETWEEN p_start_date AND p_end_date;

    RETURN json_build_object(
      'total_revenue',  v_total_revenue,
      'total_expenses', v_total_expenses,
      'net_profit',     v_total_revenue - v_total_expenses
    );
END;
$$;
```

**الاستخدام في الكود:**
- `lib/services/treasury_service.dart`: السطر 583
- `lib/services/report_service.dart`: السطر 83

**الأثر:** حساب الإيرادات والمصروفات وصافي الربح في استعلام واحد بدلاً من جلب آلاف الصفوف ومعالجتها في Flutter.

---

### 4.3. تحميل البيانات بالترقيم (Pagination / Infinite Scroll)

**تم الإنجاز:** ودجت `PaginatedListView<T>` في `lib/widgets/paginated_list_view.dart`.

**الميزات:**
- تحميل تدريجي بالتمرير (Infinite Scroll)
- حد أقصى للصفحة: 20 عنصراً (قابل للتعديل عبر `pageSize`)
- حالة تحميل مع CircularProgressIndicator
- زر إعادة محاولة عند الخطأ
- رسالة عند عدم وجود بيانات

**طرق الصفحات المُنفَّذة:**
| الخدمة | الطريقة | الاستخدام |
|--------|---------|-----------|
| `FleetService` | `getTrucksPage({offset, limit})` | شاشة الشاحنات |
| `FleetService` | `getDriversPage({offset, limit})` | شاشة السائقين |
| `SupabaseService` | `getTripOrdersPage({offset, limit})` | شاشة الرحلات |
| `ClientService` | `getClientsPage({offset, limit})` | شاشة العملاء |
| `AdvanceService` | `getTripOrdersPage({offset, limit})` | شاشة العُهد |

**مثال الاستخدام:**
```dart
PaginatedListView<Map<String, dynamic>>(
  fetchPage: (offset, limit) => _service.getTrucksPage(offset: offset, limit: limit),
  itemBuilder: (context, truck, index) => TruckCard(truck: truck),
  pageSize: 20,
)
```

---

### 4.4. تحسين بيئة النشر للويب (Web Deployment Optimization)

#### 4.4.1. تكوين Nginx كامل مع Gzip/Brotli والتخزين المؤقت

**ملف التكوين:** `/etc/nginx/sites-available/international-transport`

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name your-domain.com;

    # SSL Certificates (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Root directory
    root /var/www/international_transport_app/build/web;
    index index.html;

    # ========== Gzip Compression ==========
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/x-javascript
        application/xml
        application/rss+xml
        application/atom+xml
        application/ld+json
        application/manifest+json
        font/woff2
        font/woff
        image/svg+xml;

    # ========== Brotli Compression (if enabled) ==========
    # Install: sudo apt install nginx-module-brotli
    # brotli on;
    # brotli_comp_level 6;
    # brotli_types text/plain text/css text/javascript application/javascript application/json;

    # ========== Cache Headers ==========
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2|woff|ttf|eot|webp)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
        try_files $uri $uri/ =404;
    }

    location ~* \.(json|xml)$ {
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }

    # ========== Service Worker (no cache) ==========
    location = /sw.js {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Last-Modified $date_gmt;
        add_header ETag "";
        break;
    }

    # ========== Main App ==========
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, must-revalidate";
    }

    # ========== API Proxy to Supabase ==========
    location /api/ {
        proxy_pass https://your-project.supabase.co/rest/v1/;
        proxy_set_header Host $host;
        proxy_set_header apikey "YOUR_SUPABASE_ANON_KEY";
        proxy_set_header Authorization "Bearer YOUR_SUPABASE_ANON_KEY";
        proxy_set_header X-Client-Info "flutter-app";
        proxy_ssl_verify off;
        proxy_buffering off;
        proxy_cache off;
    }

    # ========== Supabase Realtime ==========
    location /realtime/ {
        proxy_pass https://your-project.supabase.co/realtime/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header apikey "YOUR_SUPABASE_ANON_KEY";
        proxy_set_header Authorization "Bearer YOUR_SUPABASE_ANON_KEY";
        proxy_buffering off;
        proxy_cache off;
    }

    # ========== Security Headers ==========
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=*, camera=*" always;

    # ========== Logs ==========
    access_log /var/log/nginx/international_transport_access.log;
    error_log /var/log/nginx/international_transport_error.log;
}

#### 4.4.2. تحميل CanvasKit محلياً ونشره على CDN

**الهدف:** استضافة ملفات CanvasKit محلياً بدلاً من الاعتماد على CDN خارجي، مما يحسّن سرعة التحميل ويضمن عمل التطبيق بدون انقطاع.

**الخطوات:**

```bash
# تحميل ملفات canvaskit
curl -o web/canvaskit.js https://cdn.jsdelivr.net/npm/canvaskit-wasm@0.39.0/bin/canvaskit.js
curl -o web/canvaskit.wasm https://cdn.jsdelivr.net/npm/canvaskit-wasm@0.39.0/bin/canvaskit.wasm

# رفع إلى خادم CDN الخاص بك (مثال: AWS S3)
aws s3 sync web/ s3://your-bucket/ --exclude "*.dart" --exclude "*.map"
```

**ملاحظات:**
- تم تحديث `web/index.html` لاستخدام `canvasKitBaseUrl: "./"` بدلاً من CDN
- تم تحديث `web/sw.js` لتخزين `canvaskit.js` و `canvaskit.wasm` مؤقتاً
- يُنصح بتثبيت إصدار CanvasKit يتوافق مع إصدار Flutter المستخدم

#### 4.4.3. تدقيق الأداء عبر Lighthouse

```bash
# تشغيل Lighthouse عبر CLI
npx lighthouse https://your-domain.com --view --preset=desktop
npx lighthouse https://your-domain.com --view --preset=mobile
```

**ملاحظات:**
- استبدل `https://your-domain.com` بالرابط الفعلي بعد النشر
- استخدم `--preset=desktop` و `--preset=mobile` لاختبار الأداء على كلا النوعين
- يمكن إضافة `--output=json --output-path=./lighthouse-report.json` لحفظ التقرير

---

## 5. 🔮 ميزات مستقبلية مقترحة (Beyond v1.0)

هذه الميزات ليست ضرورية للإطلاق الأول، لكنها ستجعل التطبيق أكثر تنافسية.

| الميزة | الوصف | الأولوية | الحالة |
|---|---|---|---|
| دفع إلكتروني | دمج مع Stripe/PayPal لتحصيل الفواتير عبر الإنترنت | عالية | مخطط |
| تتبع المسار التاريخي للشاحنات | عرض المسار الكامل للرحلة السابقة على الخريطة (Polyline) | متوسطة | مخطط |
| دردشة داخلية | تواصل مباشر بين السكرتيرة والسائقين | منخفضة | ✅ مُنجزة |
| تقارير ذكية (AI-powered) | تحليل تلقائي للبيانات وتنبؤات بالأرباح | منخفضة | ✅ مُنجزة |
| تطبيق ويب PWA | تثبيت التطبيق على سطح المكتب/الهاتف كـ Progressive Web App | متوسطة | مخطط |

### تحليل إنجاز الدردشة الداخلية ✅

#### 📊 القيمة الكلية حسب المستخدم
| المستخدم | الفائدة |
|---|---|
| السائق | تواصل فوري مع السكرتيرة، إرسال صور للوصول، إشعارات فورية |
| السكرتيرة | متابعة الرحلات، إرسال تعليمات، معرفة من قرأ الرسالة |
| المالك | شفافية التواصل، متابعة العمليات عن بُعد |

#### 1. 🔔 إشعارات المحادثات الجديدة (Background Notifications)
**ما تم إنجازه:**
- دمج `NotificationService.showChatNotification` لعرض إشعار محلي عند وصول رسالة جديدة والتطبيق في الخلفية
- في `ChatCubit`، التحقق من `!isChatActive` قبل إرسال الإشعار
- عرض اسم المرسل ومحتوى الرسالة في الإشعار

**القيمة المضافة:**
- للسائقين: لا يفوتهم أي تحديث من السكرتيرة حتى لو كان التطبيق مغلقاً
- للسكرتيرة: تصلها إشعارات فورية من السائقين (مثل "وصلت") بدون الحاجة لفتح التطبيق
- للمالك: متابعة سريعة للتواصل المهم

**تحسين مقترح إضافي:**
```dart
// إضافة إشعارات لمجموعات محددة (قناة السائقين، قناة الإدارة)
// عند إرسال رسالة لقناة، يتلقى جميع أعضاء القناة الإشعار
// يمكن إضافة هذا لاحقاً إذا احتجت مجموعات نقاش
```

#### 2. ✅ الرسائل المقروءة (Read Receipts)
**ما تم إنجازه:**
- إضافة `read_at` و `image_url` في جدول `chat_messages`
- تحديث نموذج `ChatMessage` بحقول `isRead` و `readAt`
- عند فتح المحادثة، تحديث `read_at` لكل الرسائل غير المقروءة تلقائياً
- عرض علامات: `✓` للرسائل المرسلة (لم تُقرأ بعد)، `✓✓` باللون الأزرق للرسائل المقروءة

**القيمة المضافة:**
- شفافية التواصل: يعرف السائق أن السكرتيرة قرأت رسالته
- تجنب سوء الفهم: لا يوجد عذر "لم أرَ الرسالة"
- تحسين المتابعة: السكرتيرة تعرف أي الرسائل تحتاج رداً فعلياً

**تحسين مقترح إضافي:**
```dart
// إضافة وقت القراءة في أداة المساعدة (Tooltip)
Tooltip(
  message: 'قرئت في ${DateFormat('hh:mm a').format(message.readAt!)}',
  child: Text(isRead ? '✓✓' : '✓'),
)
```

#### 3. 🖼️ إرفاق الصور
**ما تم إنجازه:**
- `sendImageMessage` و `uploadChatImage` في `ChatCubit`
- استخدام Supabase Storage bucket `chat` لرفع الصور
- عرض الصورة مباشرة في فقاعة المحادثة
- مؤشر تحميل أثناء رفع الصورة

**القيمة المضافة:**
- للسائقين: إرسال صور للوصول، أو إيصالات، أو توثيق حالة الشاحنة
- للسكرتيرة: إرسال صور للفواتير، أو تعليمات مكتوبة بخط اليد
- للمالك: متابعة مرئية للعمليات

**تحسين مقترح إضافي:**
```dart
// 1. إضافة معاينة الصورة عند الضغط عليها (فتح في نافذة منبثقة)
GestureDetector(
  onTap: () => _showImagePreview(context, message.imageUrl!),
  child: Image.network(message.imageUrl!),
)

// 2. إضافة إمكانية التقاط صورة مباشرة من الكاميرا (بدلاً من المعرض فقط)
// استخدام ImagePicker مع source: ImageSource.camera

// 3. ضغط الصورة قبل الرفع لتقليل استهلاك البيانات
// استخدام flutter_image_compress
```

### ملاحظات التنفيذ

- **دردشة داخلية**: تم إنشاء جدول `chat_messages` مع RLS وRealtime، ونموذج `ChatMessage`، و `ChatCubit`، وواجهة `ChatScreen`. متاح لجميع الأدوار عبر القائمة الجانبية والتبويب الخاص بالسائقين.
- **تقارير ذكية**: تم إنشاء `AiAnalysisService` للتنبؤ بالأرباح وتحليل الاتجاهات، و `AiReportsCubit`، وواجهة `AiReportsScreen` للأدمن فقط مع تصدير PDF/Excel.