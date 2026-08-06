# CalvoNote Android

Application mobile Android de **transcription vocale** (Français / Anglais) et de **traduction vers le Fulfulde Adamawa**, propulsée par l'IA **Groq**.

## Fonctionnalités

- 🎙️ **Enregistrement vocal** en ligne (micro du téléphone)
- 📝 **Transcription automatique** en Français ou Anglais via **Groq Whisper Large v3**
- 🌍 **Traduction** de la transcription vers le **Fulfulde Adamawa** via **Groq LLM** (llama-3.3-70b)
- 💾 **Historique** local des transcriptions/traductions
- 🔐 **Clés API configurables** directement dans l'app (stockées localement)

## Stack technique

- **Flutter** (Dart) — UI et logique
- **Groq API** :
  - `whisper-large-v3` pour la transcription vocale
  - `llama-3.3-70b-versatile` pour la traduction FR→Fulfulde
- **Codemagic** — CI/CD et compilation APK/AAB

## Compilation avec Codemagic

1. Connectez votre dépôt GitHub à [Codemagic](https://codemagic.io)
2. Le fichier `codemagic.yaml` à la racine configure automatiquement le build
3. Ajoutez la variable d'environnement `GROQ_API_KEY` dans Codemagic (Groups → api_keys)
4. Lancez un build — l'APK sera disponible en artifact

## Configuration locale

```bash
flutter pub get
flutter run
```

Dans l'app, allez dans **Paramètres** et saisissez votre clé API Groq.
