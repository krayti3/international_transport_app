# تهيئة بيانات افتراضية

## المتطلبات

- PowerShell
- مفتاح `service_role` من لوحة تحكم Supabase (Supabase Dashboard)

## طريقة التشغيل

### الطريقة 1: تمرير المفتاح مباشرة

```powershell
.\seed_data.ps1 -ServiceRoleKey "مفتاح_service_role_الخاص_بك"
```

### الطريقة 2: استخدام متغير البيئة

```powershell
$env:SUPABASE_SERVICE_ROLE_KEY = "مفتاح_service_role_الخاص_بك"
.\seed_data.ps1
```

## ما يقوم به السكريبت

- إنشاء المستخدم `iman@admin.com`.
- إنشاء بيانات افتراضية في جميع الجداول لمدة 31 يوماً.

## ملاحظة

السكريبت يستخدم `Invoke-RestMethod` لإرسال الطلبات، وقد تستغرق عملية التهيئة بضع دقائق حتى تكتمل.
