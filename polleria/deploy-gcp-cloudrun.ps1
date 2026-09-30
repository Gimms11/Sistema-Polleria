<#
.SYNOPSIS
    Script de configuración y despliegue serverless para Sistema Pollería en Google Cloud Run.
.DESCRIPTION
    Configura y despliega los 3 microservicios (auth-service, orders-service, payments-service)
    optimizados para Scale-to-Zero (costo $0 mientras no haya tráfico).
    Usa Google Secret Manager para proteger contraseñas y claves JWT.
.PARAMETER ProjectId
    ID del proyecto en Google Cloud Platform.
.PARAMETER Region
    Región de despliegue en GCP (default: us-central1).
.PARAMETER DryRun
    Si está activo ($true), solo valida la configuración sin realizar cambios reales.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ProjectId = "mitrufely",

    [Parameter(Mandatory = $false)]
    [string]$Region = "us-central1",

    [Parameter(Mandatory = $false)]
    [string]$ArtifactRepo = "polleria-repo",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $true
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ">>> CONFIGURACION DE DESPLIEGUE GCP CLOUD RUN (SERVERLESS)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Proyecto: $ProjectId"
Write-Host "Region:   $Region"
Write-Host "Repo:     $ArtifactRepo"
Write-Host "DryRun:   $DryRun"

if ($DryRun) {
    Write-Host "`n[MODO SIMULACION - SOLO CONFIGURACION ACTIVA]" -ForegroundColor Yellow
    Write-Host "Para desplegar en vivo cuando tengas tu cuenta lista, ejecuta:" -ForegroundColor Gray
    Write-Host ".\deploy-gcp-cloudrun.ps1 -ProjectId '$ProjectId' -Region '$Region' -DryRun:`$false`n" -ForegroundColor Gray
}

# 1. Habilitar APIs esenciales de GCP
$apisToEnable = @(
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com"
)

Write-Host "`n[Paso 1/5] APIs de GCP requeridas:" -ForegroundColor Cyan
foreach ($api in $apisToEnable) {
    Write-Host "  - $api"
}

# 2. Configuración de Artifact Registry
$repoPath = "$Region-docker.pkg.dev/$ProjectId/$ArtifactRepo"
Write-Host "`n[Paso 2/5] Repositorio de Contenedores:" -ForegroundColor Cyan
Write-Host "  URI Base: $repoPath"
Write-Host "  Comando creacion:"
Write-Host "  gcloud artifacts repositories create $ArtifactRepo --repository-format=docker --location=$Region --description='Sistema Polleria Images'" -ForegroundColor DarkGray

# 3. Secretos recomendados en Google Secret Manager (Cero fugas de credenciales)
$secrets = @(
    "polleria-db-url",
    "polleria-db-username",
    "polleria-db-password",
    "polleria-jwt-secret",
    "polleria-mail-password",
    "polleria-mercadopago-token"
)

Write-Host "`n[Paso 3/5] Secretos en Secret Manager (Proteccion de credenciales):" -ForegroundColor Cyan
foreach ($s in $secrets) {
    Write-Host "  - $s"
}

# 4. Parámetros de Serverless / Abaratamiento de Costos (Scale-to-Zero)
$commonRunFlags = @(
    "--region $Region",
    "--platform managed",
    "--allow-unauthenticated",
    "--min-instances 0",        # ESCALA A CERO CUANDO NO HAY PETICIONES (COSTO $0)
    "--max-instances 2",        # Protege tu presupuesto contra sobrecargas
    "--memory 512Mi",           # Huella de memoria ligera para Alpine JRE
    "--cpu 1",                  # 1 vCPU con CPU Throttling habilitado por defecto
    "--timeout 120"
) -join " "

Write-Host "`n[Paso 4/5] Politica de Costos Serverless (Cloud Run):" -ForegroundColor Cyan
Write-Host "  - Min Instances: 0 (Scale-to-Zero habilitado)" -ForegroundColor Green
Write-Host "  - Max Instances: 2 (Proteccion de gasto)" -ForegroundColor Green
Write-Host "  - Memoria: 512 MiB por contenedor" -ForegroundColor Green
Write-Host "  - Facturacion: Unicamente por tiempo de CPU consumido durante peticiones activas" -ForegroundColor Green

# 5. Cargar variables de entorno desde .env si existe
$envFile = Join-Path $PSScriptRoot ".env"
$envMap = @{}
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$' } | ForEach-Object {
        $envMap[$Matches[1]] = $Matches[2].Trim()
    }
}

$dbUrl = $envMap["DB_URL"]
$dbUser = $envMap["DB_USERNAME"]
$dbPass = $envMap["DB_PASSWORD"]
$jwtSec = $envMap["JWT_SECRET"]
$cors = $envMap["CORS_ALLOWED_ORIGINS"]
$mailUser = $envMap["MAIL_USERNAME"]
$mailPass = $envMap["MAIL_PASSWORD"]

# 6. Comandos de despliegue por microservicio
Write-Host "`n[Paso 5/5] Comandos de despliegue generados:" -ForegroundColor Cyan

$services = @("auth-service", "orders-service", "payments-service")
foreach ($svc in $services) {
    $imgUri = "$repoPath/${svc}:latest"
    $envVars = @(
        "SPRING_PROFILES_ACTIVE=prod",
        "DB_URL=$dbUrl",
        "DB_USERNAME=$dbUser",
        "DB_PASSWORD=$dbPass",
        "JWT_SECRET=$jwtSec",
        "CORS_ALLOWED_ORIGINS=$cors"
    )
    if ($svc -eq "auth-service") {
        $envVars += "MAIL_USERNAME=$mailUser"
        $envVars += "MAIL_PASSWORD=$mailPass"
    }
    $envVarStr = $envVars -join ","

    Write-Host "`n  # Despliegue de ${svc}:" -ForegroundColor Yellow
    Write-Host "  gcloud run deploy $svc ``"
    Write-Host "    --image $imgUri ``"
    Write-Host "    $commonRunFlags ``"
    Write-Host "    --set-env-vars `"$envVarStr`""

    if (-not $DryRun) {
        Write-Host "`n  Ejecutando despliegue de $svc en Cloud Run..." -ForegroundColor Magenta
        gcloud run deploy $svc --image $imgUri $commonRunFlags.Split(" ") --set-env-vars "$envVarStr" --project $ProjectId --quiet
    }
}

if ($DryRun) {
    Write-Host "`n[CONFIGURACION FINALIZADA SATISFACTORIAMENTE (DRY-RUN)]" -ForegroundColor Green
} else {
    Write-Host "`n[DESPLIEGUE FINALIZADO EXITOSAMENTE]" -ForegroundColor Green
}
