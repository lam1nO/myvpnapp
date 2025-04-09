import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http; // для загрузки из сети
import 'package:shared_preferences/shared_preferences.dart';


Future<String> loadVPNConfig(String configUrl) async {
  // Пока заглушка: скачай по HTTP, но позже вставь свой API
  final response = await http.get(Uri.parse("https://api.yourbrand.com/vpn-config?id=$configUrl"));
  if (response.statusCode == 200) {
    return response.body;
  } else {
    throw Exception("Не удалось загрузить конфигурацию VPN");
  }
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

class VPNHomeScreen extends StatefulWidget {
  const VPNHomeScreen({Key? key}) : super(key: key);

  @override
  State<VPNHomeScreen> createState() => _VPNHomeScreenState();
}

class _VPNHomeScreenState extends State<VPNHomeScreen> {
  late OpenVPN engine;
  String stage = "Disconnected";
  bool isLoading = false;
  String? configUrl;
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
    engine = OpenVPN(
      onVpnStageChanged: (data, raw) {
        setState(() {
          stage = raw;
          isLoading = false;
        });
      },
    );

    engine.initialize(
      groupIdentifier: "group.com.yourcompany.vpn",
      providerBundleIdentifier: "com.yourcompany.network-extension",
      localizedDescription: "Your VPN Service",
      lastStage: (lastStage) {
        setState(() {
          stage = lastStage.name;
          isLoading = false;
        });
      },
    );

// Обработка ссылки при запуске (важно!)
    _handleInitialLink();

    _initDeepLinks();
  }

  Future<void> _handleInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        print("Initial deep link: $initialUri");
        setState(() {
          configUrl = initialUri.queryParameters["file"];
        });
        if (configUrl != null) {
          _toggleVPN();
        }
      }
    } catch (err) {
      print("Ошибка получения initial deep link: $err");
    }
  }


  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen((Uri? uri) {
      print("Получен deep-link: $uri");
      if (uri != null) {
        setState(() {
          configUrl = uri.queryParameters["file"];
        });
        print("URL OpenVPN-конфига: $configUrl");
        if (configUrl != null) {
          _toggleVPN();
        }
      }
    }, onError: (err) {
      print("Ошибка обработки deep-link: $err");
    });
  }

  Future<void> _toggleVPN() async {
    if (stage.toLowerCase() == "connected") {
      setState(() => isLoading = true);
      engine.disconnect();
      return;
    }

    if (Platform.isAndroid) {
      await engine.requestPermissionAndroid();
    }

    setState(() => isLoading = true);

    try {
      final stored = await _loadStoredVpnConfig();
      if (stored == null) {
        _showError("Сначала введите конфигурацию через настройки");
        return;
      }

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

  void _showConfigOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.clipboardPaste, color: Colors.white),
            title: const Text("Вставить с буфера", style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final clipboardData = await Clipboard.getData('text/plain');
              final id = clipboardData?.text?.trim();
              if (id != null && id.isNotEmpty) {
                await _setConfigFromId(id);
              } else {
                _showError("Буфер обмена пуст");
              }
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.keyboard, color: Colors.white),
            title: const Text("Вставить вручную", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showManualEntryDialog();
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.trash2, color: Colors.white),
            title: const Text("Сбросить конфигурацию", style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              await _clearStoredVpnConfig();
              _showError("Конфигурация сброшена");
            },
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Введите код конфигурации", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Пример: alpha-test-123", hintStyle: TextStyle(color: Colors.grey)),
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
      await _saveVpnConfig(id, config); // Сохраняем
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

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

  Future<void> _clearStoredVpnConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vpn_config_id');
    await prefs.remove('vpn_config_content');
  }



  @override
  Widget build(BuildContext context) {
    bool isConnected = stage.toLowerCase() == "connected";
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Connection', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Colors.white),
            onPressed: _showConfigOptions,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnected ? LucideIcons.shieldCheck : LucideIcons.shieldAlert,
                size: 100,
                color: isConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                "Status: $stage",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _toggleVPN,
                icon: isLoading
                    ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isConnected ? LucideIcons.stopCircle : LucideIcons.play, color: Colors.white),
                label: Text(
                  isConnected ? "Disconnect" : "Connect",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                  backgroundColor: isConnected ? Colors.redAccent : Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}

const String vpnUsername = "your_username";
const String vpnPassword = "your_password";
