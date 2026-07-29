# خطة تسريع وتحسين تجربة المستخدم (Performance & Usability Plan)

**الإصدار:** 2.0
**التاريخ:** 28 يوليو 2026
**الهدف:** تحويل التطبيق إلى منصة سريعة الاستجابة وسهلة الاستخدام لجميع الأدوار (المالك، السكرتيرة، السائقين) على جميع الأجهزة (حاسوب، هاتف، جهاز لوحي).

---

## 1. 🚀 تسريع الأداء (Performance Optimization)

_محتوى هذا القسم قيد الإعداد._

---

## 2. 🎨 تحسينات سهولة الاستخدام (Usability Improvements)

_محتوى هذا القسم قيد الإعداد._

---

## 3. 📱 تصميم متجاوب للأجهزة (Responsive Design)

_محتوى هذا القسم قيد الإعداد._

---

## 4. 🛠️ تحسينات تقنية لضمان السرعة والاستقرار

### 4.1. فهرسة قاعدة البيانات (Indexing in Supabase)
_محتوى هذا القسم قيد الإعداد._

### 4.2. تحسين استعلامات التقارير (Aggregation)
_محتوى هذا القسم قيد الإعداد._

### 4.3. تحميل البيانات بالترقيم (Pagination / Infinite Scroll)
_محتوى هذا القسم قيد الإعداد._

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