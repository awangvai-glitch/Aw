import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vpn_provider.dart';
import 'server_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase dengan kredensial Anda
  await Supabase.initialize(
    url: 'https://gmndebizslctonvqvtnf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbmRlYml6c2xjdG9udnF2dG5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MzI4ODQsImV4cCI6MjA3OTIwODg4NH0.HdpFu0F1k2bwsY1TWImuHWBVw9eIrVweJWi0g30wCcI',
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => VpnProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenVPN App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      home: const VpnHomePage(),
    );
  }
}

class VpnHomePage extends StatelessWidget {
  const VpnHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenVPN Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ServerListScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<VpnProvider>(
        builder: (context, vpnProvider, child) {
          if (vpnProvider.isLoading && vpnProvider.servers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat server...'),
                ],
              ),
            );
          }

          if (vpnProvider.errorMessage != null && vpnProvider.servers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      vpnProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => vpnProvider.fetchServers(),
                    child: const Text('Coba Lagi'),
                  )
                ],
              ),
            );
          }

          return buildMainContent(context, vpnProvider);
        },
      ),
    );
  }

  Widget buildMainContent(BuildContext context, VpnProvider vpnProvider) {
    final bool isConnecting = vpnProvider.isConnecting || vpnProvider.isDisconnecting;
    final Color buttonColor = vpnProvider.isConnected ? Colors.red.shade700 : Colors.green.shade700;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            vpnProvider.currentStatus,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            child: Text(
              vpnProvider.selectedServer != null 
                  ? 'Server: ${vpnProvider.selectedServer!.name}' 
                  : 'Pilih server dari daftar',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
          ),
          if (vpnProvider.status != null && vpnProvider.isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Text('Connected Since: ${vpnProvider.status?.connectedOn}', style: Theme.of(context).textTheme.bodySmall),
                  Text('Bytes In: ${vpnProvider.status?.byteIn}', style: Theme.of(context).textTheme.bodySmall),
                  Text('Bytes Out: ${vpnProvider.status?.byteOut}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Opacity(
            opacity: isConnecting ? 0.5 : 1.0,
            child: InkWell(
              onTap: isConnecting ? null : () {
                if (vpnProvider.isConnected) {
                  vpnProvider.disconnect();
                } else {
                  vpnProvider.connect();
                }
              },
              borderRadius: BorderRadius.circular(100),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: buttonColor,
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withAlpha(150),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
                ),
                child: const Icon(
                  Icons.power_settings_new,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
