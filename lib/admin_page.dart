import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _jsonController = TextEditingController();
  bool _isLoading = false;

  Future<void> _publishData() async {
    if (_jsonController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final data = json.decode(_jsonController.text);
      final supabase = Supabase.instance.client;

      await supabase.from('stories').upsert({
        'id': data['story_id'],
        'title': data['story_info']['title'],
        'description': data['story_info']['description'],
        'genre': data['story_info']['genre'],
        'cover_image': data['story_info']['cover_image'],
      });

      await supabase.from('episodes').upsert({
        'story_id': data['story_id'],
        'episode_number': data['episode']['episode_number'],
        'title': data['episode']['episode_title'],
        'script_json': data['episode']['script'],
      });

      // --- FIX: Mounted check add kiya ---
      if (!mounted) return; 

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mubarak ho! Data Sync Ho Gaya."), backgroundColor: Colors.green),
      );
      _jsonController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: JSON format check karo! $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DreamBox Admin Panel")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Paste Master JSON Script:"),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _jsonController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: "{ 'story_id': '...', ... }",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _publishData,
                child: _isLoading ? const CircularProgressIndicator() : const Text("PUBLISH NOW"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}