<#
  Compila Apolo para producción con las protecciones activadas.

  Uso, desde C:\Apolo-Udes\apolo_udes:
      powershell -ExecutionPolicy Bypass -File scripts\compilar.ps1 apk
      powershell -ExecutionPolicy Bypass -File scripts\compilar.ps1 web

  Qué agrega frente a un "flutter build" normal:
  - APK: código ofuscado (--obfuscate) para que sea más difícil de leer si
    alguien saca la APK de una tablet. Los símbolos para leer errores se
    guardan en C:\Apolo-Udes\claves\simbolos (no se suben).
  - App Check: si existen los archivos de C:\Apolo-Udes\claves, se pasan
    las claves al compilar (nunca quedan escritas en el código):
      appcheck-token.txt  -> token de depuración de las tablets
      recaptcha-key.txt   -> clave del sitio de reCAPTCHA v3 (web)
#>
param([Parameter(Mandatory)][ValidateSet('apk', 'web')] [string]$destino)
$ErrorActionPreference = 'Stop'

$claves = 'C:\Apolo-Udes\claves'
function Leer($nombre) {
  $f = Join-Path $claves $nombre
  if (Test-Path $f) { return (Get-Content $f -Raw).Trim() } else { return '' }
}

$extra = @()
if ($destino -eq 'apk') {
  $token = Leer 'appcheck-token.txt'
  if ($token) { $extra += "--dart-define=APPCHECK_TOKEN=$token"; Write-Host 'App Check: activado para tablets.' -ForegroundColor Green }
  else { Write-Host 'App Check: sin token, la APK sale sin App Check.' -ForegroundColor Yellow }
  if (-not (Test-Path (Join-Path $PSScriptRoot '..\android\key.properties'))) {
    Write-Host 'AVISO: no hay llave propia; corre primero scripts\crear-llave-apk.ps1' -ForegroundColor Yellow
  }
  $simbolos = Join-Path $claves 'simbolos'
  flutter build apk --release --obfuscate "--split-debug-info=$simbolos" @extra
} else {
  $clave = Leer 'recaptcha-key.txt'
  if ($clave) { $extra += "--dart-define=RECAPTCHA_KEY=$clave"; Write-Host 'App Check: activado para la web.' -ForegroundColor Green }
  else { Write-Host 'App Check: sin clave de reCAPTCHA, la web sale sin App Check.' -ForegroundColor Yellow }
  flutter build web --release @extra
}
