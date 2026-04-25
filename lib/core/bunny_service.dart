import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BunnyService {
  // --- CONFIGURATION ---
  static const String _libraryId = '589020'; // From Stream -> API
  static const String _apiKey = '6e362866-6519-468e-a6c7ce9a5ce1-c812-4ed0';       // From Stream -> API
  static const String _cdnHost = 'vz-f79aeca4-809.b-cdn.net'; // From Stream -> General (Pull Zone)

  // --- 1. UPLOAD VIDEO (Stream Version) ---
  static Future<String?> uploadVideo(File videoFile, String title) async {
    try {
      // Step A: Create the Video Object
      final createUrl = Uri.parse('https://video.bunnycdn.com/library/$_libraryId/videos');
      
      final createResponse = await http.post(
        createUrl,
        headers: {
          'AccessKey': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'title': title}),
      );

      if (createResponse.statusCode != 200) {
        print("❌ Create Failed: ${createResponse.body}");
        return null;
      }

      final videoId = jsonDecode(createResponse.body)['guid'];
      print("✅ Video Created. ID: $videoId");

      // Step B: Upload the Binary File
      final uploadUrl = Uri.parse('https://video.bunnycdn.com/library/$_libraryId/videos/$videoId');
      
      final uploadResponse = await http.put(
        uploadUrl,
        headers: {
          'AccessKey': _apiKey,
          'Content-Type': 'application/octet-stream',
        },
        body: await videoFile.readAsBytes(),
      );

      if (uploadResponse.statusCode == 200) {
        print("✅ Upload Complete!");
        return videoId; // Use this ID in Supabase
      } else {
        print("❌ Upload Failed: ${uploadResponse.body}");
        return null;
      }
    } catch (e) {
      print("❌ Error: $e");
      return null;
    }
  }

  // --- 2. GET STREAM URL (Adaptive HLS) ---
  // Use this for the VideoPlayer (Network)
  static String getStreamUrl(String videoId) {
    return 'https://$_cdnHost/$videoId/playlist.m3u8';
  }

  // --- 3. GET DOWNLOAD URL (MP4) ---
  // Use this for DownloadService (Offline Mode)
  static String getDownloadUrl(String videoId) {
    // Note: You MUST enable "MP4 Fallback" in Bunny Dashboard -> Encoding
    // We typically download the 720p version to save space
    return 'https://$_cdnHost/$videoId/play_720p.mp4'; 
  }

  // --- 4. GET THUMBNAIL URL ---
  static String getThumbnailUrl(String videoId) {
    return 'https://$_cdnHost/$videoId/thumbnail.jpg';
  }
}
