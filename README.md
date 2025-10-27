# n8n GCP Deployment - Configuración de Alta Disponibilidad

Este proyecto despliega n8n en Google Cloud Platform con una configuración optimizada para respuesta inmediata y alta disponibilidad, eliminando los "cold starts".

## 🏗️ Arquitectura Desplegada

Este repositorio utiliza Terraform para aprovisionar un ecosistema n8n robusto y listo para producción en Google Cloud Platform. La arquitectura se compone de los siguientes elementos clave:

- **Google Cloud Run**: Sirve la aplicación n8n, configurada con una instancia mínima para garantizar una respuesta inmediata y eliminar los "arranques en frío" (cold starts).
- **Google Cloud SQL**: Una instancia PostgreSQL (`db-f1-micro`) actúa como el backend de base de datos persistente para todos los workflows, credenciales y ejecuciones de n8n.
- **Google Secret Manager**: Almacena de forma segura todas las credenciales sensibles, como la clave de encriptación de n8n y las contraseñas de la base de datos.
- **IAM y Service Accounts**: Se configura una cuenta de servicio dedicada para n8n con los permisos mínimos necesarios para acceder a la base de datos y a los secretos, siguiendo el principio de mínimo privilegio.

---

## 🚀 Despliegue: Del Código a la Nube

El proceso de despliegue está totalmente automatizado con Terraform. Se divide en fases claras.

**Tiempo total estimado: 10-15 minutos.**

*La mayor parte de este tiempo es consumida por Google Cloud al aprovisionar la instancia de Cloud SQL por primera vez. Es una espera única durante la creación inicial.*

### Fase 1: Configuración del Entorno Local (1 minuto)

Antes de ejecutar Terraform, necesitamos configurar las variables de entorno que apuntarán a tu proyecto de GCP.

```bash
# Navega al directorio del proyecto
cd n8n-gcp-tf

# Reemplaza con tu PROJECT_ID de GCP
export TF_VAR_project_id="tu-proyecto-gcp"
export TF_VAR_region="us-central1"
```

### Fase 2: Autenticación con GCP (1 minuto)

Terraform actuará en tu nombre, por lo que necesita autenticarse con tus credenciales de `gcloud`.

```bash
# Inicia sesión en tu cuenta de Google
gcloud auth login
gcloud auth application-default login

# Establece tu proyecto como el objetivo por defecto
gcloud config set project $TF_VAR_project_id
```

### Fase 3: Aprovisionamiento de la Infraestructura con Terraform (8-13 minutos)

Esta es la fase principal. Terraform leerá todos los archivos `.tf`, entenderá la arquitectura completa y la construirá en GCP.

```bash
# 1. Inicializar Terraform
#    Descarga los plugins necesarios (providers) para interactuar con GCP.
terraform init

# 2. Planificar los Cambios (Opcional pero recomendado)
#    Muestra una simulación de los recursos que se crearán, sin aplicar nada aún.
#    Es el paso ideal para verificar que todo es correcto.
terraform plan

# 3. Aplicar el Plan y Construir
#    Este es el comando que inicia la construcción. Terraform te mostrará el plan
#    de nuevo y te pedirá una confirmación final.
terraform apply

#    Escribe "yes" cuando se te solicite para comenzar.
```

**¿Qué está sucediendo durante el `apply`?**
1.  **Habilitación de APIs:** Terraform se asegura de que las APIs de Cloud Run, Cloud SQL y Secret Manager estén activas en tu proyecto.
2.  **Creación de la Instancia SQL:** Se aprovisiona el servidor PostgreSQL. **Esta es la parte más tardada.**
3.  **Creación de Secretos:** Se generan y almacenan las contraseñas y claves en Secret Manager.
4.  **Despliegue de n8n:** Se configura y despliega el servicio de Cloud Run, conectándolo de forma segura a la base de datos y a los secretos.

### Fase 4: Acceso a tu Instancia de n8n (1 minuto)

Una vez que el `apply` termina, Terraform mostrará las URLs de acceso y las credenciales iniciales.

1.  **Obtén la URL y el Usuario:**
    La salida de Terraform mostrará algo como:
    ```
    run_url = "https://n8n-xxxxx-uc.a.run.app"
    basic_auth_user = "ed"
    ```

2.  **Obtén la Contraseña de Acceso:**
    La contraseña se almacena en Secret Manager. Obtenla con este comando:
    ```bash
    gcloud secrets versions access latest --secret="N8N_BASIC_AUTH_PASSWORD"
    ```

3.  **Accede y Configura:**
    Abre la `run_url` en tu navegador e ingresa con el usuario y la contraseña obtenidos. El primer paso será crear tu cuenta de administrador de n8n.

---

## 💰 Arquitectura de Costos (Estimación Mensual)

Esta configuración mantiene una instancia activa 24/7 para un rendimiento óptimo. Los costos se basan en la región `us-central1` y pueden variar.

| Componente                    | Especificación                               | Costo Estimado (USD) | Justificación                                                               |
| ----------------------------- | ---------------------------------------------- | -------------------- | --------------------------------------------------------------------------- |
| **Cloud Run Service**         | 1 instancia (1 vCPU, 512 MiB RAM) 24/7         | ~$66.35              | Costo principal por mantener la instancia siempre activa para respuesta inmediata. |
| **Cloud SQL Instance**        | `db-f1-micro`, 10 GB SSD, Backups habilitados | ~$11.58              | Servidor de base de datos PostgreSQL para persistencia de datos.            |
| **Servicios de Soporte**      | Secret Manager, Logging, Artifact Registry   | ~$0.00               | El uso proyectado se encuentra dentro del generoso free tier de GCP.        |
| **Network Egress**            | Tráfico de salida de Cloud Run                 | <$1.00               | Variable según el uso; típicamente bajo para desarrollo y pruebas.        |
| **Total Estimado**            |                                                | **~$78 USD / mes**   | **~1,326 MXN / mes** (a un tipo de cambio de 17.00)                        |


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
- `region`: Región de despliegue (default: `us-central1`)
- `min_instances`: Instancias mínimas (default: `1` - para alta disponibilidad)
- `max_instances`: Instancias máximas (default: `1`)
- `db_tier`: Tier de Cloud SQL (default: `db-f1-micro`)
- `timezone`: Zona horaria (default: `America/Mexico_City`)

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





