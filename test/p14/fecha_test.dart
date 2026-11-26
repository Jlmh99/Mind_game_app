// Práctica 14: fechas del servidor.
// El backend (Render, JVM en UTC) manda LocalDateTime.now() SIN zona
// ("2026-11-26T17:15:42.123456"). La app debe tomarlo como UTC y mostrarlo en
// la hora del teléfono. Estas pruebas no dependen de la zona horaria de la
// máquina: el CI de GitHub corre en UTC y la PC de desarrollo en UTC-6, así
// que lo esperado de "hora local" se calcula aquí mismo con toLocal().
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/formato.dart';
import 'package:mindgames_app/data/incidencias_repository.dart';
import 'package:mindgames_app/data/mensajes_repository.dart';
import 'package:mindgames_app/data/partidas_repository.dart';
import 'package:mindgames_app/features/incidencias/chat/widgets/burbuja_chat.dart';

String dos(int n) => n.toString().padLeft(2, '0');

void main() {
  group('P14 fechas: fechaDelServidor', () {
    test('P14-FECHA: sin zona -> se interpreta como UTC', () {
      final f = fechaDelServidor('2026-11-26T17:15:42.123456');
      expect(f.isUtc, isTrue);
      expect(f, DateTime.utc(2026, 11, 26, 17, 15, 42, 123, 456));
    });

    test('P14-FECHA: con "Z" o con desfase -> se respeta y queda en UTC', () {
      final esperado = DateTime.utc(2026, 11, 26, 17, 15, 42);
      for (final texto in [
        '2026-11-26T17:15:42Z',
        '2026-11-26T17:15:42z',
        '2026-11-26T17:15:42+00:00',
        '2026-11-26T11:15:42-06:00',
        '2026-11-26T11:15:42-0600',
        '2026-11-26T18:15:42+01',
      ]) {
        final f = fechaDelServidor(texto);
        expect(f.isUtc, isTrue, reason: texto);
        expect(f, esperado, reason: texto);
      }
    });

    test('P14-FECHA: sin segundos fraccionarios y con espacios alrededor', () {
      expect(fechaDelServidor(' 2026-11-26T17:15:42 '), DateTime.utc(2026, 11, 26, 17, 15, 42));
    });
  });

  group('P14 fechas: los tres repositorios guardan la fecha en UTC', () {
    test('P14-FECHA: Partida.fromJson', () {
      final p = Partida.fromJson({
        'id': 1,
        'juego': 'SUDOKU',
        'tiempoSegundos': 60,
        'puntuacion': 940,
        'fecha': '2026-11-26T17:15:42.123456',
      });
      expect(p.fecha.isUtc, isTrue);
      expect(p.fecha, DateTime.utc(2026, 11, 26, 17, 15, 42, 123, 456));
    });

    test('P14-FECHA: Incidencia.fromJson (creación y actualización)', () {
      final i = Incidencia.fromJson({
        'id': 7,
        'titulo': 't',
        'descripcion': 'd',
        'estado': 'PENDIENTE',
        'prioridad': 'MEDIA',
        'creadoPor': null,
        'asignadoA': null,
        'fechaCreacion': '2026-11-26T17:00:00',
        'fechaActualizacion': '2026-11-26T17:05:00.5',
        'version': 0,
      });
      expect(i.fechaCreacion, DateTime.utc(2026, 11, 26, 17));
      expect(i.fechaActualizacion, DateTime.utc(2026, 11, 26, 17, 5, 0, 500));
    });

    test('P14-FECHA: MensajeIncidencia.fromJson', () {
      final m = MensajeIncidencia.fromJson({
        'id': 1,
        'incidenciaId': 7,
        'emisor': null,
        'texto': 'hola',
        'canal': 'PUBLICO',
        'fecha': '2026-11-26T17:15:00',
        'tieneAdjunto': false,
      });
      expect(m.fecha.isUtc, isTrue);
      expect(m.fecha, DateTime.utc(2026, 11, 26, 17, 15));
    });
  });

  group('P14 fechas: se muestran en la hora del teléfono', () {
    final utc = DateTime.utc(2026, 11, 26, 17, 15, 42);
    final local = utc.toLocal(); // en México: 11:15:42; en el CI (UTC): 17:15:42

    test('P14-FECHA: formatoFecha convierte a hora local', () {
      expect(formatoFecha(utc),
          '${dos(local.day)}/${dos(local.month)}/${local.year} ${dos(local.hour)}:${dos(local.minute)}');
    });

    test('P14-FECHA: formatoHora convierte a hora local', () {
      expect(formatoHora(utc), '${dos(local.hour)}:${dos(local.minute)}:${dos(local.second)}');
    });

    test('P14-FECHA: la hora de los mensajes del chat convierte a hora local', () {
      expect(horaMensaje(utc), '${dos(local.hour)}:${dos(local.minute)}');
    });

    test('P14-FECHA: con una fecha que ya es local no cambia nada', () {
      final ya = DateTime(2026, 11, 5, 21, 30, 7);
      expect(formatoFecha(ya), '05/11/2026 21:30');
      expect(formatoHora(ya), '21:30:07');
      expect(horaMensaje(ya), '21:30');
    });

    test('P14-FECHA: la misma partida se ve igual tanto si el servidor manda la zona como si no', () {
      expect(formatoFecha(fechaDelServidor('2026-11-26T17:15:42')),
          formatoFecha(fechaDelServidor('2026-11-26T11:15:42-06:00')));
    });
  });
}
