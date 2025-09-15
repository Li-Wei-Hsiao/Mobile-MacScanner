// lib/features/mac_scanner/presentation/settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/config/app_config.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _storage = SecureStorageService();
  final _prefixCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _remoteCtrl = TextEditingController();
  String? _exportDir;

  // 新增：版本資訊字串
  String _versionText = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
    _loadVersion(); // 讀取版本資訊
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionText = 'Version ${info.version}+${info.buildNumber}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _versionText = 'Version info unavailable';
      });
    }
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _exportDir = prefs.getString('exportDir');
    });
    _prefixCtrl.text = await _storage.read('prefix') ?? AppConfig.kDefaultCompanyPrefix;
    _hostCtrl.text = await _storage.read('scp.host') ?? '';
    _portCtrl.text = await _storage.read('scp.port') ?? AppConfig.kDefaultPort.toString();
    _userCtrl.text = await _storage.read('scp.user') ?? '';
    _passCtrl.text = await _storage.read('scp.password') ?? '';
    _remoteCtrl.text = await _storage.read('scp.remoteDir') ?? '';
  }

  Future<void> _pickExportDirectory() async {
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select export folder');
    if (dir == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exportDir', dir);
    setState(() { _exportDir = dir; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export directory saved')));
  }

  Future<void> _saveAll() async {
    await _storage.write('prefix', _prefixCtrl.text.trim());
    await _storage.write('scp.host', _hostCtrl.text.trim());
    await _storage.write('scp.port', _portCtrl.text.trim());
    await _storage.write('scp.user', _userCtrl.text.trim());
    await _storage.write('scp.password', _passCtrl.text.trim());
    await _storage.write('scp.remoteDir', _remoteCtrl.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
            onPressed: _saveAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTextField('Company Prefix (6 hex chars)', _prefixCtrl, maxLength: 6),
          const SizedBox(height: 16),
          const Divider(),
          const Text('SCP Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildTextField('Host', _hostCtrl),
          _buildTextField('Port', _portCtrl, keyboard: TextInputType.number),
          _buildTextField('Username', _userCtrl),
          _buildTextField('Password', _passCtrl, obscure: true),
          _buildTextField('Remote Dir', _remoteCtrl),
          const SizedBox(height: 16),
          const Divider(),
          const Text('Export CSV Directory', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            title: Text(_exportDir ?? 'Not set'),
            trailing: ElevatedButton(
              onPressed: _pickExportDirectory,
              child: const Text('Select'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          // 版本與作者資訊
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    _versionText,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text('Author: Leo Hsiao', style: TextStyle(color: Colors.grey)),
                  const Text('Email: leo12324leo@gmail.com', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController ctrl,
      { bool obscure = false,
        TextInputType keyboard = TextInputType.text,
        int? maxLength} )
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        maxLength: maxLength,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
