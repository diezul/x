Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Descarcă poza dacă nu există deja
$tempImage = "$env:TEMP\poza_laptop.jpg"
if (-not (Test-Path $tempImage)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $tempImage
}

# Blochează mouse și tastatură
[InputBlocker]::BlockInput($true)

# Creează fereastra
$form = New-Object Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.BackColor = 'Black'
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::None

# Imaginea
$pictureBox = New-Object Windows.Forms.PictureBox
$pictureBox.ImageLocation = $tempImage
$pictureBox.SizeMode = 'Zoom'
$pictureBox.Dock = 'Fill'
$form.Controls.Add($pictureBox)

# Deblochează doar la apăsarea tastei C
$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') {
        [InputBlocker]::BlockInput($false)
        $form.Close()
    }
})

# Arată fereastra
$form.ShowDialog()
