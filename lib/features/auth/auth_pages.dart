import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import 'validadores.dart';

// Medidas de seguridad aplicadas en estas pantallas:
//  1. Form + validators: no se envía nada al servidor si los datos no son válidos.
//  2. trim(): se rechazan usuario/correo formados solo por espacios.
//  3. maxLength + validación: límites de usuario 30, correo 100, contraseña 64.
//  4. Contraseña de mínimo 8 caracteres al registrarse.
//  5. Contraseña oculta (obscureText) con botón para mostrarla u ocultarla,
//     sin autocorrección ni sugerencias (el teclado no la aprende ni la guarda).
//  6. Mensajes genéricos: el AuthController traduce cualquier error del servidor
//     a "Credenciales inválidas", "No se pudo completar el registro" o
//     "No se pudo conectar, intenta de nuevo".
//  7. No se imprime nada en logs (ni contraseñas, ni tokens, ni respuestas).
//  8. Los TextEditingController se liberan en dispose(), así la contraseña
//     no queda en memoria al salir de la pantalla.

/// Mensaje de error debajo del formulario (siempre genérico, viene del controller).
Widget _error(BuildContext context, String? e) => e == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(e,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );

Widget _boton(String texto, bool enProceso, VoidCallback onPressed) =>
    SizedBox(
      width: double.infinity,
      child: FilledButton(
        // Deshabilitado mientras hay una petición en curso: evita envíos dobles.
        onPressed: enProceso ? null : onPressed,
        child: enProceso
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(texto),
      ),
    );

/// Campo de contraseña oculto con botón de "ojo" para mostrar/ocultar.
class _CampoPassword extends StatefulWidget {
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool habilitado;
  final VoidCallback? onEnviar;
  final Iterable<String> autofillHints;

  const _CampoPassword({
    required this.controller,
    required this.validator,
    required this.habilitado,
    this.onEnviar,
    this.autofillHints = const [AutofillHints.password],
  });

  @override
  State<_CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<_CampoPassword> {
  bool _oculta = true; // SEGURIDAD: por defecto la contraseña no se ve

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.habilitado,
      obscureText: _oculta,
      // SEGURIDAD: sin autocorrección ni sugerencias, el teclado no registra la contraseña.
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      // Permite que un gestor de contraseñas la llene de forma segura.
      autofillHints: widget.autofillHints,
      // SEGURIDAD: límite de longitud (también se valida en el validator).
      maxLength: maxPassword,
      textInputAction: TextInputAction.done, // "Enviar" desde el teclado
      onFieldSubmitted: (_) => widget.onEnviar?.call(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        border: const OutlineInputBorder(),
        counterText: '', // se oculta el contador; el límite sigue activo
        suffixIcon: IconButton(
          tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(_oculta ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
    );
  }
}

/// Campo de correo con sus límites y validación.
Widget _campoCorreo(TextEditingController controller, bool habilitado) =>
    TextFormField(
      controller: controller,
      enabled: habilitado,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      maxLength: maxCorreo, // SEGURIDAD: límite de longitud
      textInputAction: TextInputAction.next,
      validator: validarCorreo, // obligatorio, trim y formato
      decoration: const InputDecoration(
          labelText: 'Correo', border: OutlineInputBorder(), counterText: ''),
    );

// ---------------- LOGIN ----------------
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _enviar() {
    // SEGURIDAD: si algún campo no pasa la validación no se llama al servidor.
    if (!_form.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        // El correo se envía sin espacios; la contraseña tal cual.
        .login(_correo.text.trim(), _pass.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              // Valida mientras escribe, después de tocar cada campo.
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AutofillGroup(
                child: Column(children: [
                  const Icon(Icons.psychology, size: 72),
                  const Text('Mind Games',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _campoCorreo(_correo, !auth.enProceso),
                  const SizedBox(height: 12),
                  _CampoPassword(
                    controller: _pass,
                    // Login: obligatoria y máx. 64 (sin mínimo, lo valida el servidor).
                    validator: validarPasswordLogin,
                    habilitado: !auth.enProceso,
                    onEnviar: _enviar,
                  ),
                  _error(context, auth.error),
                  const SizedBox(height: 16),
                  _boton('INICIAR SESIÓN', auth.enProceso, _enviar),
                  TextButton(
                    onPressed: () {
                      // No arrastrar el error del login a la pantalla de registro.
                      ref.read(authControllerProvider.notifier).limpiarError();
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()));
                    },
                    child: const Text('¿No tienes cuenta? Regístrate'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- REGISTRO ----------------
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    // SEGURIDAD: si algún campo no pasa la validación no se llama al servidor.
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).registrar(
        _nombre.text.trim(), _correo.text.trim(), _pass.text);
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cuenta creada. Ahora inicia sesión.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return PopScope(
      // Al regresar al login se limpia el error del registro.
      onPopInvokedWithResult: (salio, _) {
        if (salio) ref.read(authControllerProvider.notifier).limpiarError();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Crear cuenta')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: AutofillGroup(
              child: Column(children: [
                TextFormField(
                  controller: _nombre,
                  enabled: !auth.enProceso,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newUsername],
                  maxLength: maxUsuario, // SEGURIDAD: límite de longitud
                  textInputAction: TextInputAction.next,
                  validator: validarUsuario, // obligatorio y rechaza solo espacios
                  decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                _campoCorreo(_correo, !auth.enProceso),
                const SizedBox(height: 12),
                _CampoPassword(
                  controller: _pass,
                  // Registro: obligatoria, de 8 a 64 caracteres.
                  validator: validarPasswordRegistro,
                  habilitado: !auth.enProceso,
                  autofillHints: const [AutofillHints.newPassword],
                  onEnviar: _enviar,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mínimo $minPassword caracteres',
                      style: TextStyle(fontSize: 12)),
                ),
                _error(context, auth.error),
                const SizedBox(height: 16),
                _boton('REGISTRARME', auth.enProceso, _enviar),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- CÓDIGO DE VERIFICACIÓN ----------------
// Sin cambios de diseño: los mensajes de error ahora son genéricos
// ("Código inválido" / "No se pudo conectar, intenta de nuevo") desde el controller.
class VerifyCodePage extends ConsumerStatefulWidget {
  const VerifyCodePage({super.key});
  @override
  ConsumerState<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends ConsumerState<VerifyCodePage> {
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación'),
        leading: BackButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).volverALogin()),
      ),
      // SingleChildScrollView: con el teclado abierto el contenido se puede
      // desplazar en lugar de desbordarse.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text('Enviamos un código a ${auth.correo ?? ''}'),
          const SizedBox(height: 16),
          TextField(
            controller: _codigo,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 8),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          _error(context, auth.error),
          const SizedBox(height: 16),
          _boton('VERIFICAR', auth.enProceso, () {
            if (_codigo.text.trim().isEmpty) return;
            ref
                .read(authControllerProvider.notifier)
                .verificarCodigo(_codigo.text.trim());
          }),
        ]),
      ),
    );
  }
}
