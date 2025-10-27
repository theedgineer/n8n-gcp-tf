# n8n GCP Deployment - Configuración Mínima

Este proyecto despliega n8n en Google Cloud Platform con una configuración optimizada para costo mínimo.

## 📋 Requisitos Previos

1. Cuenta de GCP con billing habilitado
2. Proyecto de GCP creado
3. `gcloud` CLI instalado
4. `terraform` instalado (>= 1.5.0)

## 🚀 Deployment

### 1. Configurar variables de entorno

```bash
cd n8n-gcp-tf

# Reemplaza con tu PROJECT_ID de GCP
export TF_VAR_project_id="tu-proyecto-gcp"
export TF_VAR_region="us-central1"
```

### 2. Autenticar en GCP

```bash
# Login en GCP
gcloud auth login
gcloud auth application-default login

# Configurar proyecto
gcloud config set project $TF_VAR_project_id

# Verificar billing habilitado
gcloud billing projects describe $TF_VAR_project_id --format="value(billingAccountName)"
```

### 3. Inicializar y aplicar Terraform

```bash
# Inicializar Terraform
terraform init

# Revisar el plan (revisa qué se va a crear)
terraform plan

# Aplicar cambios
terraform apply

# Confirmar con 'yes'
```

**Tiempo estimado de deployment: 5-10 minutos**

### 4. Obtener credenciales de acceso

Después del `terraform apply`, verás outputs como:

```bash
run_url = "https://n8n-xxxxx-uc.a.run.app"
basic_auth_user = "ed"
```

**Para obtener la contraseña de Basic Auth:**

```bash
# Obtener la contraseña
gcloud secrets versions access latest --secret="N8N_BASIC_AUTH_PASSWORD"
```

### 5. Acceder a n8n

1. Abre la URL de `run_url` en tu navegador
2. Ingresa:
   - Usuario: `ed`
   - Contraseña: (la que obtuviste del comando anterior)
3. Configura tu usuario administrador inicial

## 💰 Costo Estimado

- **Mensual:** $264-474 MXN (~$15-27 USD)
- **Por componente:**
  - Cloud Run (uso): $140-263 MXN
  - Cloud SQL: $153-210 MXN
  - Otros: $1-35 MXN

## 📂 Estructura del Proyecto

```
n8n-gcp-tf/
├── versions.tf       # Configuración de providers
├── variables.tf      # Variables del proyecto
├── main.tf          # APIs, Service Accounts, IAM
├── sql.tf           # Cloud SQL PostgreSQL
├── secrets.tf       # Secret Manager (credenciales)
├── run.tf           # Cloud Run service (n8n)
└── outputs.tf       # URLs y outputs
```

## 🔧 Configuración

### Variables principales:

- `project_id`: ID de tu proyecto GCP
- `region`: Región de despliegue (default: us-central1)
- `min_instances`: Instancias mínimas (default: 0 - ahorro)
- `max_instances`: Instancias máximas (default: 1)
- `db_tier`: Tier de Cloud SQL (default: db-f1-micro)
- `timezone`: Zona horaria (default: America/Mexico_City)

### Actualizar N8N_PUBLIC_URL (recomendado)

Después del primer deployment:

```bash
RUN_URL="https://n8n-xxxxx-uc.a.run.app"

gcloud run services update n8n \
  --region "$TF_VAR_region" \
  --set-env-vars N8N_PUBLIC_URL="$RUN_URL",N8N_EDITOR_BASE_URL="$RUN_URL",WEBHOOK_URL="$RUN_URL"
```

## 🛠️ Comandos útiles

### Ver logs

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=n8n" --limit 50
```

### Escalar instancias manualmente

```bash
gcloud run services update n8n --min-instances=1 --max-instances=3 --region=$TF_VAR_region
```

### Backup de la base de datos

Los backups automáticos están habilitados con PITR (Point-in-Time Recovery).

### Eliminar deployment

```bash
terraform destroy
```

## 🐛 Troubleshooting

### Cold start tardado

Si `min_instances=0`, el primer request después de inactividad puede tardar 10-30 segundos. Esto es normal y es el trade-off por ahorrar costos.

### Error de permisos

Verifica que tienes los siguientes roles en GCP:
- `roles/owner` o `roles/editor`
- `roles/iam.securityAdmin` (para IAM)
- `roles/resourcemanager.projectIamAdmin` (para IAM)

### Error de APIs no habilitadas

Las APIs se habilitan automáticamente, pero pueden tardar unos minutos. Espera 2-3 minutos después de `terraform apply` antes de preocuparte.

## 🔐 Seguridad

- **Basic Auth**: UI protegido con usuario/contraseña
- **HTTPS**: Conexiones encriptadas
- **Cloud SQL**: Sin IP pública, solo Cloud SQL connector
- **Secret Manager**: Credenciales almacenadas de forma segura
- **IAM**: Permisos mínimos necesarios

## 📚 Próximos Pasos

1. Configurar integraciones (Gmail, Gemini API, etc.)
2. Crear tus primeros workflows
3. Configurar tu primer agente (Janitor)
4. Monitorear costos en GCP Console

## 📞 Soporte

Para problemas o preguntas, consulta:
- [Documentación de n8n](https://docs.n8n.io/)
- [Documentación de Cloud Run](https://cloud.google.com/run/docs)
- [Foro de n8n](https://community.n8n.io/)

## Troubleshooting

### El servicio de Cloud Run no arranca o muestra errores 503

Al desplegar por primera vez, es posible que el contenedor de n8n arranque más rápido que la base de datos Cloud SQL. Esto puede causar errores de conexión (`Database is not ready!`).

- **Solución:** El `run.tf` incluye una "sonda de arranque" (`startup_probe`) y la variable de entorno `DB_POSTGRESDB_INIT_MAX_RETRIES` que le dan a n8n tiempo suficiente para esperar a que la base de datos esté lista y reintentar la conexión. Si el problema persiste, verifica los logs del servicio en la consola de Google Cloud para más detalles.





