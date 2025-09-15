// lib/features/mac_scanner/presentation/scanner_page.dart
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/scan_file.dart';
import '../data/scan_repository.dart';
import '../../../core/services/audio_service.dart';
import '../domain/scan_usecase.dart';
import '../../../core/utils/validators.dart';
import '../../../core/services/secure_storage_service.dart';

enum ScanStatus { scanning, success, duplicate, invalid }

class ScannerPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ScanFile scanFile;

  const ScannerPage({
    super.key,
    required this.cameras,
    required this.scanFile,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _controller;
  late final TextRecognizer _recognizer;
  late final ScanUseCase _useCase;
  bool _busy = false;

  ScanStatus _status = ScanStatus.scanning;
  String _statusText = 'Scanning for MAC...';

  List<Rect> _boxes = [];
  List<ScanStatus> _statuses = [];

  final _storage = SecureStorageService();
  int? _totalCount;
  String? _companyPrefix;

  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _recognizer = TextRecognizer();
    _useCase = ScanUseCase(repo: ScanRepository(), audio: AudioService());
    _loadPrefix().then((_) {
      _refreshCount();
      _initCameraWithPermission();
    });
  }

  Future<void> _loadPrefix() async {
    final prefix = await _storage.read('prefix');
    setState(() => _companyPrefix = prefix);
  }

  Future<void> _refreshCount() async {
    if (widget.scanFile.id != null) {
      final count = (await ScanRepository().fetchByFile(widget.scanFile.id!)).length;
      setState(() => _totalCount = count);
    }
  }

  Future<void> _initCameraWithPermission() async {
    if (_companyPrefix == null || _companyPrefix!.isEmpty) {
      setState(() => _statusText = 'Please set company prefix first');
      return;
    }
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _statusText = 'Camera permission denied');
      return;
    }
    final camera = widget.cameras.first;
    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();

    await _controller!.setFocusMode(FocusMode.locked);

    _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Uint8List _concatenatePlanes(CameraImage image) {
    final buffer = WriteBuffer();
    for (final plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  void _processCameraImage(CameraImage image) async {
    if (_busy) return;
    _busy = true;
    if (_companyPrefix == null) {
      _busy = false;
      return;
    }

    try {
      final nv21bytes = _concatenatePlanes(image);
      final inputImage = InputImage.fromBytes(
        bytes: nv21bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation90deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final visionText = await _recognizer.processImage(inputImage);

      _boxes.clear();
      _statuses.clear();

      for (final block in visionText.blocks) {
        for (final line in block.lines) {
          final raw = line.text.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '');
          if (raw.length == 12 &&
              Validators.isValidMac12(raw) &&
              Validators.hasCorrectPrefix(raw, _companyPrefix!)) {
            final suffix = raw.substring(6);
            final exists = await _useCase.repo.suffixExists(widget.scanFile.id!, suffix);
            final status = exists ? ScanStatus.duplicate : ScanStatus.success;
            _boxes.add(line.boundingBox);
            _statuses.add(status);
            if (!exists) {
              await _useCase.processCodeForFile(raw, _companyPrefix!, widget.scanFile.id!);
              AudioService().playSuccess();
              print("***************************************** play end.");
              _refreshCount();
            }
          }
        }
      }

      if (_boxes.isNotEmpty) {
        setState(() {
          _status = _statuses.last;
          _statusText = _status == ScanStatus.success ? 'Success' : 'Duplicate MAC';
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (!mounted) return;
          setState(() {
            _status = ScanStatus.scanning;
            _statusText = 'Scanning for MAC...';
            _boxes.clear();
            _statuses.clear();
          });
        });
      }
    } catch (e) {
      print('ProcessImage error: $e');
    } finally {
      _busy = false;
    }
  }
/*
  Rect _mapCorrectRect(Rect rect, Size previewSize) {
    final renderBox = _previewKey.currentContext!.findRenderObject() as RenderBox;
    final displaySize = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    // 以 cover 模式計算 scale
    final scale = max(displaySize.width / previewSize.height, displaySize.height / previewSize.width);
    final dispW = previewSize.height * scale;
    final dispH = previewSize.width  * scale;
    final offX = (dispW - displaySize.width)  / 2;
    final offY = (dispH - displaySize.height) / 2;

    final left   = rect.left   * scale - offX + offset.dx;
    final top    = rect.top    * scale - offY + offset.dy;
    final right  = rect.right  * scale - offX + offset.dx;
    final bottom = rect.bottom * scale - offY + offset.dy;

    return Rect.fromLTRB(left, top, right, bottom);
  }
*/
  Rect _mapCorrectRect(Rect rect, Size previewSize) {
    final renderBox = _previewKey.currentContext!.findRenderObject() as RenderBox;
    final displaySize = renderBox.size;
    final globalOffset = renderBox.localToGlobal(Offset.zero);

    // 扣除 AppBar + 狀態列高度
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final offset = Offset(globalOffset.dx, globalOffset.dy - appBarHeight);

    final scale = max(displaySize.width / previewSize.height, displaySize.height / previewSize.width);
    final dispW = previewSize.height * scale;
    final dispH = previewSize.width  * scale;
    final offX = (dispW - displaySize.width)  / 2;
    final offY = (dispH - displaySize.height) / 2;

    final left   = rect.left   * scale - offX + offset.dx;
    final top    = rect.top    * scale - offY + offset.dy;
    final right  = rect.right  * scale - offX + offset.dx;
    final bottom = rect.bottom * scale - offY + offset.dy;

    return Rect.fromLTRB(left, top, right, bottom);
  }




  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final previewSize = _controller!.value.previewSize!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan: ${widget.scanFile.name}'),
        actions: [
          if (_totalCount != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: Text('Count: $_totalCount')),
            ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(fit: StackFit.expand, children: [
          Center(
            child: SizedBox(
              key: _previewKey,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          for (int i = 0; i < _boxes.length; i++)
            CustomPaint(
              painter: _BoxPainter(
                _mapCorrectRect(_boxes[i], previewSize),
                _statuses[i],
              ),
            ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusText,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _BoxPainter extends CustomPainter {
  final Rect box;
  final ScanStatus status;

  _BoxPainter(this.box, this.status);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = status == ScanStatus.success
          ? Colors.green
          : status == ScanStatus.duplicate
          ? Colors.yellow
          : Colors.red;
    //canvas.drawRect(box, paint);
    canvas.drawRect(box.shift(Offset(0, -20)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
