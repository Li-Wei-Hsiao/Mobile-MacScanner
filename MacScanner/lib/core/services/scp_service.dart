// lib/core/services/scp_service.dart
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'secure_storage_service.dart';

class ScpService {
  final _storage = SecureStorageService();

  Future<void> uploadFile(File file) async {
    final host = await _storage.read('scp.host') ?? '';
    final port = int.parse(await _storage.read('scp.port') ?? '22');
    final user = await _storage.read('scp.user') ?? '';
    final pass = await _storage.read('scp.password') ?? '';
    final remoteDir = await _storage.read('scp.remoteDir') ?? '.';

    final socket = await SSHSocket.connect(host, port);
    final client = SSHClient(
      socket,
      username: user,
      onPasswordRequest: () => pass,
    );

    final sftp = await client.sftp();
    // Try to change to the target directory from remote directory
    try {
      await sftp.mkdir(remoteDir);
    } catch (_) {}

    final remotePath = '$remoteDir/${file.uri.pathSegments.last}';
    final remoteFile = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create |
      SftpFileOpenMode.write |
      SftpFileOpenMode.truncate,
    );
    final upload = remoteFile.write(file.openRead().cast());
    await upload.done;
    await remoteFile.close();
    client.close();
  }
}
