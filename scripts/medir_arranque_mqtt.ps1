param(
    [Parameter(Mandatory)]
    [ValidateSet('base','linux')]
    [string]$Configuracion,

    [Parameter(Mandatory)]
    [ValidateRange(1,10)]
    [int]$Repeticion
)

$maquina = $maquinas[$Configuracion]

$rutaCsv = Join-Path $dirResultados (
    "${Configuracion}_r${Repeticion}_arranque.csv"
)

#Prueba una publicación MQTT 3.1.1 con QoS 1
function Test-Broker {

    param([string]$Ip)

    $argumentos = @(
        '-h',$Ip,
        '-p','1883',
        '-V','mqttv311',
        '-t','tfg/disponibilidad',
        '-q','1',
        '-m','OK'
    )

    $proceso = Start-Process `
        -FilePath $mosquittoPub `
        -ArgumentList $argumentos `
        -WindowStyle Hidden `
        -PassThru

    $null = $proceso.Handle

    #Cada intento se limita a medio segundo
    if (-not $proceso.WaitForExit(500)) {

        Stop-Process -Id $proceso.Id `
            -Force `
            -ErrorAction SilentlyContinue

        return $false
    }

    return ($proceso.ExitCode -eq 0)
}

#El tiempo empieza justo antes de arrancar la VM
$cronometro = [System.Diagnostics.Stopwatch]::StartNew()

& $vmrun -T ws start $maquina.Vmx nogui | Out-Null

$disponible = $false

#Prueba el broker hasta que la publicación funciona
while ($cronometro.Elapsed.TotalSeconds -lt 60) {

    $inicioIntento = $cronometro.Elapsed.TotalMilliseconds

    if (Test-Broker -Ip $maquina.Ip) {
        $disponible = $true
        break
    }

    #Los intentos comienzan aproximadamente cada 100 ms
    $espera = [Math]::Max(
        0,
        100 - ($cronometro.Elapsed.TotalMilliseconds - $inicioIntento)
    )

    Start-Sleep -Milliseconds ([int]$espera)
}

$cronometro.Stop()

if (-not $disponible) {
    throw 'El broker no estuvo disponible en 60 segundos'
}

#Guarda solo el tiempo obtenido
$resultado = [PSCustomObject]@{
    TiempoMs = [Math]::Round(
        $cronometro.Elapsed.TotalMilliseconds,
        3
    )
}

$resultado | Export-Csv -LiteralPath $rutaCsv -NoTypeInformation -Encoding UTF8
$resultado | Format-List
Write-Host "Resultado guardado en $rutaCsv"