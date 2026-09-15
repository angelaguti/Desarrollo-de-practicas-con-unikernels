param(
    [Parameter(Mandatory)]
    [ValidateSet('base','reducida','linux')]
    [string]$Configuracion,

    [Parameter(Mandatory)]
    [ValidateRange(1,10)]
    [int]$Repeticion,

    [Parameter(Mandatory)]
    [ValidateSet(1,10)]
    [int]$Concurrencia
)

$ip = $maquinas[$Configuracion].Ip
$url = "http://${ip}:8080/"

#Comprueba que /estado está disponible
$estado = @(
    & curl.exe --http1.1 --silent --max-time 2 `
        --write-out "%{http_code}" `
        "http://${ip}:8080/estado" 2>$null
)

if ($LASTEXITCODE -ne 0 -or
    $estado.Count -ne 2 -or
    $estado[0] -cne 'OK' -or
    $estado[1] -ne '200') {

    throw 'El recurso /estado no está disponible'
}

$rutaJson = Join-Path $dirResultados (
    "${Configuracion}_c${Concurrencia}_r${Repeticion}.json"
)

#Calentamiento de 5 segundos
Write-Host "Calentamiento: 5 s concurrencia $Concurrencia"

& $oha --no-tui --no-color --http-version 1.1 `
    --disable-keepalive `
    --wait-ongoing-requests-after-deadline `
    -z 5s -c $Concurrencia $url |
    Out-Null

$fase = "carga_c${Concurrencia}"

#Mide CPU y memoria en paralelo
$trabajoRecursos = Start-Job -ScriptBlock {

    param($Ruta,$Config,$Rep,$Fase,$Dir)

    & $Ruta `
        -Configuracion $Config `
        -Repeticion $Rep `
        -Fase $Fase `
        -DirectorioResultados $Dir

} -ArgumentList @(
    $scriptRecursos,
    $Configuracion,
    $Repeticion,
    $fase,
    $dirResultados
)

try {

    #Carga medida de 30 segundos
    Write-Host "Carga medida: 30 s concurrencia $Concurrencia"

    & $oha --no-tui --no-color --http-version 1.1 `
        --disable-keepalive `
        --wait-ongoing-requests-after-deadline `
        --output-format json -o $rutaJson `
        -z 30s -c $Concurrencia $url

    $codigoCarga = $LASTEXITCODE

    #Espera a que termine el muestreo
    Wait-Job -Job $trabajoRecursos | Out-Null
    Receive-Job -Job $trabajoRecursos -ErrorAction Stop

    if ($codigoCarga -ne 0) {
        throw "oha terminó con código $codigoCarga"
    }
}
finally {
    Remove-Job -Job $trabajoRecursos -Force -ErrorAction SilentlyContinue
}

Write-Host "Resultado de carga guardado en $rutaJson"