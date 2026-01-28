import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = useTextEditingController();
    final passCtrl = useTextEditingController();
    final isLoading = useState(false);
    final error = useState('');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                const Text(
                  "Kin Vault",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                
                const Text(
                  "PRIVATE FAMILY ARCHIVE",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 80),

                const Text(
                  "EMAIL",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: emailCtrl,
                  hintText: 'name@kinvault.com',
                  obscureText: false,
                ),
                const SizedBox(height: 32),

                const Text(
                  "PASSWORD",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Password Input
                _buildTextField(
                  controller: passCtrl,
                  hintText: '••••••••',
                  obscureText: true,
                ),

                if (error.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ),

                const SizedBox(height: 48),

                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            isLoading.value = true;
                            error.value = '';
                            try {
                              await ref.read(authProvider.notifier).login(
                                    emailCtrl.text,
                                    passCtrl.text,
                                  );
                            } catch (e) {
                              error.value = "Login Failed: ${e.toString()}";
                            } finally {
                              isLoading.value = false;
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A574), 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'SIGN IN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 2.0,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF444444)),
          border: InputBorder.none,
          suffixIcon: obscureText 
            ? const Icon(Icons.visibility_outlined, color: Color(0xFF666666), size: 20) 
            : null,
        ),
      ),
    );
  }
}
