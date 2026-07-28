$ErrorActionPreference = 'Stop'
$dir = (Get-Location).Path
$base = Get-Content -LiteralPath (Join-Path $dir 'asoud-financial-settings-general-v1.svg') -Raw -Encoding UTF8
$shell = $base.Substring(0, $base.IndexOf('<!-- page header and local tabs -->'))

$tabs = @(
    @{ Key = 'general'; Label = 'عمومی'; X = 1770; Width = 140 },
    @{ Key = 'periods'; Label = 'سال مالی و دوره‌ها'; X = 1600; Width = 165 },
    @{ Key = 'coa'; Label = 'نمودار حساب‌ها'; X = 1410; Width = 145 },
    @{ Key = 'dimensions'; Label = 'ابعاد حسابداری'; X = 1220; Width = 160 },
    @{ Key = 'defaults'; Label = 'حساب‌های پیش‌فرض'; X = 1015; Width = 180 },
    @{ Key = 'closing'; Label = 'اختتامیه و افتتاحیه'; X = 790; Width = 185 }
)

function New-PageHeader([string]$active, [string]$subtitle, [string]$primaryAction) {
    $tabText = ''
    $underline = ''
    foreach ($tab in $tabs) {
        $selected = $tab.Key -eq $active
        $fill = if ($selected) { ' fill="#155bd7" font-weight="700"' } else { '' }
        $tabText += "<text x='$($tab.X)' y='286'$fill>$($tab.Label)</text>"
        if ($selected) {
            $underlineX = [int]($tab.X - ($tab.Width / 2))
            $underline = "<rect x='$underlineX' y='302' width='$($tab.Width)' height='3' rx='1.5' fill='#155bd7'/>"
        }
    }
    return @"
<!-- page header and local tabs -->
<rect y="182" width="1920" height="123" fill="#fff"/>
<text x="1848" y="222" class="t dark" font-size="26" font-weight="800" text-anchor="end">تنظیمات مالی</text>
<text x="1848" y="245" class="t muted" font-size="12" text-anchor="end">$subtitle</text>
<rect x="72" y="205" width="145" height="42" rx="8" fill="#155bd7"/><text x="197" y="231" class="t" fill="#fff" font-size="12" font-weight="700" text-anchor="end">$primaryAction</text>
<rect x="229" y="205" width="102" height="42" rx="8" fill="#fff" stroke="#b9c7dc"/><text x="309" y="231" class="t dark" font-size="12" text-anchor="end">انصراف</text>
<g class="t dark" font-size="13" text-anchor="middle">$tabText</g>
$underline
"@
}

function New-Sidebar([string]$title, [string]$status, [string]$detail, [string]$metric1, [string]$value1, [string]$metric2, [string]$value2, [string]$note) {
    return @"
<!-- contextual sidebar -->
<rect x="70" y="327" width="350" height="650" rx="10" class="card"/>
<text x="390" y="365" class="t dark" font-size="16" font-weight="800" text-anchor="end">$title</text>
<circle cx="115" cy="405" r="22" fill="#e9f8f0"/><path d="M105 405l7 7 13-17" fill="none" stroke="#168a56" stroke-width="2.5"/>
<text x="385" y="399" class="t dark" font-size="14" font-weight="700" text-anchor="end">$status</text>
<text x="385" y="420" class="t muted" font-size="10" text-anchor="end">$detail</text>
<line x1="92" y1="447" x2="398" y2="447" stroke="#dfe5ee"/>
<text x="390" y="481" class="t dark" font-size="13" font-weight="700" text-anchor="end">خلاصه کنترل</text>
<text x="390" y="520" class="t muted" font-size="11" text-anchor="end">$metric1</text><text x="98" y="520" class="t dark" font-size="12" font-weight="700">$value1</text>
<text x="390" y="558" class="t muted" font-size="11" text-anchor="end">$metric2</text><text x="98" y="558" class="t dark" font-size="12" font-weight="700">$value2</text>
<rect x="92" y="622" width="306" height="130" rx="9" fill="#edf3ff"/>
<text x="375" y="652" class="t dark" font-size="12" font-weight="700" text-anchor="end">نکته کنترلی</text>
<foreignObject x="112" y="670" width="266" height="62"><div xmlns="http://www.w3.org/1999/xhtml" dir="rtl" style="font-family:Tahoma,sans-serif;font-size:10px;line-height:1.9;color:#64748b">$note</div></foreignObject>
"@
}

function Save-Svg([string]$file, [string]$active, [string]$subtitle, [string]$action, [string]$sidebar, [string]$body) {
    $header = New-PageHeader $active $subtitle $action
    $footer = "<text x='960' y='1058' class='t muted' font-size='10' text-anchor='middle'>ASOUD ERP — Financial Settings / $active v1 — پوسته اصلی ثابت است</text></svg>"
    [IO.File]::WriteAllText(
        (Join-Path $dir $file),
        $shell + $header + $sidebar + $body + $footer,
        [Text.UTF8Encoding]::new($false)
    )
}

$periodSidebar = New-Sidebar 'وضعیت سال مالی' 'سال ۱۴۰۵ فعال است' '۱۲ دوره ماهانه ایجاد شده' 'دوره جاری' 'تیر ۱۴۰۵' 'دوره‌های قفل‌شده' '۳ دوره' 'تغییر تاریخ سال مالی پس از ثبت سند ممنوع است. بازگشایی دوره فقط با مجوز ویژه، ثبت دلیل و رویداد حسابرسی انجام می‌شود.'
$periodBody = @"
<rect x="440" y="327" width="1410" height="650" rx="10" class="card"/>
<text x="1815" y="365" class="t dark" font-size="17" font-weight="800" text-anchor="end">سال مالی و دوره‌ها</text>
<text x="1815" y="387" class="t muted" font-size="11" text-anchor="end">تقویم مالی مستقل Company و کنترل وضعیت هر دوره</text>
<rect x="470" y="412" width="1350" height="118" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="443" class="t dark" font-size="13" font-weight="800" text-anchor="end">سال مالی فعال</text>
<text x="1785" y="474" class="label" text-anchor="end">عنوان</text><rect x="1435" y="486" width="350" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="1758" y="511" class="value" text-anchor="end">سال مالی ۱۴۰۵⌄</text>
<text x="1390" y="474" class="label" text-anchor="end">تاریخ شروع</text><rect x="1040" y="486" width="350" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="1363" y="511" class="value" text-anchor="end">۱۴۰۵/۰۱/۰۱</text>
<text x="995" y="474" class="label" text-anchor="end">تاریخ پایان</text><rect x="645" y="486" width="350" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="968" y="511" class="value" text-anchor="end">۱۴۰۵/۱۲/۲۹</text>
<text x="600" y="474" class="label" text-anchor="end">الگوی دوره</text><rect x="495" y="486" width="105" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="575" y="511" class="value" text-anchor="end">ماهانه⌄</text>
<text x="1815" y="570" class="t dark" font-size="14" font-weight="800" text-anchor="end">دوره‌های مالی</text>
<rect x="470" y="588" width="1350" height="46" rx="7" fill="#edf3ff"/>
<g class="t dark" font-size="11" font-weight="700" text-anchor="end"><text x="1780" y="617">دوره</text><text x="1540" y="617">بازه</text><text x="1240" y="617">وضعیت ثبت</text><text x="980" y="617">شماره‌گذاری</text><text x="720" y="617">عملیات</text></g>
<g class="t dark" font-size="11" text-anchor="end">
 <rect x="470" y="642" width="1350" height="54" fill="#fff" stroke="#eef1f5"/><text x="1780" y="674">فروردین ۱۴۰۵</text><text x="1540" y="674">۰۱/۰۱ تا ۰۱/۳۱</text><text x="1240" y="674" fill="#168a56">بسته و تأییدشده</text><text x="980" y="674">قطعی</text><text x="720" y="674" fill="#155bd7">مشاهده</text>
 <rect x="470" y="696" width="1350" height="54" fill="#fff" stroke="#eef1f5"/><text x="1780" y="728">اردیبهشت ۱۴۰۵</text><text x="1540" y="728">۰۲/۰۱ تا ۰۲/۳۱</text><text x="1240" y="728" fill="#168a56">بسته و تأییدشده</text><text x="980" y="728">قطعی</text><text x="720" y="728" fill="#155bd7">مشاهده</text>
 <rect x="470" y="750" width="1350" height="54" fill="#fff" stroke="#eef1f5"/><text x="1780" y="782">خرداد ۱۴۰۵</text><text x="1540" y="782">۰۳/۰۱ تا ۰۳/۳۱</text><text x="1240" y="782" fill="#168a56">قفل‌شده</text><text x="980" y="782">قطعی</text><text x="720" y="782" fill="#155bd7">درخواست بازگشایی</text>
 <rect x="470" y="804" width="1350" height="54" fill="#fff" stroke="#eef1f5"/><text x="1780" y="836">تیر ۱۴۰۵</text><text x="1540" y="836">۰۴/۰۱ تا ۰۴/۳۱</text><text x="1240" y="836" fill="#b54708">باز</text><text x="980" y="836">موقت</text><text x="720" y="836" fill="#155bd7">بستن دوره</text>
 <rect x="470" y="858" width="1350" height="54" fill="#fff" stroke="#eef1f5"/><text x="1780" y="890">مرداد ۱۴۰۵</text><text x="1540" y="890">۰۵/۰۱ تا ۰۵/۳۱</text><text x="1240" y="890" fill="#64748b">آینده</text><text x="980" y="890">—</text><text x="720" y="890" fill="#64748b">—</text>
</g>
"@
Save-Svg 'asoud-financial-settings-periods-v1.svg' 'periods' 'تعریف سال مالی مستقل، دوره‌های ماهانه و کنترل باز یا قفل بودن هر بازه' '+ سال مالی جدید' $periodSidebar $periodBody

$coaSidebar = New-Sidebar 'وضعیت نمودار' 'الگو نصب شده است' 'نسخه ۱.۰ • عمومی ایران' 'تعداد حساب‌ها' '۹۶ حساب' 'حساب‌های بدون نگاشت' '۰ مورد' 'پس از ثبت گردش مالی، حذف یا تغییر ماهیت حساب ممنوع است. اصلاح ساختار از طریق نسخه جدید و نگاشت کنترل‌شده انجام می‌شود.'
$coaBody = @"
<rect x="440" y="327" width="1410" height="650" rx="10" class="card"/>
<text x="1815" y="365" class="t dark" font-size="17" font-weight="800" text-anchor="end">نمودار حساب‌ها</text>
<text x="1815" y="387" class="t muted" font-size="11" text-anchor="end">ساختار کدینگ چندسطحی، نسخه‌دار و مستقل برای Company</text>
<rect x="470" y="412" width="1350" height="58" rx="8" fill="#f8fafd" stroke="#dfe5ee"/>
<rect x="1510" y="423" width="275" height="36" rx="7" fill="#fff" stroke="#d6deea"/><text x="1760" y="446" class="t muted" font-size="10" text-anchor="end">جست‌وجوی کد یا عنوان حساب...</text>
<rect x="1360" y="423" width="132" height="36" rx="7" fill="#fff" stroke="#b9c7dc"/><text x="1472" y="446" class="t dark" font-size="11" text-anchor="end">سطح: همه⌄</text>
<rect x="1210" y="423" width="132" height="36" rx="7" fill="#fff" stroke="#b9c7dc"/><text x="1322" y="446" class="t dark" font-size="11" text-anchor="end">ماهیت: همه⌄</text>
<text x="500" y="446" class="t" fill="#155bd7" font-size="11">ورود از الگو</text>
<rect x="470" y="486" width="1350" height="46" rx="7" fill="#edf3ff"/>
<g class="t dark" font-size="11" font-weight="700" text-anchor="end"><text x="1780" y="515">کد حساب</text><text x="1560" y="515">عنوان</text><text x="1170" y="515">گروه اصلی</text><text x="900" y="515">ماهیت</text><text x="660" y="515">نوع</text></g>
<g class="t dark" font-size="11" text-anchor="end">
 <rect x="470" y="540" width="1350" height="52" fill="#fff" stroke="#eef1f5"/><text x="1780" y="571" font-weight="800">۱</text><text x="1560" y="571" font-weight="800">دارایی‌ها</text><text x="1170" y="571">دارایی</text><text x="900" y="571">بدهکار</text><text x="660" y="571">گروه</text>
 <rect x="470" y="592" width="1350" height="52" fill="#fff" stroke="#eef1f5"/><text x="1745" y="623">۱۱</text><text x="1525" y="623">دارایی‌های جاری</text><text x="1170" y="623">دارایی</text><text x="900" y="623">بدهکار</text><text x="660" y="623">گروه</text>
 <rect x="470" y="644" width="1350" height="52" fill="#fff" stroke="#eef1f5"/><text x="1710" y="675">۱۱۱</text><text x="1490" y="675">موجودی نقد و بانک</text><text x="1170" y="675">دارایی</text><text x="900" y="675">بدهکار</text><text x="660" y="675">گروه</text>
 <rect x="470" y="696" width="1350" height="52" fill="#fff" stroke="#eef1f5"/><text x="1675" y="727">۱۱۱۰۰۱</text><text x="1455" y="727">صندوق اصلی</text><text x="1170" y="727">دارایی</text><text x="900" y="727">بدهکار</text><text x="660" y="727" fill="#155bd7">صندوق</text>
 <rect x="470" y="748" width="1350" height="52" fill="#fff" stroke="#eef1f5"/><text x="1675" y="779">۱۱۱۰۰۲</text><text x="1455" y="779">حساب‌های بانکی</text><text x="1170" y="779">دارایی</text><text x="900" y="779">بدهکار</text><text x="660" y="779" fill="#155bd7">بانک</text>
 <rect x="470" y="800" width="1350" height="52" fill="#fff" stroke="#eef1f5"/><text x="1675" y="831">۱۱۲۰۰۱</text><text x="1455" y="831">حساب‌های دریافتنی تجاری</text><text x="1170" y="831">دارایی</text><text x="900" y="831">بدهکار</text><text x="660" y="831" fill="#155bd7">دریافتنی</text>
 <rect x="470" y="852" width="1350" height="52" fill="#fff" stroke="#eef1f5"/><text x="1780" y="883" font-weight="800">۲</text><text x="1560" y="883" font-weight="800">بدهی‌ها</text><text x="1170" y="883">بدهی</text><text x="900" y="883">بستانکار</text><text x="660" y="883">گروه</text>
</g>
"@
Save-Svg 'asoud-financial-settings-coa-v1.svg' 'coa' 'مدیریت نمودار حساب‌های نسخه‌دار، سطوح کدینگ و ماهیت حساب‌ها' '+ حساب جدید' $coaSidebar $coaBody

$dimensionSidebar = New-Sidebar 'کنترل ابعاد' 'ابعاد اصلی فعال‌اند' 'تفصیلی شناور اجباری است' 'ابعاد فعال' '۴ بُعد' 'قواعد ناقص' '۱ مورد' 'ابعاد تحلیلی محتوای دفتر کل را تکرار نمی‌کنند؛ آن‌ها در هر سطر سند، بر اساس حساب و Company اعتبارسنجی می‌شوند.'
$dimensionBody = @"
<rect x="440" y="327" width="1410" height="650" rx="10" class="card"/>
<text x="1815" y="365" class="t dark" font-size="17" font-weight="800" text-anchor="end">ابعاد حسابداری</text>
<text x="1815" y="387" class="t muted" font-size="11" text-anchor="end">مرکز هزینه، پروژه، شعبه و تفصیلی شناور در سطح سطر سند</text>
<g class="t dark">
 <rect x="1160" y="420" width="660" height="210" rx="10" fill="#f8fafd" stroke="#dfe5ee"/>
 <circle cx="1780" cy="458" r="19" fill="#edf3ff"/><text x="1780" y="464" fill="#155bd7" font-size="12" font-weight="800" text-anchor="middle">ت</text>
 <text x="1748" y="455" font-size="14" font-weight="800" text-anchor="end">تفصیلی شناور</text><text x="1748" y="477" class="muted" font-size="10" text-anchor="end">مشتری، تأمین‌کننده، کارمند و سایر اشخاص</text>
 <rect x="1720" y="505" width="62" height="28" rx="14" fill="#155bd7"/><circle cx="1767" cy="519" r="11" fill="#fff"/><text x="1695" y="523" font-size="11" text-anchor="end">فعال و الزامی بر اساس قاعده حساب</text>
 <text x="1780" y="568" class="label" text-anchor="end">سطوح مجاز</text><rect x="1330" y="580" width="450" height="36" rx="7" fill="#fff" stroke="#d6deea"/><text x="1750" y="603" class="value" text-anchor="end">Customer، Supplier، Employee، Other⌄</text>

 <rect x="470" y="420" width="660" height="210" rx="10" fill="#f8fafd" stroke="#dfe5ee"/>
 <circle cx="1090" cy="458" r="19" fill="#edf3ff"/><text x="1090" y="464" fill="#155bd7" font-size="12" font-weight="800" text-anchor="middle">م</text>
 <text x="1058" y="455" font-size="14" font-weight="800" text-anchor="end">مرکز هزینه</text><text x="1058" y="477" class="muted" font-size="10" text-anchor="end">تحلیل سودآوری شعبه و واحد سازمانی</text>
 <rect x="1030" y="505" width="62" height="28" rx="14" fill="#155bd7"/><circle cx="1077" cy="519" r="11" fill="#fff"/><text x="1005" y="523" font-size="11" text-anchor="end">فعال • پیش‌فرض از Branch</text>
 <text x="1090" y="568" class="label" text-anchor="end">مقدار پیش‌فرض</text><rect x="640" y="580" width="450" height="36" rx="7" fill="#fff" stroke="#d6deea"/><text x="1060" y="603" class="value" text-anchor="end">مرکز هزینه دفتر مرکزی⌄</text>

 <rect x="1160" y="650" width="660" height="210" rx="10" fill="#f8fafd" stroke="#dfe5ee"/>
 <circle cx="1780" cy="688" r="19" fill="#edf3ff"/><text x="1780" y="694" fill="#155bd7" font-size="12" font-weight="800" text-anchor="middle">ش</text>
 <text x="1748" y="685" font-size="14" font-weight="800" text-anchor="end">شعبه</text><text x="1748" y="707" class="muted" font-size="10" text-anchor="end">بعد عملیاتی برای گزارش مستقل و تجمیعی</text>
 <rect x="1720" y="735" width="62" height="28" rx="14" fill="#155bd7"/><circle cx="1767" cy="749" r="11" fill="#fff"/><text x="1695" y="753" font-size="11" text-anchor="end">فعال • اجباری برای کاربران شعبه</text>
 <text x="1780" y="798" class="label" text-anchor="end">منبع مقدار</text><rect x="1330" y="810" width="450" height="36" rx="7" fill="#fff" stroke="#d6deea"/><text x="1750" y="833" class="value" text-anchor="end">Context فعال کاربر⌄</text>

 <rect x="470" y="650" width="660" height="210" rx="10" fill="#f8fafd" stroke="#dfe5ee"/>
 <circle cx="1090" cy="688" r="19" fill="#edf3ff"/><text x="1090" y="694" fill="#155bd7" font-size="12" font-weight="800" text-anchor="middle">پ</text>
 <text x="1058" y="685" font-size="14" font-weight="800" text-anchor="end">پروژه</text><text x="1058" y="707" class="muted" font-size="10" text-anchor="end">تحلیل درآمد و هزینه قرارداد یا پروژه</text>
 <rect x="1030" y="735" width="62" height="28" rx="14" fill="#cbd5e1"/><circle cx="1045" cy="749" r="11" fill="#fff"/><text x="1005" y="753" font-size="11" text-anchor="end">اختیاری • بر اساس نوع فعالیت</text>
 <text x="1090" y="798" class="label" text-anchor="end">حساب‌های مشمول</text><rect x="640" y="810" width="450" height="36" rx="7" fill="#fff" stroke="#d6deea"/><text x="1060" y="833" class="value" text-anchor="end">درآمد و هزینه پروژه⌄</text>
</g>
"@
Save-Svg 'asoud-financial-settings-dimensions-v1.svg' 'dimensions' 'تعریف ابعاد تحلیلی و قواعد الزام آن‌ها در اسناد حسابداری' '+ بُعد جدید' $dimensionSidebar $dimensionBody

$defaultsSidebar = New-Sidebar 'کامل بودن تنظیمات' '۱۰ حساب از ۱۲ حساب' 'دو حساب نیازمند تعیین است' 'حساب‌های ضروری' '۱۰ تکمیل' 'موارد هشدار' '۲ مورد' 'همه حساب‌های پیش‌فرض باید متعلق به Company، غیرگروهی و دارای ماهیت سازگار با کاربرد انتخاب‌شده باشند.'
$defaultsBody = @"
<rect x="440" y="327" width="1410" height="650" rx="10" class="card"/>
<text x="1815" y="365" class="t dark" font-size="17" font-weight="800" text-anchor="end">حساب‌های پیش‌فرض</text>
<text x="1815" y="387" class="t muted" font-size="11" text-anchor="end">حساب‌های کنترلی مورد استفاده در عملیات، خزانه‌داری و بستن سال</text>
<rect x="470" y="412" width="1350" height="154" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="443" class="t dark" font-size="13" font-weight="800" text-anchor="end">طرف‌حساب و عملیات</text>
<text x="1785" y="475" class="label" text-anchor="end">دریافتنی مشتریان</text><rect x="1435" y="487" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1758" y="512" class="value" text-anchor="end">۱۱۲۰۰۱ — دریافتنی تجاری⌄</text>
<text x="1390" y="475" class="label" text-anchor="end">پرداختنی تأمین‌کنندگان</text><rect x="1040" y="487" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1363" y="512" class="value" text-anchor="end">۲۱۱۰۰۱ — پرداختنی تجاری⌄</text>
<text x="995" y="475" class="label" text-anchor="end">درآمد پیش‌فرض</text><rect x="645" y="487" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="968" y="512" class="value" text-anchor="end">۴۱۰۰۰۱ — فروش کالا⌄</text>
<text x="600" y="475" class="label" text-anchor="end">هزینه پیش‌فرض</text><rect x="495" y="487" width="105" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="575" y="512" class="value" text-anchor="end">۵۱۰۰۰۱⌄</text>
<rect x="470" y="584" width="1350" height="154" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="615" class="t dark" font-size="13" font-weight="800" text-anchor="end">خزانه‌داری و تسویه</text>
<text x="1785" y="647" class="label" text-anchor="end">صندوق اصلی</text><rect x="1435" y="659" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1758" y="684" class="value" text-anchor="end">۱۱۱۰۰۱ — صندوق اصلی⌄</text>
<text x="1390" y="647" class="label" text-anchor="end">بانک پیش‌فرض</text><rect x="1040" y="659" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1363" y="684" class="value" text-anchor="end">۱۱۱۰۰۲ — بانک ملت⌄</text>
<text x="995" y="647" class="label" text-anchor="end">اسناد دریافتنی</text><rect x="645" y="659" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="968" y="684" class="value" text-anchor="end">۱۱۳۰۰۱ — چک‌های دریافتی⌄</text>
<text x="600" y="647" class="label" text-anchor="end">اسناد پرداختنی</text><rect x="495" y="659" width="105" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="575" y="684" class="value" text-anchor="end">۲۱۲۰۰۱⌄</text>
<rect x="470" y="756" width="1350" height="164" rx="9" fill="#fff8e8" stroke="#f0d49b"/>
<text x="1785" y="787" class="t dark" font-size="13" font-weight="800" text-anchor="end">کنترل سال و تلفیق</text>
<text x="1785" y="819" class="label" text-anchor="end">سود و زیان انباشته</text><rect x="1435" y="831" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1758" y="856" class="value" text-anchor="end">۳۱۰۰۰۱ — سود و زیان انباشته⌄</text>
<text x="1390" y="819" class="label" text-anchor="end">کنترل اختتامیه</text><rect x="1040" y="831" width="350" height="40" rx="8" fill="#fff" stroke="#d6deea"/><text x="1363" y="856" class="value" text-anchor="end">۹۱۰۰۰۱ — کنترل اختتامیه⌄</text>
<text x="995" y="819" class="label" text-anchor="end">کنترل افتتاحیه</text><rect x="645" y="831" width="350" height="40" rx="8" fill="#fff" stroke="#e5a93d"/><text x="968" y="856" class="value" fill="#b54708" text-anchor="end">انتخاب نشده است⌄</text>
<text x="600" y="819" class="label" text-anchor="end">اختلاف تلفیق</text><rect x="495" y="831" width="105" height="40" rx="8" fill="#fff" stroke="#e5a93d"/><text x="575" y="856" class="value" fill="#b54708" text-anchor="end">—⌄</text>
"@
Save-Svg 'asoud-financial-settings-default-accounts-v1.svg' 'defaults' 'تعیین حساب‌های پیش‌فرض هر Company با کنترل ماهیت و مالکیت حساب' 'ذخیره حساب‌ها' $defaultsSidebar $defaultsBody

$closingSidebar = New-Sidebar 'آمادگی بستن سال' 'کنترل اولیه موفق' '۲ هشدار غیرمسدودکننده' 'آخرین اجرای موفق' 'سال ۱۴۰۴' 'وضعیت سال ۱۴۰۵' 'آماده پیش‌بررسی' 'سند اختتامیه و افتتاحیه واقعی، شماره‌دار و مؤثر در دفتر کل ایجاد می‌شود. اجرای تکراری با کلید یکتا کنترل خواهد شد.'
$closingBody = @"
<rect x="440" y="327" width="1410" height="650" rx="10" class="card"/>
<text x="1815" y="365" class="t dark" font-size="17" font-weight="800" text-anchor="end">اختتامیه و افتتاحیه</text>
<text x="1815" y="387" class="t muted" font-size="11" text-anchor="end">پیش‌بررسی، ایجاد اسناد واقعی، تطبیق مانده و قفل نهایی سال</text>
<rect x="470" y="412" width="1350" height="88" rx="9" fill="#edf3ff"/>
<g class="t dark" text-anchor="middle">
 <circle cx="1650" cy="445" r="16" fill="#155bd7"/><text x="1650" y="451" fill="#fff" font-size="11">۱</text><text x="1650" y="480" font-size="11" font-weight="700">پیش‌بررسی</text>
 <line x1="1560" y1="445" x2="1370" y2="445" stroke="#8bb3f4" stroke-width="2"/>
 <circle cx="1280" cy="445" r="16" fill="#fff" stroke="#8bb3f4" stroke-width="2"/><text x="1280" y="451" fill="#155bd7" font-size="11">۲</text><text x="1280" y="480" font-size="11">سند اختتامیه</text>
 <line x1="1190" y1="445" x2="1000" y2="445" stroke="#cbd5e1" stroke-width="2"/>
 <circle cx="910" cy="445" r="16" fill="#fff" stroke="#cbd5e1" stroke-width="2"/><text x="910" y="451" class="muted" font-size="11">۳</text><text x="910" y="480" font-size="11">سند افتتاحیه</text>
 <line x1="820" y1="445" x2="630" y2="445" stroke="#cbd5e1" stroke-width="2"/>
 <circle cx="540" cy="445" r="16" fill="#fff" stroke="#cbd5e1" stroke-width="2"/><text x="540" y="451" class="muted" font-size="11">۴</text><text x="540" y="480" font-size="11">تطبیق و قفل</text>
</g>
<rect x="1160" y="520" width="660" height="235" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1785" y="553" class="t dark" font-size="13" font-weight="800" text-anchor="end">پارامترهای اجرا</text>
<text x="1785" y="589" class="label" text-anchor="end">سال مالی</text><rect x="1435" y="601" width="350" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="1758" y="626" class="value" text-anchor="end">سال مالی ۱۴۰۵⌄</text>
<text x="1390" y="589" class="label" text-anchor="end">تاریخ افتتاحیه</text><rect x="1190" y="601" width="200" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="1363" y="626" class="value" text-anchor="end">۱۴۰۶/۰۱/۰۱</text>
<text x="1785" y="665" class="label" text-anchor="end">حساب سود و زیان انباشته</text><rect x="1435" y="677" width="350" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="1758" y="702" class="value" text-anchor="end">۳۱۰۰۰۱ — سود و زیان انباشته⌄</text>
<text x="1390" y="665" class="label" text-anchor="end">روش اجرا</text><rect x="1190" y="677" width="200" height="38" rx="8" fill="#fff" stroke="#d6deea"/><text x="1363" y="702" class="value" text-anchor="end">واقعی و شماره‌دار⌄</text>
<rect x="470" y="520" width="660" height="235" rx="9" fill="#f8fafd" stroke="#dfe5ee"/>
<text x="1095" y="553" class="t dark" font-size="13" font-weight="800" text-anchor="end">نتیجه پیش‌بررسی</text>
<g class="t dark" font-size="11" text-anchor="end">
 <circle cx="1080" cy="590" r="8" fill="#168a56"/><path d="M1076 590l3 3 5-7" stroke="#fff" fill="none"/><text x="1058" y="594">تراز آزمایشی متوازن است</text>
 <circle cx="1080" cy="625" r="8" fill="#168a56"/><path d="M1076 625l3 3 5-7" stroke="#fff" fill="none"/><text x="1058" y="629">اسناد موقت تعیین تکلیف شده‌اند</text>
 <circle cx="1080" cy="660" r="8" fill="#e5a93d"/><text x="1080" y="664" fill="#fff" text-anchor="middle">!</text><text x="1058" y="664">۲ سند اصلاحی پس از تاریخ کنترل ثبت شده</text>
 <circle cx="1080" cy="695" r="8" fill="#168a56"/><path d="M1076 695l3 3 5-7" stroke="#fff" fill="none"/><text x="1058" y="699">سال مالی بعدی تعریف شده است</text>
</g>
<rect x="470" y="775" width="1350" height="142" rx="9" fill="#fff" stroke="#dfe5ee"/>
<text x="1785" y="808" class="t dark" font-size="13" font-weight="800" text-anchor="end">سوابق اجرا</text>
<rect x="495" y="827" width="1290" height="38" rx="6" fill="#f8fafd"/><text x="1755" y="852" class="t dark" font-size="11" font-weight="700" text-anchor="end">سال مالی ۱۴۰۴</text><text x="1460" y="852" class="t muted" font-size="11" text-anchor="end">بسته‌شده در ۱۴۰۵/۰۱/۰۵</text><text x="1100" y="852" class="t" fill="#168a56" font-size="11" text-anchor="end">تطبیق موفق</text><text x="720" y="852" class="t" fill="#155bd7" font-size="11" text-anchor="end">مشاهده اسناد</text>
<rect x="495" y="873" width="1290" height="38" rx="6" fill="#f8fafd"/><text x="1755" y="898" class="t dark" font-size="11" font-weight="700" text-anchor="end">سال مالی ۱۴۰۳</text><text x="1460" y="898" class="t muted" font-size="11" text-anchor="end">بسته‌شده در ۱۴۰۴/۰۱/۰۷</text><text x="1100" y="898" class="t" fill="#168a56" font-size="11" text-anchor="end">تطبیق موفق</text><text x="720" y="898" class="t" fill="#155bd7" font-size="11" text-anchor="end">مشاهده اسناد</text>
"@
Save-Svg 'asoud-financial-settings-closing-opening-v1.svg' 'closing' 'اجرای کنترل‌شده اختتامیه و افتتاحیه واقعی همراه با شماره‌گذاری و تطبیق' 'اجرای پیش‌بررسی' $closingSidebar $closingBody

Write-Output 'Generated five financial settings pages.'
