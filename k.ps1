Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod C# pentru blocare/deblocare input și taskbar
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

# Ascunde Taskbar
$taskbar = [NativeMethods]::FindWindow("Shell_TrayWnd", "")
[NativeMethods]::ShowWindow($taskbar, 0)

# Blochează input
[NativeMethods]::BlockInput($true)

# Descarcă poza (salvată temporar)
$tempImage = "$env:TEMP\poza_laptop.jpg"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage -UseBasicParsing

# Variabilă de control
$script:inchis = $false
$forms = @()

# Funcție de închidere
function InchideTot {
    [NativeMethods]::BlockInput($false)
    [NativeMethods]::ShowWindow($taskbar, 1)
    $script:inchis = $true
    foreach ($f in $forms) {
        try { $f.Invoke([Action]{ $f.Close() }) } catch {}
    }
}

# CREEAZĂ CÂTE O FEREASTRĂ PE FIECARE MONITOR
foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $form = New-Object Windows.Forms.Form
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.Bounds = $screen.Bounds
    $form.BackColor = 'Black'
    $form.KeyPreview = $true
    $form.ShowInTaskbar = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::None

    $pb = New-Object Windows.Forms.PictureBox
    $pb.ImageLocation = $tempImage
    $pb.SizeMode = 'Zoom'
    $pb.Dock = 'Fill'
    $form.Controls.Add($pb)

    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') {
            InchideTot
        }
    })

    $form.Add_FormClosing({
        if (-not $script:inchis) {
            $_.Cancel = $true
        }
    })

    $null = $form.Show()
    $forms += $form
}

# Blochează scriptul până se închide manual
while (-not $script:inchis) {
    Start-Sleep -Milliseconds 300
}
