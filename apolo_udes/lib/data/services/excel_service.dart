import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  /// Permite al usuario seleccionar un archivo Excel y lo parsea
  /// Las columnas esperadas son:
  /// A: Código | B: Documento | C: Nombres | D: Apellidos |
  /// E: Programa | F: Facultad | G: Teléfono | H: Correo
  static Future<ExcelImportResult> importarGraduandos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return ExcelImportResult(
          success: false,
          message: 'No se seleccionó ningún archivo',
        );
      }

      final file = result.files.first;
      List<int>? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        return ExcelImportResult(
          success: false,
          message: 'No se pudo leer el archivo',
        );
      }

      final excel = Excel.decodeBytes(bytes);
      final graduandos = <Graduando>[];
      final errores = <String>[];

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        try {
          if (row.every((cell) => cell?.value == null)) continue;

          final codigo = _cellAsString(row, 0);
          final documento = _cellAsString(row, 1);
          final nombres = _cellAsString(row, 2);
          final apellidos = _cellAsString(row, 3);
          final programa = _cellAsString(row, 4);
          final facultad = _cellAsString(row, 5);
          final telefono = _cellAsString(row, 6);
          final correo = _cellAsString(row, 7);
          // Columna 8 (hora) se ignora — se asigna desde Firestore según facultad

          if (documento.isEmpty || nombres.isEmpty || apellidos.isEmpty) {
            errores.add('Fila ${i + 1}: documento, nombres o apellidos vacíos');
            continue;
          }

          graduandos.add(
            Graduando(
              id: 'XLSX${DateTime.now().millisecondsSinceEpoch}_$i',
              codigoEstudiantil: codigo,
              documento: documento,
              nombres: nombres,
              apellidos: apellidos,
              programa: programa.isEmpty ? 'Sin programa' : programa,
              facultad: facultad.isEmpty ? 'Sin facultad' : facultad,
              telefono: telefono,
              correo: correo,
              horaCeremonia: '08:00 AM', // Se actualiza desde Firestore según facultad
              estado: EstadoGraduando.activo,
            ),
          );
        } catch (e) {
          errores.add('Fila ${i + 1}: ${e.toString()}');
        }
      }

      return ExcelImportResult(
        success: true,
        message: 'Importación completada',
        graduandos: graduandos,
        errores: errores,
      );
    } catch (e) {
      return ExcelImportResult(
        success: false,
        message: 'Error al leer el archivo: ${e.toString()}',
      );
    }
  }

  /// Genera un Excel de plantilla y lo comparte
  static Future<bool> generarYCompartirPlantilla() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Graduandos'];

      final headers = [
        'Codigo Estudiantil',
        'Documento',
        'Nombres',
        'Apellidos',
        'Programa',
        'Facultad',
        'Telefono',
        'Correo',
      ];

      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#1A3A6B'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Sin filas de ejemplo — el usuario llena sus propios datos

      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

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

  static String _cellAsString(List<Data?> row, int col) {
    if (col >= row.length) return '';
    final cell = row[col];
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }
}