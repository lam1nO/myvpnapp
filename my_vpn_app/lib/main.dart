import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

Future<String> loadLocalVPNConfig() async {
  try {
    final rawConfig = await rootBundle.loadString('assets/emul_ovpn.ovpn');
    final properConfig = rawConfig.replaceAll(r'\n', '\n');
    return properConfig;
  } catch (e) {
    throw Exception("Не удалось загрузить локальный .ovpn файл: $e");
  }
}

class VPNHomeScreen extends StatefulWidget {
  const VPNHomeScreen({Key? key}) : super(key: key);

  @override
  State<VPNHomeScreen> createState() => _VPNHomeScreenState();
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VPNHomeScreen(),
    );
  }
}

class _VPNHomeScreenState extends State<VPNHomeScreen> {
  late OpenVPN engine;
  String stage = "Disconnected";
  bool isLoading = false;
  Duration connectionDuration = const Duration(seconds: 0);
  late final Stopwatch _stopwatch;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _ticker = Ticker((_) {
      if (_stopwatch.isRunning) {
        setState(() {
          connectionDuration = _stopwatch.elapsed;
        });
      }
    })..start();

    engine = OpenVPN(
      onVpnStageChanged: (data, raw) => setState(() {
        final lowerRaw = raw.toLowerCase();
        stage = raw;
        if (lowerRaw == 'connected') {
          _stopwatch.reset();
          _stopwatch.start();
          isLoading = false;
        } else if (lowerRaw == 'disconnected' || lowerRaw == 'idle') {
          _stopwatch.stop();
          connectionDuration = Duration.zero;
          isLoading = false;
        }
      }),
    );
    _initializeVPN();
  }

  Future<void> _initializeVPN() async {
    await engine.initialize(
      groupIdentifier: "group.com.yourcompany.vpn",
      providerBundleIdentifier: "com.yourcompany.network-extension",
      localizedDescription: "Your VPN Service",
      lastStage: (lastStage) => setState(() {
        stage = lastStage.name;
        isLoading = false;
      }),
    );
  }

  Future<void> _toggleVPN() async {
    if (stage.toLowerCase() == "connected") {
      setState(() => isLoading = true);
      engine.disconnect();
      return;
    }

    setState(() => isLoading = true);

    // try {
    //   final stored = await _loadStoredVpnConfig();
    //   if (stored == null) return _showError("Сначала введите конфигурацию через настройки");
    //   // debugPrint("Connecting to VPN with config:\n$stored['config']");
    //   await engine.connect(
    //     stored['config']!,
    //     "VPN Server",
    //     username: vpnUsername,
    //     password: vpnPassword,
    //     certIsRequired: true,
    //   );
    // } catch (e) {
    //   _showError("Ошибка подключения: $e");
    // } finally {
    //   setState(() => isLoading = false);
    // }
    try {
      final config = await loadLocalVPNConfig();
      await engine.connect(
        config,
        "Local VPN",
        username: vpnUsername,
        password: vpnPassword,
        certIsRequired: true,
      );
    } catch (e) {
      _showError("Ошибка подключения: $e");
      setState(() => isLoading = false);
    }
  }

  void _showConfigOptions() => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Wrap(
      children: [
        _buildBottomSheetItem("Вставить с буфера", LucideIcons.clipboardPaste, _pasteFromClipboard),
        _buildBottomSheetItem("Вставить вручную", LucideIcons.keyboard, _showManualEntryDialog),
        _buildBottomSheetItem("Сбросить конфигурацию", LucideIcons.trash2, _resetConfig),
      ],
    ),
  );

  ListTile _buildBottomSheetItem(String title, IconData icon, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: Colors.white),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    onTap: () {
      Navigator.pop(context);
      onTap();
    },
  );

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    final id = clipboardData?.text?.trim();
    if (id?.isNotEmpty ?? false) {
      await _setConfigFromId(id!);
    } else {
      _showError("Буфер обмена пуст");
    }
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Введите код конфигурации", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Пример: alpha-test-123",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Отмена", style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
            onPressed: () async {
              Navigator.pop(context);
              final id = controller.text.trim();
              if (id.isNotEmpty) {
                await _setConfigFromId(id);
              } else {
                _showError("ID не может быть пустым");
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setConfigFromId(String id) async {
    try {
      setState(() => isLoading = true);
      final config = await loadVPNConfig(id);
      await _saveVpnConfig(id, config);
      await engine.connect(
        config,
        "VPN Server",
        username: vpnUsername,
        password: vpnPassword,
        certIsRequired: true,
      );
    } catch (e) {
      _showError("Ошибка загрузки конфигурации: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );

  Future<void> _saveVpnConfig(String id, String config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vpn_config_id', id);
    await prefs.setString('vpn_config_content', config);
  }

  Future<Map<String, String>?> _loadStoredVpnConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('vpn_config_id');
    final config = prefs.getString('vpn_config_content');
    if (id != null && config != null) {
      return {'id': id, 'config': config};
    }
    return null;
  }

  Future<void> _resetConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vpn_config_id');
    await prefs.remove('vpn_config_content');
    _showError("Конфигурация сброшена");
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = stage.toLowerCase() == "connected";
    final Color mainColor = isConnected ? Colors.greenAccent : Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text('Welcome', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(LucideIcons.settings, color: Colors.white),
            color: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            offset: const Offset(0, 50), // смещение вниз под иконку
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: const [
                    Icon(LucideIcons.clipboardPaste, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Вставить с буфера", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: const [
                    Icon(LucideIcons.keyboard, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Вставить вручную", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Row(
                  children: const [
                    Icon(LucideIcons.trash2, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text("Сбросить конфигурацию", style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 1:
                  _pasteFromClipboard();
                  break;
                case 2:
                  _showManualEntryDialog();
                  break;
                case 3:
                  _resetConfig();
                  break;
              }
            },
          )

        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: SizedBox(
              height: 30,
              child: Center(
                child: AnimatedOpacity(
                  opacity: isConnected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _formatDuration(connectionDuration),
                    style: const TextStyle(color: Colors.white70, fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: isLoading ? null : _toggleVPN,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade900,
                  boxShadow: isLoading
                      ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.6),
                      spreadRadius: 4,
                      blurRadius: 16,
                    )
                  ]
                      : [],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isLoading
                        ? const _SpinningLoader(key: ValueKey('loader'))
                        : Icon(Icons.power_settings_new,
                        key: const ValueKey('power'),
                        color: stage.toLowerCase() == 'connected'
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        size: 80),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _SpeedTile(label: "Download", speed: "--"),
              _SpeedTile(label: "Upload", speed: "--"),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = twoDigits(duration.inHours);
    return "$hours:$minutes:$seconds";
  }
}

class _SpeedTile extends StatelessWidget {
  final String label;
  final String speed;

  const _SpeedTile({required this.label, required this.speed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 4),
        Text(speed, style: const TextStyle(color: Colors.white, fontSize: 18)),
        const Text("MB/s", style: TextStyle(color: Colors.white30, fontSize: 12)),
      ],
    );
  }
}

class Ticker {
  Ticker(this.onTick);
  final void Function(Duration) onTick;
  late final Timer _timer;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      onTick(Duration(seconds: t.tick));
    });
  }

  void dispose() {
    _timer.cancel();
  }
}

class _SpinningLoader extends StatefulWidget {
  const _SpinningLoader({Key? key}) : super(key: key);

  @override
  State<_SpinningLoader> createState() => _SpinningLoaderState();
}

class _SpinningLoaderState extends State<_SpinningLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, color: Colors.blueAccent, size: 64),
    );
  }
}




Future<String> loadVPNConfig(String configUrl) async {
  final response = await http.get(Uri.parse("http://192.168.1.11:8000/vpn-config?id=$configUrl"));
  final jsonMap = json.decode(response.body);
  final rawConfig = jsonMap['config']; // строка с \n

  final properConfig = rawConfig.replaceAll(r'\n', '\n'); // ← ключевая строка

  if (response.statusCode == 200) {
    return properConfig;
  } else {
    throw Exception("Не удалось загрузить конфигурацию VPN");
  }
}

const String vpnUsername = "your_username";
const String vpnPassword = "your_password";