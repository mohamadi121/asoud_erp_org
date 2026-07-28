# ADR-0007 — BLoC-based Approval Cartable

وضعیت: Accepted  
تاریخ: ۱۴۰۵/۰۵/۰۵

## تصمیم

State صفحه کارتابل در `ApprovalCubit` متمرکز است و UI اجازه اجرای مستقیم
Mutation تأیید را ندارد. فرمان‌های Ribbon، View انتخابی را به صفحه منتقل می‌کنند
و Backend همچنان منبع حقیقت مجوز و Workflow است.

## پیامدها

- ورودی، ارسالی، تاریخچه، Policy و Access مسیرهای مستقل دارند.
- Search و Status در قرارداد API اعمال می‌شوند.
- جزئیات به‌صورت Master/Detail در دسکتاپ و Overlay کنترل‌شده در عرض متوسط است.
- Action با Idempotency Key و Optimistic Version اجرا می‌شود.
- هیچ وضعیت مالی یا تأییدی فقط در Flutter نگهداری نمی‌شود.
