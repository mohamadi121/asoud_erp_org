# مشخصات اجرایی صفحه کارتابل آسود ERP

نسخه: ۱.۰  
وضعیت: Technical Ready  
دامنه: Flutter Web PWA، BLoC/Cubit و ERPNext/Frappe v15

## مرجع بصری

- `asoud-approval-inbox-v1.svg`: مرجع برداری قابل‌ویرایش صفحه.
- `asoud-approval-inbox-v1-preview.png`: پیش‌نمایش رندرشده.

صفحه شامل Ribbon کارتابل، ورودی، ارسالی‌ها، تاریخچه، مسیرهای تأیید، کاربران و
دسترسی، جست‌وجو، فیلتر وضعیت، شمارنده‌ها، جدول Responsive و پنل جزئیات است.

## معماری Flutter

- `approval_cubit.dart`: منبع واحد State صفحه شامل View، فیلتر، Inbox، جزئیات،
  Loading، Action و Error.
- `approval_page.dart`: رابط RTL، ناوبری پنج‌گانه، Master/Detail Responsive،
  مسیر مرحله‌ای و عملیات تأیید، بازگشت و رد.
- `frappe_approval_gateway.dart`: نگاشت API به مدل‌های Domain و ارسال
  Idempotency Key برای Mutationها.
- `workspace_page.dart`: نگاشت مستقیم فرمان‌های Ribbon به View متناظر؛
  «در انتظار من»، «ارسالی‌ها»، «تاریخچه»، «سیاست‌ها» و «جانشینی» دیگر به یک
  صفحه ثابت هدایت نمی‌شوند.

## API

```text
GET /api/method/asoud_core.api.approval_inbox
    ?company=<Company>
    [&branch=<Branch>]
    &view=incoming|outgoing|history
    [&search=<text>]
    [&status=Pending|Approved|Rejected|Returned|Invalidated]
    [&limit=1..100]

GET  /api/method/asoud_core.api.approval_request_detail
POST /api/method/asoud_core.api.start_approval_request
POST /api/method/asoud_core.api.act_on_approval
GET  /api/method/asoud_core.api.approval_policy_catalog
GET  /api/method/asoud_core.api.access_overview
POST /api/method/asoud_core.api.set_user_access
GET  /api/method/asoud_core.api.approval_settings_workspace
POST /api/method/asoud_core.api.save_approval_policy
```

## فرم عملیاتی مسیر تأیید

- ایجاد و ویرایش سیاست از داخل Flutter Web PWA انجام می‌شود.
- نوع سند، شرکت/شعبه، بازه مبلغ، اولویت، بازه اعتبار، وضعیت فعال، خودتأییدی و
  قاعده مراحل هم‌ردیف قابل تنظیم هستند.
- هر مرحله دارای ترتیب، عنوان، نوع تأییدکننده (مدیر، نقش یا کاربر مشخص) و مهلت
  ساعتی است. شماره ترتیب تکراری، تأییدکنندگان موازی را تعریف می‌کند.
- گزینه‌های فرم از Backend و فقط در محدوده Company/Branch فعال دریافت می‌شوند؛
  کنترل مجوز، تعلق شعبه، وجود Role/User و Audit در Backend تکرار می‌شود.
- مرجع تصویری فرم در `asoud-approval-policy-form-v1.svg` و PNG متناظر ثبت شده است.

Backend مجوز Company/Branch، مالک درخواست، تأییدکننده مرحله، نقش مدیریتی،
برنامه زمانی دسترسی، منع Self-approval، Digest سند، Version خوش‌بینانه و
Idempotency را مستقل از PWA کنترل می‌کند.

## شواهد فنی

- `asoud_core 0.18.0`: ۴۷ تست موفق.
- `asoud_pwa 0.18.0+18`: Flutter Analyze بدون Issue و ۲۵ تست موفق.
- تست Cubit برای View، Search، Status، Detail و Action.
- تست Widget برای RTL، Route تاریخچه و عدم Overflow.
- Flutter Web Release Build موفق.
- Gate واقعی Site توسعه: سه View، شمارنده‌ها، یک Policy و فیلتر Search/Status
  با وضعیت Passed؛ HTTP Ping برابر Pong.

اعداد SVG داده نمایشی هستند. Gate فنی صحت ساختار و قرارداد را اثبات می‌کند؛
کاربران، درخواست‌ها، سطوح تأیید و تفکیک وظایف واقعی در UAT سازمان مقصد ارزیابی
می‌شوند.
