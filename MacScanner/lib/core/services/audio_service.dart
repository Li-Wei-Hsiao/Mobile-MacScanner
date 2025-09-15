import 'package:audioplayers/audioplayers.dart';


class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playSuccess() async {
    _player.stop();
    await _player.play(AssetSource('audio/success.mp3'));
  }

  Future<void> playError() async {
    await _player.stop();                       // ← 新增
    await _player.play(AssetSource('audio/error.mp3'));
  }
}

