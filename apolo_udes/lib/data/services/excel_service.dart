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
  /// E: Programa | F: Facultad | G: Teléfono | H: Correo | I: Hora
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

      // En Android puede venir el path en lugar de bytes
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

      // Tomar la primera hoja del libro
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      // Saltar la primera fila (encabezados)
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        try {
          // Saltar filas vacías
          if (row.every((cell) => cell?.value == null)) continue;

          final codigo = _cellAsString(row, 0);
          final documento = _cellAsString(row, 1);
          final nombres = _cellAsString(row, 2);
          final apellidos = _cellAsString(row, 3);
          final programa = _cellAsString(row, 4);
          final facultad = _cellAsString(row, 5);
          final telefono = _cellAsString(row, 6);
          final correo = _cellAsString(row, 7);
          final hora = _cellAsString(row, 8);

          // Validaciones mínimas
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
              horaCeremonia: hora.isEmpty ? '08:00 AM' : hora,
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

  /// Genera un Excel de plantilla y lo comparte para que el usuario lo descargue
  static Future<bool> generarYCompartirPlantilla() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Graduandos'];

      // Encabezados
      final headers = [
        'Codigo Estudiantil',
        'Documento',
        'Nombres',
        'Apellidos',
        'Programa',
        'Facultad',
        'Telefono',
        'Correo',
        'Hora Ceremonia',
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

      // Ejemplos
      final ejemplos = [
        ['2019115023', '1098765432', 'Valentina', 'Ramírez Ortiz',
         'Medicina', 'Ciencias de la Salud', '3001234567',
         'v.ramirez@udes.edu.co', '08:00 AM'],
        ['2018223014', '1097654321', 'Carlos Andrés', 'Pérez González',
         'Ingeniería de Sistemas', 'Ingenierías y Arquitectura', '3109876543',
         'c.perez@udes.edu.co', '10:00 AM'],
        ['2019334521', '1096543210', 'Laura Sofía', 'Torres Méndez',
         'Administración de Empresas', 'Ciencias Económicas y Administrativas',
         '3154321098', 'l.torres@udes.edu.co', '02:00 PM'],
      ];

      for (int row = 0; row < ejemplos.length; row++) {
        for (int col = 0; col < ejemplos[row].length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
          );
          cell.value = TextCellValue(ejemplos[row][col]);
        }
      }

      // Borrar hoja por defecto
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.save();
      if (bytes == null) return false;

      // Guardar en el directorio temporal
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/plantilla_graduandos_apolo_udes.xlsx');
      await file.writeAsBytes(bytes);

      // Compartir
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

  // ── Helpers ──
  static String _cellAsString(List<Data?> row, int col) {
    if (col >= row.length) return '';
    final cell = row[col];
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }
}
