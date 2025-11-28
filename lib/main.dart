import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vpn_provider.dart';
import 'vpn_server.dart';
import 'widget/connect_button.dart'; // Import the new ConnectButton

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://gmndebizslctonvqvtnf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbmRlYml6c2xjdG9udnF2dG5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MzI4ODQsImV4cCI6MjA3OTIwODg4NH0.HdpFu0F1k2bwsY1TWImuHWBVw9eIrVweJWi0g30wCcI',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => VpnProvider(Supabase.instance.client),
      child: MaterialApp(
        title: 'VPN App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity, // Added for better spacing
        ),
        home: const VpnHomePage(),
      ),
    );
  }
}

class VpnHomePage extends StatelessWidget {
  const VpnHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Better vertical spacing
          children: <Widget>[
            // Server Selection Area
            Column(
              children: [
                const Text(
                  'Select a Server',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Consumer<VpnProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.servers.isEmpty) {
                      return const CircularProgressIndicator();
                    }
                    if (provider.servers.isEmpty) {
                      return const Text('No servers available.');
                    }
                    return DropdownButton<VpnServer>(
                      hint: const Text('Choose Server'),
                      value: provider.selectedServer,
                      items: provider.servers.map((VpnServer server) {
                        return DropdownMenuItem<VpnServer>(
                          value: server,
                          child: Text(server.country),
                        );
                      }).toList(),
                      onChanged: (VpnServer? newServer) {
                        if (newServer != null) {
                          provider.selectServer(newServer);
                        }
                      },
                    );
                  },
                ),
              ],
            ),

            // Connect Button Area
            Consumer<VpnProvider>(
              builder: (context, provider, child) {
                return ConnectButton(
                  vpnStage: provider.vpnStage,
                  onConnect: () {
                    provider.connect();
                  },
                  onDisconnect: () {
                    provider.disconnect();
                  },
                );
              },
            ),

            // Status Info Area
            Consumer<VpnProvider>(
              builder: (context, provider, child) {
                return Column(
                  children: [
                    if (provider.vpnStage != null)
                      Text(
                        'Stage: ${provider.vpnStage.toString().split('.').last.toUpperCase()}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    const SizedBox(height: 5),
                    if (provider.vpnStatus != null && provider.vpnStatus!.duration != null)
                      Text(
                        'Duration: ${provider.vpnStatus!.duration}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (provider.vpnStatus != null && provider.vpnStatus!.byteIn != null)
                      Text(
                        'Data In: ${provider.vpnStatus!.byteIn}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (provider.vpnStatus != null && provider.vpnStatus!.byteOut != null)
                      Text(
                        'Data Out: ${provider.vpnStatus!.byteOut}',
                        style: const TextStyle(fontSize: 14),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
