param(
    [Parameter(Mandatory)]
    [string]$Ip
)

#Abre la conexión TCP
$cliente = [System.Net.Sockets.TcpClient]::new()

$cliente.ReceiveTimeout = 5000
$cliente.SendTimeout = 5000
$cliente.Connect($Ip,8080)

$flujo = $cliente.GetStream()

#Envía BAD\r\n\r\n
$peticion = [System.Text.Encoding]::ASCII.GetBytes(
    "BAD`r`n`r`n"
)

$flujo.Write($peticion,0,$peticion.Length)
$flujo.Flush()

#Lee la respuesta
$lector = [System.IO.StreamReader]::new(
    $flujo,
    [System.Text.Encoding]::UTF8,
    $false,
    1024,
    $true
)

$respuesta = $lector.ReadToEnd()

$lector.Dispose()
$flujo.Dispose()
$cliente.Dispose()

#Muestra la respuesta recibida
$respuesta
