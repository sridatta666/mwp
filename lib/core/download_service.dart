import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'bunny_service.dart';

class DownloadService {
  final Box _box = Hive.box('downloads');
  final Dio _dio = Dio();

  // 1. DYNAMIC PATH GETTER (The Fix)
  // We reconstruct the path every time so it's always valid.
  Future<String> getFilePath(String videoId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$videoId.mp4';
  }

  // 2. Check if downloaded
  // We check Hive AND if the file actually exists physically.
  Future<bool> isDownloaded(String videoId) async {
    // Check "Intent" (Did we try to download it?)
    if (!_box.containsKey(videoId)) return false;

    // Check "Reality" (Is the file actually there?)
    final path = await getFilePath(videoId);
    return File(path).exists();
  }

  // 3. Download
  Future<void> downloadVideo(String videoId, Function(double) onProgress) async {
    try {

      final url = BunnyService.getDownloadUrl(videoId);

      print("⬇️ Attempting Download: $url");
      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/$videoId.mp4";
      final tempPath = "$savePath.tmp"; // Download to temp file first
      
      // Delete existing temp file if any
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();

      await _dio.download(
        url, 
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            // print("📦 Progress: ${(progress * 100).toStringAsFixed(0)}%");
            onProgress(progress);
          }
        },
      );

      // Rename temp file to final file
      if (await tempFile.exists()) {
        await tempFile.rename(savePath);
        print("✅ Download Success! Saved to: $savePath");
        
        final finalFile = File(savePath);
        print("✅ File Size: ${await finalFile.length()} bytes");
        
        await _box.put(videoId, savePath); 
      } else {
        throw Exception("Download failed: Temp file missing.");
      }
     

    } catch (e) {
      print("❌ Download Failed: $e");
      rethrow;
    }
  }

  // 4. Delete
  Future<void> deleteVideo(String videoId) async {
    final path = await getFilePath(videoId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await _box.delete(videoId);
  }

    // 5. Calculate Total Usage
  Future<String> getTotalUsage() async {
    int totalBytes = 0;
    final keys = _box.keys; // Get all video IDs

    for (var key in keys) {
      final path = _box.get(key);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          totalBytes += await file.length();
        }
      }
    }

    // Convert to MB
    final mb = totalBytes / (1024 * 1024);
    return "${mb.toStringAsFixed(1)} MB";
  }

  // 6. Delete ALL Downloads
  Future<void> deleteAllDownloads() async {
    final keys = _box.keys.toList(); // List because we will modify the box

    for (var key in keys) {
      final path = _box.get(key);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete(); // Delete from Phone
        }
      }
    }
    
    await _box.clear(); // Clear from Hive Memory
    print("🧹 All downloads deleted.");
  }

















}
