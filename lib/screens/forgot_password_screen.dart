import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool loading = false;

  String? _emailError;

  void _sendResetEmail() async {
    setState(() {
      loading = true;
      _emailError =
          _emailController.text.isEmpty || !_emailController.text.contains('@')
              ? 'Valid email is required'
              : null;
    });

    if (_emailError == null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success =
            await authProvider.forgotPassword(_emailController.text);

        setState(() => loading = false);

        if (success) {
          // Send return email after successful reset email
          final returnSuccess = await authProvider.sendReturnEmail(
            _emailController.text,
            '/', // Default return to LoginScreen, can be customizable
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                returnSuccess
                    ? 'Reset link and return email sent'
                    : 'Reset link sent, but return email failed',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email not found')),
          );
        }
      } catch (e) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } else {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'NIT Clearance App',
                  style: GoogleFonts.dancingScript(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    shadows: [
                      const Shadow(
                        color: Colors.indigo,
                        offset: Offset(2, 2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Forgot Password",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email, color: Colors.indigo),
                    errorText: _emailError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _emailError = value.isEmpty || !value.contains('@')
                        ? 'Valid email is required'
                        : null;
                  }),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : _sendResetEmail,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Send Email",
                          style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
