class VpnServer {
  final String name;
  final String ovpnConfig;
  final String username;
  final String password;

  VpnServer({
    required this.name,
    required this.ovpnConfig,
    required this.username,
    required this.password,
  });
}
