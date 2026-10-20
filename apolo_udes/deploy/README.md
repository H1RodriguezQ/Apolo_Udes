# Preparación de despliegue — TAREA 12

Todo lo necesario para llevar el proyecto a producción. **Aquí no se ejecuta
nada solo**: los dos scripts empiezan en modo simulación y solo escriben si les
pasas `--aplicar`. Sin `--aplicar` hacen únicamente peticiones de lectura.

```
deploy/
├── README.md        ← este archivo (el orden de pasos)
├── limpieza.js      ← borra los datos de prueba (simulación por defecto)
├── arreglos.js      ← repara contadores e índices (simulación por defecto)
└── lista-borrar.json← listado generado por la simulación de limpieza.js
```

Requisitos: **Node 18+**, el CLI de Firebase y la cuenta de servicio del
proyecto en `claves/serviceAccount.json` (esa ruta se pasa como argumento: los
scripts no traen credenciales).

---

## Orden de ejecución

### 1. Verificar antes de tocar nada

```powershell
cd apolo_udes
flutter analyze                                                # 0 errores, 0 advertencias
flutter test test/validadores_graduando_test.dart              # 33 pruebas
powershell -NoProfile -ExecutionPolicy Bypass -File rules-tests\ejecutar.ps1   # 53 comprobaciones
```

Si alguna falla, **no se despliega nada**.

### 2. Compilar el APK (necesita JDK 17+)

```powershell
$env:JAVA_HOME = "$env:TEMP\opencode\jdk17"        # o tu propio JDK
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
flutter build apk --release
# Sale en: build\app\outputs\flutter-apk\app-release.apk
```

### 3. Preparar el hosting

```powershell
flutter build web --release     # genera build\web con las 5 páginas públicas
Remove-Item hosting -Recurse -Force -ErrorAction SilentlyContinue
robocopy build\web hosting /E /NFL /NDL /NJH /NJS
```

`firebase.json` ya apunta a `hosting/`. La carpeta está en `.gitignore`: es
artefacto de compilación, igual que `build/`.

### 4. Desplegar reglas + hosting

```powershell
firebase login                                                   # una vez
firebase deploy --only firestore:rules,hosting
```

Alternativa sin `firebase login`, usando la cuenta de servicio:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\apolo_udes_fix\claves\serviceAccount.json"
firebase deploy --only firestore:rules,hosting
```

> Las reglas se han probado contra el emulador (53 casos), pero **el emulador no
> valida los datos reales**: por eso el paso 5 existe.

### 5. Limpiar los datos de prueba (IRREVERSIBLE)

```powershell
cd apolo_udes
node deploy\limpieza.js ..\claves\serviceAccount.json            # simula y escribe lista-borrar.json
node deploy\limpieza.js ..\claves\serviceAccount.json --aplicar  # borra
```

Borra 36 documentos de prueba y conserva 19 (el graduando protegido
`8GikxFi3DOqkqUfe7u1m` con sus 2 cupos y sus 2 invitados, `configuracion`,
`directivos`, `usuarios` y `auditoria`). Antes de `--aplicar`, copia de
seguridad:

```powershell
gcloud firestore export gs://<bucket>/backup
```

### 6. Reparar lo que falta en los datos (no borra nada)

```powershell
node deploy\arreglos.js ..\claves\serviceAccount.json            # simula
node deploy\arreglos.js ..\claves\serviceAccount.json --aplicar  # aplica
```

| Arreglo | Motivo |
|---|---|
| `graduandos_publico/{id}.cuposUsados = 2` | Sin ese contador la página pública cree que van 0 cupos y vuelve a pedir el cupo 1, que ya existe → la regla lo rechaza y el registro público se queda sin responder. |
| `invitados_documentos/{grad}_{doc}` × 2 | El índice de unicidad no se reconstruyó con los datos viejos: sin él, las reglas no detectarían un invitado con la cédula ya usada. |

**El orden importa:** primero `limpieza.js` y después `arreglos.js`, para no
crear índices apuntando a invitados que se van a borrar.

---

## Comprobación final

1. `firebase emulators:exec` con `rules-tests\ejecutar.ps1` → 53/53.
2. Abrir `hosting/confirmar.html` y `hosting/invitados.html` en el navegador.
3. Comprobar en la app: Graduandos → Invitaciones → **anular** un invitado de
   prueba y ver que los cupos se renumeran sin huecos.
4. Botón **Cerrar jornada** → debe aparecer en la bitácora con los accesos del día.

## Rollback

- **Reglas:** `git show HEAD:apolo_udes/firestore.rules > firestore.rules` y
  volver a desplegar.
- **Hosting:** recompilar con la versión anterior y volver a desplegar.
- **Datos:** solo desde la copia de seguridad del paso 5.
