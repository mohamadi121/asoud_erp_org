$ErrorActionPreference = 'Stop'

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$basePath = Join-Path $dir 'asoud-financial-settings-general-v1.svg'
$base = Get-Content -LiteralPath $basePath -Raw -Encoding UTF8
$marker = '<!-- page header and local tabs -->'
$shell = $base.Substring(0, $base.IndexOf($marker))

function Save-FormSvg {
    param(
        [string]$FileName,
        [string]$Title,
        [string]$Subtitle,
        [string]$Breadcrumb,
        [string]$Body,
        [string]$FooterKey
    )

    $pageHeader = @"
<!-- form page header -->
<rect y="182" width="1920" height="123" fill="#fff"/>
<text x="1848" y="218" class="t muted" font-size="11" text-anchor="end">تنظیمات مالی  /  $Breadcrumb</text>
<text x="1848" y="255" class="t dark" font-size="26" font-weight="800" text-anchor="end">$Title</text>
<text x="1848" y="282" class="t muted" font-size="12" text-anchor="end">$Subtitle</text>
<rect x="72" y="220" width="132" height="42" rx="8" fill="#155bd7"/>
<text x="181" y="246" class="t" fill="#fff" font-size="12" font-weight="700" text-anchor="end">ذخیره و ایجاد</text>
<rect x="216" y="220" width="108" height="42" rx="8" fill="#fff" stroke="#b9c7dc"/>
<text x="300" y="246" class="t dark" font-size="12" text-anchor="end">ذخیره</text>
<rect x="336" y="220" width="96" height="42" rx="8" fill="#fff" stroke="#b9c7dc"/>
<text x="408" y="246" class="t dark" font-size="12" text-anchor="end">انصراف</text>
"@

    $footer = "<text x='960' y='1058' class='t muted' font-size='10' text-anchor='middle'>ASOUD ERP — Financial Settings / $FooterKey v1 — پوسته اصلی ثابت است</text></svg>"
    [IO.File]::WriteAllText(
        (Join-Path $dir $FileName),
        $shell + $pageHeader + $Body + $footer,
        [Text.UTF8Encoding]::new($false)
    )
}

$yearBody = @"
<!-- fiscal year form -->
<rect x="70" y="327" width="350" height="650" rx="10" class="card"/>
<text x="390" y="366" class="t dark" font-size="16" font-weight="800" text-anchor="end">راهنمای ایجاد سال مالی</text>
<circle cx="115" cy="410" r="22" fill="#edf3ff"/><text x="115" y="417" class="t" fill="#155bd7" font-size="18" font-weight="800" text-anchor="middle">۱</text>
<text x="385" y="405" class="t dark" font-size="13" font-weight="700" text-anchor="end">تعیین محدوده سال</text>
<text x="385" y="425" class="t muted" font-size="10" text-anchor="end">تاریخ شروع و پایان نباید هم‌پوشانی داشته باشد.</text>
<circle cx="115" cy="475" r="22" fill="#edf3ff"/><text x="115" y="482" class="t" fill="#155bd7" font-size="18" font-weight="800" text-anchor="middle">۲</text>
<text x="385" y="470" class="t dark" font-size="13" font-weight="700" text-anchor="end">ساخت دوره‌ها</text>
<text x="385" y="490" class="t muted" font-size="10" text-anchor="end">دوره‌های ماهانه به‌صورت خودکار ساخته می‌شوند.</text>
<circle cx="115" cy="540" r="22" fill="#edf3ff"/><text x="115" y="547" class="t" fill="#155bd7" font-size="18" font-weight="800" text-anchor="middle">۳</text>
<text x="385" y="535" class="t dark" font-size="13" font-weight="700" text-anchor="end">کنترل و فعال‌سازی</text>
<text x="385" y="555" class="t muted" font-size="10" text-anchor="end">برای هر Company فقط یک سال جاری فعال است.</text>
<rect x="92" y="615" width="306" height="150" rx="9" fill="#fff7e8" stroke="#f1cf8a"/>
<text x="375" y="648" class="t dark" font-size="12" font-weight="800" text-anchor="end">کنترل مهم</text>
<foreignObject x="112" y="666" width="266" height="78"><div xmlns="http://www.w3.org/1999/xhtml" dir="rtl" style="font-family:Tahoma,sans-serif;font-size:10px;line-height:1.9;color:#64748b">پس از ثبت سند مالی، تغییر تاریخ‌های سال مجاز نیست. اصلاح فقط از طریق فرایند کنترل‌شده و ثبت سابقه حسابرسی انجام می‌شود.</div></foreignObject>

<rect x="440" y="327" width="1410" height="650" rx="10" class="card"/>
<text x="1815" y="368" class="t dark" font-size="17" font-weight="800" text-anchor="end">اطلاعات سال مالی</text>
<text x="1815" y="391" class="t muted" font-size="11" text-anchor="end">سال مالی مستقل برای هر Company و مبنای دوره‌بندی، شماره‌گذاری و قفل اسناد</text>

<rect x="470" y="416" width="1350" height="226" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="450" class="t dark" font-size="13" font-weight="800" text-anchor="end">۱. مشخصات پایه</text>
<text x="1785" y="486" class="label" text-anchor="end">شرکت <tspan fill="#d92d20">*</tspan></text>
<rect x="1370" y="498" width="415" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1755" y="524" class="value" text-anchor="end">شرکت آسود دمو⌄</text>
<text x="1325" y="486" class="label" text-anchor="end">عنوان سال مالی <tspan fill="#d92d20">*</tspan></text>
<rect x="910" y="498" width="415" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1295" y="524" class="value" text-anchor="end">سال مالی ۱۴۰۶</text>
<text x="865" y="486" class="label" text-anchor="end">کد سال</text>
<rect x="495" y="498" width="370" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="835" y="524" class="value" text-anchor="end">FY-1406</text>

<text x="1785" y="570" class="label" text-anchor="end">تاریخ شروع <tspan fill="#d92d20">*</tspan></text>
<rect x="1370" y="582" width="415" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1755" y="608" class="value" text-anchor="end">۱۴۰۶/۰۱/۰۱</text>
<text x="1325" y="570" class="label" text-anchor="end">تاریخ پایان <tspan fill="#d92d20">*</tspan></text>
<rect x="910" y="582" width="415" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1295" y="608" class="value" text-anchor="end">۱۴۰۶/۱۲/۲۹</text>
<text x="865" y="570" class="label" text-anchor="end">تقویم</text>
<rect x="495" y="582" width="370" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="835" y="608" class="value" text-anchor="end">هجری شمسی⌄</text>

<rect x="470" y="662" width="660" height="252" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1095" y="696" class="t dark" font-size="13" font-weight="800" text-anchor="end">۳. کنترل‌ها و وضعیت</text>
<rect x="1030" y="724" width="62" height="28" rx="14" fill="#155bd7"/><circle cx="1077" cy="738" r="11" fill="#fff"/>
<text x="1005" y="742" class="t dark" font-size="11" text-anchor="end">سال مالی جاری این شرکت</text>
<rect x="1030" y="772" width="62" height="28" rx="14" fill="#155bd7"/><circle cx="1077" cy="786" r="11" fill="#fff"/>
<text x="1005" y="790" class="t dark" font-size="11" text-anchor="end">شماره‌گذاری مستقل در سطح Company</text>
<rect x="1030" y="820" width="62" height="28" rx="14" fill="#d9e1ec"/><circle cx="1045" cy="834" r="11" fill="#fff"/>
<text x="1005" y="838" class="t dark" font-size="11" text-anchor="end">اجازه ثبت سند پیش از شروع سال</text>
<text x="1095" y="882" class="t muted" font-size="10" text-anchor="end">وضعیت اولیه: پیش‌نویس؛ فعال‌سازی پس از کنترل عدم هم‌پوشانی</text>

<rect x="1160" y="662" width="660" height="252" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="696" class="t dark" font-size="13" font-weight="800" text-anchor="end">۲. الگوی ایجاد دوره‌های مالی</text>
<text x="1785" y="732" class="label" text-anchor="end">الگوی دوره <tspan fill="#d92d20">*</tspan></text>
<rect x="1435" y="744" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1755" y="770" class="value" text-anchor="end">ماهانه — ۱۲ دوره⌄</text>
<text x="1390" y="732" class="label" text-anchor="end">دوره تعدیل</text>
<rect x="1190" y="744" width="200" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1360" y="770" class="value" text-anchor="end">اختیاری⌄</text>
<rect x="1720" y="812" width="62" height="28" rx="14" fill="#155bd7"/><circle cx="1767" cy="826" r="11" fill="#fff"/>
<text x="1695" y="830" class="t dark" font-size="11" text-anchor="end">ایجاد خودکار دوره‌ها پس از ذخیره</text>
<rect x="1720" y="858" width="62" height="28" rx="14" fill="#155bd7"/><circle cx="1767" cy="872" r="11" fill="#fff"/>
<text x="1695" y="876" class="t dark" font-size="11" text-anchor="end">کنترل تعطیلات و آخرین روز ماه شمسی</text>
"@

Save-FormSvg `
    -FileName 'asoud-financial-settings-fiscal-year-form-v1.svg' `
    -Title 'ایجاد سال مالی' `
    -Subtitle 'تعریف بازه قانونی، دوره‌های مالی و کنترل‌های ثبت برای یک شرکت' `
    -Breadcrumb 'سال مالی و دوره‌ها  /  ایجاد سال مالی' `
    -Body $yearBody `
    -FooterKey 'fiscal-year-form'

$accountBody = @"
<!-- account form -->
<rect x="70" y="327" width="350" height="650" rx="10" class="card"/>
<text x="390" y="366" class="t dark" font-size="16" font-weight="800" text-anchor="end">راهنمای ایجاد حساب</text>
<text x="390" y="404" class="t dark" font-size="12" font-weight="700" text-anchor="end">حساب والد انتخاب‌شده</text>
<rect x="92" y="421" width="306" height="72" rx="9" fill="#edf3ff"/>
<text x="375" y="450" class="t dark" font-size="12" font-weight="800" text-anchor="end">۱۱۱ — موجودی نقد و بانک</text>
<text x="375" y="474" class="t muted" font-size="10" text-anchor="end">دارایی ← دارایی جاری ← موجودی نقد</text>
<line x1="92" y1="520" x2="398" y2="520" stroke="#dfe5ee"/>
<text x="390" y="555" class="t dark" font-size="12" font-weight="700" text-anchor="end">قواعد کنترلی</text>
<text x="375" y="590" class="t muted" font-size="10" text-anchor="end">• ماهیت با حساب والد سازگار باشد.</text>
<text x="375" y="620" class="t muted" font-size="10" text-anchor="end">• کد در نسخه نمودار حساب‌ها یکتا باشد.</text>
<text x="375" y="650" class="t muted" font-size="10" text-anchor="end">• حساب گروه مستقیماً سندپذیر نیست.</text>
<text x="375" y="680" class="t muted" font-size="10" text-anchor="end">• حذف حساب دارای گردش ممنوع است.</text>
<rect x="92" y="735" width="306" height="115" rx="9" fill="#fff7e8" stroke="#f1cf8a"/>
<text x="375" y="766" class="t dark" font-size="12" font-weight="800" text-anchor="end">پس از اولین گردش</text>
<foreignObject x="112" y="782" width="266" height="52"><div xmlns="http://www.w3.org/1999/xhtml" dir="rtl" style="font-family:Tahoma,sans-serif;font-size:10px;line-height:1.9;color:#64748b">تغییر ماهیت، ارز و جایگاه حساب فقط از مسیر انتقال کنترل‌شده مجاز خواهد بود.</div></foreignObject>

<rect x="440" y="327" width="1410" height="650" rx="10" class="card"/>
<text x="1815" y="368" class="t dark" font-size="17" font-weight="800" text-anchor="end">مشخصات حساب</text>
<text x="1815" y="391" class="t muted" font-size="11" text-anchor="end">ایجاد حساب در نسخه فعال نمودار حساب‌های شرکت آسود دمو</text>

<rect x="470" y="416" width="1350" height="250" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="450" class="t dark" font-size="13" font-weight="800" text-anchor="end">۱. جایگاه و شناسه حساب</text>
<text x="1785" y="486" class="label" text-anchor="end">حساب والد <tspan fill="#d92d20">*</tspan></text>
<rect x="1370" y="498" width="415" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1755" y="524" class="value" text-anchor="end">۱۱۱ — موجودی نقد و بانک⌄</text>
<text x="1325" y="486" class="label" text-anchor="end">کد حساب <tspan fill="#d92d20">*</tspan></text>
<rect x="1010" y="498" width="315" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1295" y="524" class="value" text-anchor="end">۱۱۱۰۰۳</text>
<rect x="920" y="504" width="70" height="28" rx="14" fill="#155bd7"/><circle cx="975" cy="518" r="11" fill="#fff"/>
<text x="895" y="522" class="t muted" font-size="10" text-anchor="end">تولید خودکار</text>

<text x="1785" y="570" class="label" text-anchor="end">عنوان فارسی <tspan fill="#d92d20">*</tspan></text>
<rect x="1370" y="582" width="415" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1755" y="608" class="value" text-anchor="end">تنخواه‌گردان دفتر مرکزی</text>
<text x="1325" y="570" class="label" text-anchor="end">عنوان انگلیسی</text>
<rect x="910" y="582" width="415" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1295" y="608" class="value" text-anchor="end">Head Office Petty Cash</text>
<text x="865" y="570" class="label" text-anchor="end">سطح حساب</text>
<rect x="495" y="582" width="370" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="835" y="608" class="value" text-anchor="end">معین / حساب نهایی⌄</text>

<rect x="1160" y="686" width="660" height="228" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="720" class="t dark" font-size="13" font-weight="800" text-anchor="end">۲. رفتار حسابداری</text>
<text x="1785" y="756" class="label" text-anchor="end">نوع حساب <tspan fill="#d92d20">*</tspan></text>
<rect x="1435" y="768" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1755" y="794" class="value" text-anchor="end">تنخواه⌄</text>
<text x="1390" y="756" class="label" text-anchor="end">ماهیت <tspan fill="#d92d20">*</tspan></text>
<rect x="1190" y="768" width="200" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1360" y="794" class="value" text-anchor="end">بدهکار⌄</text>
<text x="1785" y="840" class="label" text-anchor="end">طبقه صورت مالی</text>
<rect x="1435" y="852" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1755" y="878" class="value" text-anchor="end">دارایی جاری⌄</text>
<text x="1390" y="840" class="label" text-anchor="end">ارز حساب</text>
<rect x="1190" y="852" width="200" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1360" y="878" class="value" text-anchor="end">ریال ایران⌄</text>

<rect x="470" y="686" width="660" height="228" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1095" y="720" class="t dark" font-size="13" font-weight="800" text-anchor="end">۳. قواعد تفصیلی و ابعاد</text>
<rect x="500" y="738" width="600" height="34" rx="6" fill="#edf3ff"/>
<g class="t dark" font-size="9" font-weight="700" text-anchor="end"><text x="1075" y="760">نوع تفصیلی</text><text x="905" y="760">وضعیت</text><text x="755" y="760">پیش‌فرض</text><text x="610" y="760">اعتبار</text></g>
<rect x="500" y="780" width="600" height="48" rx="6" fill="#fff" stroke="#dfe5ee"/>
<text x="1075" y="809" class="t dark" font-size="10" font-weight="700" text-anchor="end">کارمند / تنخواه‌دار</text>
<rect x="855" y="791" width="52" height="24" rx="12" fill="#155bd7"/><circle cx="894" cy="803" r="9" fill="#fff"/><text x="840" y="807" class="t dark" font-size="9" text-anchor="end">اجباری</text>
<text x="755" y="809" class="t muted" font-size="9" text-anchor="end">بدون پیش‌فرض</text><text x="610" y="809" class="t muted" font-size="9" text-anchor="end">همیشه</text>
<rect x="500" y="836" width="600" height="48" rx="6" fill="#fff" stroke="#dfe5ee"/>
<text x="1075" y="865" class="t dark" font-size="10" font-weight="700" text-anchor="end">مرکز هزینه</text>
<rect x="855" y="847" width="52" height="24" rx="12" fill="#d9e1ec"/><circle cx="867" cy="859" r="9" fill="#fff"/><text x="840" y="863" class="t dark" font-size="9" text-anchor="end">اختیاری</text>
<text x="755" y="865" class="t muted" font-size="9" text-anchor="end">از شعبه</text><text x="610" y="865" class="t muted" font-size="9" text-anchor="end">همیشه</text>
<rect x="500" y="892" width="108" height="24" rx="6" fill="#fff" stroke="#155bd7"/><text x="595" y="909" class="t" fill="#155bd7" font-size="9" text-anchor="end">+ افزودن قاعده</text>
"@

Save-FormSvg `
    -FileName 'asoud-financial-settings-account-form-v1.svg' `
    -Title 'ایجاد حساب' `
    -Subtitle 'تعریف حساب گروه یا حساب سندپذیر همراه با ماهیت و کنترل ابعاد حسابداری' `
    -Breadcrumb 'نمودار حساب‌ها  /  ایجاد حساب' `
    -Body $accountBody `
    -FooterKey 'account-form'

Write-Output 'Generated fiscal year and account forms.'
