# ▶️ Setări imagine
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

# ▶️ Forțează TLS modern (evită erori de descărcare)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ▶️ Descarcă imaginea
Invoke-WebRequest $imageURL -OutFile $tempImagePath -ErrorAction Stop

# ▶️ Include Forms și Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ▶️ Blochează taste (Windows + Alt) și ascultă tasta C
Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class LowLevelKeyboardHook {
    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static event EventHandler OnCPressed;

    public static void SetHook() {
        _hookID = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0);
    }

    public static void RemoveHook() {
        UnhookWindowsHookEx(_hookID);
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);

            // Blochează taste: Windows (L/R), Alt (L/R)
            if (vkCode == 0x5B || vkCode == 0x5C || vkCode == 0xA4 || vkCode == 0xA5) {
                return (IntPtr)1;
            }

            // Dacă se apasă C
            if (vkCode == 0x43) {
                if (OnCPressed != null)
                    OnCPressed(null, EventArgs.Empty);
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }
}
"@

# ▶️ Afișează poza pe toate monitoarele
$screens = [System.Windows.Forms.Screen]::AllScreens
$forms = @()

foreach ($screen in $screens) {
    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = 'Maximized'
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.StartPosition = 'Manual'
    $form.Location = $screen.Bounds.Location
    $form.Size = $screen.Bounds.Size
    $form.KeyPreview = $true
    $form.BackColor = "Black"
    $form.Cursor = [System.Windows.Forms.Cursors]::None

    $img = [System.Drawing.Image]::FromFile($tempImagePath)
    $pb = New-Object System.Windows.Forms.PictureBox
    $pb.Image = $img
    $pb.Dock = 'Fill'
    $pb.SizeMode = 'StretchImage'
    $form.Controls.Add($pb)

    $forms += $form
}

# ▶️ Închidere la tasta C
[LowLevelKeyboardHook]::OnCPressed.Add({
    [LowLevelKeyboardHook]::RemoveHook()
    [System.Windows.Forms.Application]::Exit()
})

# ▶️ Activare hook
[LowLevelKeyboardHook]::SetHook()

# ▶️ Arată toate ferestrele
foreach ($f in $forms) { $f.Show() }
[System.Windows.Forms.Application]::Run()
