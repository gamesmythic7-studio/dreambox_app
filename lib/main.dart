import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/library_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase Initialization
  await Supabase.initialize(
    url: 'https://sabgourvjxtjgxcmnkjk.supabase.co', 
    anonKey: 'sb_publishable_Jmed8JOsLRQuuAiNvRqKwA_ubjTP74E',
  );
  
  runApp(const DreamBoxApp());
}

class DreamBoxApp extends StatelessWidget {
  const DreamBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DreamBox',
      theme: ThemeData(
        // Dark theme background with light text support
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        brightness: Brightness.dark,
      ),
      // App hamesha SplashScreen se start hoga jo data fetch karega
      home: const SplashScreen(), 
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  // Library refresh karne ke liye key
  final GlobalKey<LibraryScreenState> _libraryKey = GlobalKey<LibraryScreenState>();

  // Screens list ko late initialize kar rahe hain performance ke liye
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      LibraryScreen(key: _libraryKey), 
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack ka use karne se screens apni state maintain rakhti hain
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          // Agar user Library tab (index 1) par jaye to refresh trigger karein
          if (index == 1) {
            _libraryKey.currentState?.refreshLibrary();
          }
        },
        selectedItemColor: const Color(0xFFE0F2F1), 
        unselectedItemColor: Colors.white.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF5D4037), 
        elevation: 15,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled), 
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined), 
            activeIcon: Icon(Icons.auto_stories),
            label: "Library",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), 
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}