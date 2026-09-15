param(
    [Parameter(Mandatory)]
    [ValidateSet('base', 'linux')]
    [string]$Configuracion,

    [Parameter(Mandatory)]
    [ValidateRange(1,10)]
    [int]$Repeticion,

    [Parameter(Mandatory)]
    [ValidateSet(0, 1)]
    [int]$Qos,

    [Parameter(Mandatory)]
    [ValidateSet(1, 10)]
    [int]$Publicadores
)

$ip = $maquinas[$Configuracion].Ip
$nombre = "${Configuracion}_q${Qos}_p${Publicadores}_r${Repeticion}"
$mensajesTotales = 5000 * $Publicadores

$rutaPub = Join-Path $dirResultados "${nombre}_mqttx_pub.txt"
$rutaPubInfo = Join-Path $dirResultados "${nombre}_mqttx_info.txt"
$rutaSub = Join-Path $dirResultados "${nombre}_mosquitto_sub.txt"
$rutaSubErr = Join-Path $dirResultados "${nombre}_mosquitto_sub_error.txt"
$rutaResumen = Join-Path $dirResultados "${nombre}_resumen_mqtt.csv"

#El suscriptor guarda solo la longitud del payload
$argumentosSub = @(
    '-h',$ip,'-p','1883','-V','mqttv311',
    '-t','tfg/carga','-q',"$Qos",
    '-C',"$mensajesTotales",'-F','%l'
)

#Cada publicador envía 5000 mensajes aleatorios de 128 bytes
$argumentosPub = @(
    'bench','pub','-h',$ip,'-p','1883','-V','3.1.1',
    '-c',"$Publicadores",'-t','tfg/carga','-q',"$Qos",
    '-I','tfg-pub-%i','-S','128B','-im','20',
    '-L',"$mensajesTotales",'-v'
)

#Arranca primero el suscriptor
$sub = Start-Process -FilePath $mosquittoSub -ArgumentList $argumentosSub `
    -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $rutaSub `
    -RedirectStandardError $rutaSubErr

$null = $sub.Handle
Start-Sleep -Seconds 1

#Arranca MQTTX
$inicio = Get-Date

$pub = Start-Process -FilePath $mqttx -ArgumentList $argumentosPub `
    -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $rutaPub `
    -RedirectStandardError $rutaPubInfo

$null = $pub.Handle

#Mide recursos mientras MQTTX sigue activo
& $scriptRecursos `
    -Configuracion $Configuracion `
    -Repeticion $Repeticion `
    -Fase "carga_q${Qos}_p${Publicadores}" `
    -DirectorioResultados $dirResultados `
    -HastaProcesoId $pub.Id

$pub.WaitForExit()
$pub.Refresh()

$tiempoPublicacionMs = (
    $pub.ExitTime - $inicio
).TotalMilliseconds

#QoS 0 espera 30 s y QoS 1 hasta 300 s
$esperaSubMs = if ($Qos -eq 0) { 30000 } else { 300000 }

if (-not $sub.WaitForExit($esperaSubMs)) {
    Stop-Process -Id $sub.Id -Force -ErrorAction SilentlyContinue
    $sub.WaitForExit()
}

$sub.Refresh()

#Obtiene publicados y recibidos
$coincidenciasPub = @(
    Get-Content -LiteralPath $rutaPub |
        Select-String 'Published total:\s*(\d+)'
)

$publicados = [int]$coincidenciasPub[-1].Matches[0].Groups[1].Value
$recibidos = @(Get-Content -LiteralPath $rutaSub).Count
$diferencia = $publicados - $recibidos

#Solo calcula recepción si llegó el total esperado
$tiempoRecepcionMs = $null

if ($recibidos -eq $mensajesTotales) {
    $tiempoRecepcionMs = (
        $sub.ExitTime - $inicio
    ).TotalMilliseconds
}

$tasaPublicacion = $publicados / ($tiempoPublicacionMs / 1000)

$tasaRecepcion = $null

if ($null -ne $tiempoRecepcionMs -and $tiempoRecepcionMs -gt 0) {
    $tasaRecepcion = $recibidos / ($tiempoRecepcionMs / 1000)
}

#Guarda el resumen del bloque
$resumen = [PSCustomObject]@{
    Qos = $Qos
    Publicadores = $Publicadores
    Publicados = $publicados
    Recibidos = $recibidos
    Diferencia = $diferencia
    TiempoPublicacionMs = [Math]::Round($tiempoPublicacionMs,3)
    PublicadosPorSegundo = [Math]::Round($tasaPublicacion,3)
    TiempoRecepcionMs = if ($null -eq $tiempoRecepcionMs) { $null } else { [Math]::Round($tiempoRecepcionMs,3) }
    RecibidosPorSegundo = if ($null -eq $tasaRecepcion) { $null } else { [Math]::Round($tasaRecepcion,3) }
}

$resumen | Export-Csv -LiteralPath $rutaResumen -NoTypeInformation -Encoding UTF8

#Elimina el archivo de error si está vacío
if ((Get-Item -LiteralPath $rutaSubErr).Length -eq 0) {
    Remove-Item -LiteralPath $rutaSubErr
}

$resumen | Format-List
Write-Host "Resultado guardado en $rutaResumen"