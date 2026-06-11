[English](README.md) · **Français**

# Odysseus Dashboard

Addon **centre de contrôle** pour [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) — **et lanceur de LLM locaux à part entière**. Une fenêtre native (WebView2, frameless) qui reprend les thèmes et les effets d'Odysseus, pilotée par un backend PowerShell. Conçu par David (PalpatineRex). Libre à qui veut s'en servir.

## Deux usages
1. **Avec Odysseus** — boutons Docker intégrés (démarrer / arrêter / mettre à jour / ouvrir l'app). Odysseus découvre automatiquement le `llama-server` lancé ici sur `host.docker.internal:8000`.
2. **Standalone (lanceur LLM)** — sans Odysseus, juste pour piloter vos modèles locaux :
   - scan automatique des GGUF (familles/presets déduits du nom de fichier), **favoris** (⭐ + chips one-click),
   - presets de samplers par modèle + sliders éditables, aperçu de la commande en direct, prompt de test perso,
   - contexte / n-gpu-layers / port, **auto-offload MoE** pour les gros modèles, **jauge VRAM prédictive** (taille du fichier + contexte, suggestion `--cpu-moe`),
   - **mode rapide** (reasoning off), bouton **tester le modèle** avec **benchmark tok/s** (badge ⚡ + historique sparkline),
   - un **garage à modèles** 🏁 — vitesse / VRAM / date par modèle testé, tri par tok/s, clic = sélection,
   - **logs temps réel** (sans terminal), VRAM live + **température GPU** 🔥 (nvidia-smi),
   - **téléchargeur GGUF intégré** (collez une URL HuggingFace, annulable, re-scan auto), switch **auto-start**,
   - arrêt du llama-server **par port** — ne tue jamais les autres instances llama de la machine.

## Lancer
- **`Odysseus-Dashboard.exe`** (fourni, ~71 Ko) — double-clic, fenêtre dédiée, pas de console. `WebView2Loader.dll` est à côté.
- Ou, pour développer : `powershell -STA -File dashboard-launcher.ps1`.

## Installation comme addon Odysseus
Déposer ces fichiers dans le dossier de votre installation Odysseus :
- `dashboard-launcher.ps1`, `Odysseus-Dashboard.exe`, `WebView2Loader.dll`, `odysseus.ico` à la racine,
- `dashboard.html` + `dashboard-fx.js` dans `static/`,
- `Odysseus.bat` / `Odysseus-Stop.bat` / `Odysseus-Update.bat` à la racine (les boutons Docker les appellent),
- `Update-LlamaServer.ps1` pour mettre à jour le binaire llama-server.

Les chemins par défaut visent `C:\Odysseus\` — à adapter dans le `.ps1` si votre install est ailleurs.

## Architecture
- Une fenêtre C# `OdyForm` (borderless, barre custom, coins arrondis) hébergeant une **WebView2 plein écran** qui charge `static/dashboard.html` via un vhost local.
- L'UI importe les **thèmes** d'Odysseus (`static/js/theme.js`, lecture seule) ; le **moteur d'effets** est isolé dans `dashboard-fx.js` (pour ne jamais modifier un fichier suivi d'Odysseus → pas de conflit au `git pull`).
- Backend PowerShell dans le launcher : scan GGUF, presets, lancer/arrêter/tester `llama-server`, nvidia-smi, contrôle Docker, **polling en runspace** (toute l'I/O hors du thread UI), messaging JS↔PowerShell.
- **17 thèmes**, **10 langues** (i18n autonome), presets sauvegardables, import/export JSON, effets de fond animés avec intensité/vitesse.

## Contenu du repo
| Fichier | Rôle |
|---|---|
| `Odysseus-Dashboard.exe` + `WebView2Loader.dll` | exe prêt à lancer |
| `dashboard-launcher.ps1` | source du launcher + backend (recompiler via ps2exe si modifié — voir `DASHBOARD.md`) |
| `static/dashboard.html` + `dashboard-fx.js` | l'UI (lue au runtime → un changement HTML = relancer l'exe, pas de recompil) |
| `Odysseus.bat` / `-Stop` / `-Update` | contrôle Docker d'Odysseus |
| `Update-LlamaServer.ps1` | mise à jour du binaire llama-server |
| `DASHBOARD.md` / `DASHBOARD.en.md` | documentation complète (archi, build, pièges) — FR / EN |

## Prérequis (à fournir, non inclus)
- **WebView2 Runtime** (Evergreen, Microsoft) — déjà présent sur la plupart des Windows 10/11.
- **llama-server** (llama.cpp, build CUDA ou CPU) dans un sous-dossier `llama-win\` — à télécharger sur [github.com/ggml-org/llama.cpp/releases](https://github.com/ggml-org/llama.cpp/releases) (~1 Go, non redistribué ici). Le dashboard le lance avec les bons flags.
- Pour les boutons Docker : une installation d'**Odysseus** + Docker Desktop.

## Notes
- Recompiler le `.ps1` : `Invoke-ps2exe -inputFile dashboard-launcher.ps1 -outputFile Odysseus-Dashboard.exe -noConsole -STA -iconFile odysseus.ico` (l'exe est verrouillé s'il tourne → compiler vers `.new.exe` puis remplacer).
- Pièges détaillés (cache WebView2, encodage UTF-8 sans BOM, repaint Chromium des sliders…) dans `DASHBOARD.md`.

## Crédits
Dashboard : David (PalpatineRex), assisté par Claude. Thèmes/effets : repris de [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) (pewdiepie-archdaemon). Addon non-officiel.
