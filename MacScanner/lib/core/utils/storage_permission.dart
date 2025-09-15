import 'package:permission_handler/permission_handler.dart';

class StoragePermission {
  /// 請求 MANAGE_EXTERNAL_STORAGE
  static Future<bool> requestManageExternalStorage() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      return true;
    }
    if (status.isPermanentlyDenied) {
      // 引導至系統設定頁
      openAppSettings();
    }
    return false;
  }
}
