import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

import 'vpn_server.dart';

class VpnProvider with ChangeNotifier {
  final SupabaseClient _supabase;
  late OpenVPN engine;
  List<VpnServer> _servers = [];
  VpnServer? _selectedServer;
  bool _isLoading = false;
  bool _isConnecting = false;

  VpnStatus? _vpnStatus;
  VPNStage? _vpnStage;

  List<VpnServer> get servers => _servers;
  VpnServer? get selectedServer => _selectedServer;
  bool get isLoading => _isLoading;
  bool get isConnecting => _isConnecting;
  VpnStatus? get vpnStatus => _vpnStatus;
  VPNStage? get vpnStage => _vpnStage;

  static const String _serversCacheKey = 'vpn_servers_cache';

  VpnProvider(this._supabase) {
    // Initialize the VPN engine
    engine = OpenVPN(
      onVpnStatusChanged: (VpnStatus? status) { 
        _vpnStatus = status;
        notifyListeners();
      },
      onVpnStageChanged: (VPNStage? stage, String? raw) { 
        _vpnStage = stage;
        notifyListeners();
      },
    );

    engine.initialize();
    fetchServers();
  }

  Future<void> _saveServersToCache(List<VpnServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = VpnServer.encode(servers);
    await prefs.setString(_serversCacheKey, encodedData);
  }

  Future<void> _loadServersFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_serversCacheKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      _servers = VpnServer.decode(cachedData);
      if (_selectedServer != null) {
        try {
          // Find the previously selected server in the new list
          _selectedServer = _servers.firstWhere((s) => s.id == _selectedServer!.id);
        } catch (e) {
          // If not found, select the first available server or null
          _selectedServer = _servers.isNotEmpty ? _servers.first : null;
        }
      }
      notifyListeners();
    }
  }

  Future<void> fetchServers() async {
    _isLoading = true;
    notifyListeners();

    await _loadServersFromCache();
    if (_servers.isNotEmpty) {
      _isLoading = false;
      notifyListeners();
    }

    try {
      final response = await _supabase.from('servers').select();
      final List<dynamic> data = response as List<dynamic>;
      final newServers = data.map((json) => VpnServer.fromJson(json as Map<String, dynamic>)).toList();

      if (json.encode(_servers.map((e) => e.toJson()).toList()) != json.encode(newServers.map((e) => e.toJson()).toList())) {
        _servers = newServers;
        await _saveServersToCache(_servers);
      }

      if (_selectedServer == null && _servers.isNotEmpty) {
        _selectedServer = _servers[0];
      }

    } catch (e) {
      if (kDebugMode) {
        print('Error fetching from Supabase: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectServer(VpnServer server) {
    _selectedServer = server;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_selectedServer == null) return;

    _isConnecting = true;
    notifyListeners();

    try {
      engine.connect(
          _selectedServer!.config,
          _selectedServer!.country, // Using country as the display name
          username: _selectedServer!.username,
          password: _selectedServer!.password,
      );
    } catch (e) {
      if (kDebugMode) {
        print('VPN Connection Error: $e');
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    engine.disconnect();
  }
}
