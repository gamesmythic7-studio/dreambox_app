import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../vn_engine/vn_player.dart';

class StoryDetailScreen extends StatefulWidget {
  final String id;
  final String title;
  final String image;
  final String description;

  const StoryDetailScreen({
    super.key,
    required this.id,
    required this.title,
    required this.image,
    required this.description,
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  int lastUnlockedIndex = 0; 
  bool isFavorite = false;
  
  // --- NAYE VARIABLES: Data caching ke liye ---
  List<dynamic>? _episodes; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData(); // Ek hi baar data load hoga
  }

  // Sab kuch ek saath manage karne ke liye
  Future<void> _initData() async {
    await _loadFavoriteStatus();
    await _loadCachedEpisodes(); // Pehle phone se load karo (Fast)
    _fetchAndSyncEpisodes();     // Phir background mein Supabase se check karo
  }

  // Phone ki memory (Cache) se episodes uthana
  Future<void> _loadCachedEpisodes() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('episodes_cache_${widget.id}');
    
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          _episodes = jsonDecode(cachedData);
          _isLoading = false; // Cache mil gaya toh loader hata do
        });
        _calculateProgress(_episodes!); 
      }
    }
  }

  // Supabase se naya data check karna
  Future<void> _fetchAndSyncEpisodes() async {
    try {
      final episodes = await Supabase.instance.client
          .from('episodes')
          .select()
          .eq('story_id', widget.id)
          .order('episode_number', ascending: true);

      final prefs = await SharedPreferences.getInstance();
      String newData = jsonEncode(episodes);
      String? oldData = prefs.getString('episodes_cache_${widget.id}');

      // AGAR NAYA EPISODE AAYA HAI (Data change hua hai), tabhi UI update hoga
      if (newData != oldData) {
        await prefs.setString('episodes_cache_${widget.id}', newData);
        if (mounted) {
          setState(() {
            _episodes = episodes;
            _isLoading = false;
          });
          _calculateProgress(episodes);
          _saveTotalCount(episodes.length);
        }
      } else {
        // Data same hai toh sirf loader band kar do
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Progress calculate karne ka alag logic (DRY principle)
  Future<void> _calculateProgress(List<dynamic> episodes) async {
    final prefs = await SharedPreferences.getInstance();
    int unlocked = 0;
    for (int i = 0; i < episodes.length; i++) {
      bool isDone = prefs.getBool('completed_${episodes[i]['id']}') ?? false;
      if (isDone) {
        unlocked = i + 1;
      } else {
        break;
      }
    }
    if (mounted) {
      setState(() => lastUnlockedIndex = unlocked);
    }
  }

  // --- PURANA LOAD PROGRESS AB ZARURAT NAHI (Sync mein cover ho gaya) ---
  Future<void> _loadProgress() async {
    if (_episodes != null) _calculateProgress(_episodes!);
  }

  Future<void> _loadFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isFavorite = prefs.getBool(widget.id) ?? false;
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    String savedJson = prefs.getString('saved_stories_list') ?? '[]';
    List<dynamic> savedStories = jsonDecode(savedJson);

    setState(() {
      isFavorite = !isFavorite;
    });

    if (isFavorite) {
      Map<String, dynamic> storyData = {
        'id': widget.id,
        'title': widget.title,
        'cover_url': widget.image,
        'description': widget.description,
        'genre': 'Story', 
      };
      
      if (!savedStories.any((item) => item['id'].toString() == widget.id.toString())) {
        savedStories.add(storyData);
      }
      await prefs.setBool(widget.id, true);
    } else {
      savedStories.removeWhere((item) => item['id'].toString() == widget.id.toString());
      await prefs.setBool(widget.id, false);
    }

    await prefs.setString('saved_stories_list', jsonEncode(savedStories));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite ? "Story Saved to Library! ❤️" : "Removed from Library! 💔",
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFF5D4037),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, child: _buildMysticalPoster()),
            _buildMagicGlow(top: 100, left: -50, color: Colors.white),
            _buildMagicGlow(top: 600, right: -50, color: Colors.pink.shade100),
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildDreamyAppBar(context),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 460), 
                        _buildContentSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1).withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 15),
            height: 4, width: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title.toUpperCase(), style: GoogleFonts.dmSerifDisplay(fontSize: 28, color: const Color(0xFF5D4037))),
                const SizedBox(height: 10),
                Text("ABOUT", style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5D4037), letterSpacing: 3, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(widget.description, style: GoogleFonts.poppins(color: const Color(0xFF546E7A), fontSize: 14, height: 1.6)),
                const SizedBox(height: 35),
                Text("STORY PATH", style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF5D4037), letterSpacing: 3, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildEpisodeList(), // Ab ye optimized hai
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeList() {
    // Agar data loading hai aur cache bhi nahi mila
    if (_isLoading && _episodes == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)));
    }

    // Agar cache ya data mil gaya
    if (_episodes == null || _episodes!.isEmpty) {
      return const Center(child: Text("No episodes available."));
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _episodes!.length,
      itemBuilder: (context, index) {
        final ep = _episodes![index];
        bool isLocked = index > lastUnlockedIndex;
        bool isCompleted = index < lastUnlockedIndex;
        String epTitle = ep['title'] ?? "Episode ${index + 1}";

        return _buildGlossyEpisodeTile(index, isLocked, isCompleted, epTitle, ep);
      },
    );
  }

  Future<void> _saveTotalCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_ep_count_${widget.id}', count + 1);
  }

  Widget _buildDreamyAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 80, 
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 10),
        child: _buildGlassButton(Icons.chevron_left, () => Navigator.pop(context)),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: _buildGlassButton(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            _toggleFavorite,
            iconColor: isFavorite ? Colors.redAccent : const Color(0xFF5D4037),
          ),
        ),
        const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildMysticalPoster() {
    return Container(
      height: 550,
      width: double.infinity,
      foregroundDecoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            const Color(0xFFE0F2F1).withOpacity(0.8),
            const Color(0xFFE0F2F1)
          ],
          stops: const [0, 0.4, 0.85, 1.0],
        ),
      ),
      child: Image.network(widget.image, fit: BoxFit.cover),
    );
  }

  Widget _buildGlossyEpisodeTile(int index, bool isLocked, bool isCompleted, String epTitle, dynamic epData) {
    return GestureDetector(
      onTap: isLocked
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Unlock previous episodes first!")),
              );
            }
          : () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('last_ep_id_${widget.id}', epData['id'].toString());
              await prefs.setInt('last_unlocked_${widget.id}', index + 1);

              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VNPlayerScreen(
                      storyId: widget.id,
                      episodeId: epData['id'].toString(),
                      storyTitle: widget.title,
                    ),
                  ),
                );
                _loadProgress(); // Wapas aane par progress refresh
              }
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocked ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Text("${index + 1}", style: GoogleFonts.dmSerifDisplay(fontSize: 18, color: isLocked ? Colors.grey : const Color(0xFF5D4037))),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(epTitle.toUpperCase(), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isLocked ? Colors.grey : const Color(0xFF5D4037))),
                  Text(isLocked ? "Locked" : (isCompleted ? "Completed" : "Tap to Play"), style: GoogleFonts.poppins(fontSize: 11, color: isLocked ? Colors.grey : Colors.blueGrey)),
                ],
              ),
            ),
            Icon(
              isLocked ? Icons.lock_outline : (isCompleted ? Icons.check_circle : Icons.play_circle_fill),
              color: isLocked ? Colors.grey : (isCompleted ? Colors.green : Colors.pinkAccent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap, {Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor ?? const Color(0xFF5D4037), size: 22),
      ),
    );
  }

  Widget _buildMagicGlow({double? top, double? left, double? right, required Color color}) {
    return Positioned(
      top: top, left: left, right: right,
      child: Container(
        height: 300, width: 300,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)]),
      ),
    );
  }
}