import 'dart:convert';

class VpnServer {
  final int id;
  final String country;
  final String config;
  final String username;
  final String password;
  final String host;

  VpnServer({
    required this.id,
    required this.country,
    required this.config,
    required this.username,
    required this.password,
    required this.host,
  });

  // fromJson constructor made robust against null values
  factory VpnServer.fromJson(Map<String, dynamic> json) {
    return VpnServer(
      id: json['id'] as int? ?? 0, // Default to 0 if id is null
      country: json['country'] as String? ?? '', // Default to empty string
      config: json['config'] as String? ?? '', // Default to empty string
      username: json['username'] as String? ?? '', // Default to empty string
      password: json['password'] as String? ?? '', // Default to empty string
      host: json['host'] as String? ?? '', // Default to empty string
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country': country,
      'config': config,
      'username': username,
      'password': password,
      'host': host,
    };
  }

  static String encode(List<VpnServer> servers) => json.encode(
        servers
            .map<Map<String, dynamic>>((server) => server.toJson())
            .toList(),
      );

  static List<VpnServer> decode(String servers) =>
      (json.decode(servers) as List<dynamic>)
          .map<VpnServer>((item) => VpnServer.fromJson(item as Map<String, dynamic>))
          .toList();
}
