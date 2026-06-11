**English** · [Français](README_FR.md)

# Odysseus Dashboard

A **control center** addon for [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) — **and a full-featured local LLM launcher in its own right**. A native, frameless WebView2 window that reuses Odysseus's themes and background effects, driven by a PowerShell backend. Built by David (PalpatineRex). Free for anyone to use.

## Two ways to use it
1. **With Odysseus** — built-in Docker buttons (start / stop / update / open the app). Odysseus auto-discovers the `llama-server` launched here on `host.docker.internal:8000`.
2. **Standalone (LLM launcher)** — without Odysseus, just to drive your local models:
   - automatic GGUF scan (model family & sampler presets inferred from the filename), **favorites** (⭐ + one-click chips),
   - per-model sampler presets + editable sliders, live command preview, custom test prompt,
   - context / n-gpu-layers / port, **MoE auto-offload** for large models, **predictive VRAM gauge** (file size + context, `--cpu-moe` hint),
   - **fast mode** (reasoning off), **test-model** button with **tok/s benchmark** (⚡ badge + sparkline history),
   - a **model garage** 🏁 — speed / VRAM / date per tested model, sorted by tok/s, click to select,
   - **real-time logs** (no terminal), live VRAM + **GPU temperature** 🔥 (nvidia-smi),
   - built-in **GGUF downloader** (paste a HuggingFace URL, cancellable, auto re-scan), **auto-start** switch,
   - stops llama-server **by port** — never kills other llama instances running on the machine.

## Run
- **`Odysseus-Dashboard.exe`** (included, ~71 KB) — double-click, dedicated window, no console. `WebView2Loader.dll` sits next to it.
- Or, to develop: `powershell -STA -File dashboard-launcher.ps1`.

## Install as an Odysseus addon
Drop these files into your Odysseus installation folder:
- `dashboard-launcher.ps1`, `Odysseus-Dashboard.exe`, `WebView2Loader.dll`, `odysseus.ico` at the root,
- `dashboard.html` + `dashboard-fx.js` into `static/`,
- `Odysseus.bat` / `Odysseus-Stop.bat` / `Odysseus-Update.bat` at the root (the Docker buttons call them),
- `Update-LlamaServer.ps1` to update the llama-server binary.

Default paths point to `C:\Odysseus\` — adjust them in the `.ps1` if your install lives elsewhere.

## Architecture
- A C# `OdyForm` window (borderless, custom title bar, rounded corners) hosting a **full-screen WebView2** that loads `static/dashboard.html` through a local virtual host.
- The UI imports Odysseus's **themes** (`static/js/theme.js`, read-only); the **effects engine** is isolated in `dashboard-fx.js` so no Odysseus-tracked file is ever modified → no conflict on `git pull`.
- PowerShell backend inside the launcher: GGUF scan, presets, start/stop/test `llama-server`, nvidia-smi, Docker control, **runspace polling** (all I/O off the UI thread), JS↔PowerShell messaging.
- **17 themes**, **10 languages** (self-contained i18n), savable presets, JSON import/export, animated background effects with intensity/speed controls.

## Repo contents
| File | Role |
|---|---|
| `Odysseus-Dashboard.exe` + `WebView2Loader.dll` | ready-to-run executable |
| `dashboard-launcher.ps1` | launcher + backend source (recompile via ps2exe if changed — see `DASHBOARD.md`) |
| `static/dashboard.html` + `dashboard-fx.js` | the UI (read at runtime → an HTML change = relaunch the exe, no recompile) |
| `Odysseus.bat` / `-Stop` / `-Update` | Odysseus Docker control |
| `Update-LlamaServer.ps1` | updates the llama-server binary |
| `DASHBOARD.md` / `DASHBOARD.en.md` | full documentation (architecture, build, gotchas) — FR / EN |

## Requirements (bring your own, not included)
- **WebView2 Runtime** (Evergreen, Microsoft) — already present on most Windows 10/11 machines.
- **llama-server** (llama.cpp, CUDA or CPU build) in a `llama-win\` subfolder — download from [github.com/ggml-org/llama.cpp/releases](https://github.com/ggml-org/llama.cpp/releases) (~1 GB, not redistributed here). The dashboard launches it with the right flags.
- For the Docker buttons: an **Odysseus** install + Docker Desktop.

## Notes
- Recompile the `.ps1`: `Invoke-ps2exe -inputFile dashboard-launcher.ps1 -outputFile Odysseus-Dashboard.exe -noConsole -STA -iconFile odysseus.ico` (the exe is locked while running → compile to `.new.exe` then swap).
- Detailed gotchas (WebView2 cache, UTF-8 without BOM, Chromium slider repaint…) are in `DASHBOARD.md`.

## Credits
Dashboard: David (PalpatineRex), assisted by Claude. Themes/effects: borrowed from [Odysseus](https://github.com/pewdiepie-archdaemon/odysseus) (pewdiepie-archdaemon). Unofficial addon.
