import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/api_config.dart';
import 'package:mindgames_app/core/sesion_expirada_exception.dart';
import 'package:mindgames_app/data/foto_perfil_repository.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/perfil/camara.dart';
import 'package:mindgames_app/features/perfil/compresor_foto.dart';
import 'package:mindgames_app/features/perfil/foto_perfil_controller.dart';
import 'package:mindgames_app/features/perfil/widgets/avatar_foto.dart';

// ---------------- Dobles de prueba ----------------

/// JPEG pequeño y válido para usar como "foto".
final Uint8List fotoChica =
    img.encodeJpg(img.Image(width: 20, height: 20), quality: 90);

class _DaoFalso implements SesionDao {
  @override
  Future<Sesion?> obtener() async => null;
  @override
  Future<void> guardar(Sesion sesion) async {}
  @override
  Future<void> limpiar() async {}
}

class _ApiFalsa extends ApiClient {
  _ApiFalsa(this.respuesta) : super(_DaoFalso());
  final dynamic respuesta;
  String? ruta;
  Map<String, dynamic>? cuerpo;
  bool? autenticado;

  @override
  Future<dynamic> get(String ruta, {bool autenticado = false}) async {
    this.ruta = ruta;
    this.autenticado = autenticado;
    return respuesta;
  }

  @override
  Future<dynamic> put(String ruta, Map<String, dynamic> cuerpo,
      {bool autenticado = false}) async {
    this.ruta = ruta;
    this.cuerpo = cuerpo;
    this.autenticado = autenticado;
    return respuesta;
  }
}

/// Qué debe pasar en la siguiente llamada al repositorio o la cámara.
enum Falla { ninguna, sesionExpirada, red, permisoDenegado }

class _RepoFalso implements FotoPerfilRepository {
  Falla falla = Falla.ninguna;
  Uint8List? enServidor;
  Uint8List? subida;

  @override
  ApiClient get api => throw UnimplementedError();

  void _quizaFallar() {
    if (falla == Falla.sesionExpirada) throw const SesionExpiradaException();
    if (falla == Falla.red) throw Exception('Error del servidor (500)');
  }

  @override
  Future<Uint8List?> obtener() async {
    _quizaFallar();
    return enServidor;
  }

  @override
  Future<void> subir(Uint8List bytes) async {
    _quizaFallar();
    subida = bytes;
  }
}

class _CamaraFalsa extends Camara {
  Uint8List? foto = fotoChica; // null = el usuario canceló
  bool denegar = false;

  @override
  Future<Uint8List?> tomarFoto() async {
    if (denegar) throw const CamaraDenegadaException();
    return foto;
  }
}

class _AuthFalso extends AuthController {
  bool sesionExpiradaLlamada = false;

  @override
  AuthState build() => const AuthState(
      status: AuthStatus.autenticado, correo: 'jugador@correo.com');

  @override
  Future<void> sesionExpirada() async {
    sesionExpiradaLlamada = true;
    state = const AuthState(
        status: AuthStatus.noAutenticado, error: 'Tu sesión expiró');
  }
}

void main() {
  // ---------------- Compresión ----------------
  group('comprimirFotoSync', () {
    test('una foto de menos de 2 MB se devuelve igual', () {
      expect(comprimirFotoSync(fotoChica), same(fotoChica));
    });

    test('una foto grande queda por debajo de 2 MB y sigue siendo imagen', () {
      // Ruido aleatorio a calidad 100: el peor caso para JPEG (pesa varios MB).
      final r = Random(1);
      final grande = img.Image(width: 2400, height: 2400);
      for (final p in grande) {
        p
          ..r = r.nextInt(256)
          ..g = r.nextInt(256)
          ..b = r.nextInt(256);
      }
      final original = img.encodeJpg(grande, quality: 100);
      expect(original.length, greaterThan(limiteFotoBytes));

      final comprimida = comprimirFotoSync(original);
      expect(comprimida.length, lessThan(limiteFotoBytes));
      expect(img.decodeJpg(comprimida), isNotNull);
    });

    test('bytes que no son imagen lanzan FotoNoValidaException', () {
      final basura = Uint8List(limiteFotoBytes + 10);
      expect(() => comprimirFotoSync(basura),
          throwsA(isA<FotoNoValidaException>()));
    });
  });

  // ---------------- Repositorio ----------------
  group('FotoPerfilRepository', () {
    test('GET autenticado devuelve null si no hay foto', () async {
      final api = _ApiFalsa({'foto': null});
      expect(await FotoPerfilRepository(api).obtener(), isNull);
      expect(api.ruta, rutaFotoPerfil);
      expect(api.autenticado, isTrue);
    });

    test('GET decodifica el Base64', () async {
      final api = _ApiFalsa({'foto': base64Encode(fotoChica)});
      expect(await FotoPerfilRepository(api).obtener(), fotoChica);
    });

    test('PUT autenticado envía { "foto": base64 }', () async {
      final api = _ApiFalsa({'mensaje': 'Foto actualizada correctamente'});
      await FotoPerfilRepository(api).subir(fotoChica);
      expect(api.ruta, rutaFotoPerfil);
      expect(api.autenticado, isTrue);
      expect(api.cuerpo, {'foto': base64Encode(fotoChica)});
    });
  });

  // ---------------- Controller ----------------
  group('FotoPerfilController', () {
    late _RepoFalso repo;
    late _CamaraFalsa camara;
    late ProviderContainer contenedor;

    setUp(() {
      repo = _RepoFalso();
      camara = _CamaraFalsa();
      contenedor = ProviderContainer(overrides: [
        fotoPerfilRepositoryProvider.overrideWithValue(repo),
        camaraProvider.overrideWithValue(camara),
        authControllerProvider.overrideWith(_AuthFalso.new),
      ]);
    });
    tearDown(() => contenedor.dispose());

    FotoPerfilController ctrl() =>
        contenedor.read(fotoPerfilControllerProvider.notifier);
    FotoPerfilState estado() => contenedor.read(fotoPerfilControllerProvider);
    _AuthFalso auth() =>
        contenedor.read(authControllerProvider.notifier) as _AuthFalso;

    test('cargar obtiene la foto del servidor', () async {
      repo.enServidor = fotoChica;
      await ctrl().cargar();
      expect(estado().foto, fotoChica);
      expect(estado().cargando, isFalse);
    });

    test('tomar y subir guarda la foto y la muestra', () async {
      await ctrl().tomarYSubir();
      expect(repo.subida, fotoChica);
      expect(estado().foto, fotoChica);
      expect(estado().subiendo, isFalse);
    });

    test('si el usuario cancela la cámara no se sube nada', () async {
      camara.foto = null;
      await ctrl().tomarYSubir();
      expect(repo.subida, isNull);
      expect(estado().errorSubida, isNull);
    });

    test('permiso de cámara denegado muestra un mensaje', () async {
      camara.denegar = true;
      await ctrl().tomarYSubir();
      expect(repo.subida, isNull);
      expect(estado().errorSubida, contains('permiso de cámara'));
    });

    test('error de red al subir da mensaje genérico y conserva la foto anterior',
        () async {
      repo.enServidor = fotoChica;
      await ctrl().cargar();
      repo.falla = Falla.red;
      await ctrl().tomarYSubir();
      expect(estado().errorSubida, 'No se pudo actualizar tu foto');
      expect(estado().foto, fotoChica);
      expect(auth().sesionExpiradaLlamada, isFalse);
    });

    test('error al cargar da mensaje genérico', () async {
      repo.falla = Falla.red;
      await ctrl().cargar();
      expect(estado().errorCarga, 'No se pudo cargar tu foto');
    });

    test('SesionExpiradaException (cargar y subir) llama a sesionExpirada()',
        () async {
      repo.falla = Falla.sesionExpirada;
      await ctrl().cargar();
      expect(auth().sesionExpiradaLlamada, isTrue);

      auth().sesionExpiradaLlamada = false;
      await ctrl().tomarYSubir();
      expect(auth().sesionExpiradaLlamada, isTrue);
    });
  });

  // ---------------- Widget ----------------
  group('AvatarFoto', () {
    Widget montar(FotoPerfilState estado) => MaterialApp(
          home: Scaffold(
            body: AvatarFoto(estado: estado, onTomarFoto: () {}),
          ),
        );

    testWidgets('sin foto muestra el avatar por defecto', (tester) async {
      await tester.pumpWidget(montar(const FotoPerfilState()));
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('con foto usa Image.memory', (tester) async {
      await tester.pumpWidget(montar(FotoPerfilState(foto: fotoChica)));
      final imagen = tester.widget<Image>(find.byType(Image));
      expect(imagen.image, isA<MemoryImage>());
    });

    testWidgets('mientras sube muestra spinner y desactiva la cámara',
        (tester) async {
      await tester.pumpWidget(montar(const FotoPerfilState(subiendo: true)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final boton = tester.widget<IconButton>(find.byType(IconButton));
      expect(boton.onPressed, isNull);
    });
  });
}
