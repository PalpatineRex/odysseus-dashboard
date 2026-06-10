# Odysseus Dashboard

Centre de contrôle maison pour [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) + le serveur LLM local (llama-server). Conçu par David (PalpatineRex).

> **Sauvegarde des sources du dashboard.** Les fichiers vivent en réalité DANS le working tree d'Odysseus (`C:\Odysseus\`) — ce repo en est la copie versionnée/sauvegardée, car ils sont *untracked* dans le repo upstream. À terme : contribution au repo public Odysseus.

## Ce que c'est
Une fenêtre **WebView2 frameless** (`OdyForm`, C#) qui charge `static/dashboard.html` (UI HTML/CSS/JS, vrais thèmes + effets d'Odysseus), pilotée par un backend PowerShell compilé en exe via ps2exe.

- `dashboard-launcher.ps1` — le launcher + backend (scan GGUF, presets samplers, lancer/arrêter/tester llama-server, nvidia-smi, boutons Docker Odysseus, polling en runspace, messaging JS↔PS). Compilé : `Odysseus-Dashboard.exe`.
- `static/dashboard.html` — l'UI (10 langues, 17 thèmes, presets, logs temps réel, import/export JSON). **Lu au runtime** → un changement HTML = relancer l'exe, pas de recompil.
- `static/dashboard-fx.js` — le moteur d'effets de fond animés (extrait pour ne JAMAIS modifier le `theme.js` suivi d'Odysseus).
- `DASHBOARD.md` / `DASHBOARD.en.md` — la doc complète (FR/EN).

## Installation
Ces fichiers se déposent à la racine de `C:\Odysseus\` (le `.html`/`.js` dans `static\`). Compiler l'exe : voir `DASHBOARD.md`. Lancer `Odysseus-Dashboard.exe`.

## Notes
- Sauvegarde sources uniquement : l'exe compilé, les DLL WebView2 et `llama-win\` ne sont PAS ici (régénérables / téléchargeables).
- Détails techniques + pièges : `DASHBOARD.md`.
