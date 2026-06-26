import 'dart:ui';
import 'dart:math'; // Random avatar ke liye
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  // 1. Mystical Avatars ki List (Aap yahan apne pasandida links dal sakte hain)
  final List<String> _mysticalAvatars = [
    'https://api.dicebear.com/7.x/adventurer/png?seed=Luna&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Shadow&backgroundColor=c0aede',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Star&backgroundColor=ffd5dc',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Forest&backgroundColor=d1f4f9',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Mystic&backgroundColor=ffdfbf',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Spirit&backgroundColor=ffd5dc',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Astra&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Nova&backgroundColor=ffd5dc',
  ];

  String displayName = "Dreamer";
  int diamonds = 0;
  String? avatarUrl;
  String referralCode = "DREAM777";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase.from('profiles').select().eq('id', user.id).single();

        setState(() {
          displayName = data['display_name'] ?? "New Dreamer";
          diamonds = data['diamonds'] ?? 0;
          avatarUrl = data['avatar_url'];
          referralCode = data['referral_code'] ?? "DREAM${user.id.substring(0, 4).toUpperCase()}";
          
          // 2. Agar user naya hai aur avatar null hai, toh random assign karo
          if (avatarUrl == null) {
            avatarUrl = _mysticalAvatars[Random().nextInt(_mysticalAvatars.length)];
            _updateAvatarInDB(avatarUrl!);
          }
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateAvatarInDB(String url) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', userId);
  }

  // 3. Avatar Picker Bottom Sheet (Netflix Style)
  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Choose Your Soul Avatar", style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: const Color(0xFF5D4037))),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: _mysticalAvatars.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => avatarUrl = _mysticalAvatars[index]);
                        _updateAvatarInDB(_mysticalAvatars[index]);
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(_mysticalAvatars[index]),
                        backgroundColor: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 30),
                // Header (With functional edit)
                _buildProfileHeader(),
                const SizedBox(height: 30),
                _buildDiamondWallet(context),
                const SizedBox(height: 20),
                _buildReferralSection(),
                const SizedBox(height: 30),
                _buildSettingsList(),
                const SizedBox(height: 50),
                Text(
                  "App Version 1.0.4 Build-26",
                  style: TextStyle(color: const Color(0xFF5D4037).withOpacity(0.3), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.pinkAccent),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(avatarUrl ?? _mysticalAvatars[0]),
              ),
            ),
            GestureDetector(
              onTap: _showAvatarPicker, // Netflix style picker khulega
              child: const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFF5D4037),
                child: Icon(Icons.edit, size: 15, color: Colors.white),
              ),
            )
          ],
        ),
        const SizedBox(height: 15),
        Text(
          displayName,
          style: GoogleFonts.dmSerifDisplay(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037)),
        ),
        Text(
          "Story Explorer • Level 12",
          style: GoogleFonts.poppins(color: Colors.blueGrey, fontSize: 12),
        ),
      ],
    );
  }

  // Wallet, Referral, aur Settings tiles wahi rahengi jo aapne pehle code mein di thi...
  // (Bas un tiles ke onTap mein logic add karna hai)

  Widget _buildDiamondWallet(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DIAMOND BALANCE", style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.diamond, color: Colors.pinkAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(diamonds.toString(), style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
                    ],
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {}, // Future Top-up screen
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("TOP UP"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.pinkAccent.withOpacity(0.2))),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(referralCode, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFF5D4037))),
                const Text("Invite friends to earn 50 💎", style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: referralCode));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Referral code copied!")));
            },
            child: const Text("COPY", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Column(
      children: [
        _settingTile(Icons.person_outline, "Account Settings", onTap: () {}),
        _settingTile(Icons.history, "Reading History", onTap: () {}),
        _settingTile(Icons.notifications_none, "Push Notifications", onTap: () {}),
        _settingTile(Icons.help_outline, "Help & Support", onTap: () {}),
        const SizedBox(height: 20),
        _settingTile(Icons.logout, "Logout", isLogout: true, onTap: _handleLogout),
      ],
    );
  }

  Widget _settingTile(IconData icon, String title, {bool isLogout = false, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.5))),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.redAccent : const Color(0xFF5D4037)),
        title: Text(title, style: TextStyle(color: isLogout ? Colors.redAccent : const Color(0xFF5D4037), fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.blueGrey),
        onTap: onTap,
      ),
    );
  }

  Future<void> _handleLogout() async {
    final supabase = Supabase.instance.client;
    await supabase.auth.signOut();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
  }
}