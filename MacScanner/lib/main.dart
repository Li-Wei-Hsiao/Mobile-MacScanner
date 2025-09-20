import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'routes/app_router.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request camera permission before launching the app
  PermissionStatus status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
    if (!status.isGranted) {
      // If permission is denied, exit or show error
      debugPrint('Camera permission not granted');
      return;
    }
  }
 
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false, // CLose the debug banner
      title: 'MAC Scanner',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      routerConfig: AppRouter(cameras: cameras).router,
    );
  }
}
