import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';

Widget _error(String? e) => e == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(e, style: const TextStyle(color: Colors.red)),
      );

Widget _boton(String texto, bool enProceso, VoidCallback onPressed) =>
    SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enProceso ? null : onPressed,
        child: enProceso
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(texto),
      ),
    );

// ---------------- LOGIN ----------------
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _correo = TextEditingController();
  final _pass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.psychology, size: 72),
              const Text('Mind Games',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Correo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Contraseña', border: OutlineInputBorder()),
              ),
              _error(auth.error),
              const SizedBox(height: 16),
              _boton('INICIAR SESIÓN', auth.enProceso, () {
                if (_correo.text.isEmpty || _pass.text.isEmpty) return;
                ref
                    .read(authControllerProvider.notifier)
                    .login(_correo.text.trim(), _pass.text);
              }),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterPage())),
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
            ]),
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
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _pass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(
              controller: _nombre,
              decoration: const InputDecoration(
                  labelText: 'Nombre de usuario', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Correo', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Contraseña', border: OutlineInputBorder())),
          _error(auth.error),
          const SizedBox(height: 16),
          _boton('REGISTRARME', auth.enProceso, () async {
            if (_nombre.text.isEmpty ||
                _correo.text.isEmpty ||
                _pass.text.isEmpty) return;
            final ok = await ref.read(authControllerProvider.notifier).registrar(
                _nombre.text.trim(), _correo.text.trim(), _pass.text);
            if (ok && context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Cuenta creada. Ahora inicia sesión.')));
            }
          }),
        ]),
      ),
    );
  }
}

// ---------------- CÓDIGO DE VERIFICACIÓN ----------------
class VerifyCodePage extends ConsumerStatefulWidget {
  const VerifyCodePage({super.key});
  @override
  ConsumerState<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends ConsumerState<VerifyCodePage> {
  final _codigo = TextEditingController();

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
      body: Padding(
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
          _error(auth.error),
          const SizedBox(height: 16),
          _boton('VERIFICAR', auth.enProceso, () {
            if (_codigo.text.isEmpty) return;
            ref
                .read(authControllerProvider.notifier)
                .verificarCodigo(_codigo.text.trim());
          }),
        ]),
      ),
    );
  }
}
