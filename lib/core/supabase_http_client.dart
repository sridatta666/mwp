// Export the platform-specific HTTP client for Supabase (longer timeouts on mobile/desktop).
import 'supabase_http_client_stub.dart'
    if (dart.library.io) 'supabase_http_client_io.dart' as impl;

import 'package:http/http.dart' as http;

/// Returns a custom HTTP client with longer timeouts on VM (iOS/Android/Desktop),
/// or null on web so Supabase uses the default client.
http.Client? createSupabaseHttpClient() => impl.createSupabaseHttpClient();
