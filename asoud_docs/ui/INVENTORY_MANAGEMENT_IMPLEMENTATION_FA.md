# مشخصات اجرایی داشبورد و تنظیمات پایه انبار

وضعیت: Implemented — Code Gate passed; Docker Site Gate pending Engine startup
دامنه: ERPNext/Frappe v15، Flutter Web PWA و BLoC/Cubit

## اصل معماری

تصویر ارسالی کاربر مرجع محتوا بوده است. ظاهر از پوسته قفل‌شده آسود ERP شامل
ناوبری اصلی، Ribbon زمینه‌ای، Context شرکت/شعبه، کارت‌های سفید و رنگ اصلی آبی
پیروی می‌کند. هیچ جدول موازی برای مفاهیم استاندارد انبار ساخته نشده است.

## نگاشت مفاهیم

| مفهوم محصول | منبع حقیقت ERPNext |
|---|---|
| انبار و ساختار والد/فرزند | `Warehouse` |
| نوع انبار | `Warehouse Type` |
| نوع و طبقه کالا | `Item Group` |
| واحد اندازه‌گیری | `UOM` |
| دسته واحد اصلی | `UOM Category` |
| تبدیل واحد | `UOM Conversion Factor` |
| کالا و خدمت | `Item` + `ASOUD Item Company Profile` |
| موجودی و ارزش | `Bin` محدود به Warehouseهای Company/Branch |
| گردش | `Stock Entry` |

## صفحات PWA

- داشبورد انبار: تعداد کالا/خدمت، انبارها، اقلام دارای موجودی، موجودی کل، ارزش
  و موجودی منفی و آخرین Stock Entryها.
- رسید و حواله: همان فرم عملیاتی `Stock Entry` موجود و بدون API موازی.
- انبارها: فهرست و فرم Warehouse و Warehouse Type.
- گروه و نوع کالا: ساختار Item Group برای مواد اولیه، WIP، محصول، تجهیزات و
  طبقه‌بندی‌های قابل توسعه.
- واحدها: فرم UOM، UOM Category و UOM Conversion Factor.
- کالا و خدمات: صفحه موجود با کد خودکار `GDS-#####` و `SRV-#####`، حساب‌ها و
  سیاست مستقل شرکت.

## API

```text
GET  /api/method/asoud_core.api.inventory_management_workspace
POST /api/method/asoud_core.api.save_inventory_setting
GET  /api/method/asoud_core.api.item_management_snapshot
GET  /api/method/asoud_core.api.item_management_detail
POST /api/method/asoud_core.api.save_item_master
```

Mutationها دارای Idempotency Key، کنترل Role، کنترل Company/Branch و Audit هستند.
Warehouse فقط در Company انتخابی و Branch متعلق به همان Company ایجاد می‌شود.
تنظیمات سراسری ERPNext مانند UOM فقط برای System/Stock/Item Manager قابل تغییرند.

## شواهد و مرز UAT

- تست‌های pure Backend برای Warehouse، UOM و تبدیل واحد افزوده شده‌اند.
- تست‌های Gateway، Cubit و Widget برای قرارداد API، داشبورد و بازشدن فرم افزوده
  شده‌اند.
- Flutter Analyze، مجموعه تست Flutter و Web Release Build با موفقیت اجرا شدند؛ تست‌های Backend نیز موفق‌اند.
- Docker Migration و Site Smoke به‌دلیل خاموش‌بودن Docker Engine در زمان انتشار اجرا نشدند و تا عبور آن‌ها
  وضعیت Production Ready اعلام نمی‌شود.
- نام گروه‌های واقعی، حساب موجودی، انبارهای سازمان و ضریب تبدیل باید در UAT
  کسب‌وکار مقصد تأیید شوند.

مرجع بصری: `asoud-inventory-dashboard-settings-v1.svg`.
