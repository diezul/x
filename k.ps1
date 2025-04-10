Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod pt blocare input
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

# Blochează input
[NativeMethods]::BlockInput($true)

# Descarcă poza
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Variabilă globală pt ieșire
$script:inchidereCeruta = $false
$forme = @()

# Funcție pt crearea unei ferestre pe un ecran
function AfiseazaPozaPeEcran {
    param($bounds)

    $form = New-Object Windows.Forms.Form
    $form.StartPosition = 'Manual'
    $form.Bounds = $bounds
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.BackColor = 'Black'
    $form.KeyPreview = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::None

    $pictureBox = New-Object Windows.Forms.PictureBox
    $pictureBox.ImageLocation = $tempImage
    $pictureBox.SizeMode = 'Zoom'
    $pictureBox.Dock = 'Fill'
    $form.Controls.Add($pictureBox)

    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') {
            $script:inchidereCeruta = $true
        }
    })

    $form.Add_FormClosing({
        if (-not $script:inchidereCeruta) {
            $_.Cancel = $true
        }
    })

    $forme += $form
    [System.Windows.Forms.Application]::Run($form)
}

# Rulează câte o fereastră pe fiecare monitor, dar sincron (nu cu thread)
foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $job = Start-Job -ScriptBlock {
        param($bounds, $imagePath)

        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $form = New-Object Windows.Forms.Form
        $form.StartPosition = 'Manual'
        $form.Bounds = $bounds
        $form.FormBorderStyle = 'None'
        $form.TopMost = $true
        $form.ShowInTaskbar = $false
        $form.BackColor = 'Black'
        $form.KeyPreview = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::None

        $pictureBox = New-Object Windows.Forms.PictureBox
        $pictureBox.ImageLocation = $imagePath
        $pictureBox.SizeMode = 'Zoom'
        $pictureBox.Dock = 'Fill'
        $form.Controls.Add($pictureBox)

        $form.Add_KeyDown({
            if ($_.KeyCode -eq 'C') {
                $form.Close()
            }
        })

        [System.Windows.Forms.Application]::Run($form)

    } -ArgumentList $screen.Bounds, $tempImage

    Start-Sleep -Milliseconds 500
}

# Așteaptă apăsarea tastei C global
do {
    Start-Sleep -Milliseconds 300
} until ($script:inchidereCeruta)

# Închide totul
foreach ($f in $forme) {
    try { $f.Invoke([Action]{ $f.Close() }) } catch {}
}
[NativeMethods]::BlockInput($false)
[NativeMethods]::ShowWindow($taskbar, 1)
