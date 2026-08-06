import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Service d'enregistrement audio.
/// Produit un fichier .m4a compatible avec l'API Groq Whisper.
class AudioRecorderService {
  AudioRecorderService._();
  static final AudioRecorderService instance = AudioRecorderService._();

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;

  /// Demande la permission micro.
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Démarre l'enregistrement. Retourne le chemin du fichier.
  Future<String> start() async {
    if (_isRecording) {
      throw StateError('Un enregistrement est déjà en cours');
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw StateError('Permission micro refusée');
    }

    final dir = await getTemporaryDirectory();
    final fileName =
        'calvonote_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = '${dir.path}/$fileName';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,    // .m4a
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    _isRecording = true;
    _currentPath = path;
    return path;
  }

  /// Arrête l'enregistrement et retourne le chemin du fichier.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    _currentPath = path;
    return path;
  }

  /// Annule l'enregistrement et supprime le fichier.
  Future<void> cancel() async {
    if (_isRecording) {
      await _recorder.stop();
    }
    _isRecording = false;
    _currentPath = null;
  }

  /// Libère les ressources.
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
