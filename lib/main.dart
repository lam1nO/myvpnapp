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
import 'package:flutter/foundation.dart';


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
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kReleaseMode) return; // в релизе ничего не показываем
    FlutterError.presentError(details);
  };
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
  int? downloaded = 0;
  int? uploaded = 0;
  Timer? bytesTimer;


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
        onVpnStatusChanged: (data) => setState(() {
          String? bytesIn = data?.byteIn;
          String? bytesOut = data?.byteOut;
          downloaded = int.tryParse(bytesIn ?? '0');
          uploaded = int.tryParse(bytesOut ?? '0');
        })
    );
    _initializeVPN();
  }

  @override
  void dispose() {
    bytesTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeVPN() async {
    await engine.initialize(
      groupIdentifier: "group.com.example.myVpnApp",
      providerBundleIdentifier: "com.example.myVpnApp.network-extension",
      localizedDescription: "My VPN",
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
    if (isLoading) {
      setState(() => isLoading = false);
      engine.disconnect();
      return;
    }

    setState(() => isLoading = true);

    try {
      final stored = await _loadStoredVpnConfig();
      if (stored == null) return _showError("Сначала введите конфигурацию через настройки");
      print("Connecting to VPN with config:\n$stored['config']");
      await engine.connect(
        stored['config']!,
        "VPN Server",
        certIsRequired: true,
      );
    } catch (e) {
      _showError("Ошибка подключения: $e");
    } finally {
      setState(() => isLoading = false);
    }
    // try {
    //   final config = await loadLocalVPNConfig();
    //   await engine.connect(
    //     config,
    //     "Local VPN",
    //     username: vpnUsername,
    //     password: vpnPassword,
    //     certIsRequired: true,
    //   );
    // } catch (e) {
    //   _showError("Ошибка подключения: $e");
    //   setState(() => isLoading = false);
    // }
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
        _buildBottomSheetItem("Сбросить конфигурацию", LucideIcons.trash2, () => _resetConfig(context)),
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
        backgroundColor: Color(0xFF0F111F),
        title: const Text("Введите ID конфигурации", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Введите ID...",
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

  void _showCustomSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: const Color(0xFF0F111F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 10,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  Future<void> _resetConfig(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vpn_config_id');
    await prefs.remove('vpn_config_content');

    String message = "Конфигурация сброшена";
    _showCustomSnackBar(context, "Конфигурация сброшена");
  }


  @override
  Widget build(BuildContext context) {
    final isConnected = stage.toLowerCase() == "connected";
    final Color mainColor = isConnected ? Colors.greenAccent : Colors.redAccent;

    String _formatBytes(int? bytes) {
      if (bytes == null) return "0.00";

      // final parsed = int.tryParse(bytes);
      // if (parsed == null) return "0.00";

      final mb = bytes / (1024 * 1024);
      return mb.toStringAsFixed(2);
    }


    Widget _buildBodyContent() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConnectionStatusText(
            isConnected: isConnected,
            isLoading: isLoading,
            connectionDuration: connectionDuration,
          ),
          Center(
            child: GestureDetector(
              onTap: _toggleVPN,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Пульсация вокруг кнопки во время загрузки
                  if (isLoading)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.9, end: 1.4),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Opacity(
                          opacity: 1.4 - scale,
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blueAccent.withOpacity(0.3),
                              ),
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        // Зацикливаем
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && isLoading) setState(() {});
                        });
                      },
                    ),

                  // Основная кнопка
                  AnimatedContainer(
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
                          color: Colors.blueAccent.withOpacity(0.5),
                          spreadRadius: 4,
                          blurRadius: 20,
                        )
                      ]
                          : [],
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isLoading
                            ? const LinearGradient(
                          colors: [Color(0xFF13889E), Color(0xFF36B4A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : isConnected
                            ? const LinearGradient(
                          colors: [Color(0xFF27E6B7), Color(0xFF109F99)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : const LinearGradient(
                          colors: [Color(0xFFB52626), Color(0xFF6C1616)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: isLoading
                                ? Color(0xFF13889E).withOpacity(0.55)
                                : isConnected
                                ? Color(0xFF27E6B7).withOpacity(0.55)
                                : Color(0xFFB52626).withOpacity(0.45),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: IconButton(
                        iconSize: 80,
                        icon: const Icon(Icons.power_settings_new, color: Colors.white),
                        onPressed: isLoading ? null : _toggleVPN,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),


          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SpeedTile(label: "Download", speed: _formatBytes(downloaded)),
              _SpeedTile(label: "Upload", speed: _formatBytes(uploaded)),
            ],
          ),
        ],
      );

    }

    return Scaffold(
      backgroundColor: Color(0xFF090C17),
      appBar: AppBar(
        backgroundColor: Color(0xFF090C17),
        centerTitle: true,
        title: const Text('VPN', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.settings, color: Colors.white),
            color: Color(0xFF0F111F).withOpacity(0.95),
            elevation: 16,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            offset: const Offset(0, 50), // смещение вниз под иконку

            itemBuilder: (context) => [
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: const [
                    Icon(Icons.paste, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Вставить с буфера", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: const [
                    Icon(Icons.keyboard_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Вставить вручную", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline, color: Colors.redAccent),
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
                  _resetConfig(context);
                  break;
              }
            },
          )

        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF090C17),
        ),
        child: _buildBodyContent(),
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
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 18)),
        const SizedBox(height: 4),
        Text(speed, style: const TextStyle(color: Colors.white, fontSize: 20)),
        const Text("MB", style: TextStyle(color: Colors.white30, fontSize: 14)),
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
  final response = await http.get(Uri.parse("http://185.58.207.121:8000/vpn-config?id=$configUrl"));
  final jsonMap = json.decode(response.body);
  final rawConfig = jsonMap['config']; // строка с \n

  final properConfig = rawConfig.replaceAll(r'\n', '\n'); // ← ключевая строка

  if (response.statusCode == 200) {
    return properConfig;
  } else {
    throw Exception("Не удалось загрузить конфигурацию VPN");
  }
}

class ConnectionStatusText extends StatefulWidget {
  final bool isConnected;
  final bool isLoading;
  final Duration connectionDuration;

  const ConnectionStatusText({
    super.key,
    required this.isConnected,
    required this.isLoading,
    required this.connectionDuration,
  });

  @override
  State<ConnectionStatusText> createState() => _ConnectionStatusTextState();
}

class _ConnectionStatusTextState extends State<ConnectionStatusText> {
  String currentText = "";
  bool showText = false;

  @override
  void didUpdateWidget(ConnectionStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newText = widget.isLoading
        ? "Waiting..."
        : widget.isConnected
        ? _formatDuration(widget.connectionDuration)
        : "";

    final isWaitingToTimer = currentText == "Waiting..." && widget.isConnected;

    if (newText != currentText) {
      if (isWaitingToTimer) {
        // переход "Waiting..." → таймер — с плавным исчезновением и задержкой
        setState(() {
          showText = false;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() {
            currentText = newText;
            showText = true;
          });
        });
      } else if (widget.isConnected && currentText != "Waiting...") {
        // просто тикает таймер — мгновенное обновление текста
        setState(() {
          currentText = newText;
        });
      } else {
        // остальные случаи — стандартная анимация
        setState(() {
          currentText = newText;
          showText = newText.isNotEmpty;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: 30,
        child: Center(
          child: AnimatedOpacity(
            opacity: showText ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Transform.translate(
              offset: currentText == "Waiting..." ? const Offset(6, 0) : Offset.zero,
              child: Text(
                currentText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                ),
              ),
            ),

          ),
        ),
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


const String vpnUsername = "your_username";
const String vpnPassword = "your_password";