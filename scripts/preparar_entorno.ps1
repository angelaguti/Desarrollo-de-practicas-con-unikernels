param(
    [Parameter(Mandatory)]
    [ValidateSet('http','mqtt')]
    [string]$Caso
)

#Guarda el caso elegido para toda la sesión
$caso = $Caso

#Rutas principales
$dirTrabajo = 'C:\Users\angel\Desktop\TFG\local'
$dirResultados = Join-Path $dirTrabajo "resultados\mediciones-$caso"

#Herramientas
$vmrun = 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe'
$mosquittoPub = 'C:\Program Files\mosquitto\mosquitto_pub.exe'
$mosquittoSub = 'C:\Program Files\mosquitto\mosquitto_sub.exe'

#Scripts utilizados durante la campaña
$scriptRecursos = Join-Path $dirTrabajo 'medir_recursos.ps1'
$scriptTamano = Join-Path $dirTrabajo 'medir_tamano.ps1'
$scriptArranqueHttp = Join-Path $dirTrabajo 'medir_arranque_http.ps1'
$scriptArranqueMqtt = Join-Path $dirTrabajo 'medir_arranque_mqtt.ps1'
$scriptCargaHttp = Join-Path $dirTrabajo 'ejecutar_carga.ps1'
$scriptCargaMqtt = Join-Path $dirTrabajo 'ejecutar_carga_mqtt.ps1'
$scriptPeticionMalformada = Join-Path $dirTrabajo 'enviar_peticion_malformada.ps1'

if ($caso -eq 'http') {

    #Máquinas HTTP
    $maquinas = @{
        base = @{
            Vmx = 'C:\Users\angel\Desktop\TFG\local\resultados\pruebas\http-osv-base\osv.vmx'
            Ip = '192.168.58.10'
            Apagado = 'hard'
        }
        reducida = @{
            Vmx = 'C:\Users\angel\Desktop\TFG\local\resultados\pruebas\http-osv-reducida\osv.vmx'
            Ip = '192.168.58.11'
            Apagado = 'hard'
        }
        linux = @{
            Vmx = 'C:\Users\angel\Documents\Virtual Machines\http-linux\http-linux.vmx'
            Ip = '192.168.58.12'
            Apagado = 'soft'
        }
    }

    $scriptArranque = $scriptArranqueHttp
    $oha = (Get-Command oha.exe -ErrorAction Stop).Source
}
else {

    #Máquinas MQTT
    $maquinas = @{
        base = @{
            Vmx = 'C:\Users\angel\Desktop\TFG\local\mqtt-osv-base-final\osv.vmx'
            Ip = '192.168.58.20'
            Apagado = 'hard'
        }
        linux = @{
            Vmx = 'C:\Users\angel\Documents\Virtual Machines\mqtt-linux\mqtt-linux.vmx'
            Ip = '192.168.58.21'
            Apagado = 'soft'
        }
    }

    $scriptArranque = $scriptArranqueMqtt
    $mqttx = Join-Path $dirTrabajo 'herramientas\mqttx.exe'
}

#Crea las carpetas si todavía no existen
New-Item -ItemType Directory -Path $dirResultados -Force | Out-Null

Write-Host "Entorno preparado para $caso"
Write-Host "Resultados: $dirResultados"
