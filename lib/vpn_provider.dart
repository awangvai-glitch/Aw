import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vpn_server.dart';

class VpnProvider with ChangeNotifier {
  late OpenVPN engine;
  VpnStatus? status;
  VPNStage? stage;

  List<VpnServer> _servers = [];
  VpnServer? _selectedServer;
  bool _isLoading = false;
  String? _errorMessage;

  // Getter untuk diakses UI
  List<VpnServer> get servers => _servers;
  VpnServer? get selectedServer => _selectedServer;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentStatus => stage?.toString().split('.').last.replaceAll('_', ' ').toUpperCase() ?? 'DISCONNECTED';
  bool get isConnected => stage == VPNStage.connected;
  bool get isConnecting => stage == VPNStage.connecting;
  bool get isDisconnecting => stage == VPNStage.disconnecting;


  VpnProvider() {
    // Inisialisasi engine OpenVPN
    engine = OpenVPN(
      onVpnStatusChanged: (VpnStatus? vpnStatus) {
        status = vpnStatus;
        notifyListeners();
      },
      onVpnStageChanged: (VPNStage? vpnStage, String rawStage) {
        stage = vpnStage;
        notifyListeners();
      },
    );

    engine.initialize(
      groupIdentifier: 'group.com.yourdomain.yourapp',
      providerBundleIdentifier: 'com.yourdomain.yourapp.networkextension',
      localizedDescription: 'MyVPN',
      lastStage: (vpnStage) {
        stage = vpnStage;
        notifyListeners();
      },
      lastStatus: (vpnStatus) {
        status = vpnStatus;
        notifyListeners();
      }
    );

    // Ambil data server dari Supabase saat provider dibuat
    fetchServers();
  }

  Future<void> fetchServers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Mengambil data dari tabel 'servers' di Supabase
      final response = await Supabase.instance.client.from('servers').select();

      // Parsing data dari response
      _servers = response.map<VpnServer>((data) => VpnServer(
        name: data['name'],
        ovpnConfig: data['ovpnConfig'],
        username: data['username'],
        password: data['password'],
      )).toList();

      // Jika ada server, pilih yang pertama sebagai default
      if (_servers.isNotEmpty) {
        _selectedServer = _servers.first;
      }

      developer.log("${_servers.length} server berhasil diambil dari Supabase.");

    } catch (e) {
      developer.log("Error saat mengambil server dari Supabase: $e");
      _errorMessage = "Gagal memuat daftar server. Periksa koneksi internet Anda.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedServer(VpnServer server) {
    if (isConnected) return; // Jangan ganti server saat terhubung
    _selectedServer = server;
    developer.log("Server dipilih: ${server.name}");
    notifyListeners();
  }

  void connect() {
    if (_selectedServer == null) {
      developer.log("Tidak ada server VPN yang dipilih.");
      return;
    }
    if (isConnected || isConnecting) return; // Jangan coba konek jika sudah konek atau sedang konek

    stage = VPNStage.connecting;
    notifyListeners();

    engine.connect(
      _selectedServer!.ovpnConfig,
      _selectedServer!.name,
      username: _selectedServer!.username,
      password: _selectedServer!.password,
      certIsRequired: false
    );
  }

  void disconnect() {
    if (!isConnected && !isConnecting) return;
    
    stage = VPNStage.disconnecting;
    notifyListeners();

    engine.disconnect();
  }
}
