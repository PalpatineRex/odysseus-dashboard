# Odysseus Dashboard

*(Version française : [DASHBOARD.md](DASHBOARD.md))*

A desktop control-center (a single Windows `.exe`) to:

1. **start and tune the local LLM server** (llama.cpp on GPU);
2. **drive the Odysseus stack** (Docker) — start / stop / update / open.

The interface is a **clone of the Odysseus look**: it reuses the real `theme.js`, the same 16 themes, the same background effects and the **Fira Code** font. Visually, it *is* Odysseus.

> Files: `dashboard-launcher.ps1` (source) → `Odysseus-Dashboard.exe` (compiled) + `static/dashboard.html` (the UI).

---

## 1. Why these choices — the "why behind the how"

### a) Why **native Windows** `llama-server`, not Docker?

Odysseus runs in a Docker container. We first tried to **serve the LLM on the GPU from inside the container** (WSL2). It turned out to be **fundamentally unstable**:

- **non-deterministic VRAM** allocation → random OOM (a slightly large `Context`/`Batch` = crash);
- the container environment broke GPU detection (`GPU?=a` fell back to CPU, "unified memory" caused OOM).

**Chosen solution:** a **native Windows** `llama-server.exe` (llama.cpp build in `llama-win/`) → direct GPU access, **stable** (~30 tok/s). Odysseus **auto-discovers** it at `host.docker.internal:8000` (from the container), so the integration is seamless.

➡️ The dashboard **launches this native server** (not an LLM in Docker); Odysseus (Docker) **consumes** its API on `:8000`.

### b) Why an **HTML / WebView2 doublon**, not WinForms?

The goal: the dashboard must look **exactly** like Odysseus (same themes, same animated background effect).

- **Reimplementing the effects in GDI/WinForms** never reproduces Odysseus — it always drifts.
- Putting the effect "behind the UI" in WinForms creates **holes**: native controls are **opaque** and WinForms cannot render translucent panels on top of an animated canvas.

In Odysseus (which is a **web app**), the effect is a `<canvas>` at `z-index:0` **behind everything**, and panels (`background: var(--panel)`, **opaque**) sit **on top**. Result: the effect shows **in the background**, **never through** the windows.

**Chosen solution:** rebuild the dashboard **in HTML** (a true Odysseus doublon) rendered in a **full-screen WebView2**. We reuse the **real `theme.js`**, the palettes and Fira Code → pixel-identical rendering. The "system" side (files, processes, network) stays in **PowerShell** behind it.

### c) Why WebView2?

WebView2 (Edge Chromium) renders the HTML/canvas like a real browser, so `theme.js` works **as-is**. The `.NET45` DLLs are in `webview2/` (loaded by PowerShell 5.1); the Edge WebView2 Runtime must be installed (it is, on this machine).

---

## 2. Architecture

```
Odysseus-Dashboard.exe  (ps2exe of dashboard-launcher.ps1)
│
├─ OdyForm (C#)            borderless square window, custom title bar (drag + min/max/close), thin border
├─ Full-screen WebView2  → https://odyfx.local/dashboard.html   (vhost mapped to C:\Odysseus\static)
│
├─ PowerShell backend
│   ├─ Scan-Models         scans data/huggingface + data/local for *.gguf
│   ├─ Get-Family/PRESETS  detects the family → recommended settings
│   ├─ start/stop          llama-server.exe (kill + Start-Process)
│   ├─ test                POST :8000/v1/chat/completions
│   ├─ nvidia-smi          VRAM / temperature
│   └─ Docker              Odysseus.bat / -Stop / -Update / open :7000
│
├─ Polling runspace        all I/O (TCP :7000, HTTP :8000, nvidia-smi) runs OFF the UI thread
│                          → never the "hatched window" freeze. Shared state = $S (synchronized).
│
└─ Messaging
    ├─ JS → PS   window.chrome.webview.postMessage(JSON)   → WebMessageReceived
    └─ PS → JS   ExecuteScriptAsync("window.dashInit/​dashStatus/​dashTest(...)")
```

`static/dashboard.html`: the UI (HTML/CSS/JS module). Imports `./js/theme.js` (themes + effects). **Opaque** cards (`var(--panel)`) sit on the animated background. Everything in **Fira Code**.

**Dependencies (provided by Odysseus):** `static/js/theme.js`, `static/fonts/`, `llama-win/llama-server.exe`, `Odysseus.bat` / `Odysseus-Stop.bat` / `Odysseus-Update.bat`.

---

## 3. Execution flow

1. Launch the exe → WebView2 → `dashboard.html`.
2. The HTML sends `{type:'ready'}` → PowerShell **scans** the GGUFs → pushes the list (`window.dashInit`).
3. The HTML fills the combo, applies the **recommended preset** on selection, builds the **live command**.
4. **Launch / Reload** → the HTML sends the parameters → the runspace `kill`s then `Start`s `llama-server.exe`.
5. **Test** → PowerShell `POST :8000` → response (with fallback to `reasoning_content` for *thinking* mode) → shown in the HTML.
6. **Polling** (every 600 ms) → probes `:7000` (Odysseus) + `:8000` (LLM) + `nvidia-smi` → pushes status → LEDs + text.
7. **Docker** → buttons → `Odysseus.bat` / `-Stop` / `-Update` (with confirmation) / opens `http://localhost:7000`.

---

## 4. Usage

- Double-click **`Odysseus-Dashboard.exe`**.
- Pick a **model** → recommended settings apply (adjustable). **Launch / Reload**, then **Test**.
- **Fast mode** = `--jinja --reasoning off` (turns off *thinking* — ideal for game content / bulk).
- **Odysseus (Docker)** section: Start / Stop / Update / Open the app.
- **Theme** (top right): 16 Odysseus palettes, **persisted** across sessions.

---

## 5. Build (after editing the `.ps1`)

```powershell
Invoke-ps2exe -inputFile dashboard-launcher.ps1 -outputFile Odysseus-Dashboard.exe `
  -noConsole -STA -iconFile odysseus.ico -title 'Odysseus Dashboard'
```

> `dashboard.html` is read **at runtime**: for an **HTML-only** change, no need to recompile — just relaunch the exe.

---

## 6. Files

| File | Role |
|---|---|
| `dashboard-launcher.ps1` | Launcher source (to compile) |
| `Odysseus-Dashboard.exe` | The executable |
| `static/dashboard.html` | The interface (HTML/CSS/JS) |
| `webview2/` | WebView2 DLLs (`Core`, `WinForms`, `WebView2Loader`) |
| `WebView2Loader.dll` (root) | Native loader, next to the exe |
| `%LOCALAPPDATA%\OdysseusDashboard\` | Runtime cache (WebView2 `udf` profile + `launch.log`) |

Reused from Odysseus: `static/js/theme.js`, `static/fonts/`, `llama-win/`, the `*.bat` files.

---

## 7. Known pitfalls (don't repeat)

- **`$PSScriptRoot` is EMPTY in a `ps2exe` exe** → never rely on it. Hard-coded paths + cache in `%LOCALAPPDATA%`.
- **Numeric values → llama-server**: sent with a **decimal point** (never the FR-locale comma).
- **Thinking mode (Gemma)**: the answer arrives in `reasoning_content`, not `content` → fallback handled.
- **Any I/O on the UI thread freezes the window** → everything goes through the **runspace**; the UI Timer only **reads** the shared state.
- **No `WS_EX_TRANSPARENT`** on the WebView2 window (it breaks DirectComposition rendering).

---

## 8. Git (to do — public sharing)

- Suggested `.gitignore`: `webview2/*.dll`, `WebView2Loader.dll`, `*.exe`, and the `%LOCALAPPDATA%` cache (outside the repo anyway).
- To commit: `dashboard-launcher.ps1`, `static/dashboard.html`, `DASHBOARD.md`, `DASHBOARD.en.md`.
- A user who clones will need: the WebView2 Runtime (Edge), the WebView2 DLLs (to provide / document), `llama-win/`, and the Odysseus stack.
