import 'dart:convert'; // Json encode ke liye
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Cache ke liye
import 'auth_screen.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _prepareAppData();
  }

  Future<void> _prepareAppData() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    final minimumTimer = Future.delayed(const Duration(milliseconds: 2500));

    if (session != null) {
      try {
        // Data pehle hi fetch kar rahe hain
        final responses = await Future.wait([
          minimumTimer,
          supabase.from('profiles').select('diamonds').eq('id', session.user.id).single(),
          supabase.from('stories').select().limit(20), 
        ]);

        // Unused variables ab useful ho gaye!
        final int initialDiamonds = responses[1]['diamonds'] ?? 0;
        final List<Map<String, dynamic>> initialStories = List<Map<String, dynamic>>.from(responses[2] as List);

        // 1. Console mein check karne ke liye ki data aa gaya (Debugging)
        debugPrint("✅ DreamBox Ready! Diamonds: $initialDiamonds | Stories Loaded: ${initialStories.length}");

        // 2. Stories ko pehle hi SharedPreferences mein cache kar diya 
        // (Isse Home Screen aur bhi fast load hogi)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('home_stories_cache', jsonEncode(initialStories));

        if (mounted) {
          // Home Screen ko data bhej rahe hain
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, anim, secAnim) => const MainNavigation(),
              transitionDuration: const Duration(seconds: 1),
              transitionsBuilder: (context, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
            ),
          );
        }
      } catch (e) {
        debugPrint("❌ Loading Error: $e");
        await minimumTimer;
        if (mounted) _navigateTo(const MainNavigation());
      }
    } else {
      await minimumTimer;
      if (mounted) _navigateTo(const AuthScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2F1), Color(0xFFFCE4EC), Color(0xFFFFF9C4)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            const Icon(Icons.auto_awesome, size: 80, color: Color(0xFF5D4037)),
            const SizedBox(height: 20),
            // App Name
            Text(
              "DreamBox",
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 45, 
                color: const Color(0xFF5D4037), 
                fontWeight: FontWeight.bold,
              ),
            ),
            // Quote
            Text(
              "Where Dreams Becomes Alive",
              style: GoogleFonts.poppins(
                fontSize: 14, 
                color: const Color(0xFF5D4037).withOpacity(0.7),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 50),
            const SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Color(0xFF5D4037),
              ),
            ),
          ],
        ),
      ),
    );
  }
}