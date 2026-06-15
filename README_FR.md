[English](README.md) · **Français**

# Odysseus Dashboard

> Un centre de contrôle natif pour [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) — **et un lanceur de LLM locaux à part entière.** Une fenêtre WebView2 sans cadre, pilotée par un backend PowerShell, qui reprend les thèmes et les fonds animés d'Odysseus. Pas de terminal, pas de fichier de config — pointez-le vers votre dossier de GGUF et c'est parti.

![Odysseus Dashboard — lanceur de LLM locaux](docs/screenshot.png)

<p align="left">
  <img alt="Plateforme" src="https://img.shields.io/badge/plateforme-Windows%2010%2F11-0a7bbb">
  <img alt="Backend" src="https://img.shields.io/badge/backend-PowerShell%205.1-5391FE">
  <img alt="UI" src="https://img.shields.io/badge/UI-WebView2-2C2C2C">
  <img alt="Moteur" src="https://img.shields.io/badge/moteur-llama.cpp-orange">
  <img alt="Licence" src="https://img.shields.io/badge/licence-libre%20d'usage-brightgreen">
</p>

Conçu par **David (PalpatineRex)**, assisté par Claude. Libre à qui veut s'en servir. C'est un addon **non officiel** — sans aucun lien avec le projet Odysseus.

---

## C'est quoi

Odysseus Dashboard est une appli de bureau Windows à fenêtre unique. Elle fait deux choses :

- **Lancer et régler un LLM local** — un `llama-server` natif (llama.cpp) sur votre GPU — sans jamais toucher à une ligne de commande.
- **Piloter la stack [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus)** (Docker) — démarrer, arrêter, mettre à jour et ouvrir l'app depuis un seul endroit.

La fenêtre est un vrai sosie d'Odysseus : elle importe le `theme.js` réel du projet, les mêmes palettes, les mêmes effets de fond animés et la même police **Fira Code**. Le côté « système » — scanner les fichiers, lancer les processus, lire le GPU — tourne en **PowerShell** derrière une WebView2 plein écran.

Comme Odysseus découvre tout seul un `llama-server` sur `host.docker.internal:8000`, le LLM que vous lancez ici devient le modèle qu'Odysseus utilise — l'intégration est transparente. Mais Odysseus n'est pas nécessaire : le lanceur tient debout tout seul.

## Deux usages

### 1. Avec Odysseus
Des boutons Docker intégrés démarrent / arrêtent / mettent à jour la stack et ouvrent l'app sur `http://localhost:7000`. Lancez un modèle dans le dashboard et Odysseus le détecte automatiquement sur `:8000`.

### 2. Standalone — juste un lanceur de LLM locaux
Sans Odysseus, servez-vous-en uniquement pour piloter vos modèles locaux. Tout ce qui suit fonctionne de manière autonome.

---

## Fonctionnalités

### Découverte des modèles & presets
- **Scan automatique des GGUF** dans `data\huggingface` et `data\local` (récursif). Les fichiers projecteurs `mmproj` sont ignorés ; les doublons de nom entre dossiers sont dédupliqués et loggés.
- **Détection de la famille d'après le nom de fichier** — Gemma 3/4, Qwen / Qwen3 / Qwen-Coder, Mistral (Nemo / Small / Mixtral), NemoMix, DeepSeek, Yi, LFM (Liquid), Llama, Phi… chacun avec un **preset de samplers** cohérent (température, top-p, top-k, min-p, repeat-penalty) et une justification en une ligne.
- **Sliders éditables par modèle** — partez de la reco, puis ajustez. Un **aperçu de la commande en direct** montre l'invocation `llama-server` exacte au fil de vos changements.
- **Contexte par défaut intelligent** — les gros modèles (13B+) prennent par défaut un contexte plus petit qui tient vraiment dans 12 Go de VRAM.
- **⭐ Favoris** — étoilez les modèles que vous utilisez, affichés en chips one-click. Sauvegardés localement.

### Lancement
- Réglez le **contexte (`-c`)**, les **GPU layers (`-ngl`)** et le **port** à chaque lancement.
- **Auto-offload MoE** — un modèle de plus de 10 Go reçoit automatiquement `--cpu-moe` (les experts en RAM, le reste sur GPU), plus `--no-mmap` quand il y a assez de RAM libre pour aller plus vite.
- **Mode rapide** — ajoute `--jinja --reasoning off` pour couper le « raisonnement » (idéal pour du contenu de jeu / en masse).
- **Jauge VRAM prédictive** — estime la charge à partir de la taille du GGUF et du contexte *avant* le lancement, et signale quand `--cpu-moe` va s'activer.
- **Arrête `llama-server` par port, jamais par nom** — il ne tue que le serveur qui écoute sur *votre* port ; l'instance llama d'un autre projet sur un autre port n'est pas touchée.

### Test & benchmark
- **« Tester le modèle » en un clic** — envoie un prompt sur `:8000` et affiche la réponse (repliable). On demande au modèle sa vraie identité via `/v1/models`, le « raisonnement » est retiré, et la réponse revient dans la langue de l'interface.
- **Prompt de test perso** — saisissez le vôtre (persistant) ; laissez-le vide pour une présentation automatique.
- **Benchmark ⚡ tok/s** — chaque test indique les tokens/seconde et le temps écoulé, avec une **sparkline** de vos derniers essais dans la couleur du thème.
- **🏁 Garage à modèles** — un tableau triable de chaque modèle testé : vitesse, VRAM, date. Trié par tok/s, cliquez une ligne pour re-sélectionner ce modèle. Auto-rempli à chaque test, sauvegardé localement.

### Surveillance
- **Logs llama en temps réel, sans terminal** — le log du serveur est lu en continu dans l'UI (runspace dédié, accès fichier en lecture partagée).
- **VRAM live + température GPU** via `nvidia-smi`, avec une alerte 🔥 à ≥ 83 °C.
- **LED de statut live** pour Odysseus (`:7000`) et le LLM (`:8000`).

### Récupérer des modèles
- **Téléchargeur GGUF intégré** — collez une URL HuggingFace `.gguf` et il télécharge dans `data\local`. Il vérifie d'abord l'espace disque, streame vers un fichier `.part` renommé seulement en cas de succès (jamais de GGUF à moitié écrit visible), est **annulable instantanément** même si le réseau gèle, et **re-scanne automatiquement** à la fin.
- **Mise à jour de `llama-server`** — une vérification en un clic face à la dernière release GitHub de llama.cpp, et une mise à jour explicite qui sauvegarde l'ancien build, installe le nouveau binaire CUDA Windows x64, reporte les DLL du runtime CUDA, et **revient en arrière automatiquement** si le nouveau binaire échoue.

### Apparence
- **Fenêtre sans cadre** — barre de titre custom avec drag et réduire / agrandir / fermer, fin liseré, coins nets.
- **16 palettes Odysseus intégrées** plus vos propres **thèmes custom** (enregistrés dans le `user_prefs.json` partagé d'Odysseus), un **customizer** de thème dans l'app, et des **effets de fond animés** réglables en intensité et en vitesse.
- **10 langues d'interface** (autonome, auto-détection) : anglais, français, espagnol, allemand, italien, portugais, néerlandais, russe, chinois, japonais.
- **Cartes déplaçables** — réorganisez la mise en page ; l'ordre est mémorisé.
- **Switch auto-start** — lance optionnellement le modèle sélectionné à l'ouverture (ignoré si un serveur tourne déjà, pour ne pas écraser une instance en cours).

---

## Installation & lancement

### Démarrage rapide (clé en main)
1. Récupérez `Odysseus-Dashboard.exe` (~79 Ko) et gardez `WebView2Loader.dll` à côté.
2. Double-cliquez l'exe. Pas de console, fenêtre dédiée.

C'est tout pour l'appli elle-même. Pour réellement servir un modèle, il faut aussi un build de `llama-server` et le runtime WebView2 — voir [Prérequis](#prérequis).

### Lancer depuis les sources (pour développer)
```powershell
powershell -STA -File dashboard-launcher.ps1
```
`-STA` est obligatoire (WinForms + WebView2). `dashboard.html` et `dashboard-fx.js` sont lus **au runtime** : un changement HTML/JS ne demande qu'un relancement — pas de recompil.

### Installer comme addon Odysseus
Le dashboard attend une installation Odysseus dans `C:\Odysseus\`. Déposez-y ces fichiers :

| Va dans | Fichiers |
|---|---|
| `C:\Odysseus\` (racine) | `dashboard-launcher.ps1`, `Odysseus-Dashboard.exe`, `WebView2Loader.dll`, `odysseus.ico` |
| `C:\Odysseus\` (racine) | `Odysseus.bat`, `Odysseus-Stop.bat`, `Odysseus-Update.bat` (les boutons Docker les appellent) |
| `C:\Odysseus\` (racine) | `Update-LlamaServer.ps1` (la mise à jour de llama-server) |
| `C:\Odysseus\static\` | `dashboard.html`, `dashboard-fx.js` |

Le dashboard **lit** le `static\js\theme.js` d'Odysseus (en lecture seule) pour ses thèmes : il ne modifie donc jamais un fichier suivi par Git — un `git pull` sur Odysseus reste sans conflit.

> **Chemin d'installation différent ?** Les chemins sont en dur en haut de `dashboard-launcher.ps1` (`$WV2DIR`, `$STATIC`, `$EXE`, `$SCANDIRS`, `$ODYDIR`, `$PREFS`). Modifiez-les, puis recompilez l'exe (voir [Compilation](#compilation-après-modification-du-ps1)).

---

## Utilisation

1. **Choisissez un modèle** dans la liste (groupée par famille, avec des tags 🔓/🔒). Le preset de samplers recommandé et un contexte adapté s'appliquent automatiquement.
2. **Ajustez** les sliders si vous voulez — l'**aperçu de la commande** se met à jour en direct.
3. **Lancer / Recharger.** L'ancien serveur sur ce port est arrêté, puis le nouveau démarre en caché, en loggant dans le panneau de logs live.
4. **Tester le modèle** — récupérez une réponse plus une mesure ⚡ tok/s ; consultez le **garage** pour comparer les essais.
5. Besoin d'un nouveau modèle ? Collez une URL HuggingFace `.gguf` dans le **téléchargeur** et il atterrit dans `data\local`, scanné automatiquement.
6. Vous faites aussi tourner Odysseus ? Utilisez les **boutons Docker** pour démarrer / arrêter / mettre à jour / ouvrir la stack.

---

## Architecture

```
Odysseus-Dashboard.exe   (ps2exe de dashboard-launcher.ps1)
│
├─ OdyForm (C#)            fenêtre carrée sans cadre, barre de titre HTML custom (drag + min/max/close),
│                          liseré fin, agrandissement multi-écrans, géométrie restaurée à chaque session
├─ WebView2 plein écran  → https://odyfx.local/dashboard.html   (vhost → C:\Odysseus\static)
│
├─ Backend PowerShell
│   ├─ Scan-Models         data\huggingface + data\local → *.gguf (ignore mmproj, déduplique)
│   ├─ Get-Family/PRESETS  nom de fichier → famille → réglages de samplers recommandés
│   ├─ lancer / arrêter    llama-server.exe (l'arrêt se fait PAR PORT) + auto-offload MoE
│   ├─ test                POST :8000/v1/chat/completions, tok/s, identité via /v1/models
│   ├─ nvidia-smi          VRAM + température GPU (1 tick sur 3)
│   ├─ téléchargeur        .gguf HuggingFace → data\local (.part, annulable, espace vérifié)
│   ├─ updater             Update-LlamaServer.ps1 (check / update / rollback)
│   └─ Docker              Odysseus.bat / -Stop / -Update / ouvrir :7000
│
├─ Runspaces dédiés        poll (statut/VRAM), tail des logs llama, updater, téléchargeur —
│                          TOUTE l'I/O hors du thread UI (pas de « fenêtre gelée »). État partagé = $S (synchronized).
│                          lancer / arrêter sont traités directement dans le handler de messages : jamais
│                          bloqués par un test de 150 s en cours.
│
└─ Messaging
    ├─ JS → PS   window.chrome.webview.postMessage(JSON)   → WebMessageReceived
    └─ PS → JS   ExecuteScriptAsync("window.dashInit / dashStatus / dashTest / dashLog / …")
```

Le **moteur d'effets** vit dans son propre `static/dashboard-fx.js` (un fichier appartenant à ce repo) plutôt que dans un fichier suivi par Odysseus — une raison de plus pour qu'un `git pull` sur Odysseus ne conflicte jamais.

---

## Contenu du repo

| Fichier | Rôle |
|---|---|
| `Odysseus-Dashboard.exe` + `WebView2Loader.dll` | Exécutable prêt à lancer (build ps2exe) |
| `dashboard-launcher.ps1` | Fenêtre du launcher + backend PowerShell (la source ; recompiler via ps2exe si modifié) |
| `static/dashboard.html` | L'UI (HTML/CSS/JS) — lue au runtime : un changement HTML = relancer, pas de recompil |
| `static/dashboard-fx.js` | Moteur des effets de fond animés (isolé des fichiers suivis par Odysseus) |
| `Odysseus.bat` / `Odysseus-Stop.bat` / `Odysseus-Update.bat` | Contrôle Docker d'Odysseus (les boutons Docker du dashboard les appellent) |
| `Update-LlamaServer.ps1` | Vérificateur / updater partagé de llama-server (utilisé par le dashboard et d'autres projets) |
| `odysseus.ico` | Icône de la fenêtre / de l'exe |
| `DASHBOARD.md` / `DASHBOARD.en.md` | Documentation approfondie — choix de conception, architecture, build, pièges (FR / EN) |
| `docs/screenshot.png` | La capture ci-dessus |

**Pas dans le repo** (volumineux, téléchargeables séparément, documentés ci-dessous) : `llama-win\` (~1 Go), les DLL du runtime `webview2\` (~35 Mo), et le dossier temporaire de téléchargement.

---

## Stack technique

- Backend **PowerShell 5.1**, compilé en `.exe` natif avec **[ps2exe](https://github.com/MScholtes/PS2EXE)**.
- **WebView2** (Edge Chromium) rend l'UI HTML/CSS/JS et ses effets `<canvas>` exactement comme un navigateur, si bien que le `theme.js` d'Odysseus fonctionne tel quel.
- **[llama.cpp](https://github.com/ggml-org/llama.cpp) / `llama-server`** fait l'inférence réelle (build CUDA ou CPU).
- Les boutons **Docker** pilotent la stack Odysseus via les fichiers `.bat` fournis.
- Un petit **`OdyForm` C#** (compilé en ligne) fournit la fenêtre sans cadre, redimensionnable et consciente du multi-écrans.

---

## Prérequis

À fournir vous-même — ils ne sont **pas** redistribués ici :

- **WebView2 Runtime** (Evergreen, Microsoft). Déjà présent sur la plupart des Windows 10/11 ; sinon c'est un téléchargement Microsoft gratuit.
- **`llama-server`** depuis les [releases de llama.cpp](https://github.com/ggml-org/llama.cpp/releases) (build CUDA ou CPU, ~1 Go), placé dans un sous-dossier `llama-win\`. Le dashboard le lance avec les bons flags. L'updater intégré peut l'installer et le tenir à jour.
- Les **DLL .NET de WebView2** dans un dossier `webview2\` (les assemblies compagnons du loader) — nécessaires pour lancer le `.ps1` depuis les sources.
- **Pour les boutons Docker uniquement :** une installation d'[Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) + Docker Desktop.

> Un build CUDA de `llama-server` a aussi besoin des DLL du runtime CUDA (`cudart64_12.dll`, `cublas64_12.dll`, `cublasLt64_12.dll`) à côté de lui. L'updater les reporte automatiquement d'une version à l'autre.

---

## Compilation (après modification du `.ps1`)

```powershell
Invoke-ps2exe -inputFile dashboard-launcher.ps1 -outputFile Odysseus-Dashboard.exe `
  -noConsole -STA -iconFile odysseus.ico -title 'Odysseus Dashboard'
```

L'exe en cours d'exécution est **verrouillé** : compilez vers un nom temporaire puis remplacez :

```powershell
Invoke-ps2exe -inputFile dashboard-launcher.ps1 -outputFile Odysseus-Dashboard.new.exe `
  -noConsole -STA -iconFile odysseus.ico -title 'Odysseus Dashboard'
# fermez le dashboard en cours, puis :
Move-Item -Force Odysseus-Dashboard.new.exe Odysseus-Dashboard.exe
```

Seul un changement du **`.ps1`** nécessite une recompil. Les changements de `dashboard.html` / `dashboard-fx.js` sont pris au lancement suivant.

---

## Notes & dépannage

- **Les chemins visent `C:\Odysseus\` par défaut.** Si votre installation est ailleurs, modifiez les variables en haut de `dashboard-launcher.ps1` et recompilez.
- **Fenêtre blanche / rien ne s'affiche ?** Le WebView2 Runtime manque probablement — installez-le depuis Microsoft.
- **`$PSScriptRoot` est vide dans un exe ps2exe**, d'où les chemins en dur. Les données de runtime (le dossier user-data de WebView2, `launch.log` et les logs llama) vivent dans `%LOCALAPPDATA%\OdysseusDashboard\`.
- **Un GGUF « 0 octet » dans la liste** est en général un symlink de cache HuggingFace mort côté Windows (un modèle téléchargé *dans* un conteneur crée des symlinks Linux que Windows ne résout pas), pas un téléchargement raté — le vrai blob est sous `hub\models--*\blobs\`.
- **Vous éditez `dashboard.html` ?** Écrivez-le en **UTF-8 sans BOM** (p. ex. `[IO.File]::WriteAllText` avec un encodage sans BOM) ; le `Set-Content -Encoding UTF8` de PowerShell ajoute un BOM et peut casser les accents.
- Les pièges plus profonds (gestion du cache WebView2, le bug de repaint Chromium des sliders/scrollbars, l'I/O hors thread UI, le piège des variables PowerShell insensibles à la casse…) sont documentés dans **`DASHBOARD.md`** / **`DASHBOARD.en.md`**.

---

## Crédits

Dashboard par **David (PalpatineRex)**, assisté par Claude. Thèmes et effets de fond repris d'**[Odysseus](https://github.com/pewdiepie-archdaemon/odysseus)** par *pewdiepie-archdaemon*. Inférence par **[llama.cpp](https://github.com/ggml-org/llama.cpp)**. Addon non officiel — sans lien avec le projet Odysseus.

## Licence

Aucun fichier de licence formel n'est inclus. Comme indiqué plus haut, ce dashboard est **libre d'usage pour tout le monde**. Les thèmes/effets repris et les outils embarqués (llama.cpp, WebView2, ps2exe) restent sous leurs licences amont respectives.
