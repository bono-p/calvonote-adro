# CalvoNote Android

Application mobile Android de **transcription vocale** (Français / Anglais) et de **traduction vers le Fulfulde Adamawa**.

## Architecture

```
┌─────────────┐     ┌──────────────────────┐     ┌──────────────────────────┐
│  Microphone │ ──> │  Groq Whisper v3     │ ──> │  Transcription FR ou EN  │
└─────────────┘     │  Turbo (STT)         │     └────────────┬─────────────┘
                    └──────────────────────┘                  │
                                                              v
                                              ┌────────────────────────────┐
                                              │ Écran d'édition (optionnel)│
                                              │ L'utilisateur corrige le   │
                                              │ texte transcrit            │
                                              └────────────┬───────────────┘
                                                           │
                                  ┌────────────────────────┴────────────────────┐
                                  │                                             │
                          FR (direct)                              EN (pivot)
                                  │                                             │
                                  v                                             v
              ┌─────────────────────────────────┐         ┌──────────────────────────────┐
              │  Space HF                       │         │  Groq Llama 3.3 70B          │
              │  bonopassale/fr-fuv-            │         │  Traduction EN → FR          │
              │  Tardigrade-Eon                 │         └──────────────┬───────────────┘
              │  (NLLB fine-tuné FR↔FUV)        │                        │
              └─────────────────────────────────┘                        v
                                                          ┌──────────────────────────────┐
                                                          │  Space HF (même que gauche)  │
                                                          │  FR → FUV                    │
                                                          └──────────────────────────────┘
```

## Fonctionnalités

- 🎙️ **Enregistrement vocal** en ligne (micro du téléphone, format .m4a)
- 📝 **Transcription automatique** FR ou EN via **Groq Whisper Large v3 Turbo**
- ✏️ **Édition de la transcription** avant traduction (validation utilisateur)
- 🌍 **Traduction FR→Fulfulde** via le Space HF `bonopassale/fr-fuv-Tardigrade-Eon`
- 🔄 **Pivot EN→FR** via Groq Llama 3.3 70B (pour les transcriptions anglaises)
- 💾 **Historique local** des transcriptions/traductions
- 📤 **Partage** des résultats vers d'autres apps (WhatsApp, email, etc.)
- 🔐 **Configuration locale** des clés API (Groq + token HF optionnel)

## Détails techniques sur la traduction FR→FUV

La traduction reproduit fidèlement l'architecture du logiciel desktop :

1. **Méthode principale** : HF Inference API (`bonopassale/fr-fuv-translator-tardigrade`)
   - Endpoint : `https://api-inference.huggingface.co/models/...`
   - Paramètres : `src_lang=fra_Latn`, `tgt_lang=fuv_Latn`, `max_length=512`
   - Gestion du cold start (retry automatique avec délai)
   - Gestion du 401 (modèle privé → invite à fournir un token HF)

2. **Fallback** : Gradio v4 API sur le Space `bonopassale/fr-fuv-Tardigrade-Eon`
   - Étape 1 : `POST /gradio_api/call/predict` avec `{data: [text, "Français → Fulfulde"]}` → renvoie un `event_id`
   - Étape 2 : `GET /gradio_api/call/predict/{event_id}` (SSE) → renvoie le texte traduit

Si les deux méthodes échouent, l'app affiche un message d'erreur détaillé avec les conseils de dépannage.

## Stack technique

- **Flutter** (Dart) — UI et logique
- **Groq API** :
  - `whisper-large-v3-turbo` pour la transcription vocale
  - `llama-3.3-70b-versatile` pour le pivot EN→FR
- **HuggingFace Space** `bonopassale/fr-fuv-Tardigrade-Eon` pour FR→FUV
- **Codemagic** — CI/CD et compilation APK/AAB

## Compilation avec Codemagic

1. Connectez votre dépôt GitHub à [Codemagic](https://codemagic.io)
2. Le fichier `codemagic.yaml` à la racine configure automatiquement le build
3. Lancez un build — l'APK sera disponible en artifact

## Configuration locale

```bash
flutter pub get
flutter run
```

Dans l'app, allez dans **Paramètres** et saisissez :
- **Clé API Groq** (obligatoire) — `gsk_...` depuis console.groq.com
- **Token HuggingFace** (optionnel) — `hf_...` depuis huggingface.co/settings/tokens

## Utilisation

1. Sélectionnez la langue (Français ou Anglais)
2. Touchez le micro pour enregistrer, touchez à nouveau pour arrêter
3. La transcription s'affiche automatiquement
4. Touchez **« Éditer & traduire »** pour corriger le texte si besoin
5. La traduction en Fulfulde Adamawa s'affiche
6. Utilisez les boutons **copier** ou **partager** pour exporter le résultat
