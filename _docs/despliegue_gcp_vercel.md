# Guía de Configuración de Despliegue Serverless
**Sistema de Pollería — Backend en Google Cloud Run & Frontend en Vercel**  
**Estrategia Económica:** Arquitectura Serverless con **Scale-to-Zero** (costo $0 mientras no haya peticiones).  
**Seguridad:** Aislamiento total de credenciales mediante Google Secret Manager y Vercel Environment Variables.

---

## 1. Arquitectura de Despliegue y Abaratamiento de Costos

```
  ┌────────────────────────────────────────────────────────┐
  │                 FRONTEND (Vercel)                      │
  │     SPA Angular 19 — CDN Global & SSL Automático       │
  │               (Plan Hobby: 100% Gratis)                │
  └───────────────────────────┬────────────────────────────┘
                              │ HTTPS / REST
                              ▼
  ┌────────────────────────────────────────────────────────┐
  │             BACKEND (Google Cloud Run)                 │
  │   Arquitectura Serverless con Scale-to-Zero (min = 0)  │
  │                                                        │
  │   ┌───────────────┐ ┌───────────────┐ ┌──────────────┐ │
  │   │ auth-service  │ │orders-service │ │payments-svc  │ │
  │   │  (min: 0)     │ │  (min: 0)     │ │  (min: 0)    │ │
  │   └───────┬───────┘ └───────┬───────┘ └──────┬───────┘ │
  └───────────┼─────────────────┼────────────────┼─────────┘
              │                 │                │
              └─────────────────┼────────────────┘
                                ▼
  ┌────────────────────────────────────────────────────────┐
  │           BASE DE DATOS (PostgreSQL Remoto)            │
  │   Supabase / Neon (Capa Gratuita) o Cloud SQL Mínimo   │
  └────────────────────────────────────────────────────────┘
```

### Principios de Abaratamiento Extremo
1. **Scale-to-Zero (`--min-instances 0`):** Cuando no hay comensales ni personal usando el sistema, Cloud Run reduce las instancias a **cero**. No pagas ni un solo centavo por servidores inactivos.
2. **CPU Throttling Activado:** Solo se factura el tiempo exacto de CPU y memoria mientras se procesa activamente una solicitud HTTP (facturación al milisegundo).
3. **Límite de Gasto (`--max-instances 2`):** Evita sorpresas o costos desmedidos limitando las réplicas máximas concurrentes.
4. **Memoria Optimizada (`512MiB`):** Los contenedores corren sobre Eclipse Temurin JRE 21 Alpine, manteniendo el consumo bajo control.

---

## 2. Semillas Automáticas en Producción (Seed Data)

El sistema ya está programado para sembrar automáticamente los datos esenciales cuando se despliegue sobre una base de datos nueva o limpia:

### 2.1. Usuarios Oficiales con Buzón Yopmail (`auth-service`)
Implementado en [`DataInitializer.java`](../polleria/auth-service/src/main/java/com/sistema/polleria/auth/config/DataInitializer.java):
- `admin.polleria@yopmail.com` (`ADMIN`, 2FA activo, clave: `Password123!`)
- `mozo.polleria@yopmail.com` (`MOZO`, 2FA activo, clave: `Password123!`)
- `cocina.polleria@yopmail.com` (`COCINA`, 2FA activo, clave: `Password123!`)
- `repartidor.polleria@yopmail.com` (`REPARTIDOR`, 2FA activo, clave: `Password123!`)
- `cliente.polleria@yopmail.com` (`CLIENTE`, clave: `Password123!`)

### 2.2. Mesas del Salón y Carta Oficial de Productos (`orders-service`)
Implementado en [`DataInitializer.java`](../polleria/orders-service/src/main/java/com/sistema/polleria/orders/config/DataInitializer.java):
- **Mesas:** 5 mesas iniciales (Mesas 1 a 5 con estado `LIBRE`).
- **10 Productos Oficiales:** Pollo Clásico, 1/2 Pollo, 1/4 Pollo, Combo Familiar, Anticuchos, Papas Nativas, Inca Kola 1.5L, Chicha Morada 1L, Torta de Chocolate y Almuerzo Ejecutivo.

---

## 3. Configuración del Backend en GCP Cloud Run

### 3.1. Archivos Preparados
- **Plantilla de Variables:** [`polleria/.env.production.example`](../polleria/.env.production.example)
- **Pipeline Cloud Build:** [`polleria/cloudbuild.yaml`](../polleria/cloudbuild.yaml)
- **Script Automatizado:** [`polleria/deploy-gcp-cloudrun.ps1`](../polleria/deploy-gcp-cloudrun.ps1)

### 3.2. Paso a Paso para Desplegar (Cuando Decidas Ejecutarlo)

#### 1. Iniciar sesión y fijar proyecto:
```bash
gcloud auth login
gcloud config set project TU_PROJECT_ID
```

#### 2. Habilitar APIs de GCP:
```bash
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com
```

#### 3. Crear repositorio de imágenes Docker:
```bash
gcloud artifacts repositories create polleria-repo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Sistema Polleria Microservicios"
```

#### 4. Guardar secretos en Google Secret Manager:
```bash
# Guardar contraseña de BD
echo -n "TU_DB_PASSWORD" | gcloud secrets create polleria-db-password --data-file=-

# Guardar clave JWT (mínimo 32 caracteres)
echo -n "TU_JWT_SECRET_SUPER_SEGURO_2026" | gcloud secrets create polleria-jwt-secret --data-file=-
```

#### 5. Construir y Desplegar microservicios:
```bash
# Desde la carpeta polleria/
gcloud builds submit --config cloudbuild.yaml .

# Desplegar con Scale-to-Zero:
gcloud run deploy auth-service \
  --image us-central1-docker.pkg.dev/TU_PROJECT_ID/polleria-repo/auth-service:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 2 \
  --memory 512Mi \
  --cpu 1 \
  --set-env-vars "DB_URL=jdbc:postgresql://<HOST>:5432/polleria,DB_USERNAME=postgres" \
  --set-secrets "DB_PASSWORD=polleria-db-password:latest,JWT_SECRET=polleria-jwt-secret:latest"
```
*(Repetir para `orders-service` y `payments-service` según el script `deploy-gcp-cloudrun.ps1`).*

---

## 4. Configuración del Frontend en Vercel

### 4.1. Archivos Preparados
- **Configuración Vercel:** [`frontEnd/vercel.json`](../frontEnd/vercel.json)
  - Configurado con salida `dist/frontend-app/browser`.
  - Reglas de reescritura para enrutamiento SPA (`/(.*)` ➔ `/index.html`).
  - Cabeceras HTTP de seguridad (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`).
- **Plantilla de Variables:** [`frontEnd/.env.example`](../frontEnd/.env.example)

### 4.2. Paso a Paso para Desplegar en Vercel

1. **Vía Git (Recomendado):**
   - Importa tu repositorio en el panel de [Vercel](https://vercel.com/new).
   - En **Root Directory**, selecciona `frontEnd`.
   - Vercel detectará automáticamente **Angular**.
2. **Configurar Variables de Entorno en Vercel:**
   - En **Project Settings > Environment Variables**, agrega:
     - `NG_APP_AUTH_API_URL`: URL asignada a tu Cloud Run de `auth-service`.
     - `NG_APP_ORDERS_API_URL`: URL asignada a tu Cloud Run de `orders-service`.
     - `NG_APP_PAYMENTS_API_URL`: URL asignada a tu Cloud Run de `payments-service`.
     - `NG_APP_MERCADOPAGO_PUBLIC_KEY`: Tu clave pública de Mercado Pago.
3. **CORS en Backend:**
   - Una vez que Vercel te dé tu dominio (ej: `https://sistema-polleria.vercel.app`), actualiza la variable `CORS_ALLOWED_ORIGINS` en Cloud Run para permitir que tu frontend consuma los servicios.

---

## 5. Resumen de Seguridad: Protección contra Fugas

| Archivo | Estado de Seguridad | Propósito |
| :--- | :---: | :--- |
| `polleria/.env` | 🔒 **Ignorado en `.gitignore`** | Contiene credenciales solo para desarrollo local en tu máquina. |
| `polleria/.env.production.example` | ✅ **Sanitizado / Plantilla** | Documenta las variables requeridas sin exponer valores reales. |
| `frontEnd/.env.example` | ✅ **Sanitizado / Plantilla** | Guía de configuración para Vercel. |
| `frontEnd/vercel.json` | ✅ **Limpio de Secretos** | Solo reglas de routing y headers defensivos. |
| `polleria/deploy-gcp-cloudrun.ps1` | ✅ **Modo DryRun por Defecto** | Previene ejecuciones accidentales y usa Secret Manager. |
