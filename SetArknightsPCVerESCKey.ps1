# SetArknightsPCVerESCKey.ps1
# Version: 202602112356
Write-Host "=====欢迎使用Arknights 暂停快捷键修改脚本=====" -ForegroundColor Cyan
Write-Host "欢迎关注up主：Fer_Amiya 当前版本：202602112356" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""


$RegPath = "HKCU:\Software\Hypergryph\Arknights"
$ValueName = "KEYBOARD_SETTING_h2904437537"

# 步骤1：获取用户按键
Write-Host "请按下你想用于【ESC功能】的按键（按任意键即可）..." -ForegroundColor Cyan
$key = [System.Console]::ReadKey($true)
Write-Host "`n你按下了: $($key.Key)" -ForegroundColor Green

# 步骤2：转换为代号
function Convert-KeyToId {
    param([System.ConsoleKey]$Key)

    # 特殊映射
    $SpecialMap = @{
        'Escape' = 'bannedEscape'
        'Tab'    = 'keyTab'
        'Enter'  = 'keyEnter'
        'Spacebar' = 'keySpace'
        'Backspace' = 'keyBackspace'
        'LeftArrow' = 'keyLeft'
        'RightArrow' = 'keyRight'
        'UpArrow' = 'keyUp'
        'DownArrow' = 'keyDown'
        'Insert' = 'keyInsert'
        'Delete' = 'keyDelete'
        'Home' = 'keyHome'
        'End' = 'keyEnd'
        'PageUp' = 'keyPageUp'
        'PageDown' = 'keyPageDown'
        'F1' = 'keyF1'; 'F2' = 'keyF2'; 'F3' = 'keyF3'; 'F4' = 'keyF4'
        'F5' = 'keyF5'; 'F6' = 'keyF6'; 'F7' = 'keyF7'; 'F8' = 'keyF8'
        'F9' = 'keyF9'; 'F10' = 'keyF10'; 'F11' = 'keyF11'; 'F12' = 'keyF12'
    }

    if ($SpecialMap.ContainsKey($Key.ToString())) {
        return $SpecialMap[$Key.ToString()]
    }

    # 尝试字母 A-Z
    if ([int]$Key -ge [int][ConsoleKey]::A -and [int]$Key -le [int][ConsoleKey]::Z) {
        return "alpha$($Key.ToString())"
    }

    # 尝试数字 0-9（注意：ConsoleKey.D0 到 D9）
    if ([int]$Key -ge [int][ConsoleKey]::D0 -and [int]$Key -le [int][ConsoleKey]::D9) {
        $digit = [int]$Key - [int][ConsoleKey]::D0
        return "num$digit"
    }

    # 默认 fallback（不太可能触发）
    return "key$($Key.ToString())"
}

$KeyId = Convert-KeyToId -Key $key.Key
Write-Host "转换后的 keyId: $KeyId" -ForegroundColor Yellow

# 步骤3：读取注册表中的 hex 值
if (-not (Test-Path $RegPath)) {
    Write-Error "注册表路径不存在: $RegPath"
    exit 1
}

$regValue = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop
$hexBytes = $regValue.$ValueName

if ($null -eq $hexBytes -or $hexBytes.Count -eq 0) {
    Write-Error "注册表值 '$ValueName' 为空或不存在。"
    exit 1
}

# 步骤4：将 hex 转为 UTF-8 字符串（去掉末尾 \0）
# 找到最后一个非零字节（因为结尾有 00）
$len = $hexBytes.Count
while ($len -gt 0 -and $hexBytes[$len - 1] -eq 0) { $len-- }
if ($len -eq 0) { Write-Error "无效的注册表数据"; exit 1 }

$jsonBytes = $hexBytes[0..($len - 1)]
$jsonStr = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
Write-Host "原始 JSON:`n$jsonStr" -ForegroundColor Gray

# 步骤5：解析 JSON 并修改 ESC.keyId
try {
    $jsonObj = $jsonStr | ConvertFrom-Json
} catch {
    Write-Error "JSON 解析失败: $_"
    exit 1
}

if (-not $jsonObj.PSObject.Properties['ESC']) {
    Write-Error "JSON 中未找到 ESC 字段"
    exit 1
}

$jsonObj.ESC.keyId = $KeyId

$newJsonStr = $jsonObj | ConvertTo-Json -Compress
Write-Host "新 JSON:`n$newJsonStr" -ForegroundColor Green

# 步骤6：转回 hex（UTF-8 + 结尾 \0）
$newBytes = [System.Text.Encoding]::UTF8.GetBytes($newJsonStr)
$finalBytes = $newBytes + @(0)  # 添加 null terminator

# 步骤7：写回注册表
try {
    Set-ItemProperty -Path $RegPath -Name $ValueName -Value $finalBytes -Type Binary -Force
    Write-Host "✅ 已成功更新注册表！ESC 键已设为: $KeyId" -ForegroundColor Green
} catch {
    Write-Error "写入注册表失败: $_"
}