
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vpn_server.dart';

class VpnProvider with ChangeNotifier {
  final SupabaseClient _supabase;
  late final OpenVPN _openvpn;
  VpnStatus? _status;
  VPNStage? _stage;
  Timer? _timer;

  List<VpnServer> _servers = [];
  VpnServer? _selectedServer;
  bool _isLoading = false;

  VpnProvider(this._supabase) {
    _openvpn = OpenVPN(
      onVpnStatusChanged: (VpnStatus? status) {
        _status = status;
        print('VPN Status changed: $status');
        notifyListeners();
      },
      onVpnStageChanged: (VPNStage stage, String raw) {
        _stage = stage;
        print('VPN Stage changed: $stage, Raw: $raw');
        notifyListeners();
      },
    );
    fetchVpnServers();
  }

  List<VpnServer> get servers => _servers;
  VpnServer? get selectedServer => _selectedServer;
  VpnStatus? get vpnStatus => _status;
  VPNStage? get vpnStage => _stage;
  bool get isLoading => _isLoading;

  bool get isConnecting => _stage != null && _stage != VPNStage.disconnected && _stage != VPNStage.error;

  Future<void> fetchVpnServers() async {
    _isLoading = true;
    notifyListeners();

    print("Fetching VPN servers from Supabase...");

    try {
      final response = await _supabase.from('servers').select(); // Corrected table name
      print("Supabase response: $response");

      _servers = response.map<VpnServer>((json) => VpnServer.fromJson(json)).toList();
      print("Successfully fetched ${_servers.length} servers.");

    } catch (e, s) {
      print('Error fetching VPN servers: $e');
      print('Stacktrace: $s');
      _servers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void selectServer(VpnServer server) {
    _selectedServer = server;
    notifyListeners();
  }

  void connect() {
    if (_selectedServer == null || isConnecting) return;

    // --- Detailed Logging --- 
    print("--- Attempting to Connect ---");
    print("Server: ${_selectedServer!.country}");
    print("Username: ${_selectedServer!.username}");
    // Do not log the password for security.
    if (_selectedServer!.configFile.isNotEmpty) {
      print("Config File (first 100 chars): ${_selectedServer!.configFile.substring(0, 100)}...");
    } else {
      print("Config File is EMPTY!");
    }
    print("-----------------------------");
    // --- End of Logging ---

    _stage = VPNStage.connecting;
    notifyListeners();

    _openvpn.connect(
      _selectedServer!.configFile,
      _selectedServer!.country,
      username: _selectedServer!.username,
      password: _selectedServer!.password,
    );
  }

  void disconnect() {
    _openvpn.disconnect();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
