import 'dart:convert';
import 'dart:developer' as developer;
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

  VpnStatus? _vpnStatus;
  VPNStage? _vpnStage;

  List<VpnServer> get servers => _servers;
  VpnServer? get selectedServer => _selectedServer;
  bool get isLoading => _isLoading;
  VpnStatus? get vpnStatus => _vpnStatus;
  VPNStage? get vpnStage => _vpnStage;

  static const String _serversCacheKey = 'vpn_servers_cache';

  VpnProvider(this._supabase) {
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
      try {
        _servers = VpnServer.decode(cachedData);
        if (_servers.isNotEmpty) {
          if (_selectedServer != null) {
            _selectedServer = _servers.firstWhere((s) => s.id == _selectedServer!.id, orElse: () => _servers.first);
          } else {
            _selectedServer = _servers.first;
          }
        } else {
            _selectedServer = null;
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error loading from cache: $e");
        }
        await prefs.remove(_serversCacheKey);
        _servers = [];
        _selectedServer = null;
      }
      notifyListeners();
    }
  }

  Future<void> fetchServers() async {
    _isLoading = true;
    notifyListeners();

    await _loadServersFromCache();
    
    try {
      final List<dynamic> response = await _supabase.from('servers').select();
      final newServers = response.map((json) => VpnServer.fromJson(json as Map<String, dynamic>)).toList();

      if (json.encode(_servers.map((e) => e.toJson()).toList()) != json.encode(newServers.map((e) => e.toJson()).toList())) {
        _servers = newServers;
        await _saveServersToCache(_servers);
        
        if (_servers.isNotEmpty) {
          if (_selectedServer != null) {
            _selectedServer = _servers.firstWhere((s) => s.id == _selectedServer!.id, orElse: () => _servers.first);
          } else {
            _selectedServer = _servers.first;
          }
        } else {
            _selectedServer = null;
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error fetching from Supabase: $e');
        print('Stack trace: $stackTrace');
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
    // Create a local, non-nullable copy of the selected server.
    final server = _selectedServer;

    // All subsequent checks and actions use the local 'server' variable.
    if (server == null) {
      developer.log('No server selected. Connection aborted.', name: 'vpn.connect.error');
      return;
    }

    if (server.config.isEmpty) {
      developer.log('Server config is empty. Connection aborted.', name: 'vpn.connect.error', error: json.encode(server.toJson()));
      _vpnStage = VPNStage.disconnected;
      notifyListeners();
      return;
    }

    if (server.country.isEmpty) {
      developer.log('Server country is empty. Connection aborted.', name: 'vpn.connect.error', error: json.encode(server.toJson()));
      _vpnStage = VPNStage.disconnected;
      notifyListeners();
      return;
    }
    
    developer.log(
      'Attempting to connect...',
      name: 'vpn.connect',
      error: json.encode(server.toJson()), 
    );

    _vpnStage = VPNStage.connecting;
    notifyListeners();

    try {
      engine.connect(
          server.config,
          server.country,
          username: server.username,
          password: server.password,
      );
    } catch (e, s) {
        developer.log(
        'VPN Connection Failed',
        name: 'vpn.connect.error',
        error: e,
        stackTrace: s,
      );
      _vpnStage = VPNStage.disconnected;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    engine.disconnect();
  }
}
