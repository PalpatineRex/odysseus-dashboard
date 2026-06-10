# Odysseus Dashboard

*(English version: [DASHBOARD.en.md](DASHBOARD.en.md))*

Control-center desktop (un seul `.exe` Windows) pour :

1. **lancer et régler le serveur LLM local** (llama.cpp sur GPU) ;
2. **piloter la stack Odysseus** (Docker) — démarrer / arrêter / update / ouvrir.

L'interface est un **doublon du look Odysseus** : elle réutilise le vrai `theme.js`, les mêmes 16 thèmes, les mêmes effets de fond et la police **Fira Code**. Visuellement, c'est Odysseus.

> Fichiers : `dashboard-launcher.ps1` (source) → `Odysseus-Dashboard.exe` (compilé) + `static/dashboard.html` (l'UI).

---

## 1. Pourquoi ces choix — le « pourquoi du comment »

### a) Pourquoi `llama-server` **natif Windows**, et pas dans Docker ?

Odysseus tourne en conteneur Docker. On a d'abord essayé de **servir le LLM sur GPU depuis le conteneur** (WSL2). Ça s'est révélé **fondamentalement instable** :

- allocation VRAM **non déterministe** → OOM aléatoires (un `Context`/`Batch` un peu grand = crash) ;
- l'environnement du conteneur faussait la détection GPU (`GPU?=a` retombait en CPU, l'« unified memory » provoquait des OOM).

**Solution retenue :** un `llama-server.exe` **natif Windows** (build llama.cpp dans `llama-win/`) → accès GPU direct, **stable** (~30 tok/s). Odysseus le **découvre automatiquement** sur `host.docker.internal:8000` (côté conteneur), donc l'intégration est transparente.

➡️ Le dashboard **lance ce serveur natif** (pas un LLM dans Docker) ; Odysseus (Docker) **consomme** son API sur `:8000`.

### b) Pourquoi un **doublon HTML / WebView2**, et pas du WinForms ?

Le but : que le dashboard ressemble **exactement** à Odysseus (mêmes thèmes, même effet de fond animé).

- **Réimplémenter les effets en GDI/WinForms** ne reproduit jamais Odysseus à l'identique — ça diverge toujours.
- Mettre l'effet « derrière l'UI » en WinForms crée des **trous** : les contrôles natifs sont **opaques** et WinForms ne sait pas afficher des panneaux translucides au-dessus d'un canvas animé.

Or, dans Odysseus (qui est une **app web**), l'effet est un `<canvas>` en `z-index:0` **derrière tout**, et les panneaux (`background: var(--panel)`, **opaques**) sont **posés dessus**. Résultat : l'effet se voit **dans le fond**, **jamais à travers** les fenêtres.

**Solution retenue :** refaire le dashboard **en HTML** (un vrai doublon d'Odysseus) rendu dans une **WebView2 plein écran**. On réutilise le **vrai `theme.js`**, les palettes et Fira Code → rendu pixel-identique. Le « système » (fichiers, process, réseau) reste en **PowerShell** derrière.

### c) Pourquoi WebView2 ?

WebView2 (Edge Chromium) rend le HTML/canvas comme un vrai navigateur, donc `theme.js` fonctionne **tel quel**. Les DLLs `.NET45` sont dans `webview2/` (chargées par PowerShell 5.1) ; le Runtime Edge WebView2 doit être installé (il l'est sur cette machine).

---

## 2. Architecture

```
Odysseus-Dashboard.exe  (ps2exe de dashboard-launcher.ps1)
│
├─ OdyForm (C#)            fenêtre borderless carrée, barre custom (drag + min/max/close), trait fin
├─ WebView2 plein écran  → https://odyfx.local/dashboard.html   (vhost mappé sur C:\Odysseus\static)
│
├─ Backend PowerShell
│   ├─ Scan-Models         scanne data/huggingface + data/local pour les *.gguf
│   ├─ Get-Family/PRESETS  détecte la famille → réglages recommandés
│   ├─ lancer/arrêter      llama-server.exe (kill + Start-Process)
│   ├─ test                POST :8000/v1/chat/completions
│   ├─ nvidia-smi          VRAM / température
│   └─ Docker              Odysseus.bat / -Stop / -Update / ouvrir :7000
│
├─ Runspace de polling     toute l'I/O (TCP :7000, HTTP :8000, nvidia-smi) tourne HORS du thread UI
│                          → jamais de gel « fenêtre hachurée ». État partagé = $S (synchronized).
│
└─ Messaging
    ├─ JS → PS   window.chrome.webview.postMessage(JSON)   → WebMessageReceived
    └─ PS → JS   ExecuteScriptAsync("window.dashInit/​dashStatus/​dashTest(...)")
```

`static/dashboard.html` : l'UI (HTML/CSS/JS module). Importe `./js/theme.js` (thèmes + effets). Cartes **opaques** (`var(--panel)`) posées sur le fond animé. Tout en **Fira Code**.

**Dépendances (fournies par Odysseus)** : `static/js/theme.js`, `static/fonts/`, `llama-win/llama-server.exe`, `Odysseus.bat` / `Odysseus-Stop.bat` / `Odysseus-Update.bat`.

---

## 3. Flux d'exécution

1. Lancement de l'exe → WebView2 → `dashboard.html`.
2. Le HTML envoie `{type:'ready'}` → PowerShell **scanne** les GGUF → pousse la liste (`window.dashInit`).
3. Le HTML remplit le combo, applique le **preset recommandé** à la sélection, construit la **commande live**.
4. **Lancer / Recharger** → le HTML envoie les paramètres → le runspace `kill` puis `Start` `llama-server.exe`.
5. **Tester** → PowerShell `POST :8000` → réponse (avec repli sur `reasoning_content` pour le mode *thinking*) → affichée dans le HTML.
6. **Polling** (toutes les 600 ms) → sonde `:7000` (Odysseus) + `:8000` (LLM) + `nvidia-smi` → pousse le statut → LEDs + texte.
7. **Docker** → boutons → `Odysseus.bat` / `-Stop` / `-Update` (avec confirmation) / ouvre `http://localhost:7000`.

---

## 4. Utilisation

- Double-clic sur **`Odysseus-Dashboard.exe`**.
- Choisir un **modèle** → les réglages recommandés s'appliquent (ajustables). **Lancer / Recharger**, puis **Tester**.
- **Mode rapide** = `--jinja --reasoning off` (coupe le *thinking* — idéal contenu de jeu / bulk).
- Section **Odysseus (Docker)** : Démarrer / Arrêter / Update / Ouvrir l'app.
- **Thème** (en haut à droite) : 16 palettes Odysseus, **sauvegardé** entre les sessions.

---

## 5. Compilation (après modification du `.ps1`)

```powershell
Invoke-ps2exe -inputFile dashboard-launcher.ps1 -outputFile Odysseus-Dashboard.exe `
  -noConsole -STA -iconFile odysseus.ico -title 'Odysseus Dashboard'
```

> `dashboard.html` est lu **au runtime** : pour un changement **HTML uniquement**, pas besoin de recompiler — il suffit de relancer l'exe.

---

## 6. Fichiers

| Fichier | Rôle |
|---|---|
| `dashboard-launcher.ps1` | Source du launcher (à compiler) |
| `Odysseus-Dashboard.exe` | L'exécutable |
| `static/dashboard.html` | L'interface (HTML/CSS/JS) |
| `webview2/` | DLLs WebView2 (`Core`, `WinForms`, `WebView2Loader`) |
| `WebView2Loader.dll` (racine) | Loader natif, à côté de l'exe |
| `%LOCALAPPDATA%\OdysseusDashboard\` | Cache runtime (profil WebView2 `udf` + `launch.log`) |

Réutilisés d'Odysseus : `static/js/theme.js`, `static/fonts/`, `llama-win/`, les `*.bat`.

---

## 7. Pièges connus (ne pas refaire)

- **`$PSScriptRoot` est VIDE dans un exe `ps2exe`** → ne jamais en dépendre. Chemins en dur + cache dans `%LOCALAPPDATA%`.
- **Valeurs numériques → llama-server** : envoyées avec **point décimal** (jamais la virgule de la locale FR).
- **Mode thinking (Gemma)** : la réponse arrive dans `reasoning_content` et pas `content` → repli géré.
- **Tout I/O sur le thread UI gèle la fenêtre** → tout passe par le **runspace** ; le Timer UI ne fait que **lire** l'état partagé.
- **Pas de `WS_EX_TRANSPARENT`** sur la fenêtre WebView2 (casse le rendu DirectComposition).

---

## 8. Git (à faire — partage public)

- `.gitignore` conseillé : `webview2/*.dll`, `WebView2Loader.dll`, `*.exe`, et le cache `%LOCALAPPDATA%` (hors repo de toute façon).
- À committer : `dashboard-launcher.ps1`, `static/dashboard.html`, `DASHBOARD.md`, `DASHBOARD.en.md`.
- Un utilisateur qui clone aura besoin : du Runtime WebView2 (Edge), des DLLs WebView2 (à fournir / documenter), de `llama-win/`, et de la stack Odysseus.
