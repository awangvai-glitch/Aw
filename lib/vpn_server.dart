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

  // fromJson constructor remains the same
  factory VpnServer.fromJson(Map<String, dynamic> json) {
    return VpnServer(
      id: json['id'] as int,
      country: json['country'] as String,
      config: json['config'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      host: json['host'] as String,
    );
  }

  // Add toJson method to convert the object to a Map
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

  // Helper method to encode a list of servers to a JSON string
  static String encode(List<VpnServer> servers) => json.encode(
        servers
            .map<Map<String, dynamic>>((server) => server.toJson())
            .toList(),
      );

  // Helper method to decode a JSON string to a list of servers
  static List<VpnServer> decode(String servers) =>
      (json.decode(servers) as List<dynamic>)
          .map<VpnServer>((item) => VpnServer.fromJson(item))
          .toList();
}
