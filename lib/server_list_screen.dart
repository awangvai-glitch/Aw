import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vpn_provider.dart';
import 'vpn_server.dart';

class ServerListScreen extends StatelessWidget {
  const ServerListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Server VPN'),
      ),
      // Gunakan Consumer untuk rebuild hanya bagian ini saat provider berubah
      body: Consumer<VpnProvider>(
        builder: (context, vpnProvider, child) {
          // 1. Tampilkan Indikator Loading
          if (vpnProvider.isLoading && vpnProvider.servers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Tampilkan Pesan Error
          if (vpnProvider.errorMessage != null && vpnProvider.servers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  vpnProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          // 3. Tampilkan Daftar Server
          return ListView.builder(
            itemCount: vpnProvider.servers.length,
            itemBuilder: (context, index) {
              VpnServer server = vpnProvider.servers[index];
              bool isSelected = server.name == vpnProvider.selectedServer?.name;

              return ListTile(
                title: Text(server.name),
                leading: const Icon(Icons.dns, color: Colors.white70),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  // Jangan izinkan mengganti server saat sudah terhubung
                  if (!vpnProvider.isConnected) {
                     vpnProvider.setSelectedServer(server);
                  }
                  // Kembali ke halaman sebelumnya setelah memilih
                  Navigator.of(context).pop();
                },
              );
            },
          );
        },
      ),
    );
  }
}
