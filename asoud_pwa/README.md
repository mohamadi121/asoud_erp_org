# ASOUD PWA

RTL Flutter Web shell for ASOUD ERP with Frappe login and company/branch context selection. The layout is feature-first; business rules and authorization remain on the backend. BLoC/Cubit is used only for client state and workflow presentation.

The selected company/branch is persisted through the backend
`asoud_core.api.set_active_context` POST endpoint before the workspace opens.

The phase-two workspace loads the permitted company's Iranian accounting
settings and versioned chart, provides explicit IRR/Toman and Jalali conversion,
and reads the base trial balance. Setup is exposed only when the backend reports
that the selected Company is pending; backend roles and Company permission remain
authoritative.

Iranian accounting presentation state is owned by an independent
`IranAccountingCubit`. Its numbering workspace loads Company-scoped fiscal years
and temporary documents, performs legal final numbering for an explicit date
range, and creates idempotent same-day `ASOUD Document Consolidation` records.
Temporary numbers are retained by the backend as the permanent audit reference.

The phase-eight workspace adds a dedicated Persian reports area for the journal,
general ledger, floating-detail ledger, six-column trial balance, balance sheet
and profit-and-loss statement. It displays the canonical checksum and downloads
the full permission-scoped result as CSV, XLSX or RTL PDF using the authenticated
browser session.

The phase-ten operational workbench adds permission-scoped recent documents and
safe draft forms for sales, purchase, payment, stock, journal, treasury, cheque
and intercompany operations. Mutations use a shared CSRF-secured session and a
new persistent idempotency key. Standard submittable documents use controlled
submit/cancel actions; cheque and intercompany records retain their dedicated
state machines.

## Run

```text
flutter pub get
flutter run -d chrome
```

## Verify

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --pwa-strategy=none
```

The build explicitly disables Flutter's generated service worker. ASOUD's online-first cache policy will be added deliberately after API and security rules are implemented.

## Structure

- `lib/app`: bootstrap, routing and application shell
- `lib/core`: API, authentication, context, permissions and shared infrastructure
- `lib/features`: feature-first data/domain/presentation modules
- `test`: unit, BLoC and widget tests
