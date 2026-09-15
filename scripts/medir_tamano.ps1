#Calcula el tamaño desplegable de cada configuración
$resultados = foreach ($nombre in $maquinas.Keys) {

    #Obtiene el VMX y todos los VMDK
    $vmx = Get-Item -LiteralPath $maquinas[$nombre].Vmx
    $vmdk = @(Get-ChildItem -LiteralPath $vmx.DirectoryName -File |
        Where-Object { $_.Extension -eq '.vmdk' })

    #Suma VMX y familia VMDK
    $bytes = $vmx.Length + ($vmdk | Measure-Object Length -Sum).Sum

    [PSCustomObject]@{
        Configuracion = $nombre
        TotalBytes = $bytes
        TotalMiB = [Math]::Round($bytes / 1MB,3)
    }
}

#Guarda una fila por configuración
$rutaCsv = Join-Path $dirResultados 'tamanos_desplegables.csv'

$resultados | Export-Csv -LiteralPath $rutaCsv -NoTypeInformation -Encoding UTF8
$resultados | Format-Table -AutoSize
Write-Host "Resultado guardado en $rutaCsv"
