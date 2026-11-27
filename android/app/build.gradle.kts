plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Firma de producción (Práctica 14): se lee SOLO de variables de entorno, así
// ninguna contraseña ni ruta de keystore queda en el repositorio.
//   MG_KEYSTORE_PATH, MG_KEYSTORE_PASSWORD, MG_KEY_ALIAS, MG_KEY_PASSWORD
// Si falta alguna (o el keystore no existe), un build RELEASE falla con un
// mensaje claro; nunca se firma con la clave de debug. Los builds debug y
// profile no las necesitan.
// ---------------------------------------------------------------------------
val variablesFirma = listOf("MG_KEYSTORE_PATH", "MG_KEYSTORE_PASSWORD", "MG_KEY_ALIAS", "MG_KEY_PASSWORD")
val firma: Map<String, String?> = variablesFirma.associateWith { System.getenv(it) }
val faltanFirma = variablesFirma.filter { firma[it].isNullOrBlank() }
val keystoreFirma = firma["MG_KEYSTORE_PATH"]?.takeIf { it.isNotBlank() }?.let { file(it) }

android {
    namespace = "com.example.mindgames_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mindgames_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Solo se llena si están las 4 variables; si no, el chequeo de abajo
            // detiene cualquier tarea release antes de compilar.
            if (faltanFirma.isEmpty() && keystoreFirma != null) {
                storeFile = keystoreFirma
                storePassword = firma["MG_KEYSTORE_PASSWORD"]
                keyAlias = firma["MG_KEY_ALIAS"]
                keyPassword = firma["MG_KEY_PASSWORD"]
            }
        }
    }

    buildTypes {
        release {
            // Firma de producción (variables de entorno). Ya no se usa la de debug.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Si se pide una tarea release (p. ej. flutter build apk --release ->
// assembleRelease) y falta la firma, se detiene con un mensaje claro en lugar
// de firmar con otra clave. No afecta a debug ni profile.
gradle.taskGraph.whenReady {
    val pideRelease = allTasks.any { it.project == project && it.name.contains("Release") }
    if (!pideRelease) return@whenReady
    if (faltanFirma.isNotEmpty()) {
        throw GradleException(
            "Firma release: faltan variables de entorno: ${faltanFirma.joinToString(", ")}. " +
                "Expórtalas en la terminal antes de compilar. " +
                "No se firma con la clave de debug."
        )
    }
    if (keystoreFirma == null || !keystoreFirma.isFile) {
        throw GradleException("Firma release: MG_KEYSTORE_PATH no apunta a un keystore existente.")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
