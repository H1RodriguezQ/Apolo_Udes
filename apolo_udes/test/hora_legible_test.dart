import 'package:flutter_test/flutter_test.dart';
import 'package:apolo_udes/core/constants/app_constants.dart';

void main() {
  test('la hora guardada se muestra en formato colombiano', () {
    expect(AppConstants.horaLegible('09:30 AM'), '9:30 a. m.');
    expect(AppConstants.horaLegible('12:00 PM'), '12:00 p. m.');
    expect(AppConstants.horaLegible('07:00 PM'), '7:00 p. m.');
  });
  test('un texto que no es hora se deja igual', () {
    expect(AppConstants.horaLegible('Por confirmar'), 'Por confirmar');
  });
}
