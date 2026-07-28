# سند نیازمندی محصول و معماری ASOUD HR

نسخه ۲.۰ — مبنای یکپارچه با ASOUD ERP  
تاریخ: ۱۴۰۵/۰۵/۰۴  
وضعیت: Technical Baseline

## ۱. تصمیمات قطعی

- ASOUD HR یک ماژول دامنه‌ای ASOUD ERP است؛ محصول مستقل و پایگاه داده جداگانه نیست.
- Backend بر پایه ERPNext/Frappe v15 و Custom App مستقل `asoud_hr` است.
- رابط کاربری فعلی فقط Flutter Web PWA و در مخزن `asoud_pwa` است.
- Next.js، اپ موبایل Native، Push موبایل و Offline Draft موبایل از دامنه فعلی حذف و به آینده منتقل شدند.
- Frappe و ERPNext Core مستقیماً تغییر نمی‌کنند.
- Holding، Company، Branch، User Context، User Access، Approval، Delegation، Idempotency و Audit از `asoud_core` بازاستفاده می‌شوند.
- تاریخ مرجع در Backend میلادی استاندارد است و نمایش شمسی در لایه ایرانی‌سازی و رابط انجام می‌شود.
- حضور، مرخصی عملیاتی و حقوق و دستمزد به تصمیم نصب نسخه سازگار HRMS v15 در فاز آینده وابسته‌اند.

## ۲. مرز مالکیت

| لایه | مسئولیت |
|---|---|
| ERPNext استاندارد | User، Role، Company، Department، Designation، Employee، File، ToDo و Notification Log |
| asoud_core | هلدینگ، شعبه، محیط فعال، دسترسی، زمان‌بندی دسترسی، Approval، تفویض، Audit و Idempotency |
| asoud_hr | سمت سازمانی، انتساب تاریخ‌دار، مدارک، گزارش روزانه، مکاتبات، اقدامات و داشبورد HR |
| asoud_iran | اعتبارسنجی و نمایش ایرانی، شمسی و الزامات بومی آینده |
| asoud_pwa | رابط Flutter Web PWA فارسی و RTL |

## ۳. دامنه اجرایی

### HR-1 — سازمان و پرسنل

- درخت Department استاندارد و شعبه مشترک ASOUD
- Position Instance با ظرفیت و مدیر جایگاه
- انتساب تاریخ‌دار کارمند بدون حذف تاریخچه
- جلوگیری از حلقه مدیریتی و هم‌پوشانی انتساب
- توسعه Employee با شعبه، سمت، شناسه ملی محافظت‌شده و نسخه مجوز
- مدارک پرسنلی فقط در File خصوصی
- تاریخچه تغییر وضعیت استخدام
- پروفایل ۳۶۰ پایه و Mask اطلاعات حساس

### HR-2 — گزارش کار روزانه

- یک گزارش فعال برای هر کارمند و تاریخ
- چند فعالیت در Child Table
- محاسبه مدت از ساعت شروع و پایان
- جلوگیری از مدت منفی، متناقض یا بیشتر از ۲۴ ساعت
- خلاصه روز، مانع و درخواست کمک
- اتصال اختیاری فعالیت به سند دیگر
- گردش تأیید مدیر مستقیم با مسیر جایگزین HR
- ابطال تأیید پس از تغییر محتوای گزارش

### HR-3 — مکاتبات و اقدامات

- نامه داخلی، درخواست، اطلاعیه، گزارش، دستور و پیشنهاد
- گیرنده مستقیم، گیرنده واحدی و رونوشت
- اولویت، محرمانگی و مهلت پاسخ
- Thread پاسخ بدون Chat بلادرنگ
- جلوگیری از گیرنده واحدی برای «کاملاً محرمانه»
- ثبت مشاهده تغییرناپذیر
- تبدیل مکاتبه به اقدام با مسئول، مهلت، نتیجه و گزارش کار مرتبط
- Notification Log با متن امن برای موارد محرمانه

### HR-4 — داشبورد و PWA

- کارت پرسنل فعال، گزارش امروز، افراد بدون گزارش، مکاتبات و اقدامات باز
- فهرست پرسنل، گزارش‌ها و مکاتبات
- ثبت سریع گزارش روزانه
- ایجاد پیش‌نویس مکاتبه
- ماژول اصلی «منابع انسانی» در Ribbon دسکتاپ
- صفحه‌بندی و فیلتر در Backend
- عدم Cache محتوای حساس بدون سیاست صریح

### HR-5 — کنترل و پذیرش

- مجوز مبتنی بر Company، Branch، خود کارمند و مدیر مستقیم
- دسترسی HR Manager و Auditor مبتنی بر نقش و Scope
- Idempotency برای Mutationها
- Field Redaction برای شناسه ملی
- Private File برای مدارک
- Audit برای تغییر وضعیت، انتساب و ارسال مکاتبه
- migration واقعی و Metadata Gate
- تست واحد Backend، تست Gateway و Build Release وب

## ۴. مدل داده مصوب

| DocType | نوع | مسئولیت |
|---|---|---|
| ASOUD Organization Position | Master | نمونه واقعی جایگاه، ظرفیت و سلسله‌مراتب |
| ASOUD Employee Assignment | Transaction | انتساب مؤثر در بازه زمانی |
| ASOUD Employee Document | Transaction | مدرک خصوصی و طبقه‌بندی‌شده |
| ASOUD Employment Status History | Append history | تاریخچه وضعیت همکاری |
| ASOUD Daily Work Report | Submittable | گزارش روزانه والد |
| ASOUD Work Report Activity | Child | فعالیت‌های گزارش |
| ASOUD Internal Communication | Submittable | مکاتبه رسمی |
| ASOUD Communication Recipient | Child | گیرنده و رونوشت |
| ASOUD Communication Reply | Transaction | پاسخ Thread |
| ASOUD Communication Action | Transaction | اقدام قابل پیگیری |
| ASOUD Communication View Log | Append-only | اثبات مشاهده |
| ASOUD HR Notification Preference | User master | ترجیح اعلان و ساعات سکوت |

مدل‌های ASOUD Branch، User Context، User Access، Approval Request، Approval Action،
Delegation و Audit Event در این App تکرار نمی‌شوند.

## ۵. ماتریس دسترسی پایه

| نقش | دامنه |
|---|---|
| System Manager | کنترل فنی کامل |
| ASOUD HR Manager | مدیریت HR در Company/Branch مجاز |
| ASOUD HR User | عملیات پرسنلی مجاز بدون دسترسی کامل به فیلد حساس |
| مدیر مستقیم | مشاهده زیرمجموعه مستقیم و اقدام روی گزارش آنان |
| ASOUD Employee | پرونده، گزارش، مکاتبه و اقدام متعلق به خود |
| ASOUD HR Auditor | مشاهده کنترل‌شده و بدون Mutation عملیاتی |

هیچ فیلتر Frontend جایگزین کنترل Backend نیست.

## ۶. APIهای پایدار اولیه

- `asoud_hr.api.dashboard`
- `asoud_hr.api.organization`
- `asoud_hr.api.employees`
- `asoud_hr.api.employee_profile`
- `asoud_hr.api.work_reports`
- `asoud_hr.api.save_work_report`
- `asoud_hr.api.request_work_report_approval`
- `asoud_hr.api.communications`
- `asoud_hr.api.create_communication`
- `asoud_hr.api.communication_detail`
- `asoud_hr.api.add_reply`
- `asoud_hr.api.create_action`
- `asoud_hr.api.notifications`

Mutationهای حساس دارای Idempotency Key هستند. List APIها باید در نسخه‌های بعدی نیز
صفحه‌بندی، Field Whitelist و Scope سمت سرور را حفظ کنند.

## ۷. امنیت و حریم خصوصی

- شناسه ملی در سطح مجوز بالاتر و خروجی API برای کاربران غیرمجاز Mask می‌شود.
- مدارک پرسنلی باید File خصوصی باشند.
- متن مکاتبه از الگوهای HTML اجرایی خطرناک محافظت می‌شود.
- پیش‌نمایش اعلان محرمانه نباید متن کامل را افشا کند.
- مشاهده مکاتبه در View Log تغییرناپذیر ثبت می‌شود.
- حذف رکوردهای اصلی منطقی است؛ حذف تاریخچه و Audit مجاز نیست.
- Export باید همان Scope و Redaction نمایش را رعایت کند.
- Retention واقعی قراردادها و مدارک باید پیش از Production Go توسط مسئول حقوقی تصویب شود.

## ۸. معیار پذیرش

- App ششم `asoud_hr` در image اختصاصی نصب شود.
- تمام DocTypeهای مصوب در migration واقعی ساخته شوند.
- Custom Fieldهای Employee و Department موجود باشند.
- Policy پیش‌فرض گزارش کار با مدیر مستقیم/HR ایجاد شود.
- کاربر خارج از Company یا Branch نتواند داده HR را بخواند.
- کارمند فقط گزارش خود و مدیر فقط زیرمجموعه مستقیم را ببیند.
- گزارش تکراری روز، انتساب هم‌پوشان، حلقه مدیر و File عمومی رد شوند.
- Flutter Analyze بدون خطا، همه تست‌ها سبز و Web Release Build موفق باشد.
- Metadata Gate و HTTP Smoke Test روی Site توسعه عبور کنند.

## ۹. موارد صریحاً معوق

- اپ موبایل Android/iOS
- Push Notification موبایل و Deep Link Native
- Offline Draft موبایل
- حضور و غیاب عملیاتی
- مرخصی و مأموریت پیشرفته
- Payroll و مزایا
- KPI و ارزیابی عملکرد پیشرفته
- هوش مصنوعی
- اتصال بیرونی SMS

معوق بودن این موارد به معنی حذف مسیر توسعه نیست؛ تنها مانع ادعای تکمیل آن‌ها در Gate فعلی است.

