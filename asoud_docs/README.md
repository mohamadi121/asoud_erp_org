# مستندات معماری ASOUD ERP

فایل `architecture.html` منبع قابل‌ویرایش معماری کل سامانه و فایل PDF خروجی رسمی است.

نسخه جاری معماری: ۳.۷ — صفحه کارتابل BLoC و گردش تأیید

مستند تفصیلی منابع انسانی:

- `hr/ASOUD_HR_PRD_FA_v2.0.md`
- `hr/ASOUD_HR_PRD_FA_v2.0.html`
- `hr/ASOUD_HR_PRD_FA_v2.0.pdf`

مرجع رابط داشبورد:

- `ui/asoud-dashboard-ribbon-v1.svg`
- `ui/DASHBOARD_IMPLEMENTATION_FA.md`
- `ui/asoud-approval-inbox-v1.svg`
- `ui/CARTABLE_IMPLEMENTATION_FA.md`

## تولید PDF در Windows

```powershell
& 'C:\Program Files\Google\Chrome\Application\chrome.exe' `
  --headless --disable-gpu --no-pdf-header-footer `
  --print-to-pdf='ASOUD_ERP_Architecture_FA_v3.7.pdf' `
  (Resolve-Path '.\architecture.html').Path
```

نسخه‌های قبلی برای سابقه نگهداری می‌شوند. نسخه ۳.۷ مرجع جاری معماری است.
