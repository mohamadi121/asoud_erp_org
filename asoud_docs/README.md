# مستندات معماری ASOUD ERP

فایل `architecture.html` منبع قابل‌ویرایش معماری کل سامانه و فایل PDF خروجی رسمی است.

نسخه جاری معماری: ۴.۰ — گردش تأیید و داشبورد و تنظیمات پایه انبار

مستند تفصیلی منابع انسانی:

- `hr/ASOUD_HR_PRD_FA_v2.0.md`
- `hr/ASOUD_HR_PRD_FA_v2.0.html`
- `hr/ASOUD_HR_PRD_FA_v2.0.pdf`

مرجع رابط داشبورد:

- `ui/asoud-dashboard-ribbon-v1.svg`
- `ui/DASHBOARD_IMPLEMENTATION_FA.md`
- `ui/asoud-approval-inbox-v1.svg`
- `ui/CARTABLE_IMPLEMENTATION_FA.md`
- `ui/asoud-approval-policy-form-v1.svg`
- `ui/asoud-inventory-dashboard-settings-v1.svg`
- `ui/INVENTORY_MANAGEMENT_IMPLEMENTATION_FA.md`

## تولید PDF در Windows

```powershell
& 'C:\Program Files\Google\Chrome\Application\chrome.exe' `
  --headless --disable-gpu --no-pdf-header-footer `
  --print-to-pdf='ASOUD_ERP_Architecture_FA_v4.0.pdf' `
  (Resolve-Path '.\architecture.html').Path
```

نسخه‌های قبلی برای سابقه نگهداری می‌شوند. نسخه ۴.۰ مرجع جاری معماری است.
