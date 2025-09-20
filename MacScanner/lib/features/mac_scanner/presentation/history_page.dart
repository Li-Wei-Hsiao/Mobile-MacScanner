import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/scan_repository.dart';
import '../data/scan_record.dart';

class HistoryPage extends StatefulWidget {
  final int? fileId;
  final String? fileName;
  const HistoryPage({super.key, this.fileId, this.fileName});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repo = ScanRepository();
  bool _sortAscending = true;

  Future<List<ScanRecord>> _loadRecords() async {
    final records = widget.fileId != null
        ? await _repo.fetchByFile(widget.fileId!)
        : await _repo.fetchRecent(200);
    records.sort((a, b) =>
    _sortAscending ? a.mac.compareTo(b.mac) : b.mac.compareTo(a.mac)
    );
    return records;
  }

  Future<void> _deleteRecord(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteRecord(id);
      setState(() {});
    }
  }

  void _toggleSort() => setState(() => _sortAscending = !_sortAscending);

  @override
  Widget build(BuildContext context) {
    final title = widget.fileName != null
        ? 'Records: ${widget.fileName}'
        : 'Recent Records';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: 'Sort by MAC',
            onPressed: _toggleSort,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Resequence & Reload',
            onPressed: () async {
              if (widget.fileId != null) await _repo.resequenceFile(widget.fileId!);
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ScanRecord>>(
        future: _loadRecords(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snap.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text('No records'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: records.length,
            itemBuilder: (context, i) {
              final r = records[i];
              final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
              return Card(
                child: ListTile(
                  leading: r.localId != null
                      ? CircleAvatar(child: Text('${r.localId}'))
                      : null,
                  title: Text(r.mac, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                  subtitle: Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(dt), style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteRecord(r.id!),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 4),
          );
        },
      ),
    );
  }
}
