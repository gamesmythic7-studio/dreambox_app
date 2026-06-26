import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' show ImageFilter;
import 'package:shared_preferences/shared_preferences.dart';
import 'story_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. BAS YE EK LINE ADD KI HAI: Screen change hone par diamonds yaad rakhne ke liye
int cachedDiamonds = 0; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String currentTheme = "Smooth Mode";
  final supabase = Supabase.instance.client;
  
  // Naya Variable data store karne ke liye
  late Future<List<Map<String, dynamic>>> _storiesFuture;

  final List<String> categories = const [
    'NEW ARRIVALS', 'ROMANTIC', 'HORROR', 'COMEDY',
    'SUPERNATURAL', 'ACTION', 'ADVENTURE', 'SCI-FI', 'DRAMA'
  ];

  @override
  void initState() {
    super.initState();
    // App load hote hi sirf EK baar data fetch hoga
    _storiesFuture = _getStoriesOnce();
  }

  // Static Fetch Function (No Stream/Realtime)
  Future<List<Map<String, dynamic>>> _getStoriesOnce() async {
    try {
      final data = await supabase
          .from('stories')
          .select()
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> fetchedStories = List<Map<String, dynamic>>.from(data);
      
      // Cache for library
      _cacheStoriesForLibrary(fetchedStories);
      
      return fetchedStories;
    } catch (e) {
      debugPrint("Fetch Error: $e");
      return [];
    }
  }

  // --- STORIES CACHE LOGIC ---
  Future<void> _cacheStoriesForLibrary(List<Map<String, dynamic>> stories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_stories_cache', jsonEncode(stories));
  }

  // --- DIAMOND PLANS MODAL ---
  void _showDiamondPlans(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("GET DIAMONDS", style: GoogleFonts.dmSerifDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
            const SizedBox(height: 20),
            _buildPlanTile("Starter Pack", "10 Diamonds", "₹99", Colors.blue.shade200),
            _buildPlanTile("Story Lover", "50 Diamonds", "₹399", Colors.pink.shade200),
            _buildPlanTile("Ultimate Reader", "Unlimited", "₹999", Colors.amber.shade200),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanTile(String title, String qty, String price, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(qty, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), shape: const StadiumBorder()),
            child: Text(price, style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- SETTINGS MENU ---
  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 15),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Text("SETTINGS", style: GoogleFonts.dmSerifDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
                const Divider(height: 30),
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: Colors.pinkAccent),
                  title: const Text("App Theme", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(currentTheme),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _showThemePicker(context),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.blue),
                  title: const Text("Account"),
                  onTap: () {},
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Choose Experience", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _themeOption(context, "Dark Mode", Icons.dark_mode_outlined),
            _themeOption(context, "Lite Mode", Icons.light_mode_outlined),
            _themeOption(context, "Smooth Mode", Icons.auto_awesome_outlined),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext context, String name, IconData icon) {
    bool isSelected = currentTheme == name;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.pinkAccent : Colors.grey),
      title: Text(name, style: TextStyle(color: isSelected ? Colors.pinkAccent : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.pinkAccent) : null,
      onTap: () {
        setState(() => currentTheme = name);
        Navigator.pop(context);
        Navigator.pop(context);
      },
    );
  }

  void _navigateToDetail(BuildContext context, Map story) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryDetailScreen(
          id: story['id'].toString(),
          title: story['title'] ?? 'No Title',
          image: story['cover_url'] ?? '',
          description: story['description'] ?? 'Explore this amazing story!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2F1), Color(0xFFFCE4EC), Color(0xFFFFF9C4)],
          ),
        ),
        child: Stack(
          children: [
            _buildMagicGlow(top: 100, right: -50, color: Colors.white),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildDreamyAppBar(context),
                SliverToBoxAdapter(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _storiesFuture, 
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 400); 
                      }

                      final allStories = snapshot.data ?? [];
                      if (allStories.isEmpty) return const Center(child: Text("No stories found."));

                      return Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildHeroCarousel(context, allStories),
                          for (var cat in categories) 
                            _buildCategoryRow(context, cat, allStories),
                          const SizedBox(height: 100),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel(BuildContext context, List<Map<String, dynamic>> stories) {
    final heroStories = stories.take(3).toList();
    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.85),
        itemCount: heroStories.length,
        itemBuilder: (context, index) => _buildGlossyCard(
          context,
          image: heroStories[index]['cover_url'],
          isHero: true,
          onTap: () => _navigateToDetail(context, heroStories[index]),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context, String title, List<Map<String, dynamic>> allStories) {
    final categoryStories = allStories.where((s) => s['genre'].toString().toUpperCase() == title).toList();
    if (categoryStories.isEmpty && title != 'NEW ARRIVALS') return const SizedBox();
    final displayStories = title == 'NEW ARRIVALS' ? allStories : categoryStories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          child: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF5D4037).withValues(alpha: 0.7))),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: displayStories.length,
            itemBuilder: (context, index) => _buildGlossyCard(
              context,
              image: displayStories[index]['cover_url'],
              isHero: false,
              onTap: () => _navigateToDetail(context, displayStories[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlossyCard(BuildContext context, {required String image, required bool isHero, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isHero ? null : 140,
        margin: const EdgeInsets.only(right: 15, bottom: 10, top: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.8), offset: const Offset(-4, -4), blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(image, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image))),
        ),
      ),
    );
  }

  Widget _buildDreamyAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.white.withValues(alpha: 0.2), 
      elevation: 0,
      expandedHeight: 70,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: FlexibleSpaceBar(
            title: Text('DREAMBOX', style: GoogleFonts.dmSerifDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => _showDiamondPlans(context),
          child: _buildDiamondCounter(context),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF5D4037)),
          onPressed: () => _showSettingsMenu(context),
        ),
        const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildDiamondCounter(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return const SizedBox();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('profiles').stream(primaryKey: ['id']).eq('id', userId),
      builder: (context, snapshot) {
        
        // 2. DOOSRA CHANGE: Yahan data aate hi hum usko apne global variable mein daal rahe hain
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          cachedDiamonds = snapshot.data![0]['diamonds'] ?? 0;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF85C1E9), size: 14),
            const SizedBox(width: 4),
            // 3. TEESRA CHANGE: Text me "diamonds" ki jagah "cachedDiamonds" display ho raha hai
            Text("$cachedDiamonds", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
          ]),
        );
      },
    );
  }

  Widget _buildMagicGlow({double? top, double? right, required Color color}) {
    return Positioned(top: top, right: right, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 100, spreadRadius: 50)])));
  }
}