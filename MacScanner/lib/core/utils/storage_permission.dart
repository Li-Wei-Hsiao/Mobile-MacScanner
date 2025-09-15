import 'package:permission_handler/permission_handler.dart';

class StoragePermission {
  // Request MANAGE_EXTERNAL_STORAGE
  static Future<bool> requestManageExternalStorage() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      return true;
    }
    if (status.isPermanentlyDenied) {
      // Permanently denied, open app settings
      openAppSettings();
    }
    return false;
  }
}
