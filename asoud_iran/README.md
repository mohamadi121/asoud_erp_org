# ASOUD Iran

افزونهٔ حسابداری ایران برای Frappe/ERPNext v15 که به `asoud_core` وابسته است و
Core را تغییر نمی‌دهد.

## قابلیت‌های فاز یک

- موتور متوازن اختتامیه و افتتاحیه
- DocType اجرای بستن سال مالی
- ساخت و Submit اسناد واقعی `Journal Entry`
- ارتباط اسناد تولیدشده با اجرای اختتامیه و نوع سند
- قفل سطری اجرای اختتامیه و جلوگیری از اجرای تکراری
- کنترل تاریخ اختتامیه و افتتاحیه نسبت به Fiscal Year
- توقف کنترل‌شده در صورت وجود مانده باز دریافتنی/پرداختنی تفکیک‌شده بر اساس طرف حساب

API تغییردهندهٔ وضعیت فقط با `POST`:

- `asoud_iran.api.execute_closing`

## قابلیت‌های فاز دو

- قالب نمودار حساب‌های Submit‌شده و نسخه‌دار
- قالب عمومی `ASOUD-IR-GENERAL-V1.1.0` شامل ۹۶ حساب چندسطحی
- Setup قفل‌شده، تکرارپذیر و بدون بازنویسی حساب‌های موجود
- دفتر کل IRR و تبدیل صریح و دقیق IRR/Toman
- تبدیل اعتبارسنجی‌شده Gregorian/Jalali با Timezone تهران
- تفصیلی شناور مشترک در Holding با کد مستقل هر Company
- قواعد نوع تفصیلی مجاز/اجباری برای حساب معین
- Snapshot تفصیلی روی GL Entry و جلوگیری از Merge ردیف‌های متفاوت
- تراز آزمایشی و گردش تفصیلی مبتنی بر GL استاندارد
- Permission مستقل Company/Holding برای Setup، گزارش و تفصیلی

APIهای فاز دو:

- `POST asoud_iran.api.apply_iran_setup`
- `GET asoud_iran.api.iran_setup_plan`
- `GET asoud_iran.api.company_accounting_settings`
- `GET asoud_iran.api.company_chart_of_accounts`
- `GET asoud_iran.api.convert_amount`
- `GET asoud_iran.api.to_jalali`
- `GET asoud_iran.api.from_jalali`
- `GET asoud_iran.api.accounting_trial_balance`
- `GET asoud_iran.api.floating_detail_ledger`
- `GET asoud_iran.api.standard_accounting_report`
- `GET asoud_iran.api.export_accounting_report`

## Phase-eight reporting and migration

- Canonical schema `1.0` for journal, general ledger, floating-detail ledger,
  six-column trial balance, balance sheet and profit-and-loss reports
- Deterministic SHA-256 checksum and IRR/Jalali metadata on every report
- UTF-8 BOM CSV, right-to-left XLSX and right-to-left PDF from the same canonical
  rows and totals
- Company/branch/account/detail filters with backend permission enforcement,
  two-year range limit and 20,000-row safety limit
- Controlled, balanced and idempotent opening-balance import with real
  `Opening Entry`, registry integration and cancellation path
- Real-site acceptance:
  `asoud_iran.phase_eight_acceptance.run_phase_eight_acceptance`

## آزمون

```bash
python -m pytest
bench --site asoud.localhost execute asoud_iran.phase_one_acceptance.run_phase_one_acceptance
bench --site asoud.localhost execute asoud_iran.phase_two_acceptance.run_phase_two_acceptance
```
