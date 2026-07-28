# ASOUD Core

هستهٔ عمومی ASOUD برای Frappe/ERPNext v15، بدون تغییر مستقیم در Core فریم‌ورک یا ERPNext.

## قابلیت‌های فعلی

- ساختار هلدینگ، شرکت استاندارد ERPNext و شعبهٔ عملیاتی
- دسترسی مستقل در سطح کل شرکت یا یک/چند شعبه
- دسترسی مدیر هلدینگ به شرکت‌ها و شعب وابسته
- زمینهٔ فعال شرکت/شعبه برای هر کاربر و ارائهٔ آن در Boot Info میزکار
- اعمال کنترل شرکت/شعبه روی اسناد حسابداری، خرید، فروش، انبار و دریافت/پرداخت
- کنترل تعلق انبار و مرکز هزینهٔ پیش‌فرض شعبه به همان شرکت
- Batch شماره‌گذاری، تاریخچهٔ تغییر شماره و قفل دوره
- شمارهٔ موقت تغییرناپذیر و شمارهٔ قطعی روی `Journal Entry`
- بازشماری از ابتدای بازهٔ انتخابی تا پایان سال مالی برای جلوگیری از تداخل شماره
- انتقال رسمی بین‌شرکتی با تأیید مبدأ/مقصد، دو سند واقعی و سند جبرانی
- نگاشت حساب‌های شرکت‌ها، حذف معاملات داخلی و تراز تلفیقی Holding
- ثبت اجرای پایلوت و سناریوهای UAT با مرزبندی پذیرش فنی و تجاری

## APIها

- `asoud_core.api.accessible_contexts`
- `asoud_core.api.active_context`
- `asoud_core.api.set_active_context` — فقط با درخواست `POST`
- `asoud_core.api.final_number`
- `asoud_core.api.lock_period`
- `asoud_core.api.approve_intercompany_source`
- `asoud_core.api.accept_intercompany_destination`
- `asoud_core.api.compensate_intercompany_transfer`
- `asoud_core.api.holding_consolidation_report`

## اسناد استاندارد دارای زمینهٔ شعبه

- Journal Entry
- Sales Invoice
- Purchase Invoice
- Payment Entry
- Stock Entry
- Delivery Note
- Purchase Receipt

## آزمون

```bash
python -m pytest
```

تست‌های منطق دامنه مستقل از Frappe هستند. Migration و Smoke Test سایت از مخزن
`asoud_infra` اجرا می‌شود.

Seed تکرارپذیر و Gate یکپارچگی واقعی Frappe:

```bash
bench --site asoud.localhost execute asoud_core.phase_one_demo.ensure_phase_one_demo
bench --site asoud.localhost execute asoud_core.phase_one_acceptance.run_phase_one_acceptance
```

## Phase-five operational baseline

- Shared Holding-level Customer, Supplier and Item masters
- Independent Company activation, credit, payment terms, accounts and price lists
- Branch-owned Warehouses and enforced document/warehouse context
- Standard ERPNext sales, purchase, payment and stock flows without Core forks
- Goods and Service distinction through the standard `is_stock_item` contract
- Operational APIs: `asoud_core.api.operational_catalog` and
  `asoud_core.api.operational_dashboard`
- Repeatable real-site gate:
  `asoud_core.phase_five_acceptance.run_phase_five_acceptance`

## Phase-six treasury baseline

- Company/branch-scoped Bank, Cash and Petty Cash treasury accounts
- Real Journal Entries for receipts, payments, transfers and petty-cash funding
- Petty-cash claims with receipt-level expense rows and custodian validation
- Incoming and outgoing cheque lifecycle with immutable transition events
- Cash count adjustments and exact bank-statement reconciliation
- Read-only treasury dashboard API and controlled cheque-transition API
- Repeatable real-site gate:
  `asoud_core.phase_six_acceptance.run_phase_six_acceptance`

## Phase-seven intercompany and consolidation

- Company/Branch permission checks and record locking on both approvals
- Immutable completed transfer with a unique idempotency key
- Paired submitted Journal Entries in separate legal ledgers
- Explicit compensating transfer instead of one-sided cancellation
- Mandatory submitted stock vouchers for Goods transfers
- Holding account mapping and balanced elimination layer
- Mixed-currency consolidation fails closed until an FX translation engine exists
- Repeatable real-site gate:
  `asoud_core.phase_seven_acceptance.run_phase_seven_acceptance`

## Phase-nine controlled UAT

- Submitted `ASOUD Pilot Run` and auditable scenario evidence
- Synthetic, anonymized and real-data profiles are distinguished
- A real `Go` decision requires business sign-off attachment and accepter
- Repeatable isolated-site gate:
  `asoud_core.phase_nine_acceptance.run_controlled_pilot`

## Phases ten through thirteen technical readiness

- Dedicated operational workbench API; public generic DocType mutation is not
  used by the PWA
- Strict per-DocType field allowlists for sales, purchase, payment, stock,
  journal, treasury, cheque and intercompany drafts
- CSRF-secured shared browser session plus persistent idempotency ledger
- Dedicated intercompany approval flow; generic submit cannot bypass it
- Append-only hash-chained audit events for sensitive mutations
- Submitted migration reconciliation and cutover-control records
- Real-data acceptance and Production Go fail closed without signed evidence
- Repeatable isolated-site gate:
  `asoud_core.phase_ten_thirteen_acceptance.run_acceptance`
