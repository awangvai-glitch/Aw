import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartssh2/dartssh2.dart';

// Wrapper class to adapt a standard Socket to the SSHSocket abstract class.
class _ProxyTunnelSocket implements SSHSocket {
  final Socket _socket;

  _ProxyTunnelSocket(this._socket);

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;
}

class SshStateProvider with ChangeNotifier {
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnected = false;
  String _output = '';
  String _error = '';
  bool _isLoading = false;

  bool get isConnected => _isConnected;
  String get output => _output;
  String get error => _error;
  bool get isLoading => _isLoading;

  Future<void> connect(
    String host, 
    int port, 
    String username, 
    String password,
    {String? proxyHost, int? proxyPort}
  ) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      SSHSocket socket;
      if (proxyHost != null && proxyHost.isNotEmpty && proxyPort != null) {
        _output = 'Connecting to proxy $proxyHost:$proxyPort...';
        notifyListeners();
        final underlyingSocket = await Socket.connect(proxyHost, proxyPort);
        underlyingSocket.write('CONNECT $host:$port HTTP/1.1\r\n\r\n');
        await underlyingSocket.flush();

        final response = await underlyingSocket.first.timeout(const Duration(seconds: 10));
        final responseString = utf8.decode(response);

        if (!responseString.contains('200')) {
          throw Exception('Proxy connection failed: $responseString');
        }

        _output += '\nProxy connected. Tunnel established.';
        notifyListeners();
        socket = _ProxyTunnelSocket(underlyingSocket);
      } else {
        socket = await SSHSocket.connect(host, port);
      }

      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      _client = client;
      _isConnected = true;
      _output = 'Connected to $host';
    } catch (e) {
      _error = 'Failed to connect: $e';
      _isConnected = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _session?.close();
    _client?.close();
    _client = null;
    _session = null;
    _isConnected = false;
    _output = '';
    _error = '';
    notifyListeners();
  }

  Future<void> execute(String command) async {
    if (_client == null || !_isConnected) {
      _error = 'Not connected to any server.';
      notifyListeners();
      return;
    }

    try {
      final result = await _client!.run(command);
      final resultString = utf8.decode(result);
      _output += '\n\n> $command\n$resultString';
    } catch (e) {
      _error = 'Failed to execute command: $e';
    } finally {
      notifyListeners();
    }
  }
}

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SshStateProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const MaterialColor primarySeedColor = Colors.deepPurple;

    final TextTheme appTextTheme = TextTheme(
      displayLarge: GoogleFonts.oswald(fontSize: 57, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.openSans(fontSize: 14),
    );

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeedColor,
        brightness: Brightness.light,
      ),
      textTheme: appTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primarySeedColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primarySeedColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500),
        ),
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
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.deepPurple.shade200,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Flutter SSH Client',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MyHomePage(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '22');
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _proxyHostController = TextEditingController();
  final TextEditingController _proxyPortController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _loadConnectionDetails();
  }

  Future<void> _loadConnectionDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hostController.text = prefs.getString('host') ?? '';
      _portController.text = prefs.getString('port') ?? '22';
      _usernameController.text = prefs.getString('username') ?? '';
      _proxyHostController.text = prefs.getString('proxyHost') ?? '';
      _proxyPortController.text = prefs.getString('proxyPort') ?? '';
    });
  }

  Future<void> _saveConnectionDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host', _hostController.text);
    await prefs.setString('port', _portController.text);
    await prefs.setString('username', _usernameController.text);
    await prefs.setString('proxyHost', _proxyHostController.text);
    await prefs.setString('proxyPort', _proxyPortController.text);
  }

  @override
  Widget build(BuildContext context) {
    final sshProvider = Provider.of<SshStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Client'),
        actions: [
          // Theme toggle buttons moved here for better access
          IconButton(
            icon: Icon(Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!sshProvider.isConnected)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(labelText: 'SSH Host'),
                        ),
                        TextField(
                          controller: _portController,
                          decoration: const InputDecoration(labelText: 'SSH Port'),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(labelText: 'Username'),
                        ),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 10),
                        Divider(),
                        const SizedBox(height: 10),
                         TextField(
                          controller: _proxyHostController,
                          decoration: const InputDecoration(labelText: 'Proxy Host (Optional)'),
                        ),
                        TextField(
                          controller: _proxyPortController,
                          decoration: const InputDecoration(labelText: 'Proxy Port'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 20),
                        sshProvider.isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: () async {
                                  await _saveConnectionDetails();
                                  final port = int.tryParse(_portController.text) ?? 22;
                                  final proxyPort = int.tryParse(_proxyPortController.text);
                                  sshProvider.connect(
                                    _hostController.text,
                                    port,
                                    _usernameController.text,
                                    _passwordController.text,
                                    proxyHost: _proxyHostController.text,
                                    proxyPort: proxyPort,
                                  );
                                },
                                child: const Text('Connect'),
                              ),
                      ],
                    ),
                  ),
                ),
              if (sshProvider.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    sshProvider.error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (sshProvider.isConnected)
                Column(
                  children: [
                    Container(
                      height: 400, // Increased height for better view
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withAlpha(204) // Fixed deprecated withOpacity
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        reverse: true, // Auto-scroll to bottom
                        child: SelectableText(
                          sshProvider.output,
                          style: GoogleFonts.robotoMono( // Monospace font
                            color: Colors.lightGreenAccent, // Classic terminal color
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commandController,
                            onSubmitted: (value) { // Execute on enter
                              sshProvider.execute(value);
                              _commandController.clear();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Enter command...',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            sshProvider.execute(_commandController.text);
                            _commandController.clear();
                          },
                        ),
                      ],
                    ),
                     const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: sshProvider.disconnect,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}