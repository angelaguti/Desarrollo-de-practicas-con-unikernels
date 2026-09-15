param(
    [Parameter(Mandatory)]
    [ValidateSet('base','reducida','linux')]
    [string]$Configuracion,

    [Parameter(Mandatory)]
    [ValidateRange(1,10)]
    [int]$Repeticion
)

$maquina = $maquinas[$Configuracion]

#Comprueba si /estado devuelve exactamente OK y HTTP 200
function Test-ServicioDisponible {

    param([string]$Ip)

    $respuesta = @(
        & curl.exe --http1.1 --silent --max-time 0.5 `
            --write-out "%{http_code}" `
            "http://${Ip}:8080/estado" 2>$null
    )

    $codigoCurl = $LASTEXITCODE

    return (
        $codigoCurl -eq 0 -and
        $respuesta.Count -eq 2 -and
        $respuesta[0] -ceq 'OK' -and
        $respuesta[1] -eq '200'
    )
}

$rutaCsv = Join-Path $dirResultados (
    "${Configuracion}_r${Repeticion}_arranque.csv"
)

New-Item -ItemType Directory -Path $dirResultados -Force | Out-Null

#El tiempo empieza justo antes de arrancar la VM
$cronometro = [System.Diagnostics.Stopwatch]::StartNew()

& $vmrun -T ws start $maquina.Vmx nogui | Out-Null

$disponible = $false

#Consulta /estado hasta que el servicio esté disponible
while ($cronometro.Elapsed.TotalSeconds -lt 60) {

    $inicioIntento = $cronometro.Elapsed.TotalMilliseconds

    if (Test-ServicioDisponible -Ip $maquina.Ip) {
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
    throw 'El servicio no estuvo disponible en 60 segundos'
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