<#
  Corre las pruebas de carga (carga.js) contra el emulador de Firestore con
  las reglas REALES del proyecto. No toca la base de datos real.

  Uso (desde la carpeta apolo_udes):
      powershell -NoProfile -ExecutionPolicy Bypass -File pruebas-carga\ejecutar.ps1

  Requisitos: Node 18 o superior, Java 17+ y el CLI de Firebase.
#>
$ErrorActionPreference = 'Stop'

# Java: el emulador no arranca sin el. Se busca en el PATH, en JAVA_HOME y en
# los dos JDK que ya hay en este equipo.
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  $candidatos = @()
  if ($env:JAVA_HOME) { $candidatos += (Join-Path $env:JAVA_HOME 'bin') }
  $candidatos += (Get-ChildItem 'C:\Program Files\Microsoft' -Filter 'jdk-17*' -ErrorAction SilentlyContinue |
                  ForEach-Object { Join-Path $_.FullName 'bin' })
  $candidatos += 'C:\Users\PC HENRY\AppData\Local\Temp\opencode\jdk\jdk-21.0.12.1+1-jre\bin'
  foreach ($c in $candidatos) {
    if ($c -and (Test-Path (Join-Path $c 'java.exe'))) { $env:Path = "$c;$env:Path"; break }
  }
}
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  Write-Host 'No se encontro java: instala un JDK 17+ o define JAVA_HOME.' -ForegroundColor Red
  exit 2
}

$raiz = Split-Path -Parent $PSScriptRoot
Push-Location $raiz
try {
  firebase emulators:exec --only firestore --project demo-apolo 'node "pruebas-carga\carga.js"'
  $codigo = $LASTEXITCODE
} finally {
  Pop-Location
}

if ($codigo -eq 0) { Write-Host 'Pruebas de carga terminadas sin errores.' -ForegroundColor Green }
else { Write-Host "Las pruebas de carga encontraron fallos (codigo $codigo)." -ForegroundColor Red }
exit $codigo
