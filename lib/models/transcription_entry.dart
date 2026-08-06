/// Représente une entrée d'historique : transcription + traduction.
class TranscriptionEntry {
  final String id;
  final String audioPath;
  final String language;        // 'fr' ou 'en'
  final String transcription;   // texte transcrit
  final String translation;     // texte traduit en Fulfulde
  final DateTime createdAt;
  final String? errorMessage;

  TranscriptionEntry({
    required this.id,
    required this.audioPath,
    required this.language,
    required this.transcription,
    required this.translation,
    required this.createdAt,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioPath': audioPath,
        'language': language,
        'transcription': transcription,
        'translation': translation,
        'createdAt': createdAt.toIso8601String(),
        'errorMessage': errorMessage,
      };

  factory TranscriptionEntry.fromJson(Map<String, dynamic> json) =>
      TranscriptionEntry(
        id: json['id'] as String,
        audioPath: json['audioPath'] as String,
        language: json['language'] as String,
        transcription: json['transcription'] as String,
        translation: json['translation'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        errorMessage: json['errorMessage'] as String?,
      );
}
