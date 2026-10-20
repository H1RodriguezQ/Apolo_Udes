<#
  Ejecuta las pruebas de firestore.rules (capa 2) contra el emulador de
  Firestore, con las reglas REALES del proyecto y sin tocar produccion.

  Uso (desde cualquier sitio):
      powershell -NoProfile -ExecutionPolicy Bypass -File rules-tests\ejecutar.ps1

  Requisitos: Java 17+ (para el emulador) y el CLI de Firebase.
  Sale con codigo distinto de 0 si alguna comprobacion falla.
#>
$ErrorActionPreference = 'Stop'
$codigo = 1

# 1) Java: sin el no arranca el emulador. Se busca en el PATH, en JAVA_HOME,
#    en APPOLO_JAVA_HOME y, como ultimo recurso, en un JRE portatil.
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  $candidatos = @()
  if ($env:JAVA_HOME) { $candidatos += (Join-Path $env:JAVA_HOME 'bin') }
  if ($env:APPOLO_JAVA_HOME) { $candidatos += (Join-Path $env:APPOLO_JAVA_HOME 'bin') }
  $candidatos += 'C:\Users\PC HENRY\AppData\Local\Temp\opencode\jdk\jdk-21.0.12.1+1-jre\bin'
  foreach ($c in $candidatos) {
    if ($c -and (Test-Path (Join-Path $c 'java.exe'))) { $env:Path = "$c;$env:Path"; break }
  }
}
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  Write-Host 'No se encontro java: instala un JRE 17+ o define JAVA_HOME.' -ForegroundColor Red
  exit 2
}
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Host 'No se encontro el CLI de Firebase (npm install -g firebase-tools).' -ForegroundColor Red
  exit 2
}

# 2) Se corre desde la raiz del proyecto con el firebase.json del PROYECTO
#    (el mismo que usa el despliegue), porque la CLI de Firebase no permite
#    que las reglas queden fuera de la carpeta del archivo de configuracion.
#    Los logs del emulador (`*.log`) ya estan cubiertos por el .gitignore.
$raiz = Split-Path -Parent $PSScriptRoot
$scriptRel = 'rules-tests\casos.ps1'
# Las comillas van DENTRO de la cadena: firebase tokeniza el comando y el
# trayecto de este equipo contiene espacios.
$comando = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $scriptRel + '"'

Push-Location $raiz
try {
  firebase emulators:exec --only firestore --project demo-apolo $comando
  $codigo = $LASTEXITCODE
} finally {
  Pop-Location
}

if ($codigo -eq 0) { Write-Host 'Todas las comprobaciones de reglas pasaron.' -ForegroundColor Green }
else { Write-Host "Hubo fallos en las reglas (codigo $codigo)." -ForegroundColor Red }
exit $codigo
