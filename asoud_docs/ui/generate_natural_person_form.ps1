$ErrorActionPreference='Stop'
$dir=(Get-Location).Path
$source=Get-Content -LiteralPath (Join-Path $dir 'asoud-companies-with-create-form-v1.svg') -Raw -Encoding UTF8
$source=$source.Replace('شرکت‌ها</text>','اشخاص و شرکت‌ها</text>')
$source=$source.Replace('ثبت شرکت جدید</text>','ثبت شخص حقیقی</text>')
$oldPattern='<rect x="92" y="402"[\s\S]*?<rect x="92" y="642"'
$newBlock=@'
<rect x="92" y="402" width="558" height="228" rx="9" fill="#fff" stroke="#a9c7ff"/>
<rect x="376" y="414" width="262" height="34" rx="7" fill="#155bd7"/><text x="507" y="436" class="t" fill="#fff" font-size="11" font-weight="700" text-anchor="middle">شخص حقیقی</text>
<rect x="104" y="414" width="262" height="34" rx="7" fill="#f8fafd" stroke="#dfe5ee"/><text x="235" y="436" class="t d" font-size="11" text-anchor="middle">شخصیت حقوقی</text>
<text x="625" y="468" class="t m" font-size="9" text-anchor="end">نام *</text><rect x="381" y="478" width="269" height="34" rx="7" fill="#f8fafd" stroke="#dfe5ee"/><text x="625" y="500" class="t d" font-size="11" font-weight="600" text-anchor="end">محمد</text>
<text x="358" y="468" class="t m" font-size="9" text-anchor="end">نام خانوادگی *</text><rect x="92" y="478" width="269" height="34" rx="7" fill="#f8fafd" stroke="#dfe5ee"/><text x="336" y="500" class="t d" font-size="11" font-weight="600" text-anchor="end">رضایی</text>
<text x="625" y="532" class="t m" font-size="9" text-anchor="end">کد ملی *</text><rect x="381" y="542" width="269" height="34" rx="7" fill="#f8fafd" stroke="#dfe5ee"/><text x="625" y="564" class="t d" font-size="11" text-anchor="end">۰۰۱۲۳۴۵۶۷۸</text>
<text x="358" y="532" class="t m" font-size="9" text-anchor="end">تاریخ تولد</text><rect x="92" y="542" width="269" height="34" rx="7" fill="#f8fafd" stroke="#dfe5ee"/><text x="336" y="564" class="t d" font-size="11" text-anchor="end">۱۳۶۵/۰۲/۱۵</text>
<text x="625" y="596" class="t m" font-size="9" text-anchor="end">نوع فعالیت</text><rect x="381" y="606" width="269" height="24" rx="7" fill="#f8fafd" stroke="#dfe5ee"/><text x="625" y="623" class="t d" font-size="9" text-anchor="end">بازرگانی و خدمات⌄</text>
<rect x="323" y="611" width="14" height="14" rx="3" fill="#fff" stroke="#155bd7"/><text x="310" y="623" class="t d" font-size="9" text-anchor="end">این شخص صاحب یا مدیر دفتر است</text>
<rect x="92" y="642"
'@
$source=[regex]::Replace($source,$oldPattern,$newBlock)
[IO.File]::WriteAllText((Join-Path $dir 'asoud-natural-person-with-create-form-v1.svg'),$source,[Text.UTF8Encoding]::new($false))
Write-Output 'Generated natural-person registration state.'
