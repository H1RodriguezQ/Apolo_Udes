import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/validators/validadores_graduando.dart';
import '../models/models.dart';

class ExcelImportResult {
  final bool success;
  final String message;
  final List<Graduando> graduandos;
  final List<String> errores;

  ExcelImportResult({
    required this.success,
    required this.message,
    this.graduandos = const [],
    this.errores = const [],
  });
}

class ExcelService {
  /// Límite de filas por archivo, para que un Excel enorme no bloquee la app.
  static const _maxFilas = 2000;

  /// Columnas esperadas:
  /// A: Código | B: Documento | C: Nombres | D: Apellidos |
  /// E: Programa | F: Facultad | G: Teléfono | H: Correo
  ///
  /// Cada fila pasa por las MISMAS validaciones del formulario de "Agregar
  /// graduando". Las filas que no cumplen se rechazan con su motivo.
  static Future<ExcelImportResult> importarGraduandos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return ExcelImportResult(success: false, message: 'No se seleccionó ningún archivo');
      }

      final file = result.files.first;
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        return ExcelImportResult(success: false, message: 'No se pudo leer el archivo');
      }

      final excel = Excel.decodeBytes(bytes);
      final graduandos = <Graduando>[];
      final errores = <String>[];

      final sheet = excel.tables[excel.tables.keys.first]!;

      if (sheet.rows.length - 1 > _maxFilas) {
        return ExcelImportResult(
          success: false,
          message: 'El archivo tiene más de $_maxFilas filas. Divídelo en varios archivos.',
        );
      }

      final documentosVistos = <String>{};
      final codigosVistos = <String>{};

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final fila = i + 1; // número de fila como se ve en Excel
        try {
          if (row.every((cell) => cell?.value == null)) continue;

          final codigo = _normalizarCodigo(_cellAsString(row, 0));
          final documento = _soloDigitos(_cellAsString(row, 1));
          final nombres = limpiarEspacios(_cellAsString(row, 2));
          final apellidos = limpiarEspacios(_cellAsString(row, 3));
          final programaTexto = _cellAsString(row, 4);
          final facultadTexto = _cellAsString(row, 5);
          final telefono = _soloDigitos(_cellAsString(row, 6));
          final correo = _cellAsString(row, 7).toLowerCase();

          // 1. Mismas reglas que el formulario.
          final problemas = <String>[];
          void revisar(String campo, String? error) {
            if (error != null) problemas.add('$campo: $error');
          }
          revisar('código', validarCodigoUdes(codigo));
          revisar('documento', validarDocumento(documento));
          revisar('nombres', validarNombrePersona(nombres));
          revisar('apellidos', validarNombrePersona(apellidos));
          revisar('teléfono', validarTelefono(telefono));
          revisar('correo', validarCorreo(correo));

          // 2. Facultad y programa deben existir en el catálogo de la app.
          final facultad = _buscarEnCatalogo(facultadTexto, AppConstants.facultades);
          String? programa;
          if (facultad == null) {
            problemas.add(facultadTexto.isEmpty
                ? 'facultad: Requerida'
                : 'facultad: "$facultadTexto" no existe');
          } else {
            programa = _buscarEnCatalogo(
                programaTexto, AppConstants.programasPorFacultad[facultad] ?? const []);
            if (programa == null) {
              problemas.add(programaTexto.isEmpty
                  ? 'programa: Requerido'
                  : 'programa: "$programaTexto" no pertenece a $facultad');
            }
          }

          // 3. Repetidos dentro del mismo archivo.
          if (documento.isNotEmpty && !documentosVistos.add(documento)) {
            problemas.add('documento $documento repetido en el archivo');
          }
          if (codigo.isNotEmpty && !codigosVistos.add(codigo)) {
            problemas.add('código $codigo repetido en el archivo');
          }

          if (problemas.isNotEmpty) {
            errores.add('Fila $fila: ${problemas.join('; ')}');
            continue;
          }

          graduandos.add(Graduando(
            // ID aleatorio: el enlace público de invitados usa este ID, así
            // que no debe poder adivinarse (antes era 'XLSX' + la hora).
            id: FirebaseFirestore.instance.collection('graduandos').doc().id,
            codigoEstudiantil: codigo,
            documento: documento,
            nombres: nombres,
            apellidos: apellidos,
            programa: programa!,
            facultad: facultad!,
            telefono: telefono,
            correo: correo,
            horaCeremonia: '08:00 AM', // Se actualiza desde Firestore según facultad
            estado: EstadoGraduando.activo,
          ));
        } catch (e) {
          errores.add('Fila $fila: no se pudo leer ($e)');
        }
      }

      return ExcelImportResult(
        success: true,
        message: 'Importación completada',
        graduandos: graduandos,
        errores: errores,
      );
    } catch (e) {
      return ExcelImportResult(success: false, message: 'Error al leer el archivo: $e');
    }
  }

  /// Genera la plantilla con una hoja "Instrucciones" que explica el formato
  /// y lista las facultades y programas válidos.
  static Future<bool> generarYCompartirPlantilla() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Graduandos'];

      final headers = [
        'Codigo Estudiantil', 'Documento', 'Nombres', 'Apellidos',
        'Programa', 'Facultad', 'Telefono', 'Correo',
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#1A3A6B'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      final ins = excel['Instrucciones'];
      var fila = 0;
      void escribir(String texto, {bool negrita = false}) {
        final cell = ins.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: fila++));
        cell.value = TextCellValue(texto);
        if (negrita) cell.cellStyle = CellStyle(bold: true);
      }

      escribir('Formato de cada columna', negrita: true);
      escribir('Código: 11 dígitos. Empieza por $prefijoCodigoUdes (sede principal Bucaramanga), seguido de 2 dígitos del año de ingreso y 7 del consecutivo.');
      escribir('Documento: solo números, de 6 a 12 dígitos, sin puntos. No empieza por 0.');
      escribir('Nombres y Apellidos: solo letras.');
      escribir('Teléfono: celular de 10 dígitos (3XXXXXXXXX) o fijo (60XXXXXXXX).');
      escribir('Correo: formato usuario@dominio.com');
      escribir('Facultad y Programa: escribirlos como aparecen abajo.');
      escribir('Importante: formatea Código, Documento y Teléfono como TEXTO para no perder los ceros iniciales.');
      fila++;
      escribir('Facultades y programas válidos', negrita: true);
      for (final f in AppConstants.facultades) {
        escribir(f, negrita: true);
        for (final p in AppConstants.programasPorFacultad[f] ?? const <String>[]) {
          escribir('    $p');
        }
      }

      if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1');

      final bytes = excel.save();
      if (bytes == null) return false;

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/plantilla_graduandos_apolo_udes.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Plantilla Graduandos - Apolo UDES',
        text: 'Plantilla Excel para importar graduandos al sistema Apolo UDES',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Lectura de celdas ──

  /// Texto de la celda. Los enteros se devuelven sin ".0" (Excel guarda
  /// 1098765432 como 1098765432.0).
  static String _cellAsString(List<Data?> row, int col) {
    if (col >= row.length) return '';
    final v = row[col]?.value;
    if (v == null) return '';
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
    }
    return v.toString().trim();
  }

  /// Quita puntos, espacios y guiones: "1.098.765.432" -> "1098765432".
  static String _soloDigitos(String v) => v.replaceAll(RegExp(r'[\s.\-]'), '');

  /// Si la celda del código estaba como número, Excel borra el 0 inicial
  /// (01AANNNNNNN -> 1AANNNNNNN). Se recupera solo en ese caso exacto.
  static String _normalizarCodigo(String v) {
    final t = _soloDigitos(v);
    if (RegExp(r'^\d+$').hasMatch(t) &&
        t.length == largoCodigoUdes - 1 &&
        '0$t'.startsWith(prefijoCodigoUdes)) {
      return '0$t';
    }
    return t;
  }

  /// Busca sin distinguir mayúsculas ni tildes y devuelve el nombre oficial.
  static String? _buscarEnCatalogo(String texto, List<String> catalogo) {
    final buscado = _sinTildes(limpiarEspacios(texto).toLowerCase());
    if (buscado.isEmpty) return null;
    for (final opcion in catalogo) {
      if (_sinTildes(opcion.toLowerCase()) == buscado) return opcion;
    }
    return null;
  }

  static String _sinTildes(String s) {
    const con = 'áéíóúüñ';
    const sin = 'aeiouun';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = con.indexOf(ch);
      b.write(i >= 0 ? sin[i] : ch);
    }
    return b.toString();
  }
}