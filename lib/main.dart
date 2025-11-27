import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vpn_provider.dart';
import 'vpn_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ejpukqbkfivgnkffmlux.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqcHVrcWJrZml2Z25rZmZtbHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTU2MDQyMzMsImV4cCI6MjAzMTE4MDIzM30.4i4Lz-_sI7nwsWJ5Vp4i_9M3D_3V3rU_i-Hk2AqKxOM',
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
    final vpnProvider = Provider.of<VpnProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Select a server:',
            ),
            Consumer<VpnProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.servers.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text('No servers found. Check your connection or Supabase configuration.'),
                  );
                }

                return DropdownButton<VpnServer>(
                  hint: const Text('Select Server'),
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
            const SizedBox(height: 20),
            Consumer<VpnProvider>(
              builder: (context, provider, child) {
                final isConnecting = provider.isConnecting;
                final buttonText = isConnecting ? 'CONNECTING...' : 'CONNECT';

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isConnecting ? 0.5 : 1.0,
                  child: ElevatedButton(
                    onPressed: provider.selectedServer == null || isConnecting
                        ? null
                        : () => provider.connect(),
                    child: Text(buttonText),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => vpnProvider.disconnect(),
              child: const Text('DISCONNECT'),
            ),
            const SizedBox(height: 20),
            if (vpnProvider.vpnStatus != null)
              Text('Status: ${vpnProvider.vpnStatus!.toJson().toString()}'),
            if (vpnProvider.vpnStage != null)
              Text('Stage: ${vpnProvider.vpnStage.toString()}'),
          ],
        ),
      ),
    );
  }
}
