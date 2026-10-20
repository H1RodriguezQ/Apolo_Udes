# ============================================================================
# Pruebas de firestore.rules (capa 2 de validacion)
#
# Se ejecuta DENTRO de `firebase emulators:exec`, contra el emulador de
# Firestore con las reglas REALES del proyecto. No toca datos de produccion.
#
# Como se emula la autenticacion:
#   * El emulador acepta JWT con "alg":"none" y toma `sub` como uid; asi se
#     prueba cada rol sin necesitar el emulador de Auth.
#   * `Bearer owner` es la llave de administrador del emulador (siembra).
# Los perfiles `usuarios/{uid}` se siembran con owner: las reglas leen el rol
# desde ahi, y sin perfil `esStaff()` es falso.
#
# IDs con marca de tiempo (`$run`): la suite se puede repetir aunque el
# emulador conserve los datos entre arranques.
# ============================================================================

$ErrorActionPreference = 'Stop'

$base = 'http://localhost:8080/v1/projects/demo-apolo/databases/(default)/documents'
$ruta = 'projects/demo-apolo/databases/(default)/documents'
$run = [DateTime]::UtcNow.Ticks

# --- autenticacion ----------------------------------------------------------
function B64Url([string]$s) {
  [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}
$ahora = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$cabecera = B64Url '{"alg":"none","typ":"JWT"}'
function Jwt([string]$sub) {
  $carga = '{"sub":"' + $sub + '","aud":"demo-apolo","iat":' + $ahora + ',"exp":' + ($ahora + 86400) + '}'
  return $cabecera + '.' + (B64Url $carga) + '.'
}

# --- valores de campo REST --------------------------------------------------
function S([string]$v) { return @{ stringValue = $v } }
function N([int]$v) { return @{ integerValue = "$v" } }
function Mas([hashtable]$a, [hashtable]$b) {
  $r = @{}
  foreach ($k in $a.Keys) { $r[$k] = $a[$k] }
  foreach ($k in $b.Keys) { $r[$k] = $b[$k] }
  return $r
}

# --- HTTP contra el emulador ------------------------------------------------
function Http([string]$m, [string]$u, [string]$json, [string]$token) {
  $h = @{}
  if ($token) { $h['Authorization'] = "Bearer $token" }
  # GET sin cuerpo: si se le pasa `-Body ''` el cliente intenta enviar
  # contenido con un verbo que no lo admite (ProtocolViolationException).
  $p = @{ Uri = $u; Method = $m; Headers = $h; UseBasicParsing = $true; TimeoutSec = 30 }
  if ($json) {
    $p['ContentType'] = 'application/json'
    $p['Body'] = $json
  }
  try {
    $r = Invoke-WebRequest @p
    return [int]$r.StatusCode
  } catch {
    # -2 = el cliente ni siquiera llego al servidor (para depurar).
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode.value__ }
    return -2
  }
}
function RutaDoc([string]$c, [string]$id) { return "$base/$c/$id" }
function Leer([string]$c, [string]$id, [string]$t) { return Http GET (RutaDoc $c $id) $null $t }
function Listar([string]$c, [string]$t) { return Http GET "$base/$c" $null $t }
function Escribir([string]$c, [string]$id, [hashtable]$campos, [string]$t) {
  $json = @{ fields = $campos } | ConvertTo-Json -Depth 15 -Compress
  return Http PATCH (RutaDoc $c $id) $json $t
}
function Borrar([string]$c, [string]$id, [string]$t) { return Http DELETE (RutaDoc $c $id) $null $t }
function Commit($escrituras, [string]$t) {
  $partes = @()
  foreach ($w in @($escrituras)) { $partes += ($w | ConvertTo-Json -Depth 15 -Compress) }
  $json = '{"writes":[' + ($partes -join ',') + ']}'
  return Http POST "${base}:commit" $json $t
}
# Hora del servidor: en REST no existe `serverTimestamp` directo. Van DOS
# escrituras sobre el MISMO documento en el mismo commit: primero los campos
# y luego el transform (en el proto Write.update y Write.transform son
# excluyentes, y el transform necesita que el documento ya exista).
function ConFecha([string]$c, [string]$id, [hashtable]$campos, [string]$campo) {
  $n = "$ruta/$c/$id"
  return @(
    @{ update = @{ name = $n; fields = $campos } },
    @{ transform = @{ document = $n; fieldTransforms = @(@{ fieldPath = $campo; setToServerValue = 'REQUEST_TIME' }) } }
  )
}

# Lote completo de registro publico: cupo + indice unico + invitado (hora del
# servidor) + contador publico. Las reglas miran el estado final del lote,
# asi que entran o salen juntos.
function Lote([string]$g, [string]$inv, [string]$docPorDefecto, [hashtable]$extra) {
  $campos = @{
    id = S $inv; graduandoId = S $g; graduandoNombre = S 'Graduando Prueba'
    nombreInvitado = S 'Maria Fernanda'; correoInvitado = S 'invitado@prueba.co'
    documento = S $docPorDefecto; tipo = S 'principal'; estado = S 'pendiente'
    cupo = N 1
  }
  $campos = Mas $campos $extra
  $doc = $campos.documento.stringValue
  $invPath = "$ruta/invitados/$inv"
  return @(
    @{ update = @{ name = "$ruta/cupos/${g}_1"; fields = @{ graduandoId = S $g; invitadoId = S $inv; numero = N 1 } } },
    @{ update = @{ name = "$ruta/invitados_documentos/${g}_${doc}"; fields = @{ graduandoId = S $g; documento = S $doc; invitadoId = S $inv } } },
    @{ update = @{ name = $invPath; fields = $campos } },
    @{ transform = @{ document = $invPath; fieldTransforms = @(@{ fieldPath = 'fechaRegistro'; setToServerValue = 'REQUEST_TIME' }) } },
    @{ update = @{ name = "$ruta/graduandos_publico/$g"; fields = @{ nombre = S 'Graduando Prueba'; invitadosPermitidos = N 2; cuposUsados = N 1 } } }
  )
}

# --- comprobaciones ---------------------------------------------------------
$hechos = 0
$fallos = 0
function Comprobar([string]$nombre, [int]$obtenido, [int]$esperado) {
  $script:hechos++
  if ($obtenido -eq $esperado) { "  [OK]    $nombre -> HTTP $obtenido" }
  else { $script:fallos++; "  [FALLO] $nombre -> esperado HTTP $esperado y salio HTTP $obtenido" }
}

# --- usuarios de prueba -----------------------------------------------------
$anon = $null
$owner = 'owner'
$uidAdmin = 'adm-test'; $uidOp = 'ope-test'; $uidCon = 'con-test'; $uidInac = 'inac-test'
$tAdmin = Jwt $uidAdmin
$tOp = Jwt $uidOp
$tCon = Jwt $uidCon
$tInac = Jwt $uidInac
$tSinPerfil = Jwt 'sin-perfil'

# --- siembra (siempre con owner: no pasa por las reglas) --------------------
Comprobar 'siembra: perfil de administrador' (Escribir usuarios $uidAdmin @{ rol = S 'admin'; estado = S 'activo'; correo = S 'admin@test.co'; nombre = S 'Admin Test' } $owner) 200
$null = Escribir usuarios $uidOp @{ rol = S 'operador'; estado = S 'activo'; correo = S 'op@test.co'; nombre = S 'Operador Test'; puntoValidacion = S 'Puerta 1' } $owner
$null = Escribir usuarios $uidCon @{ rol = S 'consulta'; estado = S 'activo'; correo = S 'con@test.co'; nombre = S 'Consulta Test' } $owner
$null = Escribir usuarios $uidInac @{ rol = S 'consulta'; estado = S 'inactivo'; correo = S 'inac@test.co'; nombre = S 'Inactivo Test' } $owner

$gA = "ga-$run"
$gB = "gb-$run"
foreach ($g in @($gA, $gB)) {
  $null = Escribir graduandos $g @{ nombre = S 'Graduando Prueba'; invitadosPermitidos = N 2 } $owner
  $null = Escribir graduandos_publico $g @{ nombre = S 'Graduando Prueba'; invitadosPermitidos = N 2; cuposUsados = N 0 } $owner
}
$null = Escribir configuracion 'evento' @{ lugar = S 'Auditorio Prueba'; ciudad = S 'Bucaramanga' } $owner

$docSemilla = '10' + (($run % 999983).ToString().PadLeft(6, '7'))
$invSemilla = "inv-$run"
$null = Escribir invitados $invSemilla @{
  id = S $invSemilla; graduandoId = S $gA; graduandoNombre = S 'Graduando Prueba'
  nombreInvitado = S 'Invitado Semilla'; correoInvitado = S 'semilla@test.co'
  documento = S $docSemilla; tipo = S 'principal'; estado = S 'pendiente'; cupo = N 0
} $owner

# ============================================================================
# A. Denegacion por defecto y documentos publicos
# ============================================================================
''
'A. Denegacion por defecto y documentos publicos'
Comprobar 'anonimo no lee graduandos' (Leer graduandos $gA $anon) 403
Comprobar 'anonimo no lista graduandos' (Listar graduandos $anon) 403
Comprobar 'anonimo si lee graduandos_publico' (Leer graduandos_publico $gA $anon) 200
Comprobar 'anonimo no lista graduandos_publico' (Listar graduandos_publico $anon) 403
Comprobar 'anonimo si lee la configuracion del evento' (Leer configuracion 'evento' $anon) 200
Comprobar 'anonimo no lista configuracion' (Listar configuracion $anon) 403
Comprobar 'anonimo si lee un invitado (pagina de confirmacion)' (Leer invitados $invSemilla $anon) 200
Comprobar 'anonimo no lista invitados' (Listar invitados $anon) 403
Comprobar 'anonimo no lee perfiles' (Leer usuarios $uidAdmin $anon) 403
Comprobar 'anonimo no lista perfiles' (Listar usuarios $anon) 403

# ============================================================================
# B. Roles sobre graduandos
# ============================================================================
''
'B. Roles sobre graduandos'
Comprobar 'rol consulta si lista graduandos' (Listar graduandos $tCon) 200
Comprobar 'rol operador si lista graduandos' (Listar graduandos $tOp) 200
Comprobar 'rol operador NO crea graduandos' (Escribir graduandos "g-op-$run" @{ nombre = S 'x' } $tOp) 403
Comprobar 'rol admin si crea graduandos' (Escribir graduandos "g-adm-$run" @{ nombre = S 'x' } $tAdmin) 200
Comprobar 'perfil inactivo no lee nada' (Listar graduandos $tInac) 403
Comprobar 'usuario autenticado sin perfil no lee nada' (Listar graduandos $tSinPerfil) 403

# ============================================================================
# C. Configuracion
# ============================================================================
''
'C. Configuracion'
Comprobar 'operador no escribe configuracion' (Escribir configuracion 'evento' @{ lugar = S 'Otro' } $tOp) 403
Comprobar 'admin si escribe configuracion' (Escribir configuracion 'evento' @{ lugar = S 'Auditorio Prueba'; ciudad = S 'Bucaramanga' } $tAdmin) 200

# ============================================================================
# D. Perfiles de usuario
# ============================================================================
''
'D. Perfiles de usuario'
Comprobar 'rol consulta no lee perfiles ajenos' (Leer usuarios $uidAdmin $tCon) 403
Comprobar 'admin si lee perfiles' (Leer usuarios $uidOp $tAdmin) 200
Comprobar 'admin crea usuario valido' (Escribir usuarios "u-$run" @{ rol = S 'consulta'; estado = S 'activo'; nombre = S 'Nuevo Usuario'; correo = S 'nuevo@test.co' } $tAdmin) 200
Comprobar 'admin no crea usuario con correo invalido' (Escribir usuarios "u-bad-$run" @{ rol = S 'consulta'; estado = S 'activo'; nombre = S 'Nuevo'; correo = S 'no-es-correo' } $tAdmin) 403
Comprobar 'admin no crea operador sin punto de validacion' (Escribir usuarios "u-op-$run" @{ rol = S 'operador'; estado = S 'activo'; nombre = S 'Op Nuevo'; correo = S 'opnuevo@test.co' } $tAdmin) 403
Comprobar 'operador no crea usuarios' (Escribir usuarios "u-o-$run" @{ rol = S 'consulta'; estado = S 'activo'; nombre = S 'X'; correo = S 'x@test.co' } $tOp) 403
Comprobar 'admin no se borra a si mismo' (Borrar usuarios $uidAdmin $tAdmin) 403
Comprobar 'admin si borra otro usuario' (Borrar usuarios "u-$run" $tAdmin) 200

# ============================================================================
# E. Validaciones (solo insercion y solo el propio punto)
# ============================================================================
''
'E. Validaciones'
$valId = "val-$run"
$camposVal = @{
  codigo = S 'QR123'; nombre = S 'Invitado Prueba'; tipo = S 'qr'; resultado = S 'valido'
  puntoValidacion = S 'Puerta 1'; operadorId = S $uidOp; operadorCorreo = S 'op@test.co'
}
Comprobar 'operador registra una validacion en SU punto' (Commit (ConFecha validaciones $valId $camposVal 'timestamp') $tOp) 200
Comprobar 'operador no valida en un punto ajeno' (Commit (ConFecha validaciones "val-x-$run" (Mas $camposVal @{ puntoValidacion = S 'Otro punto' }) 'timestamp') $tOp) 403
Comprobar 'operador no puede firmar la validacion con uid ajeno' (Commit (ConFecha validaciones "val-u-$run" (Mas $camposVal @{ operadorId = S 'otro-uid' }) 'timestamp') $tOp) 403
Comprobar 'rol consulta no registra validaciones' (Commit (ConFecha validaciones "val-c-$run" $camposVal 'timestamp') $tCon) 403
Comprobar 'nadie modifica una validacion (sin repudio)' (Escribir validaciones $valId @{ resultado = S 'invalido' } $tAdmin) 403
Comprobar 'nadie borra una validacion (sin repudio)' (Borrar validaciones $valId $tAdmin) 403

# ============================================================================
# F. Bitacora de auditoria
# ============================================================================
''
'F. Bitacora de auditoria'
$audId = "aud-$run"
$camposAud = @{
  autorId = S $uidAdmin; autorCorreo = S 'admin@test.co'; autorRol = S 'Administrador'
  accion = S 'Prueba de reglas'; detalle = S 'rules-tests'; tipo = S 'prueba'
}
Comprobar 'admin deja un registro en la bitacora' (Commit (ConFecha auditoria $audId $camposAud 'fecha') $tAdmin) 200
Comprobar 'la bitacora rechaza campos de mas' (Commit (ConFecha auditoria "aud-x-$run" (Mas $camposAud @{ extra = S 'x' }) 'fecha') $tAdmin) 403
Comprobar 'la bitacora rechaza un autor ajeno' (Commit (ConFecha auditoria "aud-a-$run" (Mas $camposAud @{ autorId = S 'otro-uid' }) 'fecha') $tAdmin) 403
Comprobar 'rol consulta tambien puede registrar en la bitacora' (Commit (ConFecha auditoria "aud-c-$run" (Mas $camposAud @{ autorId = S $uidCon }) 'fecha') $tCon) 200
Comprobar 'operador no consulta la bitacora' (Listar auditoria $tOp) 403
Comprobar 'admin si consulta la bitacora' (Listar auditoria $tAdmin) 200
Comprobar 'la bitacora no admite actualizaciones' (Escribir auditoria $audId @{ detalle = S 'editado' } $tAdmin) 403

# ============================================================================
# G. Solicitudes de correo (solo el administrador y solo peticion nueva)
# ============================================================================
''
'G. Solicitudes de correo'
$solCampos = @{
  tipo = S 'campana'; titulo = S 'Recordatorio'; mensaje = S 'Mensaje de prueba'
  destinatarios = S 'todos'; estado = S 'pendiente'; enviados = N 0; creadoPor = S 'admin@test.co'
}
Comprobar 'admin crea una solicitud masiva' (Commit (ConFecha solicitudes_correo "sol-$run" $solCampos 'fecha') $tAdmin) 200
Comprobar 'individual sin destinatario concreto se rechaza' (Commit (ConFecha solicitudes_correo "sol-i-$run" (Mas $solCampos @{ destinatarios = S 'individual' }) 'fecha') $tAdmin) 403
Comprobar 'titulo con salto de linea se rechaza' (Commit (ConFecha solicitudes_correo "sol-n-$run" (Mas $solCampos @{ titulo = S "Asunto`nOtro asunto" }) 'fecha') $tAdmin) 403
Comprobar 'operador no puede pedir correos' (Commit (ConFecha solicitudes_correo "sol-o-$run" $solCampos 'fecha') $tOp) 403
Comprobar 'la solicitud no se puede marcar como enviada' (Escribir solicitudes_correo "sol-$run" @{ estado = S 'enviado' } $tAdmin) 403

# ============================================================================
# H. Registro publico de invitados (pagina sin sesion)
# ============================================================================
''
'H. Registro publico de invitados'
$docA = '10' + (($run % 999911).ToString().PadLeft(6, '8'))
$docB = '11' + (($run % 999887).ToString().PadLeft(6, '9'))
$invA = "inva-$run"
Comprobar 'pagina publica: el lote completo ocupa el cupo 1' (Commit (Lote $gA $invA $docA @{}) $anon) 200
Comprobar 'no se sube el contador sin que exista el cupo' (Commit (@{ update = @{ name = "$ruta/graduandos_publico/$gB"; fields = @{ nombre = S 'Graduando Prueba'; invitadosPermitidos = N 2; cuposUsados = N 1 } } }) $anon) 403
Comprobar 'nombre con etiquetas HTML se rechaza' (Commit (Lote $gB "invb-$run" $docB @{ nombreInvitado = S '<script>alert(1)</script>' }) $anon) 403
Comprobar 'correo con puntos dobles se rechaza' (Commit (Lote $gB "invc-$run" $docB @{ correoInvitado = S 'a..b@prueba.co' }) $anon) 403
Comprobar 'documento que empieza por 0 se rechaza' (Commit (Lote $gB "invd-$run" $docB @{ documento = S '0123456' }) $anon) 403

Comprobar 'el invitado confirma su asistencia UNA sola vez' (Commit (@{ update = @{ name = "$ruta/invitados/$invA"; fields = @{ confirmacion = S 'confirmado' } }; updateMask = @{ fieldPaths = @('confirmacion') } }) $anon) 200
Comprobar 'la segunda confirmacion se rechaza' (Commit (@{ update = @{ name = "$ruta/invitados/$invA"; fields = @{ confirmacion = S 'rechazado' } }; updateMask = @{ fieldPaths = @('confirmacion') } }) $anon) 403
Comprobar 'al confirmar no se puede cambiar otro campo' (Commit (@{ update = @{ name = "$ruta/invitados/$invA"; fields = @{ nombreInvitado = S 'Otro Nombre' } }; updateMask = @{ fieldPaths = @('nombreInvitado') } }) $anon) 403

# ============================================================================
''
"[RESUMEN] $hechos comprobaciones, $fallos fallos"
if ($fallos -gt 0) { exit 1 }
exit 0
