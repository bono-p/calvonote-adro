# CalvoNote Mobile — Phase 1

> Transcription vocale FR / EN / Fulfulde Adamawa  
> DevLab · Flutter Android

---

## Architecture Phase 1 (100% online)

```
Micro → Groq Whisper API → Texte FR/EN
                              ↓
                   HF NLLB bonopassale → Texte Fulfulde
                              ↓
                   HF MMS-TTS-ful API → Audio WAV
                              ↓
                         Haut-parleur
```

---

## Structure du projet

```
calvonote/
├── lib/
│   ├── main.dart                  # Point d'entrée
│   ├── theme/
│   │   └── app_theme.dart         # Couleurs, typographie
│   ├── services/
│   │   ├── groq_service.dart      # Transcription + LLM Groq
│   │   ├── fuv_service.dart       # Traduction FR↔Fulfulde + TTS Fulfulde
│   │   ├── audio_service.dart     # Enregistrement micro + lecture audio
│   │   └── settings_service.dart  # Stockage sécurisé clés API
│   ├── screens/
│   │   ├── home_screen.dart       # Écran principal
│   │   ├── translate_screen.dart  # Traduction manuelle FR↔Fulfulde
│   │   ├── ai_screen.dart         # Outils IA (correction, résumé, chat)
│   │   └── settings_screen.dart   # Paramètres et clés API
│   └── widgets/
│       ├── record_button.dart     # Bouton micro animé
│       └── result_card.dart       # Carte résultat réutilisable
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   ├── proguard-rules.pro
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/com/devlab/calvonote/MainActivity.kt
│   │       └── res/
│   │           ├── xml/network_security_config.xml
│   │           └── values/{styles,colors}.xml
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
├── pubspec.yaml
└── codemagic.yaml
```

---

## Installation et premier lancement

### Prérequis
- Flutter SDK ≥ 3.10 (`flutter --version`)
- Android Studio ou VS Code avec extension Flutter
- Appareil Android (API 24+) ou émulateur

### 1. Installer les dépendances
```bash
flutter pub get
```

### 2. Configurer les clés API
Lance l'app, va dans **Paramètres** (icône ⚙️) et saisis :
- **Clé API Groq** → https://console.groq.com (gratuit)
- **Token HuggingFace** → https://huggingface.co/settings/tokens

### 3. Lancer en debug
```bash
flutter run
```

### 4. Builder un APK
```bash
flutter build apk --debug
# APK dans : build/app/outputs/apk/debug/app-debug.apk
```

---

## Codemagic — Build cloud

1. Connecte ton repo GitHub/GitLab à [codemagic.io](https://codemagic.io)
2. Dans **Environment Variables** du dashboard, ajoute :
   - `GROQ_API_KEY` → ta clé Groq (marquer comme **secret**)
   - `HF_TOKEN` → ton token HF (marquer comme **secret**)
3. Lance le workflow **android-debug** pour tester
4. Pour la release, configure le keystore Android dans **Code signing**

---

## Roadmap

| Phase | Contenu | Statut |
|-------|---------|--------|
| **Phase 1** | Pipeline complet online (Groq + HF) | ✅ Ce livrable |
| **Phase 2** | MMS-TTS-ful offline (ONNX on-device) | 🔜 |
| **Phase 3** | Whisper Fulfulde offline (whisper.cpp GGML) | 🔜 |
| **Phase 4** | Historique, partage, améliorations UX | 🔜 |

---

## Modèles utilisés

| Modèle | Usage | Mode |
|--------|-------|------|
| `whisper-large-v3-turbo` (Groq) | Transcription FR/EN/FUV | Online |
| `bonopassale/nllb-fra-fuv-finetuned` | Traduction FR↔Fulfulde | Online |
| `facebook/mms-tts-ful` | Synthèse vocale Fulfulde | Online Phase 1 → Offline Phase 2 |
| `llama-3.3-70b-versatile` (Groq) | Correction, résumé, chat | Online |
| TTS natif Android | Lecture FR/EN | Offline (intégré Android) |
