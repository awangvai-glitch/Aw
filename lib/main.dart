import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async { // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
  final prefs = await SharedPreferences.getInstance(); // Get prefs instance

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Pass SharedPreferences to the provider
        ChangeNotifierProvider(create: (_) => ConnectionProvider(prefs)),
      ],
      child: const MyApp(),
    ),
  );
}


// --- Providers --- 

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
  static const _platform = MethodChannel('com.iwansrv.sshtunnel/vpn');
  // Separate channel for status updates from the service
  static const _statusChannel = MethodChannel('com.iwansrv.sshtunnel/vpn/status');
  final SharedPreferences _prefs;

  // Controllers for all text fields
  late final TextEditingController sshHostController;
  late final TextEditingController sshPortController;
  late final TextEditingController sshUserContoller;
  late final TextEditingController sshPasswordController;
  late final TextEditingController payloadController;
  late final TextEditingController sniController;
  late final TextEditingController proxyHostController;
  late final TextEditingController proxyPortController;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  final List<String> _logs = ['Aplikasi siap.'];
  List<String> get logs => List.unmodifiable(_logs);

  Map<String, String>? _untrustedHostKeyInfo;
  Map<String, String>? get untrustedHostKeyInfo => _untrustedHostKeyInfo;

  ConnectionProvider(this._prefs) {
    _statusChannel.setMethodCallHandler(_handleNativeMethod);
    _loadSettings(); // Load settings on startup
  }

  void _loadSettings() {
    // Initialize controllers with saved values or defaults
    sshHostController = TextEditingController(text: _prefs.getString('sshHost') ?? '10.0.2.2');
    sshPortController = TextEditingController(text: _prefs.getString('sshPort') ?? '22');
    sshUserContoller = TextEditingController(text: _prefs.getString('sshUser') ?? 'user');
    sshPasswordController = TextEditingController(text: _prefs.getString('sshPass'));
    payloadController = TextEditingController(text: _prefs.getString('payload'));
    sniController = TextEditingController(text: _prefs.getString('sni'));
    proxyHostController = TextEditingController(text: _prefs.getString('proxyHost'));
    proxyPortController = TextEditingController(text: _prefs.getString('proxyPort'));

    // Add listeners to save on change
    sshHostController.addListener(() => _saveString('sshHost', sshHostController.text));
    sshPortController.addListener(() => _saveString('sshPort', sshPortController.text));
    sshUserContoller.addListener(() => _saveString('sshUser', sshUserContoller.text));
    sshPasswordController.addListener(() => _saveString('sshPass', sshPasswordController.text));
    payloadController.addListener(() => _saveString('payload', payloadController.text));
    sniController.addListener(() => _saveString('sni', sniController.text));
    proxyHostController.addListener(() => _saveString('proxyHost', proxyHostController.text));
    proxyPortController.addListener(() => _saveString('proxyPort', proxyPortController.text));
  }

  Future<void> _saveString(String key, String value) async {
    await _prefs.setString(key, value);
  }

   Future<void> _handleNativeMethod(MethodCall call) async {
    switch (call.method) {
      case 'updateStatus':
        final args = call.arguments as Map<dynamic, dynamic>;
        final statusStr = args['status'] as String? ?? '';
        final message = args['message'] as String? ?? '';
        
        if (statusStr.isNotEmpty) {
            _updateStatusFromString(statusStr, message);
        }
        if (message.isNotEmpty) {
            _addLog(message, fromNative: true);
        }

        notifyListeners();
        break;

      case 'verifyHostKey':
        _untrustedHostKeyInfo = Map<String, String>.from(call.arguments as Map);
        _status = ConnectionStatus.error; // Force user interaction
        _addLog("Host key verification needed!", fromNative: true);
        notifyListeners();
        break;
      default:
        _addLog("Panggilan metode tidak dikenal: ${call.method}", fromNative: true);
        break;
    }
  }

  void _updateStatusFromString(String statusStr, String message) {
    switch(statusStr) {
        case "connected":
            _status = ConnectionStatus.connected;
            break;
        case "disconnected":
            _status = ConnectionStatus.disconnected;
            break;
        case "error":
            _status = ConnectionStatus.error;
            break;
        case "connecting":
             _status = ConnectionStatus.connecting;
             break;
        // New case: when VPN is technically on but connection failed
        case "vpn_on_but_error":
            _status = ConnectionStatus.error;
            break;
    }
  }

  Future<void> connect() async {
    if (_status == ConnectionStatus.connecting) return; // Prevent multiple calls

    if (sshHostController.text.isEmpty ||
        sshPortController.text.isEmpty ||
        sshUserContoller.text.isEmpty ||
        sshPasswordController.text.isEmpty) {
      _status = ConnectionStatus.error;
      _addLog("Error: Kolom SSH (Host, Port, User, Pass) wajib diisi!");
      notifyListeners();
      return; 
    }

    _status = ConnectionStatus.connecting;
    _logs.clear();
    _addLog('Meminta izin VPN...');
    notifyListeners();

    try {
      final config = {
        "host": sshHostController.text,
        "port": sshPortController.text,
        "username": sshUserContoller.text,
        "password": sshPasswordController.text,
        "payload": payloadController.text,
        "sni": sniController.text,
        "proxyHost": proxyHostController.text,
        "proxyPort": proxyPortController.text,
      };
      // This call now just triggers the permission dialog and starts the service
      await _platform.invokeMethod('startVpn', config);
      _addLog("Izin VPN diberikan. Service dimulai di latar belakang.");
      // The status will now be updated by the service via the statusChannel.

    } on PlatformException catch (e) {
      _addLog("Error: ${e.message ?? 'Gagal memulai VPN'}");
      _status = ConnectionStatus.error;
      notifyListeners();
    }
  }

  Future<void> userTrustsHostKey() async {
    final keyInfo = _untrustedHostKeyInfo;
    if (keyInfo != null) {
      _addLog("Mempercayai kunci baru dan mencoba menghubungkan kembali...");
      _untrustedHostKeyInfo = null;
      notifyListeners();
      try {
        await _platform.invokeMethod('userTrustsHostKey', {
            'hostname': keyInfo['hostname'],
            'keyAlgorithm': keyInfo['keyAlgorithm'],
            'keyString': keyInfo['keyString'],
        });
      } on PlatformException catch(e) {
        _addLog("Gagal mengirim kepercayaan: ${e.message}");
      }
    }
  }

  void clearUntrustedKeyInfoAndDisconnect() {
    _untrustedHostKeyInfo = null;
    _addLog("Verifikasi kunci ditolak oleh pengguna.");
    disconnect();
  }

  Future<void> disconnect() async {
    _status = ConnectionStatus.disconnected;
    _addLog('Memutus koneksi...');
    notifyListeners();
    try {
      await _platform.invokeMethod('stopVpn');
    } on PlatformException catch (e) {
      _addLog("Error: ${e.message ?? 'Gagal menghentikan VPN'}");
      // Even if it fails, UI is already disconnected
    }
  }

  void _addLog(String log, {bool fromNative = false}) {
    final prefix = fromNative ? "" : "[UI] ";
    final context = navigatorKey.currentContext;
    if (context != null) {
      final timestamp = TimeOfDay.now().format(context);
      _logs.insert(0, '$prefix[$timestamp] $log');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        const Color primarySeedColor = Colors.cyan;

        final textTheme = GoogleFonts.latoTextTheme(Theme.of(context).textTheme);

        final baseTheme = ThemeData(
            useMaterial3: true, textTheme: textTheme, brightness: Brightness.dark);

        return MaterialApp(
          title: 'SSH Tunnel',
          navigatorKey: navigatorKey,
          theme: baseTheme.copyWith(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: primarySeedColor, brightness: Brightness.light)),
          darkTheme: baseTheme.copyWith(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: primarySeedColor, brightness: Brightness.dark)),
          themeMode: themeProvider.themeMode,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// --- Main Screen with Bottom Navigation ---

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    connectionProvider.addListener(_showHostKeyDialogIfNeeded);
  }

  @override
  void dispose() {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    connectionProvider.removeListener(_showHostKeyDialogIfNeeded);
    _pageController.dispose();
    super.dispose();
  }

  void _showHostKeyDialogIfNeeded() {
    final connectionProvider = Provider.of<ConnectionProvider>(context, listen: false);
    final keyInfo = connectionProvider.untrustedHostKeyInfo;
    if (keyInfo != null && navigatorKey.currentContext != null && ModalRoute.of(navigatorKey.currentContext!)?.isCurrent == true) {
      showDialog(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (context) => HostKeyDialog(keyInfo: keyInfo));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    // This is the modern and correct way to handle the back button.
    return PopScope(
      canPop: false, // Prevents the screen from being popped automatically.
      onPopInvokedWithResult: (bool didPop, Object? result) {
        // This callback is called after a pop gesture is attempted.
        if (didPop) {
          // If the pop was successful (which it won't be because canPop is false),
          // do nothing.
          return;
        }
        
        // If we are not on the main connect page, navigate back to it.
        if (_selectedIndex != 0) {
          _onItemTapped(0);
        } else {
          // If we are already on the main page, exit the app.
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: const [
            ConnectPage(),
            SettingsPage(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.power_settings_new), label: 'Connect'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// --- Page 1: Connect Page ---
class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final connectionProvider = context.watch<ConnectionProvider>();
    final status = connectionProvider.status;

    return Scaffold(
      appBar: AppBar(
        title: Text('SSH Tunnel', style: GoogleFonts.oswald(fontSize: 24)),
        actions: const [ThemeToggleButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            ConnectButton(status: status),
            const SizedBox(height: 24),
            StatusIndicator(status: status),
            const SizedBox(height: 24),
            const Expanded(
              child: LogsView(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Page 2: Settings Page ---

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ConnectionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfigurasi'),
         actions: const [ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _buildCard(
            context: context,
            title: 'Server SSH',
            icon: Icons.computer,
            children: [
              _buildTextField(provider.sshHostController, 'Host', Icons.dns_outlined),
              _buildTextField(provider.sshPortController, 'Port', Icons.power_outlined, keyboardType: TextInputType.number),
              _buildTextField(provider.sshUserContoller, 'Username', Icons.person_outline),
              _buildTextField(provider.sshPasswordController, 'Password', Icons.password_outlined, obscureText: true),
            ],
          ),
          _buildCard(
            context: context,
            title: 'Proxy & Obfuscation',
            icon: Icons.shield_outlined,
            children: [
               _buildTextField(provider.proxyHostController, 'Proxy Host (Opsional)', Icons.http_outlined),
              _buildTextField(provider.proxyPortController, 'Proxy Port (Opsional)', Icons.power_outlined, keyboardType: TextInputType.number),
              _buildTextField(provider.payloadController, 'Payload (Opsional)', Icons.text_snippet_outlined, hint: 'e.g., CONNECT [host_port] HTTP/1.1'),
              _buildTextField(provider.sniController, 'SNI / Bug Host (Opsional)', Icons.security_outlined, hint: 'e.g., m.example.com'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required BuildContext context, required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// --- New Logs View Widget ---
class LogsView extends StatelessWidget {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<ConnectionProvider>().logs;
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.only(top: 16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        reverse: true,
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          Color color = Colors.grey.shade500;
          if(log.contains("Error:") || log.contains("failed") || log.contains("!!!")) color = Colors.red.shade400;
          if(log.contains("Success!")) color = Colors.green.shade400;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
            child: Text(log, style: GoogleFonts.firaCode(fontSize: 12, color: color)),
          );
        },
      ),
    );
  }
}


// --- Reusable Widgets ---

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return IconButton(
      icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => themeProvider.toggleTheme(),
      tooltip: 'Toggle Theme',
    );
  }
}

class ConnectButton extends StatelessWidget {
  final ConnectionStatus status;
  const ConnectButton({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ConnectionProvider>();
    
    // The button is now controlled by whether the VPN service is supposed to be active.
    // Disconnected means service is off. Anything else means service is on (or trying to be).
    bool isServiceActive = status != ConnectionStatus.disconnected;
    bool isConnecting = status == ConnectionStatus.connecting;

    VoidCallback? onPressed = isConnecting ? null : () {
       isServiceActive ? provider.disconnect() : provider.connect();
    };
    
    Color buttonColor = isServiceActive ? Colors.red.shade700 : Colors.green.shade700;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: buttonColor.withAlpha(102), // Correct way to set opacity
              blurRadius: 15,
              spreadRadius: 5,
              offset: const Offset(0, 5),
            )
          ]
        ),
        child: Center(
          child: isConnecting
              ? const SizedBox(height: 50, width: 50, child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white))
              : Icon(
                  isServiceActive ? Icons.stop : Icons.power_settings_new, 
                  color: Colors.white, 
                  size: 80
                ),
        ),
      ),
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final ConnectionStatus status;
  const StatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    IconData icon;

    switch (status) {
      case ConnectionStatus.connected:
        text = 'TERHUBUNG';
        color = Colors.green.shade400;
        icon = Icons.gpp_good_outlined;
        break;
      case ConnectionStatus.connecting:
        text = 'MENGHUBUNGKAN...';
        color = Colors.orange.shade400;
        icon = Icons.hourglass_top_outlined;
        break;
      case ConnectionStatus.error:
        text = 'GAGAL TERHUBUNG'; // More specific error text
        color = Colors.red.shade400;
        icon = Icons.error_outline;
        break;
      case ConnectionStatus.disconnected:
        text = 'TERPUTUS';
        color = Colors.grey.shade500;
        icon = Icons.power_off_outlined;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class HostKeyDialog extends StatelessWidget {
  final Map<String, String> keyInfo;
  const HostKeyDialog({super.key, required this.keyInfo});

  @override
  Widget build(BuildContext context) {
    final connectionProvider = context.read<ConnectionProvider>();
    return AlertDialog(
      title: const Text('Verifikasi Host Key'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text("Keaslian host '${keyInfo['hostname']}' tidak dapat dipastikan."),
            const SizedBox(height: 16),
            const Text('Sidik jari kunci adalah:'),
            const SizedBox(height: 8),
            Text(
              keyInfo['fingerprint'] ?? 'Tidak tersedia',
              style: GoogleFonts.firaCode(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Apakah Anda ingin mempercayai kunci ini?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('TOLAK'),
          onPressed: () {
            Navigator.of(context).pop();
            connectionProvider.clearUntrustedKeyInfoAndDisconnect();
          },
        ),
        FilledButton(
          child: const Text('PERCAYAI'),
          onPressed: () {
            Navigator.of(context).pop();
            connectionProvider.userTrustsHostKey();
          },
        ),
      ],
    );
  }
}
