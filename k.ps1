Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$temp = "$env:TEMP\poza.jpg"
Invoke-WebRequest "https://raw.githubusercontent.com/diezul/x/main/1.jpg" -OutFile $temp -UseBasicParsing

$form = New-Object Windows.Forms.Form
$form.WindowState = 'Maximized'
$form.FormBorderStyle = 'None'
$form.TopMost = $true
$form.KeyPreview = $true

$pb = New-Object Windows.Forms.PictureBox
$pb.Dock = 'Fill'
$pb.SizeMode = 'Zoom'
$pb.Image = [System.Drawing.Image]::FromFile($temp)
$form.Controls.Add($pb)

$form.Add_KeyDown({
    if ($_.KeyCode -eq 'C') { $form.Close() }
})

$form.ShowDialog()
