import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart'; // Audio ke liye import

class VNPlayerScreen extends StatefulWidget {
  final String storyId;
  final String episodeId;
  final String storyTitle;

  const VNPlayerScreen({
    super.key,
    required this.storyId,
    required this.episodeId,
    required this.storyTitle,
  });

  @override
  State<VNPlayerScreen> createState() => _VNPlayerScreenState();
}

class _VNPlayerScreenState extends State<VNPlayerScreen> {
  int _currentIndex = 0;
  String _displayedText = "";
  Timer? _typewriterTimer;
  
  bool _isLoading = true;
  bool _isTransitioning = false;
  
  bool _isAutoPlay = false;
  bool _isSoundOn = true;

  List<dynamic> _script = [];
  String _currentEpId = "";
  
  final supabase = Supabase.instance.client;

  // --- AUDIO PLAYERS ---
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _ambiencePlayer = AudioPlayer();
  String? _currentBgm;
  String? _currentAmbience;

  @override
  void initState() {
    super.initState();
    _currentEpId = widget.episodeId;
    _loadSettings();
    _initializeEpisode(_currentEpId);
  }

  // --- AUDIO LOGIC ---
  Future<void> _handleAudio(Map scene) async {
    if (!_isSoundOn) return;

    // 1. BGM Logic (Looping)
    if (scene.containsKey('bgm')) {
      String newBgm = scene['bgm'];
      if (_currentBgm != newBgm) {
        _currentBgm = newBgm;
        await _bgmPlayer.stop();
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.play(AssetSource('sounds/bgm/$newBgm.mp3'));
      }
    }

    // 2. Ambience Logic (Looping)
    if (scene.containsKey('ambience')) {
      String newAmb = scene['ambience'];
      if (_currentAmbience != newAmb) {
        _currentAmbience = newAmb;
        await _ambiencePlayer.stop();
        await _ambiencePlayer.setReleaseMode(ReleaseMode.loop);
        await _ambiencePlayer.play(AssetSource('sounds/ambience/$newAmb.mp3'));
      }
    }

    // 3. SFX Logic (One-shot)
    if (scene.containsKey('sfx')) {
      await _sfxPlayer.stop(); // Pichla SFX agar chal raha ho toh reset karein
      await _sfxPlayer.play(AssetSource('sounds/sfx/${scene['sfx']}.mp3'));
    }
  }

  Future<void> _stopAllAudio() async {
    await _bgmPlayer.stop();
    await _sfxPlayer.stop();
    await _ambiencePlayer.stop();
    _currentBgm = null;
    _currentAmbience = null;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoPlay = prefs.getBool('autoPlay') ?? false;
      _isSoundOn = prefs.getBool('soundOn') ?? true;
    });
    if (!_isSoundOn) _stopAllAudio();
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (key == 'soundOn' && !value) _stopAllAudio();
  }

  Future<void> _initializeEpisode(String epId) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isTransitioning = false;
      _script = [];
      _displayedText = "";
    });
    
    try {
      dynamic queryId = int.tryParse(epId) ?? epId;

      final response = await supabase
          .from('episodes')
          .select('script_json') 
          .eq('id', queryId)
          .single();

      final rawData = response['script_json'];
      
      if (rawData == null) throw "Database mein script nahi mili!";

      List<dynamic> fetchedScript = [];
      if (rawData is List) {
        fetchedScript = rawData;
      } else if (rawData is Map && rawData.containsKey('script')) {
        fetchedScript = rawData['script'];
      }

      if (mounted) {
        setState(() {
          _script = fetchedScript;
        });
        
        if (_script.isEmpty) throw "Episode script is empty!";
        
        await _loadProgress(epId);
      }
    } catch (e) {
      debugPrint("VN Player Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadProgress(String epId) async {
    final prefs = await SharedPreferences.getInstance();
    String key = "${widget.storyId}_${epId}_progress";
    int savedIndex = prefs.getInt(key) ?? 0;

    if (mounted) {
      setState(() {
        _currentIndex = (savedIndex < _script.length) ? savedIndex : 0;
        _isLoading = false; 
      });
      _startTypewriter();
    }
  }

  Future<void> _saveProgress(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("${widget.storyId}_${_currentEpId}_progress", index);
    await prefs.setString('last_ep_id_${widget.storyId}', _currentEpId);
    
    int currentUnlocked = prefs.getInt('last_unlocked_${widget.storyId}') ?? 0;
    if (currentUnlocked == 0) {
      await prefs.setInt('last_unlocked_${widget.storyId}', 1);
    }
  }

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    if (_script.isEmpty || _currentIndex >= _script.length) return;

    var currentScene = _script[_currentIndex];
    _handleAudio(currentScene); // Audio yahan trigger hoga

    setState(() => _displayedText = "");
    String fullText = currentScene["text"]?.toString() ?? "...";
    int charIndex = 0;

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (charIndex < fullText.length) {
        if (mounted) {
          setState(() {
            _displayedText += fullText[charIndex];
            charIndex++;
          });
        }
      } else {
        timer.cancel();
        if (_isAutoPlay) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isAutoPlay && !_isTransitioning) _nextDialogue();
          });
        }
      }
    });
  }

  void _jumpToScene(dynamic targetId) {
    int nextIndex = _script.indexWhere((element) => element['id'] == targetId);
    if (nextIndex != -1) {
      setState(() {
        _currentIndex = nextIndex;
        _saveProgress(_currentIndex);
        _startTypewriter();
      });
    }
  }

  void _nextDialogue() {
    if (_isTransitioning || _script.isEmpty) return;

    var currentScene = _script[_currentIndex];

    if (currentScene.containsKey('target')) {
      _jumpToScene(currentScene['target']);
      return;
    }

    bool hasChoices = (currentScene["choices"] != null && (currentScene["choices"] as List).isNotEmpty);
    if (hasChoices) return;

    if (_currentIndex < _script.length - 1) {
      setState(() {
        _currentIndex++;
        _saveProgress(_currentIndex);
        _startTypewriter();
      });
    } else {
      _handleEpisodeCompletion();
    }
  }

  void _handleEpisodeCompletion() async {
    _typewriterTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_$_currentEpId', true); 

    setState(() => _isTransitioning = true);

    try {
      final episodes = await supabase
          .from('episodes')
          .select('id, episode_number')
          .eq('story_id', widget.storyId)
          .order('episode_number', ascending: true);

      await prefs.setInt('total_ep_count_${widget.storyId}', episodes.length + 1);

      int currentIndexInList = episodes.indexWhere((ep) => ep['id'].toString() == _currentEpId);

      if (currentIndexInList != -1 && currentIndexInList + 1 < episodes.length) {
        String nextEpId = episodes[currentIndexInList + 1]['id'].toString();
        await prefs.setString('last_ep_id_${widget.storyId}', nextEpId);
        await prefs.setInt('last_unlocked_${widget.storyId}', currentIndexInList + 2);
        
        await Future.delayed(const Duration(seconds: 3));
        _currentEpId = nextEpId;
        _currentIndex = 0;
        _initializeEpisode(_currentEpId);
      } else {
        await prefs.setInt('last_unlocked_${widget.storyId}', episodes.length + 1);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("SETTINGS", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037), letterSpacing: 2)),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: Text("Auto Play", style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF5D4037))),
                    activeThumbColor: Colors.pinkAccent,
                    value: _isAutoPlay,
                    onChanged: (val) {
                      setModalState(() => _isAutoPlay = val);
                      setState(() => _isAutoPlay = val);
                      _saveSetting('autoPlay', val);
                      if (val && _script.isNotEmpty && _displayedText.length == (_script[_currentIndex]["text"]?.toString().length ?? 0)) {
                        _nextDialogue();
                      }
                    },
                  ),
                  SwitchListTile(
                    title: Text("Sound Effects", style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF5D4037))),
                    activeThumbColor: Colors.pinkAccent,
                    value: _isSoundOn,
                    onChanged: (val) {
                      setModalState(() => _isSoundOn = val);
                      setState(() => _isSoundOn = val);
                      _saveSetting('soundOn', val);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
    _ambiencePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isTransitioning) {
      return const Scaffold(
        backgroundColor: Color(0xFFE0F2F1), 
        body: Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)))
      );
    }

    var currentScene = _script.isNotEmpty ? _script[_currentIndex] : {};
    String fullDialogueText = currentScene["text"]?.toString() ?? "";
    bool isTextFinished = _displayedText.length == fullDialogueText.length;
    List<dynamic>? choices = currentScene["choices"];

    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND LAYER
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Image.network(
              currentScene["bg"] ?? "https://via.placeholder.com/800",
              key: ValueKey("$_currentIndex$_currentEpId"),
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
            ),
          ),
          
          // CHARACTER SPRITE LAYER (Added layering)
          if (currentScene["sprite"] != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 180), // Dialogue box ke upar
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Image.network(
                    currentScene["sprite"],
                    key: ValueKey(currentScene["sprite"]),
                    height: MediaQuery.of(context).size.height * 0.6,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isTransitioning || _script.isEmpty) return;
                if (_displayedText.length < fullDialogueText.length) {
                  setState(() => _displayedText = fullDialogueText);
                  _typewriterTimer?.cancel();
                } else {
                  _nextDialogue();
                }
              },
            ),
          ),

          if (isTextFinished && choices != null && choices.isNotEmpty)
            _buildChoiceOverlay(choices),

          // DIALOGUE BOX
          if (!_isTransitioning && _script.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40, left: 15, right: 15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (currentScene["speaker"] ?? "???").toString().toUpperCase(), 
                            style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: Colors.pinkAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              _displayedText, 
                              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, height: 1.5)
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // TOP NAVIGATION
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("DreamBox", style: GoogleFonts.dmSerifDisplay(fontSize: 28, color: Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 10)])),
                  Row(
                    children: [
                      _buildGlassIcon(Icons.home_rounded, () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      _buildGlassIcon(Icons.settings_rounded, _showSettingsSheet),
                    ],
                  )
                ],
              ),
            ),
          ),

          if (_isTransitioning) _buildTransitionOverlay(),
        ],
      ),
    );
  }

  Widget _buildChoiceOverlay(List<dynamic> choices) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: choices.map((choice) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: GestureDetector(
                onTap: () => _jumpToScene(choice["target"]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        choice["text"] ?? "",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGlassIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildTransitionOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Preparing Next Path...", style: GoogleFonts.dmSerifDisplay(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 40),
                const SizedBox(width: 220, child: LinearProgressIndicator(color: Colors.pinkAccent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}