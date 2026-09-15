# Desarrollo-de-practicas-con-unikernels
Repositorio asociado al Trabajo Fin de Grado **Desarrollo de prácticas con unikernels**, realizado en el Grado en Ingeniería Telemática de la Universidad de Alcalá.

Este repositorio contiene el código, las configuraciones, los scripts de medición y los resultados experimentales utilizados para comparar la ejecución de dos servicios (HTTP y MQTT) sobre **OSv** y una **máquina virtual Linux convencional**.

Los resultados incluidos corresponden a la campaña experimental final de **10 repeticiones (R1–R10)**.

## Estructura del repositorio

```text
.
├───http/
│   ├───aplicacion/
│   ├───configuracion/
│   │   ├───linux/
│   │   └───osv/
│   │       ├───base/
│   │       └───reducida/
│   └───resultados mediciones/
│       ├───resultados brutos/
│       └───resumen_brutos_http.xlsx
├───mqtt/
│   ├───configuracion/
│   │   ├───linux/
│   │   └───osv/
│   ├───mosquitto/
│   │   └───fuentes/
│   └───resultados mediciones/
│       ├───resultados brutos/
│       └───resumen_brutos_mqtt.xlsx
└───scripts/
```

### `http/`
Contiene todos los archivos relacionados con el caso de estudio HTTP.
- `aplicacion/`: código fuente del servidor HTTP, ejecutable utilizado y archivos necesarios para su incorporación a OSv.
- `configuracion/linux/`: configuración de la máquina virtual Linux, red y servicio `systemd`.
- `configuracion/osv/base/`: configuración correspondiente a la imagen OSv base.
- `configuracion/osv/reducida/`: configuración correspondiente a la imagen OSv reducida.
- `resultados mediciones/resultados brutos/`: resultados obtenidos en R1–R10 para disponibilidad, recursos y carga.
- `resultados mediciones/resumen_brutos_http.xlsx`: recopilación de los resultados utilizados para elaborar las tablas y figuras de la memoria.

### `mqtt/`
Contiene los archivos correspondientes al caso de estudio MQTT.
- `configuracion/linux/`: configuración de la máquina virtual Linux y del servicio Mosquitto.
- `configuracion/osv/`: configuración de la imagen OSv utilizada para ejecutar Mosquitto.
- `mosquitto/`: ejecutable empleado, biblioteca requerida, configuración, archivos de integración con OSv y parche aplicado al código fuente.
- `mosquitto/fuentes/`: paquete de fuentes de Eclipse Mosquitto 2.1.2 utilizado como base de la adaptación.
- `resultados mediciones/resultados brutos/`: resultados obtenidos en R1–R10 para disponibilidad, recursos, publicaciones y recepciones.
- `resultados mediciones/resumen_brutos_mqtt.xlsx`: recopilación de los resultados utilizados en el análisis final.

### `scripts/`
Contiene los scripts PowerShell utilizados durante la campaña experimental:

| Script | Función |
| --- | --- |
| `preparar_entorno.ps1` | Define las rutas, herramientas, direcciones IP y máquinas utilizadas para cada caso de estudio. |
| `medir_arranque_http.ps1` | Arranca una máquina y mide el tiempo hasta que el servicio HTTP responde correctamente. |
| `medir_arranque_mqtt.ps1` | Arranca una máquina y mide el tiempo hasta que el broker admite una publicación MQTT. |
| `medir_recursos.ps1` | Obtiene muestras de memoria y procesador del proceso `vmware-vmx` durante reposo o carga. |
| `ejecutar_carga.ps1` | Ejecuta la carga HTTP mediante `oha` y registra simultáneamente los recursos consumidos. |
| `ejecutar_carga_mqtt.ps1` | Ejecuta la carga MQTT mediante MQTTX CLI, registra la recepción mediante `mosquitto_sub` y recoge los recursos. |
| `medir_tamano.ps1` | Calcula el tamaño desplegable de cada máquina a partir del VMX y sus VMDK. |
| `resumir_cargas.ps1` | Extrae del JSON de `oha` las métricas utilizadas en el análisis HTTP. |
| `enviar_peticion_malformada.ps1` | Envía una petición TCP deliberadamente malformada para comprobar el tratamiento del error HTTP. |

## Caso de estudio HTTP
El primer caso consiste en un servidor HTTP/1.1 desarrollado específicamente para el TFG y ejecutado sobre tres configuraciones:
- **OSv base**
- **OSv reducida**
- **Linux**

El servicio escucha en el puerto `8080` y dispone, entre otros, de los recursos `/` y `/estado`.
Las cargas experimentales se realizaron con **1 y 10 conexiones concurrentes**. Cada configuración y nivel de carga se repitió diez veces.
Los archivos JSON generados por `oha` y los CSV de disponibilidad y recursos se conservan en:
```text
http/resultados mediciones/resultados brutos/
```

## Caso de estudio MQTT
El segundo caso utiliza **Eclipse Mosquitto 2.1.2** como broker MQTT y compara:
- **OSv**
- **Linux**
Las pruebas utilizan MQTT 3.1.1 y combinan:
- QoS 0 y QoS 1.
- 1 y 10 publicadores.
- 5.000 mensajes por publicador.
Las mediciones se realizaron sobre el tema `tfg/carga` y para comprobar la disponibilidad del broker se utilizó `tfg/disponibilidad`.
Los resultados brutos se encuentran en:
```text
mqtt/resultados mediciones/resultados brutos/
```
Para cada combinación se conservan:
- salida de MQTTX CLI
- información de la ejecución
- salida del suscriptor `mosquitto_sub`
- resumen de mensajes publicados y recibidos
- muestras de recursos
- medida de disponibilidad

## Ejecución de los scripts
Los scripts fueron ejecutados desde **Windows PowerShell 5.1**.
Las rutas incluidas en `preparar_entorno.ps1` corresponden al equipo utilizado durante el TFG. Para reproducir los experimentos deben adaptarse las rutas de trabajo, herramientas y máquinas virtuales.

### 1. Preparar PowerShell
Situarse en el directorio que contiene los scripts:
```powershell
Set-Location "C:\Users\angel\Desktop\TFG\local"
```
Si la política de ejecución impide ejecutar los scripts:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```
El cambio se limita al proceso actual de PowerShell.

### 2. Preparar el entorno
El script debe cargarse mediante **dot-sourcing**, ya que define las variables utilizadas por los demás scripts.
Para HTTP:
```powershell
. .\preparar_entorno.ps1 -Caso http
```

Para MQTT:
```powershell
. .\preparar_entorno.ps1 -Caso mqtt
```

A partir de este punto, los ejemplos muestran una repetición concreta. El parámetro `-Repeticion` admite valores entre `1` y `10`.

# Ejecución de las pruebas HTTP
## Medida de disponibilidad
Para OSv base:
```powershell
& .\medir_arranque_http.ps1 `
    -Configuracion base `
    -Repeticion 4
```

Para OSv reducida:
```powershell
& .\medir_arranque_http.ps1 `
    -Configuracion reducida `
    -Repeticion 4
```

Para Linux:
```powershell
& .\medir_arranque_http.ps1 `
    -Configuracion linux `
    -Repeticion 4
```

El script arranca la máquina correspondiente y mide el tiempo transcurrido hasta que `/estado` responde con el contenido esperado y código HTTP `200`.

## Recursos en reposo
Con la máquina correspondiente en ejecución:
```powershell
& .\medir_recursos.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Fase reposo
```
El valor de `-Configuracion` puede sustituirse por `base`, `reducida` o `linux`.

## Carga con 1 conexión
```powershell
& .\ejecutar_carga.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Concurrencia 1
```

## Carga con 10 conexiones
```powershell
& .\ejecutar_carga.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Concurrencia 10
```

El script comprueba primero la disponibilidad de `/estado`, realiza un calentamiento de 5 s y posteriormente aplica la carga medida durante 30 s.
Durante la carga también se registran los recursos del proceso `vmware-vmx`.

Los resultados de `oha` se almacenan en archivos JSON con nombres del tipo:
```text
base_c1_r4.json
base_c10_r4.json
```
De los cuales interesan:
- tasa de éxito
- solicitudes por segundo
- p50
- p95
- p99

## Comprobación de una petición malformada
```powershell
& .\enviar_peticion_malformada.ps1 `
    -Ip 192.168.58.10
```
La dirección IP debe sustituirse por la correspondiente a la configuración que se quiera comprobar.

## Tamaño desplegable
Después de preparar el entorno HTTP:
```powershell
& .\medir_tamano.ps1
```

El resultado se almacena en:
```text
tamanos_desplegables.csv
```

# Ejecución de las pruebas MQTT
Antes de ejecutar estas pruebas debe prepararse el entorno MQTT:
```powershell
. .\preparar_entorno.ps1 -Caso mqtt
```

## Medida de disponibilidad
Para OSv:
```powershell
& .\medir_arranque_mqtt.ps1 `
    -Configuracion base `
    -Repeticion 4
```

Para Linux:
```powershell
& .\medir_arranque_mqtt.ps1 `
    -Configuracion linux `
    -Repeticion 4
```

La disponibilidad se determina realizando una publicación MQTT 3.1.1 con QoS 1 sobre `tfg/disponibilidad`.

## Recursos en reposo
```powershell
& .\medir_recursos.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Fase reposo
```
El parámetro `-Configuracion` admite `base` o `linux` para este caso de estudio.

## Carga QoS 0 con 1 publicador
```powershell
& .\ejecutar_carga_mqtt.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Qos 0 `
    -Publicadores 1
```

## Carga QoS 0 con 10 publicadores
```powershell
& .\ejecutar_carga_mqtt.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Qos 0 `
    -Publicadores 10
```

## Carga QoS 1 con 1 publicador
```powershell
& .\ejecutar_carga_mqtt.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Qos 1 `
    -Publicadores 1
```

## Carga QoS 1 con 10 publicadores
```powershell
& .\ejecutar_carga_mqtt.ps1 `
    -Configuracion base `
    -Repeticion 4 `
    -Qos 1 `
    -Publicadores 10
```

Para realizar las mismas pruebas sobre Linux basta con sustituir:
```powershell
-Configuracion base
```
por:
```powershell
-Configuracion linux
```

Cada publicador envía 5.000 mensajes de 128 bytes. El script inicia un suscriptor con `mosquitto_sub`, ejecuta la carga con MQTTX CLI y compara posteriormente el número de mensajes publicados y recibidos.
Los resultados se almacenan con nombres que identifican configuración, QoS, número de publicadores y repetición, por ejemplo:
```text
base_q1_p10_r4_resumen_mqtt.csv
base_q1_p10_r4_mqttx_pub.txt
base_q1_p10_r4_mqttx_info.txt
base_q1_p10_r4_mosquitto_sub.txt
base_r4_recursos_carga_q1_p10.csv
```

## Tamaño desplegable
Después de preparar el entorno MQTT:
```powershell
& .\medir_tamano.ps1
```

## Resultados
Los datos incluidos en este repositorio corresponden a las diez repeticiones utilizadas en el análisis final del TFG.

### HTTP
```text
http/resultados mediciones/
├── resultados brutos/
└── resumen_brutos_http.xlsx
```

Los resultados brutos contienen:
- tiempos de disponibilidad
- resultados JSON de `oha`
- recursos en reposo
- recursos durante carga con 1 conexión
- recursos durante carga con 10 conexiones
- tamaños desplegables

### MQTT

```text
mqtt/resultados mediciones/
├── resultados brutos/
└── resumen_brutos_mqtt.xlsx
```

Los resultados brutos contienen:
- tiempos de disponibilidad
- salidas de MQTTX CLI
- salidas de `mosquitto_sub`
- resúmenes de mensajes publicados y recibidos
- recursos en reposo
- recursos durante las cuatro combinaciones de carga
- tamaños desplegables
Los archivos Excel reúnen los datos empleados para elaborar las tablas, figuras y valores agregados presentados en la memoria.

## Software de terceros
Este repositorio contiene algunos componentes de terceros necesarios para reproducir el caso de estudio MQTT. Estos componentes **no forman parte del código desarrollado específicamente para este TFG**.

### Eclipse Mosquitto
Para el caso MQTT se utilizó **Eclipse Mosquitto 2.1.2**.
- Proyecto oficial: [Eclipse Mosquitto](https://mosquitto.org/)
- Repositorio oficial: [eclipse-mosquitto/mosquitto](https://github.com/eclipse-mosquitto/mosquitto)

El paquete fuente empleado se conserva en:
```text
mqtt/mosquitto/fuentes/mosquitto-2.1.2.tar.gz
```
Se mantiene una copia local para identificar de forma inequívoca las fuentes sobre las que se realizó la adaptación utilizada en el TFG.
Las modificaciones necesarias para su ejecución en OSv se recogen separadamente en:
```text
mqtt/mosquitto/mosquitto-opendir-stat.patch
```

El ejecutable utilizado se encuentra en:
```text
mqtt/mosquitto/mosquitto
```

Mosquitto se distribuye bajo **Eclipse Public License 2.0 o BSD 3-Clause**. El paquete fuente conserva los archivos de licencia y avisos correspondientes.
- [Licencia de Eclipse Mosquitto](https://github.com/eclipse-mosquitto/mosquitto/blob/master/LICENSE.txt)
- [Eclipse Public License 2.0](https://www.eclipse.org/legal/epl-2.0/)
- [Eclipse Distribution License 1.0](https://www.eclipse.org/org/documents/edl-v10.php)

### cJSON
El archivo:
```text
mqtt/mosquitto/libcjson.so.1
```
corresponde a **cJSON**, utilizado como dependencia de Mosquitto. Se trata de software de terceros y no de código desarrollado para este TFG.

cJSON se distribuye bajo licencia MIT.
- Repositorio oficial: [DaveGamble/cJSON](https://github.com/DaveGamble/cJSON)
- [Licencia MIT de cJSON](https://github.com/DaveGamble/cJSON/blob/master/LICENSE)

## Consideraciones de reproducibilidad
Las configuraciones y scripts conservan determinados valores utilizados en el entorno experimental original, como:
- rutas locales
- direcciones IP privadas
- rutas de VMware
- nombres de máquinas virtuales
Estos valores deben adaptarse antes de repetir los experimentos en otro equipo.

En particular, debe revisarse:
```text
scripts/preparar_entorno.ps1
```

Los resultados existentes no deben interpretarse como valores que vayan a reproducirse exactamente en otro equipo, puesto que dependen tanto de la configuración de las máquinas virtuales como del hardware y del software del anfitrión.

## Autoría
El código del servidor HTTP, los scripts experimentales, las configuraciones específicas, las adaptaciones realizadas y el tratamiento de los resultados forman parte del Trabajo Fin de Grado.

Los componentes identificados en la sección **Software de terceros** mantienen la autoría y las condiciones de licencia de sus respectivos proyectos.
