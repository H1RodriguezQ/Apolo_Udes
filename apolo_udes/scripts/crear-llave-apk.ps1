<#
  Crea la llave propia para firmar la APK de las tablets (se hace UNA vez).

  Uso, desde C:\Apolo-Udes\apolo_udes:
      powershell -ExecutionPolicy Bypass -File scripts\crear-llave-apk.ps1

  - La llave queda en C:\Apolo-Udes\claves\apolo-tablets.jks (carpeta que
    nunca se sube a GitHub).
  - Se crea android\key.properties con la ruta y la contraseña (también
    está en el .gitignore).
  - GUARDA UNA COPIA de la llave y la contraseña en otro lado (USB o
    gestor de contraseñas). Si se pierde, las tablets no aceptan
    actualizaciones firmadas con otra llave: toca desinstalar y reinstalar.
#>
$ErrorActionPreference = 'Stop'

$claves = 'C:\Apolo-Udes\claves'
$jks = Join-Path $claves 'apolo-tablets.jks'
$props = Join-Path $PSScriptRoot '..\android\key.properties'

if (Test-Path $jks) {
  Write-Host "Ya existe $jks. No se crea otra para no perder la anterior." -ForegroundColor Yellow
  exit 1
}

# keytool viene con el JDK 17 que usa Flutter.
$keytool = Get-ChildItem 'C:\Program Files\Microsoft' -Filter 'jdk-17*' -ErrorAction SilentlyContinue |
  ForEach-Object { Join-Path $_.FullName 'bin\keytool.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $keytool) { Write-Host 'No se encontró keytool (JDK 17).' -ForegroundColor Red; exit 2 }

New-Item -ItemType Directory -Force -Path $claves | Out-Null

$seguro = Read-Host 'Escribe una contraseña para la llave (mínimo 8 caracteres)' -AsSecureString
$clave = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro))
if ($clave.Length -lt 8) { Write-Host 'La contraseña es muy corta.' -ForegroundColor Red; exit 3 }

& $keytool -genkeypair -v -keystore $jks -storetype JKS -alias apolo -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass $clave -keypass $clave -dname 'CN=Apolo UDES, OU=Graduados, O=Universidad de Santander, L=Bucaramanga, C=CO'

@"
storePassword=$clave
keyPassword=$clave
keyAlias=apolo
storeFile=$($jks -replace '\\','/')
"@ | Set-Content -Encoding ASCII $props

Write-Host ''
Write-Host "Llave creada: $jks" -ForegroundColor Green
Write-Host 'Huella SHA-1 y SHA-256 (cópialas para restringir la llave de API Android):'
& $keytool -list -v -keystore $jks -alias apolo -storepass $clave | Select-String 'SHA1:|SHA256:'
