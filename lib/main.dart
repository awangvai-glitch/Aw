
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_page.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => SshStateProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// --- STATE MANAGEMENT ---

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

enum SshConnectionState { disconnected, connecting, connected, disconnecting, error }

class SshStateProvider with ChangeNotifier {
  SshConnectionState _state = SshConnectionState.disconnected;
  SSHClient? _client;
  Timer? _timer;
  int _connectionTime = 0;
  String _errorMessage = '';

  SshConnectionState get state => _state;
  int get connectionTime => _connectionTime;
  String get errorMessage => _errorMessage;

  String get connectionTimeString {
    final duration = Duration(seconds: _connectionTime);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> toggleSshConnection() async {
    if (state == SshConnectionState.connected || state == SshConnectionState.connecting) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  Future<void> _connect() async {
    _state = SshConnectionState.connecting;
    _errorMessage = '';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString(sshHostKey);
      final port = prefs.getInt(sshPortKey);
      final username = prefs.getString(sshUsernameKey);
      final password = prefs.getString(sshPasswordKey);

      if (host == null || port == null || username == null || password == null || host.isEmpty || username.isEmpty) {
        throw Exception('SSH settings are not configured. Please set them first.');
      }

      if (kIsWeb) {
        throw UnsupportedError('SSH connections are not supported on web.');
      }

      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 15));

      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      await _client!.authenticated;

      _state = SshConnectionState.connected;
      _startTimer();
      await NotificationService().showSshConnectedNotification(connectionTimeString);
    } catch (e) {
      if (e.toString().contains('SSHAuthFail')) {
        _handleError('Authentication Failed. Please check your username and password in Settings.');
      } else if (e is SocketException) {
        if (e.osError != null && e.osError!.message.contains('Failed host lookup')) {
          _handleError('Hostname not found. Please check the host address in Settings.');
        } else {
          _handleError(
              'Connection Failed. Please check:\n- Host & Port are correct.\n- Your device has an internet connection.\n- The SSH server is running and accessible.');
        }
      } else {
        _handleError('An unexpected error occurred: ${e.toString()}');
      }
    }
    notifyListeners();
  }

  Future<void> _disconnect() async {
    _state = SshConnectionState.disconnecting;
    notifyListeners();

    _client?.close();
    _client = null;
    _stopTimer();
    _state = SshConnectionState.disconnected;
    await NotificationService().cancelSshNotification();
    notifyListeners();
  }

  // CORRECTED: Made synchronous to satisfy the analyzer.
  void _handleError(String message) {
    _state = SshConnectionState.error;
    _errorMessage = message;
    _stopTimer();
    NotificationService().cancelSshNotification(); // Fire and forget.
  }

  void _startTimer() {
    _connectionTime = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _connectionTime++;
      if (state == SshConnectionState.connected) {
        NotificationService().showSshConnectedNotification(connectionTimeString);
      }
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _connectionTime = 0;
  }
}

// --- UI ---

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primarySeedColor = Colors.teal;

    final TextTheme appTextTheme = TextTheme(
      displayLarge: GoogleFonts.oswald(fontSize: 57, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.openSans(fontSize: 14),
      headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w500),
    );

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.light,
      ),
      textTheme: appTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        titleTextStyle: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.dark,
      ),
      textTheme: appTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'SSH Tunnel',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SshHomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class SshHomePage extends StatelessWidget {
  const SshHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final sshProvider = Provider.of<SshStateProvider>(context);

    String statusText = "Tap to Connect";
    Color statusColor = Colors.grey;

    switch (sshProvider.state) {
      case SshConnectionState.connecting:
        statusText = "Connecting...";
        statusColor = Colors.orange;
        break;
      case SshConnectionState.connected:
        statusText = "Connected";
        statusColor = Colors.green;
        break;
      case SshConnectionState.disconnecting:
        statusText = "Disconnecting...";
        statusColor = Colors.orange;
        break;
      case SshConnectionState.disconnected:
        statusText = "Disconnected";
        statusColor = Theme.of(context).colorScheme.onSurface.withAlpha(153); // 0.6 opacity
        break;
      case SshConnectionState.error:
        statusText = "Error";
        statusColor = Colors.red;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH TUNNEL'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primary.withAlpha(26), // 0.1 opacity
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Spacer(),
              Text(
                statusText.toUpperCase(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              if (sshProvider.state == SshConnectionState.connected)
                Text(
                  sshProvider.connectionTimeString,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                )
              else
                Text(
                  '--:--:--',
                   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(128), // 0.5 opacity
                  ),
                ),
                if (sshProvider.state == SshConnectionState.error)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    sshProvider.errorMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),
              const ConnectionButton(),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionButton extends StatelessWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sshProvider = Provider.of<SshStateProvider>(context);
    final bool isConnecting = sshProvider.state == SshConnectionState.connecting || sshProvider.state == SshConnectionState.disconnecting;
    final bool isConnected = sshProvider.state == SshConnectionState.connected;

    Color buttonColor = isConnected ? Colors.teal : Colors.grey.shade800;
    if(sshProvider.state == SshConnectionState.error) buttonColor = Colors.red;

    List<BoxShadow> boxShadow = [
      BoxShadow(
        color: buttonColor.withAlpha(102), // 0.4 opacity
        blurRadius: 25,
        spreadRadius: 5,
        offset: const Offset(0, 10),
      )
    ];

    return GestureDetector(
      onTap: () {
        if (!isConnecting) {
          sshProvider.toggleSshConnection();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
          boxShadow: isConnecting ? [] : boxShadow,
          border: Border.all(
            color: buttonColor,
            width: 8,
          ),
        ),
        child: Center(
          child: isConnecting
              ? CircularProgressIndicator(
                  color: buttonColor,
                )
              : Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: buttonColor,
                ),
        ),
      ),
    );
  }
}
