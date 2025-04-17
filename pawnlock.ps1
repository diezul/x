# =============================
# PawnshopLock v6.1 - Debug Mode
# =============================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- CONFIGURATION ---
$imageURL = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID   = '656189986'
$rawURL   = 'https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1'

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("PawnshopLock script STARTED on $env:COMPUTERNAME", "DEBUG MODE")

# --- TELEGRAM TEST ---
function Send-TG($msg) {
    try {
        $body = @{ chat_id = $chatID; text = $msg } | ConvertTo-Json -Compress
        Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" `
            -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 10
    } catch {
        Write-Host "Failed to send Telegram message"
    }
}

Send-TG "DEBUG: PawnshopLock script has launched on $env:COMPUTERNAME ($env:USERNAME)"

# END (temporary, just to verify launch)
Start-Sleep -Seconds 10
