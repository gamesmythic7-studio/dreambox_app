import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // Navigation ke liye import zaroori hai

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  bool _obscureText = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  // Sabse zaroori update: Auth Logic with Navigation
  Future<void> _handleAuth() async {
    // Basic validation
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError("Please fill in all fields");
      return;
    }
    if (!isLogin && _usernameController.text.trim().isEmpty) {
      _showError("Please enter a username");
      return;
    }

    setState(() => isLoading = true);
    
    try {
      if (isLogin) {
        // --- LOGIN ---
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // --- SIGNUP ---
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {'username': _usernameController.text.trim()},
        );
        
        // Agar email confirmation on hai, toh user ko batana padega
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Success! Check your email if confirmation is required.")),
          );
        }
      }

      // Success: Navigate to MainNavigation and clear stack
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      // Supabase ke specific errors (Invalid credentials, Rate limit etc.)
      _showError(e.message);
    } catch (e) {
      _showError("An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2F1), Color(0xFFFCE4EC), Color(0xFFFFF9C4)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  isLogin ? "Welcome Back" : "Begin Your Story",
                  style: GoogleFonts.dmSerifDisplay(fontSize: 32, color: const Color(0xFF5D4037)),
                ),
                const SizedBox(height: 30),
                
                // GLASS CARD
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          if (!isLogin) _buildTextField(_usernameController, "Username", Icons.person_outline),
                          if (!isLogin) const SizedBox(height: 15),
                          _buildTextField(_emailController, "Email", Icons.email_outlined),
                          const SizedBox(height: 15),
                          _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
                          if (isLogin) 
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text("Forgot Password?", style: TextStyle(color: Color(0xFF5D4037), fontSize: 12)),
                              ),
                            ),
                          const SizedBox(height: 25),
                          
                          // AUTH BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5D4037),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(isLogin ? "ENTER DREAMBOX" : "CREATE ACCOUNT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                Text("OR", style: TextStyle(color: Colors.blueGrey.withValues(alpha: 0.5), fontSize: 12)),
                const SizedBox(height: 20),
                _socialButton("Continue with Google", Icons.g_mobiledata),
                const SizedBox(height: 30),
                
                TextButton(
                  onPressed: () => setState(() {
                    isLogin = !isLogin;
                    _emailController.clear();
                    _passwordController.clear();
                    _usernameController.clear();
                  }),
                  child: Text(
                    isLogin ? "New to DreamBox? Start your story here" : "Already a Dreamer? Login",
                    style: const TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF5D4037), size: 20),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, size: 20, color: const Color(0xFF5D4037)), 
              onPressed: () => setState(() => _obscureText = !_obscureText))
          : null,
        hintText: label,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }

  Widget _socialButton(String text, IconData icon) {
    return InkWell(
      onTap: () {
        _showError("Google Login coming soon!");
      },
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.redAccent, size: 30),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}