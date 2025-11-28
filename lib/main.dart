import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

import 'vpn_provider.dart';
import 'vpn_server.dart';
import 'widget/connect_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gmndebizslctonvqvtnf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbmRlYml6c2xjdG9udnF2dG5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MzI4ODQsImV4cCI6MjA3OTIwODg4NH0.HdpFu0F1k2bwsY1TWImuHWBVw9eIrVweJWi0g30wCcI',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Use super-parameters

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => VpnProvider(Supabase.instance.client),
      child: MaterialApp(
        title: 'Flutter VPN',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vpnProvider = Provider.of<VpnProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter VPN'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (vpnProvider.isLoading)
              const CircularProgressIndicator()
            else if (vpnProvider.servers.isEmpty)
              const Text('No server available') // This is where the message comes from
            else
              DropdownButton<VpnServer>(
                value: vpnProvider.selectedServer,
                hint: const Text("Select Server"),
                items: vpnProvider.servers.map((VpnServer server) {
                  return DropdownMenuItem<VpnServer>(
                    value: server,
                    child: Text(server.country),
                  );
                }).toList(),
                onChanged: (VpnServer? newServer) {
                  if (newServer != null) {
                    vpnProvider.selectServer(newServer);
                  }
                },
              ),
            const SizedBox(height: 20),
            ConnectButton(
              vpnStage: vpnProvider.vpnStage ?? VPNStage.disconnected,
              onPressed: () {
                if (vpnProvider.vpnStage == VPNStage.connected) {
                  vpnProvider.disconnect();
                } else {
                  vpnProvider.connect();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
