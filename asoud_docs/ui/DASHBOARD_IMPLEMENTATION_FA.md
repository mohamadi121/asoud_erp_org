# مشخصات اجرایی داشبورد Ribbon آسود ERP

نسخه: ۱.۱  
وضعیت: Technical Ready  
دامنه: Flutter Web PWA و ERPNext/Frappe v15

## مرجع بصری

فایل `asoud-dashboard-ribbon-v1.svg` مرجع برداری تأییدشده داشبورد است. گروه‌های
اصلی SVG نام‌گذاری شده‌اند تا اندازه‌ها و مرز کامپوننت‌ها قابل استخراج باشند:

- `top-navigation`
- `context-ribbon`
- `dashboard-content`
- `kpi-cards`
- `cash-flow-panel`
- `income-mix-panel`
- `recent-operations`
- `approval-inbox`
- `quick-access-drawer`
- `quick-create-drawer`
- `notification-popover`

## ساختار Flutter

- `core/theme/asoud_theme.dart`: رنگ‌ها، Border، Card و Input مشترک.
- `features/dashboard/domain`: مدل Aggregate و قرارداد Gateway.
- `features/dashboard/data`: اتصال به API مجوزمحور Frappe.
- `features/dashboard/presentation/dashboard_page.dart`: داشبورد Responsive،
  نمودارهای بدون وابستگی خارجی، جدول، کارتابل، اعلان و دو کشو.
- `features/home/presentation/workspace_page.dart`: منوی اصلی و Ribbon زمینه‌ای.

## قرارداد API

```text
GET /api/method/asoud_core.api.dashboard_workspace
    ?company=<Company>
    [&branch=<Branch>]
```

```text
GET  /api/method/asoud_core.api.operational_link_options
POST /api/method/asoud_core.api.mark_dashboard_notification_read
```

پاسخ شامل موارد زیر است:

- `cards`: فروش، دریافت، پرداخت، بانک، صندوق و تنخواه.
- `cash_flow`: دریافت و پرداخت شش ماه اخیر.
- `income_mix`: تفکیک کالا و خدمات در ماه جاری.
- `recent_operations`: هشت سند اخیر از قراردادهای عملیاتی پشتیبانی‌شده.
- `approval_inbox`: کارتابل ورودی و شمارنده‌های ورودی/خروجی.
- `notifications`: پنج اعلان آخر کاربر جاری.
- `quick_create_contracts`: هشت قرارداد Allowlist شده برای ایجاد پیش‌نویس.

Company و Branch فقط ورودی نمایش نیستند؛ Backend با `can_access_context` مجوز
کاربر را مجدداً ارزیابی می‌کند. ایجاد پیش‌نویس از API موجود
`create_operational_draft` با Idempotency Key استفاده می‌کند.

## رفتار رابط

- Dashboard صفحه پیش‌فرض بعد از انتخاب Company/Branch است.
- منوی اصلی افقی و Ribbon زمینه‌ای هستند؛ Sidebar ناوبری اصلی نیست.
- کشوی راست برای Dashboardهای سریع و نماهای ذخیره‌شده است و همه ردیف‌ها به
  ماژول مقصد متصل‌اند.
- کشوی چپ نوع سند را از قرارداد Backend می‌گیرد و فرم کامل همان قرارداد را باز
  می‌کند.
- اعلان‌ها به شکل Popover نمایش داده می‌شوند؛ هر اعلان قابل خواندن و مسیریابی
  به ماژول سند است.
- فروش، خرید و انبار از Workbench مشترک استفاده می‌کنند، اما قراردادها و اسناد
  هر صفحه بر اساس نوع سند همان ماژول فیلتر می‌شوند.
- جست‌وجوی سراسری، راهنما، پروفایل، انتخاب زمینه Company/Branch، کارتابل،
  «مشاهده همه» و تمام فرمان‌های Ribbon رفتار متصل دارند.
- فرم عملیاتی مشترک از Metadata واقعی DocType v15 نوع فیلد، عنوان، الزامی‌بودن،
  Read-only، Select و Link را می‌گیرد. Date Picker، Checkbox، ورودی عددی،
  جست‌وجوی Link، ردیف Child و اعتبارسنجی سمت کاربر فعال است.

## شواهد فنی

- `asoud_core 0.17.0`: ۴۶ تست موفق.
- `asoud_pwa 0.17.0+17`: Flutter Analyze بدون Issue و ۲۱ تست موفق.
- Flutter Web Release Build موفق.
- HTTP واقعی روی `asoud.localhost`: شش کارت، شش نقطه زمانی، هشت عملیات اخیر و
  هشت قرارداد ایجاد سریع.

این Gate صحت فنی و قراردادهای سامانه را پوشش می‌دهد؛ تأیید نهایی رنگ، فاصله،
فونت سازمانی و داده‌های واقعی بر عهده UAT کسب‌وکار است.
