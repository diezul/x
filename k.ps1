Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod nativ pentru input și taskbar
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

# ▶️ TRIMITE MESAJ PE TELEGRAM
$pcName = $env:COMPUTERNAME
$message = "PC-ul $pcName din amanet este protejat."

$uri = 'https://api.telegram.org/bot7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co/sendMessage'
$body = @{
    'chat_id' = '656189986'
    'text'    = $message
} | ConvertTo-Json -Compress

try {
    Invoke-RestMethod -Uri $uri -Method POST -Body $body -ContentType 'application/json'
} catch {
    # Nu afișăm eroarea, doar continuăm
}

# ▶️ ASCUNDE TASKBAR
$taskbar = [Native]::FindWindow("Shell_TrayWnd", "")
[Native]::ShowWindow($taskbar, 0)

# ▶️ BLOCHEAZĂ INPUT
[Native]::BlockInput($true)

# ▶️ DESCARCĂ POZA
$temp = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $temp -UseBasicParsing

# ▶️ CALCULEAZĂ DIMENSIUNE TOTALĂ A MONITOARELOR
$bounds = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.Bounds }
$minX = ($bounds | ForEach-Object { $_.X }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$minY = ($bounds | ForEach-Object { $_.Y }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$maxRight = ($bounds | ForEach-Object { $_.Right }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$maxBottom = ($bounds | ForEach-Object { $_.Bottom }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$width = $maxRight - $minX
$height = $maxBottom - $minY

# ▶️ VARIABILĂ DE CONTROL
$script:inchis = $false

# ▶️ CREARE FEREASTRĂ URIAȘĂ PESTE TOATE MONITOARELE
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

# ▶️ IEȘIRE LA C
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        $script:inchis = $true
        $form.Close()
    }
})

# ▶️ PREVINE ÎNCHIDEREA MANUALĂ
$form.Add_FormClosing({
    if (-not $script:inchis) { $_.Cancel = $true }
})

# ▶️ ARATĂ ȘI RULEAZĂ
$form.Show()
[System.Windows.Forms.Application]::Run($form)

# ▶️ DEBLOCHEAZĂ INPUT LA IEȘIRE
[Native]::BlockInput($false)
[Native]::ShowWindow($taskbar, 1)
