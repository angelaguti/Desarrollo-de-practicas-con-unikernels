param(
    [Parameter(Mandatory)]
    [ValidateSet('base','reducida','linux')]
    [string]$Configuracion,

    [Parameter(Mandatory)]
    [ValidateRange(1,10)]
    [int]$Repeticion,

    [Parameter(Mandatory)]
    [ValidateSet(
        'reposo',
        'carga_c1',
        'carga_c10',
        'carga_q0_p1',
        'carga_q0_p10',
        'carga_q1_p1',
        'carga_q1_p10'
    )]
    [string]$Fase,

    [string]$DirectorioResultados = $dirResultados,

    #En MQTT permite medir hasta que termine MQTTX
    [int]$HastaProcesoId = 0
)

#Busca el proceso vmware-vmx activo
$procesos = @(Get-Process vmware-vmx -ErrorAction SilentlyContinue)

if ($procesos.Count -ne 1) {
    throw 'Debe haber exactamente un proceso vmware-vmx activo'
}

$pidVmx = $procesos[0].Id

$rutaCsv = Join-Path $DirectorioResultados (
    "${Configuracion}_r${Repeticion}_recursos_${Fase}.csv"
)

New-Item -ItemType Directory -Path $DirectorioResultados -Force | Out-Null

#Normaliza la CPU con los procesadores lógicos del host
$procesadoresLogicos = (
    Get-CimInstance Win32_ComputerSystem
).NumberOfLogicalProcessors

#Reposo: 10 muestras. HTTP: 30. MQTT: hasta terminar MQTTX
if ($Fase -eq 'reposo') {
    $duracionSegundos = 10
}
elseif ($HastaProcesoId -eq 0) {
    $duracionSegundos = 30
}
else {
    $duracionSegundos = $null
}

#Referencia inicial para calcular la CPU entre muestras
$cronometro = [System.Diagnostics.Stopwatch]::StartNew()
$proceso = Get-Process -Id $pidVmx
$cpuAnterior = $proceso.TotalProcessorTime.TotalSeconds
$tiempoAnterior = $cronometro.Elapsed.TotalSeconds

$muestras = @()
$segundo = 0

while ($true) {

    if ($null -ne $duracionSegundos -and $segundo -ge $duracionSegundos) {
        break
    }

    #En MQTT se detiene cuando termina MQTTX
    if ($HastaProcesoId -ne 0 -and $segundo -gt 0) {
        if (-not (Get-Process -Id $HastaProcesoId -ErrorAction SilentlyContinue)) {
            break
        }
    }

    $segundo++

    #Evita acumular retraso entre muestras
    $esperaMs = [Math]::Max(
        0,
        ($segundo - $cronometro.Elapsed.TotalSeconds) * 1000
    )

    Start-Sleep -Milliseconds ([int]$esperaMs)

    $proceso = Get-Process -Id $pidVmx
    $tiempoActual = $cronometro.Elapsed.TotalSeconds
    $cpuActual = $proceso.TotalProcessorTime.TotalSeconds

    #CPU consumida durante el último intervalo
    $cpuHost = (
        ($cpuActual - $cpuAnterior) /
        ($tiempoActual - $tiempoAnterior) /
        $procesadoresLogicos * 100
    )

    #Memoria residente de vmware-vmx en el host
    $memoriaHost = $proceso.WorkingSet64 / 1MB

    $muestras += [PSCustomObject]@{
        Segundo = $segundo
        MemoriaHostMiB = [Math]::Round($memoriaHost,3)
        CpuHostPorcentaje = [Math]::Round($cpuHost,3)
    }

    $cpuAnterior = $cpuActual
    $tiempoAnterior = $tiempoActual
}

$cronometro.Stop()

#Guarda todas las muestras
$muestras | Export-Csv -LiteralPath $rutaCsv -NoTypeInformation -Encoding UTF8

Write-Host "Se guardaron $($muestras.Count) muestras en $rutaCsv"
