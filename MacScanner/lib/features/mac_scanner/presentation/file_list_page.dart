import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/storage_permission.dart';
import '../data/file_repository.dart';
import '../data/scan_repository.dart';
import '../data/scan_file.dart';
import '../domain/export_usecase.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/scp_service.dart';
import 'scanner_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class FileListPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FileListPage({super.key, required this.cameras});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  final _fileRepo = FileRepository();
  final _scanRepo = ScanRepository();
  final _fileService = FileService();
  final _scpService = ScpService();
  late final ExportUseCase _exportUseCase = ExportUseCase(
    fileService: _fileService,
    fileRepo: _fileRepo,
    scanRepo: _scanRepo,
  );

  Future<List<ScanFile>> _loadFiles() => _fileRepo.getAllFiles();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAC Scanner Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ScanFile>>(
        future: _loadFiles(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final files = snap.data ?? [];
          if (files.isEmpty) {
            return const Center(child: Text('No files. Tap + to create.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: files.length,
            itemBuilder: (_, i) => _buildTile(files[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFileDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTile(ScanFile file) {
    final updated = DateTime.fromMillisecondsSinceEpoch(file.updatedAt);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder),
        title: Text(file.name),
        subtitle: Text(
          'Records: ${file.recordCount}  •  ${DateFormat('MM/dd HH:mm').format(updated)}',
        ),
        onTap: () => _openRecords(file),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _onAction(action, file),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'scan',
              child: Row(children: const [Icon(Icons.camera_alt), SizedBox(width: 8), Text('Scan')]),
            ),
            PopupMenuItem(
              value: 'view',
              child: Row(children: const [Icon(Icons.history), SizedBox(width: 8), Text('View')]),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(children: const [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')]),
            ),
            PopupMenuItem(
              value: 'export',
              child: Row(children: const [Icon(Icons.download_outlined), SizedBox(width: 8), Text('Export CSV')]),
            ),
            PopupMenuItem(
              value: 'upload',
              child: Row(children: const [Icon(Icons.cloud_upload), SizedBox(width: 8), Text('Upload')]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: const [Icon(Icons.delete), SizedBox(width: 8), Text('Delete')]),
            ),
          ],
        ),
      ),
    );
  }

  void _onAction(String action, ScanFile file) {
    switch (action) {
      case 'scan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ScannerPage(cameras: widget.cameras, scanFile: file)),
        ).then((_) => setState(() {}));
        break;
      case 'view':
        _openRecords(file);
        break;
      case 'edit':
        _editFile(file);
        break;
      case 'export':
        _exportToExternal(file);
        break;
      case 'upload':
        _exportAndUpload(file);
        break;
      case 'delete':
        _deleteFile(file);
        break;
    }
  }

  void _openRecords(ScanFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryPage(fileId: file.id, fileName: file.name),
      ),
    ).then((_) {
      setState(() {});  // Refresh file list when returning to home page, including record counts
    });
  }

  void _editFile(ScanFile file) {
    final nameCtrl = TextEditingController(text: file.name);
    final descCtrl = TextEditingController(text: file.description);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit File'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final updated = file.copyWith(
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
              );
              await _fileRepo.updateFile(updated);
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCreateFileDialog() {
    final name = TextEditingController();
    final desc = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New File'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await _fileRepo.createFile(name.text.trim(), desc.text.trim());
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExternal(ScanFile file) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = prefs.getString('exportDir');
      if (dir == null || dir.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set export directory in Settings')),
        );
        return;
      }
      if (!await StoragePermission.requestManageExternalStorage()) return;

      // 使用 ExportUseCase.exportsFileToCSV
      final csvPath = await _exportUseCase.exportFileToCSV(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $csvPath')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportAndUpload(ScanFile file) async {
    final csv = await _exportUseCase.exportFileToCSV(file);
    try {
      await _scpService.uploadFile(File(csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _deleteFile(ScanFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file.name}" and all records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _fileRepo.deleteFile(file.id!);
      setState(() {});
    }
  }
}
