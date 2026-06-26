import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'story_detail_screen.dart';
import '../vn_engine/vn_player.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  LibraryScreenState createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  
  String _searchQuery = "";
  List<dynamic> _allStories = [];
  Map<String, bool> _favoritesMap = {};
  Map<String, double> _progressMap = {}; 
  Map<String, String> _lastEpisodeMap = {}; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLibraryData();
  }

  void refreshLibrary() {
    _fetchLibraryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLibraryData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      String savedJson = prefs.getString('saved_stories_list') ?? '[]';
      List<dynamic> savedStories = jsonDecode(savedJson);

      String? cachedData = prefs.getString('home_stories_cache');
      List<dynamic> mergedStories = List.from(savedStories);

      if (cachedData != null) {
        List<dynamic> homeCached = jsonDecode(cachedData);
        for (var story in homeCached) {
          if (!mergedStories.any((s) => s['id'].toString() == story['id'].toString())) {
            mergedStories.add(story);
          }
        }
      }

      Map<String, bool> favs = {};
      Map<String, double> progress = {};
      Map<String, String> lastEp = {};

      for (var story in mergedStories) {
        String storyId = story['id'].toString();
        favs[storyId] = prefs.getBool(storyId) ?? false;
        
        // --- NAYA LOGIC: Total count track karna ---
        int unlocked = prefs.getInt('last_unlocked_$storyId') ?? 0; 
        int total = prefs.getInt('total_ep_count_$storyId') ?? 999; // Default bada number rakha hai taaki errors na aayein

        // Agar progress 0 se zyada hai AUR total se kam hai, tabhi Continue list mein jayega
        if (unlocked > 0 && unlocked < total) {
          progress[storyId] = (unlocked / total).clamp(0.1, 1.0); // Progress dynamic ban gayi
          lastEp[storyId] = prefs.getString('last_ep_id_$storyId') ?? "1"; 
        }
      }

      if (mounted) {
        setState(() {
          _allStories = mergedStories;
          _favoritesMap = favs;
          _progressMap = progress;
          _lastEpisodeMap = lastEp;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Library Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _continueReadingList => _allStories.where((s) => _progressMap.containsKey(s['id'].toString())).toList();
  List<dynamic> get _favoritesList => _allStories.where((s) => _favoritesMap[s['id'].toString()] == true).toList();
  List<dynamic> get _filteredStories => _allStories.where((s) => s['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

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
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              if (_searchQuery.isEmpty) _buildGlassTabBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)))
                    : RefreshIndicator(
                        onRefresh: _fetchLibraryData,
                        color: const Color(0xFF5D4037),
                        child: _searchQuery.isEmpty
                            ? TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildStoryGrid(_continueReadingList, isContinueTab: true),
                                  _buildStoryGrid(_favoritesList, isContinueTab: false),
                                ],
                              )
                            : _buildStoryGrid(_filteredStories, isContinueTab: false),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(20), 
    child: Row(
      children: [
        Text("LIBRARY", style: GoogleFonts.dmSerifDisplay(fontSize: 32, color: const Color(0xFF5D4037))),
      ],
    )
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: "Search your collection...",
        prefixIcon: const Icon(Icons.search, color: Color(0xFF5D4037)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _buildGlassTabBar() => TabBar(
    controller: _tabController,
    labelColor: const Color(0xFF5D4037),
    indicatorColor: const Color(0xFF5D4037),
    tabs: const [Tab(text: "Continue"), Tab(text: "Saved")],
  );

  Widget _buildStoryGrid(List<dynamic> stories, {required bool isContinueTab}) {
    if (stories.isEmpty) {
      return Center(child: Text("Nothing here yet", style: GoogleFonts.poppins(color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.7
      ),
      itemCount: stories.length,
      itemBuilder: (context, index) => _buildGlassCard(stories[index], isContinueTab),
    );
  }

  Widget _buildGlassCard(dynamic story, bool isContinueTab) {
    final storyId = story['id'].toString();
    return GestureDetector(
      onTap: () async {
        if (isContinueTab && _lastEpisodeMap.containsKey(storyId)) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VNPlayerScreen(
                storyId: storyId,
                episodeId: _lastEpisodeMap[storyId]!,
                storyTitle: story['title'] ?? "Untitled",
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryDetailScreen(
                id: storyId,
                title: story['title'] ?? "Untitled",
                image: story['cover_url'] ?? "",
                description: story['description'] ?? "",
              ),
            ),
          );
        }
        _fetchLibraryData();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Image.network(story['cover_url'] ?? "", fit: BoxFit.cover, width: double.infinity),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    story['title'] ?? "", 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF5D4037))
                  ),
                ),
                if (isContinueTab && _progressMap.containsKey(storyId))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: LinearProgressIndicator(
                      value: _progressMap[storyId],
                      backgroundColor: Colors.white24,
                      color: Colors.pinkAccent,
                      minHeight: 3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}