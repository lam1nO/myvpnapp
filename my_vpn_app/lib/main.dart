import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class VPNHomeScreen extends StatefulWidget {
  const VPNHomeScreen({Key? key}) : super(key: key);

  @override
  State<VPNHomeScreen> createState() => _VPNHomeScreenState();
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
        stage = raw;
        isLoading = false;
        if (raw.toLowerCase() == 'connected') {
          _stopwatch.reset();
          _stopwatch.start();
        } else {
          _stopwatch.stop();
          connectionDuration = Duration.zero;
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

    try {
      final stored = await _loadStoredVpnConfig();
      if (stored == null) return _showError("Сначала введите конфигурацию через настройки");

      await engine.connect(
        stored['config']!,
        "VPN Server",
        username: vpnUsername,
        password: vpnPassword,
        certIsRequired: true,
      );
    } catch (e) {
      _showError("Ошибка подключения: $e");
    } finally {
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
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Colors.white),
            onPressed: _showConfigOptions,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _formatDuration(connectionDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 24),
              ),
            ),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 12,
                    valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                    backgroundColor: Colors.grey.shade900,
                  ),
                ),
                IconButton(
                  iconSize: 80,
                  icon: Icon(Icons.power_settings_new, color: mainColor),
                  onPressed: isLoading ? null : _toggleVPN,
                ),
              ],
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


Future<String> loadVPNConfig(String configUrl) async {
  final response = await http.get(Uri.parse("https://api.yourbrand.com/vpn-config?id=$configUrl"));
  if (response.statusCode == 200) {
    return response.body;
  } else {
    throw Exception("Не удалось загрузить конфигурацию VPN");
  }
}

const String vpnUsername = "your_username";
const String vpnPassword = "your_password";