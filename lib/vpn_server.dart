import 'dart:developer' as developer;

class VpnServer {
  final String id;
  final String country;
  final String username;
  final String password;
  final String configFile;

  VpnServer({
    required this.id,
    required this.country,
    required this.username,
    required this.password,
    required this.configFile,
  });

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    // Log the incoming data for easier debugging in the future.
    developer.log('Parsing VpnServer from JSON', name: 'vpn_app.data', error: json.toString());

    try {
      return VpnServer(
        // Safely handle the ID. If it's null, provide a fallback.
        // .toString() works reliably on both int and String types.
        id: (json['id'] ?? 'invalid_id').toString(),

        // Safely handle the country, defaulting to 'N/A' if null.
        country: json['country'] as String? ?? 'N/A',

        // Safely handle username, defaulting to an empty string.
        username: json['username'] as String? ?? '',

        // Safely handle password, defaulting to an empty string.
        password: json['password'] as String? ?? '',

        // The database column is likely 'config_file'.
        configFile: json['config_file'] as String? ?? '',
      );
    } catch (e, s) {
      developer.log(
        'Failed to parse VpnServer from JSON',
        name: 'vpn_app.error',
        error: {'error': e.toString(), 'json': json},
        stackTrace: s,
      );
      // Re-throw the error so we know something went wrong, but with more context.
      throw FormatException('Failed to parse VpnServer', json);
    }
  }
}
