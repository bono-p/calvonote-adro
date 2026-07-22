import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────
//  SERVICE AUDIO
//  - Enregistrement micro (record)
//  - Lecture WAV Fulfulde (audioplayers)
//  - TTS FR/EN natif Android (flutter_tts)
// ─────────────────────────────────────────────────────────────

enum AudioState { idle, recording, playing }

class AudioService {
  final AudioRecorder   _recorder   = AudioRecorder();
  final AudioPlayer     _player     = AudioPlayer();
  final FlutterTts      _tts        = FlutterTts();

  AudioState _state     = AudioState.idle;
  String?    _recordPath;

  AudioState get state => _state;
  bool get isRecording => _state == AudioState.recording;
  bool get isPlaying   => _state == AudioState.playing;

  // ── Initialisation ────────────────────────────────────────────

  Future<void> init() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);

    _player.onPlayerComplete.listen((_) {
      _state = AudioState.idle;
    });
  }

  // ── Permissions ───────────────────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> get hasMicPermission async =>
      (await Permission.microphone.status).isGranted;

  // ── Enregistrement ────────────────────────────────────────────

  Future<bool> startRecording() async {
    if (_state != AudioState.idle) return false;

    final hasPermission = await requestMicPermission();
    if (!hasPermission) return false;

    try {
      final dir       = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordPath     = '${dir.path}/calvonote_rec_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder:    AudioEncoder.aacLc,
          bitRate:    128000,
          sampleRate: 16000, // Whisper préfère 16kHz
        ),
        path: _recordPath!,
      );

      _state = AudioState.recording;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Arrête l'enregistrement et retourne le chemin du fichier audio.
  Future<String?> stopRecording() async {
    if (_state != AudioState.recording) return null;
    try {
      final path = await _recorder.stop();
      _state     = AudioState.idle;
      return path ?? _recordPath;
    } catch (_) {
      _state = AudioState.idle;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (_state != AudioState.recording) return;
    await _recorder.cancel();
    _state = AudioState.idle;
    if (_recordPath != null) {
      try { await File(_recordPath!).delete(); } catch (_) {}
    }
  }

  // ── Lecture WAV Fulfulde ──────────────────────────────────────

  Future<void> playWav(String path, {VoidCallback? onComplete}) async {
    await stopPlayback();
    _state = AudioState.playing;

    if (onComplete != null) {
      _player.onPlayerComplete.listen((_) {
        _state = AudioState.idle;
        onComplete();
      });
    }

    await _player.play(DeviceFileSource(path));
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _state = AudioState.idle;
  }

  // ── TTS natif FR/EN ───────────────────────────────────────────

  Future<void> speak(
    String text, {
    String language = 'fr-FR',
    VoidCallback? onComplete,
  }) async {
    await _tts.setLanguage(language);

    if (onComplete != null) {
      _tts.setCompletionHandler(onComplete);
    }

    _state = AudioState.playing;
    await _tts.speak(text);
    _state = AudioState.idle;
  }

  Future<void> stopTts() async {
    await _tts.stop();
    _state = AudioState.idle;
  }

  // ── Nettoyage ─────────────────────────────────────────────────

  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
    await _tts.stop();
  }
}

