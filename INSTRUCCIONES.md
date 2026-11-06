# Pasos para correrlo

1. `flutter create mind_games_movil --platforms=android` (si no lo has creado)
2. Copia la carpeta `lib/` de este proyecto sobre la `lib/` del tuyo.
3. Agrega las dependencias de `pubspec_dependencias.yaml` y corre `flutter pub get`.
4. Genera el código de Floor:
   `dart run build_runner build --delete-conflicting-outputs`
5. En `android/app/src/main/AndroidManifest.xml`, antes de `<application>`:
   `<uses-permission android:name="android.permission.INTERNET"/>`
6. En `android/app/build.gradle.kts` pon `minSdk = 29` (Android 10+).
7. Edita `lib/core/api_config.dart` con la URL y rutas reales de tu API.
8. `flutter run`
9. Mientras el backend siga en http (local), en `AndroidManifest.xml` agrega al tag `<application`:
   `android:usesCleartextTraffic="true"`  (quítalo al apuntar a https de Render).
10. Levanta el backend local (`./mvnw spring-boot:run` en la carpeta backend) antes de probar la app.
