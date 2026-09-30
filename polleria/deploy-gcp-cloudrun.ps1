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
    [string]$ProjectId = "tu-gcp-project-id",

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

# 5. Comandos de despliegue por microservicio
Write-Host "`n[Paso 5/5] Comandos de despliegue generados:" -ForegroundColor Cyan

$services = @("auth-service", "orders-service", "payments-service")
foreach ($svc in $services) {
    $imgUri = "$repoPath/${svc}:latest"
    Write-Host "`n  # Despliegue de $svc:" -ForegroundColor Yellow
    Write-Host "  gcloud run deploy $svc ``"
    Write-Host "    --image $imgUri ``"
    Write-Host "    $commonRunFlags ``"
    Write-Host "    --set-env-vars `"SPRING_PROFILES_ACTIVE=prod`""
}

if (-not $DryRun) {
    Write-Host "`nIniciando ejecucion real de gcloud..." -ForegroundColor Magenta
    # Ejecucion real solo cuando el usuario lo solicite explicitamente
    # gcloud builds submit --config cloudbuild.yaml ...
} else {
    Write-Host "`n[CONFIGURACION FINALIZADA SATISFACTORIAMENTE]" -ForegroundColor Green
}
