import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/supabase_service.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController();
  
  // State
  String _difficulty = 'Beginner';
  String _workoutType = 'standard'; // 'standard' or 'sequence'
  
  // Standard Video State
  File? _selectedVideo;
  String? _uploadedVideoId; 
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  // Sequence Video State
  final List<Map<String, dynamic>> _clips = []; // {file: File, videoId: String?, isUploading: bool, title: String, restDuration: int}

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isAdmin = await SupabaseService().isUserAdmin();
    if (!isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: Admins Only")));
        Navigator.pop(context);
      }
    }
  }

  // --- 1. PICK VIDEO (Standard) ---
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      setState(() {
        _selectedVideo = File(video.path);
        _uploadedVideoId = null; 
      });
    }
  }

  // --- 2. UPLOAD TO BUNNY (Standard) ---
  Future<void> _uploadToBunny() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
    });

    try {
      final videoId = await _performBunnyUpload(_selectedVideo!, _titleController.text);
      
      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
        _uploadedVideoId = videoId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Video Uploaded!")));
      }

    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 3. SEQUENCE LOGIC ---
  Future<void> _pickClip() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      setState(() {
        _clips.add({
          'file': File(video.path),
          'videoId': null,
          'isUploading': false,
          'title': 'Clip ${_clips.length + 1}',
          'restDuration': 30, // Default 30s rest
        });
      });
    }
  }

  Future<void> _uploadClip(int index) async {
    final clip = _clips[index];
    if (clip['file'] == null || clip['videoId'] != null) return;

    setState(() {
      _clips[index]['isUploading'] = true;
    });

    try {
      final videoId = await _performBunnyUpload(clip['file'], "${_titleController.text} - Clip ${index + 1}");
      
      setState(() {
        _clips[index]['isUploading'] = false;
        _clips[index]['videoId'] = videoId;
      });
    } catch (e) {
      setState(() {
        _clips[index]['isUploading'] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading clip ${index + 1}: $e")));
      }
    }
  }

  Future<String> _performBunnyUpload(File file, String title) async {
      // ⚠️ REPLACE THESE WITH YOUR ACTUAL KEYS
      const String libraryId = "589020"; 
      const String apiKey = "6e362866-6519-468e-a6c7ce9a5ce1-c812-4ed0";
      
      // A. Create Video Entry
      final createUrl = Uri.parse("https://video.bunnycdn.com/library/$libraryId/videos");
      
      final createResponse = await http.post(
        createUrl,
        headers: {
          "AccessKey": apiKey,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({"title": title.isEmpty ? "New Workout" : title}),
      );

      if (createResponse.statusCode != 200) {
        throw "Failed to create video entry: ${createResponse.body}";
      }

      final videoData = jsonDecode(createResponse.body);
      final String videoId = videoData['guid'];

      // B. Upload Binary File
      final uploadUrl = Uri.parse("https://video.bunnycdn.com/library/$libraryId/videos/$videoId");
      final videoBytes = await file.readAsBytes();

      final uploadResponse = await http.put(
        uploadUrl,
        headers: {
          "AccessKey": apiKey,
          "Content-Type": "application/octet-stream",
        },
        body: videoBytes,
      );

      if (uploadResponse.statusCode != 200) {
        throw "Failed to upload file bytes: ${uploadResponse.body}";
      }
      
      return videoId;
  }

  void _removeClip(int index) {
    setState(() {
      _clips.removeAt(index);
    });
  }

  // --- 4. SAVE TO SUPABASE ---
  Future<void> _saveWorkout() async {
    // Validation
    if (_workoutType == 'standard' && _uploadedVideoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload the main video.")));
      return;
    }
    if (_workoutType == 'sequence' && (_clips.isEmpty || _clips.any((c) => c['videoId'] == null))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add clips and ensure all are uploaded.")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final client = Supabase.instance.client;
      
      // Construct Payload
      final Map<String, dynamic> payload = {
        'title': _titleController.text,
        'description': _descController.text,
        'duration': int.tryParse(_durationController.text) ?? 15,
        'difficulty': _difficulty,
        'created_at': DateTime.now().toIso8601String(),
        'type': _workoutType,
      };

      if (_workoutType == 'standard') {
        payload['video_id'] = _uploadedVideoId;
        payload['clips'] = null;
      } else {
        payload['video_id'] = ''; // Or some placeholder
        payload['clips'] = _clips.map((c) => {
          'video_id': c['videoId'],
          'title': c['title'],
          'rest_duration': c['restDuration'],
        }).toList();
      }
      
      await client.from('workouts').insert(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 Workout Published!")));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Database Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Upload Workout"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Metadata Form
            _buildTextField("Title", _titleController),
            const SizedBox(height: 15),
            _buildTextField("Description", _descController, maxLines: 3),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildTextField("Duration (mins)", _durationController, isNumber: true)),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _difficulty,
                  dropdownColor: AppTheme.surfaceVariant,
                  decoration: _inputDecoration("Difficulty"),
                    items: ["Beginner", "Intermediate", "Advanced"]
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(color: AppTheme.textPrimary))))
                        .toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // 2. Type Selector
             DropdownButtonFormField<String>(
              value: _workoutType,
              dropdownColor: AppTheme.surfaceVariant,
              decoration: _inputDecoration("Workout Type"),
              items: [
                DropdownMenuItem(value: 'standard', child: Text("Standard Video", style: TextStyle(color: AppTheme.textPrimary))),
                DropdownMenuItem(value: 'sequence', child: Text("Clip Sequence", style: TextStyle(color: AppTheme.textPrimary))),
              ],
              onChanged: (v) => setState(() => _workoutType = v!),
            ),

            const SizedBox(height: 30),
            
            // 3. Media Picker
            if (_workoutType == 'standard') _buildStandardUploader() else _buildSequenceUploader(),

            const SizedBox(height: 40),

            // 4. Final Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_isSaving ? "Saving…" : "Publish workout"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildStandardUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Main video", style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickVideo,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.surfaceVariant),
            ),
            child: _selectedVideo == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_rounded, color: AppTheme.primary, size: 40),
                      const SizedBox(height: 10),
                      Text("Tap to select video", style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 40),
                      const SizedBox(height: 10),
                      Text(_selectedVideo!.path.split(RegExp(r'[/\\]')).last, style: TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        if (_selectedVideo != null && _uploadedVideoId == null)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadToBunny,
              icon: _isUploading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background))
                  : Icon(Icons.cloud_upload_rounded),
              label: Text(_isUploading ? "Uploading…" : "Upload to Bunny"),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: AppTheme.background),
            ),
          ),
        if (_uploadedVideoId != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_rounded, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text("Video ID: $_uploadedVideoId", style: TextStyle(color: AppTheme.primary, fontSize: 12))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSequenceUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Workout clips", style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            TextButton.icon(
              onPressed: _pickClip,
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Add Clip"),
            )
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _clips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final clip = _clips[index];
            final isUploaded = clip['videoId'] != null;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isUploaded ? AppTheme.primary.withOpacity(0.5) : AppTheme.surfaceVariant),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8)),
                        child: Text("${index + 1}", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((clip['file'] as dynamic).path.split(RegExp(r'[/\\]')).last, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Text(isUploaded ? "Uploaded" : "Pending", style: TextStyle(color: isUploaded ? AppTheme.primary : AppTheme.accent, fontSize: 12)),
                                if (clip['isUploading'] == true) ...[
                                  const SizedBox(width: 10),
                                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_rounded, color: AppTheme.accent),
                        onPressed: () => _removeClip(index),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: _inputDecoration("Title").copyWith(isDense: true, contentPadding: const EdgeInsets.all(10)),
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          onChanged: (v) => _clips[index]['title'] = v,
                          controller: TextEditingController(text: clip['title']),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: _inputDecoration("Rest (s)").copyWith(isDense: true, contentPadding: const EdgeInsets.all(10)),
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _clips[index]['restDuration'] = int.tryParse(v) ?? 30,
                          controller: TextEditingController(text: clip['restDuration'].toString()),
                        ),
                      ),
                    ],
                  ),
                  if (!isUploaded && clip['isUploading'] != true)
                    TextButton(
                      onPressed: () => _uploadClip(index),
                      child: const Text("Upload Clip"),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool isNumber = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textMuted),
      filled: true,
      fillColor: AppTheme.surfaceVariant,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
    );
  }
}
