import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:app_links/app_links.dart';

Future<String> loadVPNConfig(String configUrl) async {
  // TODO: Скачать конфиг из сети, пока заглушка
  return await rootBundle.loadString('assets/my_emulator.ovpn');
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

    _initDeepLinks();
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
    if (configUrl == null) {
      print("Нет конфигурации для VPN");
      return;
    }
    String vpnConfig = await loadVPNConfig(configUrl!);
    await engine.connect(
      vpnConfig,
      "VPN Server",
      username: vpnUsername,
      password: vpnPassword,
      certIsRequired: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = stage.toLowerCase() == "connected";
    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Connection', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
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
