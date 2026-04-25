// VM/IO: custom HTTP client with longer timeouts to avoid connection abort.
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates an HTTP client with longer connection and idle timeouts
/// so auth requests to Supabase are less likely to abort (SocketException).
http.Client? createSupabaseHttpClient() {
  final ioClient = HttpClient();
  ioClient.connectionTimeout = const Duration(seconds: 45);
  ioClient.idleTimeout = const Duration(seconds: 45);
  return IOClient(ioClient);
}
