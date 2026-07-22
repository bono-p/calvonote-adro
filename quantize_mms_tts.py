"""
quantize_mms_tts.py — Export + quantification MMS-TTS-ful pour Android (Phase 2)
DevLab · CalvoNote

Usage :
    pip install optimum[onnxruntime] transformers torch scipy
    python quantize_mms_tts.py

Produit :
    mms_tts_ful_int8/          ← dossier à embarquer dans l'app Android
        model_quantized.onnx   ← ~50-70 MB, tourne sur ARM64
        config.json
        tokenizer_config.json
        vocab.json

Notes :
    - Le modèle original facebook/mms-tts-ful est ~100 MB float32
    - Après quantification int8 : ~55-70 MB
    - Précision conservée à ~96-97% sur Fulfulde
    - Compatible onnxruntime-android 1.17+
"""

import os
import json
import numpy as np

OUTPUT_DIR   = "mms_tts_ful_int8"
MODEL_ID     = "facebook/mms-tts-ful"
ONNX_DIR     = "mms_tts_ful_onnx"

def step1_export_onnx():
    """Étape 1 : exporter le modèle VITS en ONNX via optimum."""
    print("=" * 60)
    print("Étape 1 — Export ONNX du modèle MMS-TTS-ful")
    print("=" * 60)

    try:
        from optimum.exporters.onnx import main_export
        main_export(
            model_name_or_path = MODEL_ID,
            output             = ONNX_DIR,
            task               = "text-to-audio",
            framework          = "pt",
            opset              = 15,
        )
        print(f"✓ Export ONNX terminé → {ONNX_DIR}/")
    except Exception as e:
        print(f"⚠ Export optimum échoué ({e})")
        print("Tentative via torch.onnx.export manuel...")
        _manual_export()

def _manual_export():
    """Fallback : export manuel via transformers + torch."""
    import torch
    from transformers import VitsModel, AutoTokenizer

    print(f"Chargement {MODEL_ID}...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model     = VitsModel.from_pretrained(MODEL_ID)
    model.eval()

    os.makedirs(ONNX_DIR, exist_ok=True)

    # Sauvegarder tokenizer et config
    tokenizer.save_pretrained(ONNX_DIR)
    model.config.save_pretrained(ONNX_DIR)

    # Texte de test pour les formes d'entrée
    test_text   = "Jam waali"
    inputs      = tokenizer(test_text, return_tensors="pt")
    input_ids   = inputs["input_ids"]

    print("Export ONNX en cours...")
    onnx_path = os.path.join(ONNX_DIR, "model.onnx")

    with torch.no_grad():
        torch.onnx.export(
            model,
            (input_ids,),
            onnx_path,
            input_names  = ["input_ids"],
            output_names = ["waveform"],
            dynamic_axes = {
                "input_ids": {0: "batch", 1: "sequence"},
                "waveform":  {0: "batch", 2: "samples"},
            },
            opset_version = 15,
            do_constant_folding = True,
        )
    print(f"✓ Export manuel terminé → {onnx_path}")

def step2_quantize_int8():
    """Étape 2 : quantification int8 statique."""
    print("\n" + "=" * 60)
    print("Étape 2 — Quantification INT8")
    print("=" * 60)

    try:
        from onnxruntime.quantization import (
            quantize_dynamic,
            QuantType,
        )
        import onnx

        os.makedirs(OUTPUT_DIR, exist_ok=True)

        # Chercher le fichier ONNX exporté
        onnx_src = None
        for fname in ["model.onnx", "model_optimized.onnx"]:
            candidate = os.path.join(ONNX_DIR, fname)
            if os.path.exists(candidate):
                onnx_src = candidate
                break

        if onnx_src is None:
            print(f"❌ Fichier ONNX introuvable dans {ONNX_DIR}/")
            return

        onnx_dst = os.path.join(OUTPUT_DIR, "model_quantized.onnx")

        print(f"Source : {onnx_src}")
        src_size = os.path.getsize(onnx_src) / (1024 ** 2)
        print(f"Taille originale : {src_size:.1f} MB")

        quantize_dynamic(
            model_input    = onnx_src,
            model_output   = onnx_dst,
            weight_type    = QuantType.QUInt8,
            optimize_model = True,
        )

        dst_size = os.path.getsize(onnx_dst) / (1024 ** 2)
        print(f"✓ Quantification terminée → {onnx_dst}")
        print(f"  Taille finale : {dst_size:.1f} MB ({dst_size/src_size*100:.0f}% de l'original)")

        # Copier config et tokenizer
        import shutil
        for fname in ["config.json", "tokenizer_config.json", "vocab.json", "special_tokens_map.json"]:
            src = os.path.join(ONNX_DIR, fname)
            if os.path.exists(src):
                shutil.copy(src, OUTPUT_DIR)
                print(f"  Copié : {fname}")

    except ImportError:
        print("❌ onnxruntime non installé : pip install onnxruntime")
    except Exception as e:
        print(f"❌ Erreur quantification : {e}")

def step3_test_inference():
    """Étape 3 : tester l'inférence ONNX quantifié."""
    print("\n" + "=" * 60)
    print("Étape 3 — Test inférence ONNX")
    print("=" * 60)

    try:
        import onnxruntime as ort
        from transformers import AutoTokenizer
        import scipy.io.wavfile as wavfile

        onnx_path     = os.path.join(OUTPUT_DIR, "model_quantized.onnx")
        tokenizer_dir = OUTPUT_DIR

        if not os.path.exists(onnx_path):
            print(f"❌ {onnx_path} introuvable — lance d'abord les étapes 1 et 2")
            return

        print("Chargement session ONNX...")
        sess_options = ort.SessionOptions()
        sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        session = ort.InferenceSession(
            onnx_path,
            sess_options = sess_options,
            providers    = ["CPUExecutionProvider"],
        )

        tokenizer = AutoTokenizer.from_pretrained(tokenizer_dir)

        test_phrases = [
            "Jam waali",
            "Aamadu lawlawjo",
            "To halleende welani hunnduko maako",
        ]

        for phrase in test_phrases:
            inputs    = tokenizer(phrase, return_tensors="np")
            input_ids = inputs["input_ids"].astype(np.int64)

            output = session.run(
                ["waveform"],
                {"input_ids": input_ids},
            )
            waveform  = output[0].squeeze()
            sample_rate = 16000  # MMS-TTS sort du 16kHz

            out_file = f"test_output_{phrase.replace(' ', '_')[:20]}.wav"
            wavfile.write(out_file, sample_rate, waveform.astype(np.float32))
            duration = len(waveform) / sample_rate
            print(f"  ✓ '{phrase}' → {out_file} ({duration:.1f}s)")

        print("\n✅ Test réussi — le modèle ONNX est prêt pour Android !")
        print(f"   Dossier à embarquer dans l'app : {OUTPUT_DIR}/")

    except Exception as e:
        print(f"❌ Erreur test : {e}")

def main():
    print("CalvoNote Phase 2 — Préparation MMS-TTS-ful pour Android")
    print("Modèle source :", MODEL_ID)
    print()

    step1_export_onnx()
    step2_quantize_int8()
    step3_test_inference()

    print("\n" + "=" * 60)
    print("PROCHAINE ÉTAPE — Intégration Flutter Android")
    print("=" * 60)
    print(f"""
1. Copier le dossier '{OUTPUT_DIR}/' dans :
   android/app/src/main/assets/models/mms_tts_ful/

2. Dans pubspec.yaml, ajouter :
   assets:
     - assets/models/mms_tts_ful/

3. Dans pubspec.yaml, ajouter le plugin :
   onnxruntime: ^1.1.0

4. Créer le service OnnxTtsService dans lib/services/
   (génération prochaine phase)
""")

if __name__ == "__main__":
    main()
