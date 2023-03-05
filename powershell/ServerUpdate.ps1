#html url
$url = 'http://localhost:8080/'

#html code
$htmlCode = @"    
<!DOCTYPE html> <html> <body>
<h1>PowerShell Web Server</h1>
<p>Example Web Server with Http Listener</p>
</body> </html>
"@

# start basic web server
$htmlListener = New-Object System.Net.HttpListener
$htmlListener.Prefixes.Add($url)
$htmlListener.Start()

Write-Host "Listening on $url"

try {
  while ($true) {
    # process html request
    $httpContext = $htmlListener.GetContext()

    $httpRequest = $httpContext.Request
    $httpResponse = $httpContext.Response

    # show the HTML code/page to the caller
    $url = $httpRequest.RawUrl
    $method = $httpRequest.HttpMethod

    if ($url -eq '/quit') {
      Throw 'Server stopped'
    }

    if ($url -eq '/execute' -and $method -eq 'POST') {
      # get the body of the request
      $buffer = New-Object Byte[] $httpRequest.ContentLength64
      $httpRequest.InputStream.Read($buffer, 0, $buffer.Length)
      $body = [System.Text.Encoding]::UTF8.GetString($buffer)
      $body = $body -replace '\r', ''
      $body = $body -replace '\n', ''

      # execute the command
      Write-Host "Executing: $body"
    }

    $httpResponse.OutputStream.Close()
  }
}
catch {
  Write-Error $_.Exception.Message
  $htmlListener.Stop()
}