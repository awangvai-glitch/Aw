
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// --- Providers for State Management ---

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionProvider with ChangeNotifier {
  static const _channel = MethodChannel('com.iwansrv.sshtunnel/vpn');

  final sshHostController = TextEditingController(text: '127.0.0.1');
  final sshPortController = TextEditingController(text: '22');
  final sshUserContoller = TextEditingController(text: 'user');
  final sshPasswordController = TextEditingController(text: 'password');

  final payloadController = TextEditingController();
  final sniController = TextEditingController();

  final proxyHostController = TextEditingController();
  final proxyPortController = TextEditingController();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  final List<String> _logs = ['Aplikasi siap.'];
  List<String> get logs => _logs;

  Map<String, String>? _untrustedHostKeyInfo;
  Map<String, String>? get untrustedHostKeyInfo => _untrustedHostKeyInfo;

  ConnectionProvider() {
    _channel.setMethodCallHandler(_handleNativeMethod);
  }

  Future<void> _handleNativeMethod(MethodCall call) async {
    switch (call.method) {
      case 'updateStatus':
        final args = call.arguments as Map<dynamic, dynamic>;
        _updateStatusFromString(args['status'] as String);
        _addLog(args['message'] as String, fromNative: true);
        break;
      case 'verifyHostKey':
        _untrustedHostKeyInfo = Map<String, String>.from(call.arguments as Map);
        _status = ConnectionStatus.error; // Stop current connection process
        _addLog("Host key verification needed!", fromNative: true);
        notifyListeners();
        break;
      default:
        break;
    }
  }

  void _updateStatusFromString(String statusStr) {
    _status = ConnectionStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => ConnectionStatus.error
    );
    notifyListeners();
  }

  Future<void> connect({String? trustedKey}) async {
    _status = ConnectionStatus.connecting;
    if (trustedKey == null) {
      _logs.clear();
    }
    _addLog('Memulai koneksi...');
    notifyListeners();

    try {
      final config = {
        "sshHost": sshHostController.text,
        "sshPort": sshPortController.text,
        "sshUser": sshUserContoller.text,
        "sshPass": sshPasswordController.text,
        "payload": payloadController.text,
        "sni": sniController.text,
        "proxyHost": proxyHostController.text,
        "proxyPort": proxyPortController.text,
        "trustedKey": trustedKey, // Pass the trusted key if available
      };
      await _channel.invokeMethod('startVpn', config);
    } on PlatformException catch (e) {
      _addLog("Error: Failed to start VPN. ${e.message}");
      _status = ConnectionStatus.error;
    }
    notifyListeners();
  }

  Future<void> trustAndReconnect() async {
    final keyToTrust = _untrustedHostKeyInfo?['keyString'];
    if (keyToTrust != null) {
      _untrustedHostKeyInfo = null; // Clear the prompt
      _addLog("Mempercayai kunci baru dan mencoba menghubungkan kembali...");
      notifyListeners();
      await connect(trustedKey: keyToTrust);
    } 
  }

  void clearUntrustedKeyInfo(){
      _untrustedHostKeyInfo = null;
      notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('stopVpn');
      _status = ConnectionStatus.disconnected;
      _addLog('Koneksi diputus.');
    } on PlatformException catch (e) {
      _addLog("Error: Failed to stop VPN. ${e.message}");
      _status = ConnectionStatus.error;
    }
    notifyListeners();
  }

  void _addLog(String log, {bool fromNative = false}) {
     final prefix = fromNative ? "" : "[UI] ";
     final context = navigatorKey.currentContext;
     if (context != null) {
        _logs.insert(0, '$prefix[${TimeOfDay.now().format(context)}] $log');
        notifyListeners();
     }
  }

  @override
  void dispose() {
    sshHostController.dispose();
    sshPortController.dispose();
    sshUserContoller.dispose();
    sshPasswordController.dispose();
    payloadController.dispose();
    sniController.dispose();
    proxyHostController.dispose();
    proxyPortController.dispose();
    super.dispose();
  }
}

// --- Main Application Widget ---

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Listen for changes in ConnectionProvider to show the dialog
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    connectionProvider.addListener(_showHostKeyDialogIfNeeded);
  }

  @override
  void dispose() {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    connectionProvider.removeListener(_showHostKeyDialogIfNeeded);
    super.dispose();
  }

  void _showHostKeyDialogIfNeeded() {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final keyInfo = connectionProvider.untrustedHostKeyInfo;
    if (keyInfo != null && navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false, // User must make a choice
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Verifikasi Host Key'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text("Keaslian host '${keyInfo['hostname']}' tidak dapat dipastikan."),
                  const SizedBox(height: 16),
                  const Text('Sidik jari kunci SHA256 adalah:'),
                  const SizedBox(height: 8),
                  Text(
                    keyInfo['fingerprint'] ?? 'Tidak tersedia',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                   const SizedBox(height: 16),
                   const Text('Apakah Anda ingin mempercayai kunci ini dan melanjutkan koneksi?', style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Text(
                    'PERINGATAN: Jika kunci ini berubah tanpa diduga, bisa jadi ada serangan Man-in-the-Middle!',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                   )
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('TOLAK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  connectionProvider.clearUntrustedKeyInfo();
                   connectionProvider.disconnect();
                },
              ),
              FilledButton(
                child: const Text('PERCAYAI'),
                onPressed: () {
                  Navigator.of(context).pop();
                  connectionProvider.trustAndReconnect();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        const Color primarySeedColor = Colors.cyan;
        final textTheme = GoogleFonts.latoTextTheme(Theme.of(context).textTheme);

        final lightTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: primarySeedColor, brightness: Brightness.light),
          textTheme: textTheme,
        );

        final darkTheme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: primarySeedColor, brightness: Brightness.dark),
          textTheme: textTheme,
        );

        return MaterialApp(
          title: 'SSH Tunnel',
          navigatorKey: navigatorKey,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const HomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// --- Home Page UI (Remains mostly the same) ---

class HomePage extends StatelessWidget {
  const HomePage({super.key});

 @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final connectionProvider = Provider.of<ConnectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('SSH Tunnel', style: GoogleFonts.oswald(fontSize: 24)),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle(context, 'Konfigurasi'),
            const SizedBox(height: 8),
            _buildConfigForm(context, connectionProvider),
            const SizedBox(height: 24),
            _buildConnectButton(context, connectionProvider),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Log Status'),
            const SizedBox(height: 8),
            _buildLogPanel(context, connectionProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
  
  Widget _buildConfigForm(BuildContext context, ConnectionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(controller: provider.sshHostController, label: 'SSH Host'),
        _buildTextField(controller: provider.sshPortController, label: 'SSH Port', keyboardType: TextInputType.number),
        _buildTextField(controller: provider.sshUserContoller, label: 'SSH User'),
        _buildTextField(controller: provider.sshPasswordController, label: 'SSH Password', obscureText: true),
        const SizedBox(height: 16),
        _buildTextField(controller: provider.payloadController, label: 'Payload (Opsional)'),
        _buildTextField(controller: provider.sniController, label: 'SNI / Bug Host (Opsional)'),
        const SizedBox(height: 16),
        _buildTextField(controller: provider.proxyHostController, label: 'Proxy Host (Opsional)'),
        _buildTextField(controller: provider.proxyPortController, label: 'Proxy Port (Opsional)', keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context, ConnectionProvider provider) {
    bool isConnected = provider.status == ConnectionStatus.connected;
    bool isConnecting = provider.status == ConnectionStatus.connecting;

    Color buttonColor = isConnected ? Colors.green : (isConnecting ? Colors.orange : Theme.of(context).colorScheme.primary);
    String buttonText = isConnected ? 'Disconnect' : (isConnecting ? 'Connecting...' : 'Connect');

    return ElevatedButton(
      onPressed: isConnecting ? null : () {
        isConnected ? provider.disconnect() : provider.connect();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isConnecting
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
          : Text(buttonText),
    );
  }

  Widget _buildLogPanel(BuildContext context, ConnectionProvider provider) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        reverse: true,
        itemCount: provider.logs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              provider.logs[index],
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          );
        },
      ),
    );
  }
}
