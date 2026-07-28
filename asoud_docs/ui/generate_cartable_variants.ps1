$ErrorActionPreference = 'Stop'
$outDir = (Get-Location).Path

function Get-Shell([string]$activeTab, [string]$title, [string]$subtitle) {
    $tabs = @(
        @{ Label = 'در انتظار من'; X = 1740; Key = 'pending' },
        @{ Label = 'ارسالی‌ها'; X = 1580; Key = 'sent' },
        @{ Label = 'تاریخچه'; X = 1430; Key = 'history' },
        @{ Label = 'مسیرهای تأیید'; X = 1250; Key = 'routes' },
        @{ Label = 'کاربران و دسترسی'; X = 1050; Key = 'access' }
    )
    $tabSvg = ''
    foreach ($tab in $tabs) {
        $color = if ($tab.Key -eq $activeTab) { '#155bd7' } else { '#334155' }
        $weight = if ($tab.Key -eq $activeTab) { '700' } else { '500' }
        $tabSvg += "<text x='$($tab.X)' y='286' class='t' font-size='14' font-weight='$weight' fill='$color' text-anchor='middle'>$($tab.Label)</text>"
        if ($tab.Key -eq $activeTab) {
            $tabSvg += "<rect x='$($tab.X - 67)' y='299' width='134' height='3' rx='1.5' fill='#155bd7'/>"
        }
    }
    return @"
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
<defs>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="160%"><feDropShadow dx="0" dy="5" stdDeviation="9" flood-color="#12213d" flood-opacity=".10"/></filter>
  <style>
    .t{font-family:Vazirmatn,Tahoma,"Segoe UI",sans-serif}
    .muted{fill:#64748b}.dark{fill:#12213d}.line{stroke:#dfe5ee}.card{fill:#fff;stroke:#dfe5ee}
    .ico{fill:none;stroke:#12213d;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
  </style>
</defs>
<rect width="1920" height="1080" fill="#f5f7fb"/>
<!-- frozen primary navigation -->
<rect width="1920" height="66" fill="#fff"/>
<line x1="0" y1="65.5" x2="1920" y2="65.5" stroke="#dfe5ee"/>
<rect x="1848" y="14" width="38" height="38" rx="8" fill="#155bd7"/>
<path d="M1867 21l10 12-10 12-10-12z" fill="none" stroke="#fff" stroke-width="2"/>
<text x="1835" y="40" class="t dark" font-size="22" font-weight="800" text-anchor="end">ERP آسود</text>
<g class="t" font-size="14" fill="#12213d" text-anchor="middle">
 <text x="1644" y="41" fill="#155bd7" font-weight="700">داشبورد</text><rect x="1595" y="63" width="98" height="3" fill="#155bd7"/>
 <text x="1515" y="41">مالی</text><text x="1400" y="41">خزانه‌داری</text><text x="1285" y="41">فروش</text>
 <text x="1180" y="41">خرید</text><text x="1080" y="41">انبار</text><text x="965" y="41">منابع انسانی</text>
 <text x="850" y="41">گزارش‌ها</text><text x="735" y="41">تنظیمات</text>
</g>
<rect x="384" y="13" width="252" height="40" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<circle cx="414" cy="33" r="7" fill="none" stroke="#155bd7" stroke-width="2"/><path d="M419 38l6 6" stroke="#155bd7" stroke-width="2"/>
<text x="611" y="38" class="t muted" font-size="12" text-anchor="end">جست‌وجوی ماژول یا فرمان...</text>
<circle cx="350" cy="33" r="7" class="ico"/><path d="M350 23v2M342 43h16" class="ico"/>
<circle cx="298" cy="32" r="8" class="ico"/><text x="298" y="37" font-family="Arial" font-size="13" text-anchor="middle" fill="#12213d">?</text>
<circle cx="224" cy="33" r="20" fill="#edf3ff"/><circle cx="224" cy="29" r="6" class="ico"/><path d="M214 44c2-7 18-7 20 0" class="ico"/>
<text x="193" y="29" class="t dark" font-size="13" font-weight="700" text-anchor="end">مدیر سیستم</text>
<text x="193" y="46" class="t muted" font-size="10" text-anchor="end">شرکت آسود — دفتر مرکزی</text>
<path d="M28 25h17M28 33h17M28 41h17" class="ico"/>
<!-- frozen ribbon -->
<rect y="66" width="1920" height="116" fill="#f8fafd"/><line x1="0" y1="181.5" x2="1920" y2="181.5" stroke="#dfe5ee"/>
<rect x="1718" y="77" width="68" height="72" rx="10" fill="#edf3ff"/><path d="M1742 96h20v23h-20zM1747 91h10v5" fill="none" stroke="#155bd7" stroke-width="2"/>
<text x="1752" y="135" class="t" fill="#155bd7" font-size="12" font-weight="700" text-anchor="middle">کارتابل</text>
<path d="M1824 102l11-10 11 10v20h-8v-12h-7v12h-7z" class="ico"/><text x="1835" y="135" class="t dark" font-size="12" text-anchor="middle">خانه</text>
<line x1="1628" y1="78" x2="1628" y2="166" stroke="#dfe5ee"/>
<g class="t dark" font-size="11" text-anchor="middle">
 <path d="M1558 94h18v23h-18zM1563 99h8M1563 105h8M1563 111h8" class="ico"/><text x="1567" y="135">فعالیت‌ها</text>
 <path d="M1462 96h18v18h-18zM1471 100v10M1466 105h10" class="ico"/><text x="1471" y="135">سند جدید</text>
 <path d="M1351 100h27M1351 100l7-7M1351 100l7 7M1378 113h-27M1378 113l-7-7M1378 113l-7 7" class="ico"/><text x="1365" y="135">دریافت/پرداخت</text>
 <path d="M1250 93h20v25h-20zM1255 100h10M1255 106h10M1255 112h7" class="ico"/><text x="1260" y="135">فاکتور</text>
 <path d="M1150 94h20v23h-20zM1154 101h12M1154 107h8" class="ico"/><text x="1160" y="135">گزارش کار</text>
 <path d="M1027 105a12 12 0 1 0 5-10M1027 92v10h10" class="ico"/><text x="1039" y="135">به‌روزرسانی</text>
 <path d="M920 94v25M909 101h22M913 111h14" class="ico"/><text x="920" y="135">شخصی‌سازی</text>
 <path d="M824 93h9M824 93v9M851 93h-9M851 93v9M824 119h9M824 119v-9M851 119h-9M851 119v-9" class="ico"/><text x="838" y="135">تمام‌صفحه</text>
</g>
<line x1="885" y1="78" x2="885" y2="166" stroke="#dfe5ee"/>
<rect x="650" y="91" width="210" height="38" rx="8" fill="#fff" stroke="#dfe5ee"/><text x="840" y="115" class="t dark" font-size="12" text-anchor="end">شرکت آسود دمو</text>
<rect x="460" y="91" width="175" height="38" rx="8" fill="#fff" stroke="#dfe5ee"/><text x="615" y="115" class="t dark" font-size="12" text-anchor="end">دفتر مرکزی</text>
<rect x="269" y="91" width="176" height="38" rx="8" fill="#fff" stroke="#dfe5ee"/><text x="425" y="115" class="t dark" font-size="12" text-anchor="end">سال مالی ۱۴۰۵</text>
<!-- local page header -->
<rect y="182" width="1920" height="121" fill="#fff"/>
<text x="1848" y="219" class="t dark" font-size="24" font-weight="800" text-anchor="end">$title</text>
<text x="1848" y="240" class="t muted" font-size="12" text-anchor="end">$subtitle</text>
<rect x="72" y="198" width="165" height="41" rx="8" fill="#155bd7"/><text x="218" y="224" class="t" font-size="13" font-weight="700" fill="#fff" text-anchor="end">ارسال سند برای تأیید</text><path d="M203 218h15m-6-6l6 6-6 6" fill="none" stroke="#fff" stroke-width="2"/>
$tabSvg
"@
}

function Get-Footer {
    return @"
<text x="960" y="1060" class="t muted" font-size="10" text-anchor="middle">ASOUD ERP — Frozen Shell Proposal v1 — پوسته اصلی در تمام صفحات ثابت است</text>
</svg>
"@
}

$sentBody = @"
<rect y="303" width="1920" height="65" fill="#f8fafd"/>
<rect x="1418" y="315" width="442" height="40" rx="9" fill="#fff" stroke="#dfe5ee"/>
<text x="1828" y="340" class="t muted" font-size="12" text-anchor="end">جست‌وجوی شماره سند، گیرنده یا عنوان...</text>
<rect x="1210" y="315" width="192" height="40" rx="9" fill="#fff" stroke="#dfe5ee"/><text x="1380" y="340" class="t dark" font-size="12" text-anchor="end">همه وضعیت‌ها⌄</text>
<rect x="70" y="386" width="1780" height="592" rx="10" class="card"/>
<rect x="86" y="402" width="1748" height="43" rx="7" fill="#f8fafd"/>
<g class="t dark" font-size="12" font-weight="700" text-anchor="middle"><text x="1725" y="428">نوع سند</text><text x="1450" y="428">شماره سند</text><text x="1190" y="428">ارسال‌شده برای</text><text x="900" y="428">تاریخ ارسال</text><text x="650" y="428">مرحله جاری</text><text x="340" y="428">وضعیت</text></g>
<g class="t dark" font-size="13" text-anchor="middle">
 <rect x="86" y="459" width="1748" height="78" rx="8" fill="#edf3ff" stroke="#a9c7ff"/><text x="1725" y="492" font-weight="700">فاکتور فروش</text><text x="1450" y="492">SINV-00042</text><text x="1190" y="492">مدیر مالی</text><text x="900" y="492">۱۴۰۵/۰۵/۰۶ ـ ۰۹:۴۰</text><text x="650" y="492">مرحله ۲ از ۳</text><rect x="282" y="477" width="116" height="28" rx="14" fill="#fff2d8"/><text x="340" y="496" fill="#b66a00" font-size="12">در انتظار تأیید</text>
 <text x="1725" y="584" font-weight="700">سند حسابداری</text><text x="1450" y="584">ACC-JV-0033</text><text x="1190" y="584">مدیر شرکت</text><text x="900" y="584">۱۴۰۵/۰۵/۰۵ ـ ۱۵:۲۲</text><text x="650" y="584">مرحله ۱ از ۲</text><rect x="282" y="569" width="116" height="28" rx="14" fill="#e9f8f0"/><text x="340" y="588" fill="#168a56" font-size="12">تأیید شد</text>
 <line x1="86" y1="615" x2="1834" y2="615" class="line"/><text x="1725" y="662" font-weight="700">درخواست پرداخت</text><text x="1450" y="662">ACC-PAY-0030</text><text x="1190" y="662">مدیر شعبه</text><text x="900" y="662">۱۴۰۵/۰۵/۰۴ ـ ۱۲:۱۰</text><text x="650" y="662">پایان مسیر</text><rect x="282" y="647" width="116" height="28" rx="14" fill="#fdecec"/><text x="340" y="666" fill="#d14343" font-size="12">برگشت داده شد</text>
 <line x1="86" y1="693" x2="1834" y2="693" class="line"/><text x="1725" y="740" font-weight="700">انتقال بین‌شرکتی</text><text x="1450" y="740">ICT-00018</text><text x="1190" y="740">مدیر هلدینگ</text><text x="900" y="740">۱۴۰۵/۰۵/۰۳ ـ ۱۰:۰۵</text><text x="650" y="740">مرحله ۳ از ۳</text><rect x="282" y="725" width="116" height="28" rx="14" fill="#eaf1ff"/><text x="340" y="744" fill="#155bd7" font-size="12">در حال بررسی</text>
</g>
<text x="1815" y="946" class="t muted" font-size="11" text-anchor="end">نمایش ۴ مورد از ۲۴ سند ارسالی</text>
"@

$historyBody = @"
<rect y="303" width="1920" height="65" fill="#f8fafd"/>
<rect x="1418" y="315" width="442" height="40" rx="9" fill="#fff" stroke="#dfe5ee"/><text x="1828" y="340" class="t muted" font-size="12" text-anchor="end">جست‌وجو در رویدادها و اسناد...</text>
<rect x="1194" y="315" width="208" height="40" rx="9" fill="#fff" stroke="#dfe5ee"/><text x="1380" y="340" class="t dark" font-size="12" text-anchor="end">۳۰ روز گذشته⌄</text>
<rect x="70" y="386" width="1780" height="592" rx="10" class="card"/>
<text x="1815" y="424" class="t dark" font-size="16" font-weight="700" text-anchor="end">خط زمانی عملیات کارتابل</text>
<line x1="1650" y1="462" x2="1650" y2="890" stroke="#dfe5ee" stroke-width="3"/>
<g class="t">
 <circle cx="1650" cy="495" r="17" fill="#e9f8f0"/><path d="M1642 495l6 6 11-14" fill="none" stroke="#168a56" stroke-width="2.5"/><text x="1605" y="488" class="dark" font-size="14" font-weight="700" text-anchor="end">فاکتور فروش SINV-00038 تأیید نهایی شد</text><text x="1605" y="512" class="muted" font-size="11" text-anchor="end">توسط مدیر مالی • امروز ۱۰:۳۵ • مسیر فروش عمده</text>
 <circle cx="1650" cy="585" r="17" fill="#edf3ff"/><path d="M1644 585h12m-6-6v12" stroke="#155bd7" stroke-width="2"/><text x="1605" y="578" class="dark" font-size="14" font-weight="700" text-anchor="end">درخواست پرداخت ACC-PAY-0028 وارد مرحله دوم شد</text><text x="1605" y="602" class="muted" font-size="11" text-anchor="end">ارسال از مدیر شعبه به مدیر شرکت • امروز ۰۹:۱۲</text>
 <circle cx="1650" cy="675" r="17" fill="#fdecec"/><path d="M1643 668l14 14m0-14l-14 14" stroke="#d14343" stroke-width="2"/><text x="1605" y="668" class="dark" font-size="14" font-weight="700" text-anchor="end">سند حسابداری ACC-JV-0029 برای اصلاح برگشت داده شد</text><text x="1605" y="692" class="muted" font-size="11" text-anchor="end">توسط مدیر شرکت • دیروز ۱۶:۴۸ • علت: اصلاح مرکز هزینه</text>
 <circle cx="1650" cy="765" r="17" fill="#fff2d8"/><path d="M1644 757h12l-6 8-6-8m0 16h12l-6-8" fill="none" stroke="#b66a00" stroke-width="2"/><text x="1605" y="758" class="dark" font-size="14" font-weight="700" text-anchor="end">انتقال بین‌شرکتی ICT-00015 ثبت و برای تأیید ارسال شد</text><text x="1605" y="782" class="muted" font-size="11" text-anchor="end">توسط حسابدار هلدینگ • ۱۴۰۵/۰۵/۰۴ ـ ۱۴:۲۰</text>
</g>
<rect x="100" y="458" width="390" height="180" rx="9" fill="#f8fafd" stroke="#dfe5ee"/><text x="458" y="490" class="t dark" font-size="14" font-weight="700" text-anchor="end">خلاصه دوره</text>
<g class="t" font-size="12"><text x="458" y="530" class="muted" text-anchor="end">تأییدشده</text><text x="130" y="530" class="dark" font-size="18" font-weight="700">۲۴</text><text x="458" y="568" class="muted" text-anchor="end">برگشت‌خورده</text><text x="130" y="568" class="dark" font-size="18" font-weight="700">۳</text><text x="458" y="606" class="muted" text-anchor="end">میانگین زمان پاسخ</text><text x="130" y="606" class="dark" font-size="18" font-weight="700">۴س ۱۲د</text></g>
"@

$routesBody = @"
<rect y="303" width="1920" height="65" fill="#f8fafd"/>
<rect x="1660" y="315" width="200" height="40" rx="9" fill="#155bd7"/><text x="1838" y="341" class="t" fill="#fff" font-size="12" font-weight="700" text-anchor="end">+ مسیر تأیید جدید</text>
<rect x="70" y="386" width="560" height="592" rx="10" class="card"/>
<text x="598" y="425" class="t dark" font-size="16" font-weight="700" text-anchor="end">مسیرهای فعال</text>
<rect x="86" y="449" width="528" height="78" rx="8" fill="#edf3ff" stroke="#a9c7ff"/><text x="590" y="478" class="t dark" font-size="14" font-weight="700" text-anchor="end">فروش عمده</text><text x="590" y="501" class="t muted" font-size="11" text-anchor="end">۳ مرحله • شرکت آسود • فعال</text>
<g class="t"><text x="590" y="565" class="dark" font-size="14" font-weight="700" text-anchor="end">پرداخت و خزانه‌داری</text><text x="590" y="588" class="muted" font-size="11" text-anchor="end">۲ مرحله • دفتر مرکزی • فعال</text><line x1="86" y1="610" x2="614" y2="610" class="line"/><text x="590" y="650" class="dark" font-size="14" font-weight="700" text-anchor="end">سند حسابداری</text><text x="590" y="673" class="muted" font-size="11" text-anchor="end">۲ مرحله • همه شعب • فعال</text></g>
<rect x="650" y="386" width="1200" height="592" rx="10" class="card"/>
<text x="1815" y="425" class="t dark" font-size="17" font-weight="800" text-anchor="end">مسیر تأیید فروش عمده</text><text x="1815" y="449" class="t muted" font-size="11" text-anchor="end">اعمال روی فاکتور فروش • شرکت آسود • نسخه ۴</text>
<line x1="905" y1="578" x2="1590" y2="578" stroke="#b9c7dc" stroke-width="3"/>
<g class="t">
 <circle cx="1590" cy="578" r="28" fill="#e9f8f0"/><text x="1590" y="585" fill="#168a56" font-size="18" font-weight="800" text-anchor="middle">۱</text><text x="1590" y="635" class="dark" font-size="14" font-weight="700" text-anchor="middle">مدیر شعبه</text><text x="1590" y="657" class="muted" font-size="10" text-anchor="middle">بررسی اولیه</text>
 <circle cx="1360" cy="578" r="28" fill="#edf3ff"/><text x="1360" y="585" fill="#155bd7" font-size="18" font-weight="800" text-anchor="middle">۲</text><text x="1360" y="635" class="dark" font-size="14" font-weight="700" text-anchor="middle">مدیر فروش</text><text x="1360" y="657" class="muted" font-size="10" text-anchor="middle">تأیید عملیاتی</text>
 <circle cx="1130" cy="578" r="28" fill="#edf3ff"/><text x="1130" y="585" fill="#155bd7" font-size="18" font-weight="800" text-anchor="middle">۳</text><text x="1130" y="635" class="dark" font-size="14" font-weight="700" text-anchor="middle">مدیر مالی</text><text x="1130" y="657" class="muted" font-size="10" text-anchor="middle">تأیید نهایی</text>
 <circle cx="905" cy="578" r="28" fill="#f8fafd" stroke="#b9c7dc"/><path d="M893 578l8 8 16-18" fill="none" stroke="#64748b" stroke-width="2.5"/><text x="905" y="635" class="dark" font-size="14" font-weight="700" text-anchor="middle">پایان مسیر</text>
</g>
<rect x="690" y="724" width="1120" height="145" rx="9" fill="#f8fafd" stroke="#dfe5ee"/><text x="1775" y="755" class="t dark" font-size="13" font-weight="700" text-anchor="end">قواعد مسیر</text>
<g class="t muted" font-size="11" text-anchor="end"><text x="1775" y="790">• شروع مسیر پس از ثبت قطعی سند و کنترل Company/Branch</text><text x="1775" y="819">• رد یا برگشت سند فقط همراه با ثبت علت و رویداد حسابرسی</text><text x="1775" y="848">• تغییر مسیر روی درخواست‌های جاری اثر ندارد و نسخه جدید ایجاد می‌کند</text></g>
"@

$accessBody = @"
<rect y="303" width="1920" height="65" fill="#f8fafd"/>
<rect x="1650" y="315" width="210" height="40" rx="9" fill="#155bd7"/><text x="1838" y="341" class="t" fill="#fff" font-size="12" font-weight="700" text-anchor="end">+ افزودن عضویت کاربر</text>
<rect x="70" y="386" width="1780" height="592" rx="10" class="card"/>
<rect x="86" y="402" width="1748" height="43" rx="7" fill="#f8fafd"/>
<g class="t dark" font-size="12" font-weight="700" text-anchor="middle"><text x="1710" y="428">کاربر</text><text x="1425" y="428">نقش</text><text x="1165" y="428">Company</text><text x="890" y="428">Branch</text><text x="610" y="428">سطح کارتابل</text><text x="315" y="428">وضعیت</text></g>
<g class="t dark" font-size="13" text-anchor="middle">
 <rect x="86" y="459" width="1748" height="78" rx="8" fill="#edf3ff" stroke="#a9c7ff"/><circle cx="1785" cy="498" r="20" fill="#dce9ff"/><text x="1785" y="504" fill="#155bd7" font-weight="800">م</text><text x="1745" y="491" font-weight="700" text-anchor="end">مدیر هلدینگ</text><text x="1745" y="511" class="muted" font-size="10" text-anchor="end">holding.manager@asoud.ir</text><text x="1425" y="498">مدیر هلدینگ</text><text x="1165" y="498">همه شرکت‌ها</text><text x="890" y="498">همه شعب</text><text x="610" y="498">مشاهده و تأیید کامل</text><rect x="275" y="484" width="80" height="28" rx="14" fill="#e9f8f0"/><text x="315" y="503" fill="#168a56" font-size="12">فعال</text>
 <text x="1710" y="582" font-weight="700">مدیر شرکت آسود</text><text x="1425" y="582">مدیر شرکت</text><text x="1165" y="582">شرکت آسود</text><text x="890" y="582">همه شعب</text><text x="610" y="582">تأیید سطح شرکت</text><rect x="275" y="568" width="80" height="28" rx="14" fill="#e9f8f0"/><text x="315" y="587" fill="#168a56" font-size="12">فعال</text>
 <line x1="86" y1="615" x2="1834" y2="615" class="line"/><text x="1710" y="662" font-weight="700">مدیر شعبه مرکزی</text><text x="1425" y="662">مدیر شعبه</text><text x="1165" y="662">شرکت آسود</text><text x="890" y="662">دفتر مرکزی</text><text x="610" y="662">تأیید سطح شعبه</text><rect x="275" y="648" width="80" height="28" rx="14" fill="#e9f8f0"/><text x="315" y="667" fill="#168a56" font-size="12">فعال</text>
 <line x1="86" y1="695" x2="1834" y2="695" class="line"/><text x="1710" y="742" font-weight="700">حسابدار محدود</text><text x="1425" y="742">حسابدار</text><text x="1165" y="742">شرکت آسود</text><text x="890" y="742">دفتر مرکزی</text><text x="610" y="742">ارسال و مشاهده شخصی</text><rect x="275" y="728" width="80" height="28" rx="14" fill="#fff2d8"/><text x="315" y="747" fill="#b66a00" font-size="12">محدود</text>
</g>
<rect x="112" y="820" width="1696" height="92" rx="9" fill="#f8fafd" stroke="#dfe5ee"/><text x="1775" y="850" class="t dark" font-size="13" font-weight="700" text-anchor="end">اصل دسترسی مؤثر</text><text x="1775" y="880" class="t muted" font-size="11" text-anchor="end">دسترسی هر کاربر از ترکیب عضویت Company، شعبه فعال، نقش و مجوز سند محاسبه می‌شود؛ هیچ دسترسی بین شرکت‌ها به‌صورت ضمنی منتقل نمی‌شود.</text>
"@

$pages = @(
    @{ File = 'asoud-cartable-sent-v1.svg'; Tab = 'sent'; Title = 'ارسالی‌های من'; Subtitle = 'درخواست‌هایی که برای بررسی و تأیید دیگران ارسال کرده‌اید'; Body = $sentBody },
    @{ File = 'asoud-cartable-history-v1.svg'; Tab = 'history'; Title = 'تاریخچه کارتابل'; Subtitle = 'ردپای کامل ارسال، تأیید، برگشت و تغییر مرحله درخواست‌ها'; Body = $historyBody },
    @{ File = 'asoud-cartable-approval-routes-v1.svg'; Tab = 'routes'; Title = 'مسیرهای تأیید'; Subtitle = 'تعریف و مشاهده گردش‌های تأیید نسخه‌دار برای اسناد سازمان'; Body = $routesBody },
    @{ File = 'asoud-cartable-user-access-v1.svg'; Tab = 'access'; Title = 'کاربران و دسترسی'; Subtitle = 'کنترل عضویت، نقش و دامنه دسترسی کارتابل در سطح شرکت و شعبه'; Body = $accessBody }
)

foreach ($page in $pages) {
    $svg = (Get-Shell $page.Tab $page.Title $page.Subtitle) + $page.Body + (Get-Footer)
    [System.IO.File]::WriteAllText((Join-Path $outDir $page.File), $svg, [System.Text.UTF8Encoding]::new($false))
}

Write-Output "Generated $($pages.Count) SVG files in $outDir"
