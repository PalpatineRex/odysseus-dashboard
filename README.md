# Odysseus Dashboard

Addon **centre de contrôle** pour [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) — **et lanceur de LLM locaux à part entière**. Conçu par David (PalpatineRex). Libre à qui veut s'en servir.

> **Deux usages :**
> 1. **Avec Odysseus** — boutons Docker (démarrer/arrêter/update/ouvrir), Odysseus découvre le llama-server lancé ici sur `host.docker.internal:8000`.
> 2. **Standalone** — rien que pour **lancer/piloter des LLM locaux** (llama-server) : scan automatique des GGUF, presets de samplers par famille de modèle, contexte/ngl/port, auto-offload MoE, mode rapide (reasoning off), test du modèle, logs temps réel, VRAM live. Pas besoin d'Odysseus pour ça.
>
> Addon non-officiel : ces fichiers se déposent dans un dossier Odysseus (le `.html`/`.js` dans `static\`), mais le launcher fonctionne seul pour la partie LLM.

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
