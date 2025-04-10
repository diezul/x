Add-Type -AssemblyName PresentationFramework, System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class InputBlocker {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# Funcție pentru descărcarea și salvarea pozei temporar
$tempImagePath = "$env:TEMP\componenta_laptop.jpg"
Invoke-WebRequest -Uri "https://github.com/diezul/x/blob/main/1.jpg?raw=true" -OutFile $tempImagePath

# Blochează input-ul
[InputBlocker]::BlockInput($true)

# Creați fereastra WPF
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        WindowStyle="None" 
        ResizeMode="NoResize"
        WindowState="Maximized"
        Topmost="True"
        Background="Black"
        KeyDown="Window_KeyDown"
        ShowInTaskbar="False"
        Cursor="None">
    <Grid>
        <Image Source="$tempImagePath" Stretch="Uniform"/>
    </Grid>
</Window>
"@

# Funcție care închide fereastra dacă se apasă C
$code = @"
using System.Windows;
using System.Windows.Input;

public partial class Window : Window {
    public Window() {
        InitializeComponent();
    }
    private void Window_KeyDown(object sender, KeyEventArgs e) {
        if (e.Key == Key.C) {
            this.Close();
        }
    }
}
"@

Add-Type -ReferencedAssemblies PresentationFramework -TypeDefinition $code -Language CSharp

# Încarcă fereastra și o afișează
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Când se închide fereastra, deblochează input-ul
$window.Add_Closed({
    [InputBlocker]::BlockInput($false)
})

$window.ShowDialog()
