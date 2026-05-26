# 📋 SUSTIHORARIO

> **Sistema inteligente de gestión de sustituciones y guardias para centros educativos.**

---

## 🚀 ¿Qué es SUSTIHORARIO?

SUSTIHORARIO automatiza uno de los procesos más costosos de la gestión escolar: **coordinar quién cubre a quién cuando un profesor falta**. El sistema detecta ausencias, busca al sustituto más adecuado según disponibilidad y carga de trabajo, asigna la guardia automáticamente y notifica a todos los implicados — sin que el coordinador tenga que hacer nada a mano.

---

## ✨ Características principales

### Para el Coordinador
- **Gestión de bajas** — Tramita ausencias con fechas de inicio/fin y genera las guardias asociadas automáticamente.
- **Asignación inteligente** — El algoritmo busca al profesor disponible con menos guardias en la semana; si no hay nadie, activa un modo *fallback* y avisa al coordinador.
- **Panel de guardias** — Vista centralizada de todas las guardias asignadas y pendientes del centro.
- **Modelos de horario** — Crea, edita y asigna plantillas de horario a los profesores del centro.
- **Estadísticas** — Gráfico de barras con los profesores más activos, filtrable por semana, mes o año.
- **Gestión de usuarios** — Alta, baja y consulta de profesores y coordinadores del centro.
- **Configuración** — Define el límite semanal de guardias por profesor directamente desde la app.
- **Notificaciones** — Alertas en tiempo real sobre guardias sin asignar o asignaciones con fallback.

### Para el Profesor
- **Solicitar baja** — Proceso guiado para comunicar una ausencia con todos los datos necesarios.
- **Mis guardias** — Historial de guardias asignadas con opción de añadirlas al calendario del dispositivo.
- **Horario personal** — Visualización de clases fijas y tramos disponibles para guardia.
- **Mercado de intercambio** — Ofrece tus guardias al resto de compañeros o reclama las suyas.

### Para el Administrador
- **Gestión de centros** — Crea, edita y elimina centros educativos. El cambio de ID migra automáticamente todos los datos relacionados (usuarios, guardias, bajas, notificaciones).

---

## 🛠️ Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter (Dart) |
| Backend / Base de datos | Firebase Firestore |
| Autenticación | Firebase Auth |
| Notificaciones push | Firebase Cloud Messaging |
| Navegación | go_router |
| Estado | Provider + ChangeNotifier |
| Gráficas | fl_chart |
| Animaciones | flutter_animate |
| Calendario nativo | device_calendar |
| Zonas horarias | timezone |

---

## 🗂️ Estructura del proyecto

```
lib/
├── models/           # Modelos de datos (User, Horario, Centro)
├── pages/
│   ├── admin/        # Pantallas del administrador
│   ├── coordinador/  # Panel del coordinador (bajas, guardias, estadísticas...)
│   ├── profesor/     # Panel del profesor (guardias, horario, mercado...)
│   └── loginYregister/
├── providers/        # Estado global (usuarios, horario, tema)
├── routes/           # Configuración de rutas con go_router
├── services/         # Lógica de negocio (guardias, calendario, notificaciones)
└── main.dart
```

---

## ⚙️ Instalación y configuración

### 1. Clona el repositorio
```bash
git clone https://github.com/tu-usuario/sustihorario.git
cd sustihorario
```

### 2. Configura las variables de entorno
Crea un fichero `.env` en la raíz del proyecto:
```env
FIREBASE_API_KEY=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_PROJECT_ID=...
FIREBASE_STORAGE_BUCKET=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_APP_ID=...
FIREBASE_MEASUREMENT_ID=...
```

### 3. Instala dependencias
```bash
flutter pub get
```

### 4. Ejecuta la aplicación
```bash
flutter run
```

---

## 🔐 Roles de usuario

| Rol | Acceso |
|-----|--------|
| `admin` | Gestión global de centros |
| `coordinador` | Panel completo del centro (bajas, guardias, usuarios, config) |
| `profesor` | Sus guardias, horario, solicitudes y mercado de intercambio |

---

## 📱 Plataformas soportadas

Android · iOS · Web · Windows · macOS · Linux

---

## 📄 Licencia

Este proyecto se distribuye bajo la licencia MIT. Consulta el archivo `LICENSE` para más detalles.
