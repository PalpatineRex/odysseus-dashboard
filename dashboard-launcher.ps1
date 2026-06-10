# ============================================================
#  Odysseus Dashboard — launcher HTML (WebView2 plein ecran)
#  L'UI = dashboard.html (doublon Odysseus). PowerShell pilote derriere.
#  -> compile en exe avec ps2exe, exactement comme l'ancien.
# ============================================================
$ErrorActionPreference = 'Stop'
$WV2DIR = 'C:\Odysseus\webview2'
$STATIC = 'C:\Odysseus\static'
$APPDIR = Join-Path $env:LOCALAPPDATA 'OdysseusDashboard'
try { New-Item -ItemType Directory -Force -Path $APPDIR | Out-Null } catch {}
$UDF    = Join-Path $APPDIR 'udf'
$LOG    = Join-Path $APPDIR 'launch.log'
$GEO    = Join-Path $APPDIR 'window.json'
$LLMLOG = Join-Path $APPDIR 'llama.run.log'
$OUTLOG = Join-Path $APPDIR 'llama.out.log'
$ERRLOG = Join-Path $APPDIR 'llama.err.log'
function DLog($m){ try { Add-Content -Path $LOG -Value ("[{0}] {1}" -f (Get-Date -Format HH:mm:ss.fff), [string]$m) } catch {} }
try { Set-Content -Path $LOG -Value "=== launcher start ===" } catch {}
$env:Path = "$WV2DIR;$env:Path"
try {
  Add-Type -Path "$WV2DIR\Microsoft.Web.WebView2.Core.dll"
  Add-Type -Path "$WV2DIR\Microsoft.Web.WebView2.WinForms.dll"
  $script:wvOK = $true
} catch { $script:wvOK = $false }
DLog "wvOK=$($script:wvOK)"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- DPI aware (System) ----
try { Add-Type -Namespace W -Name Dpi -MemberDefinition '[DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int v);' ; [W.Dpi]::SetProcessDpiAwareness(1) | Out-Null } catch {}

# ---- helpers Win32 (drag fenetre borderless) ----
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WinDrag {
  [DllImport("user32.dll")] public static extern bool ReleaseCapture();
  [DllImport("user32.dll")] public static extern int SendMessage(IntPtr h,int m,int w,int l);
}
"@

# ---- OdyForm : borderless, coins arrondis, redimensionnable (repris de l'ancien launcher) ----
Add-Type -ReferencedAssemblies 'System.Windows.Forms','System.Drawing' -TypeDefinition @"
#pragma warning disable 0649
using System; using System.Drawing; using System.Windows.Forms; using System.Runtime.InteropServices;
public class OdyForm : Form {
  [DllImport("gdi32.dll")] static extern IntPtr CreateRoundRectRgn(int a,int b,int c,int d,int e,int f);
  [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
  [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr h, int f);
  [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr h, ref MONITORINFO mi);
  const int WM_GETMINMAXINFO = 0x0024;
  struct RECT2 { public int left, top, right, bottom; }
  struct MONITORINFO { public int cbSize; public RECT2 rcMonitor; public RECT2 rcWork; public int dwFlags; }
  struct POINT2 { public int x, y; }
  struct MINMAXINFO { public POINT2 ptReserved, ptMaxSize, ptMaxPosition, ptMinTrackSize, ptMaxTrackSize; }
  const int WM_NCHITTEST = 0x0084;
  const int HTCLIENT=1,HTLEFT=10,HTRIGHT=11,HTTOP=12,HTTOPLEFT=13,HTTOPRIGHT=14,HTBOTTOM=15,HTBOTTOMLEFT=16,HTBOTTOMRIGHT=17;
  public int Grip = 6;
  public int Radius = 0;
  public Color BorderColor = Color.FromArgb(64,64,74);   // trait fin discret (plus de magenta)
  public OdyForm() { this.FormBorderStyle = FormBorderStyle.None; this.DoubleBuffered = true; this.SetStyle(ControlStyles.ResizeRedraw, true); }
  protected override void OnPaint(PaintEventArgs e) {
    base.OnPaint(e);
    if (this.WindowState != FormWindowState.Normal) return;
    using (var pen = new Pen(BorderColor, 1f)) e.Graphics.DrawRectangle(pen, 0, 0, this.Width-1, this.Height-1);
  }
  void Reround() { this.Region = null; }   // fenetre CARREE (pas d'arrondi)
  protected override void OnResize(EventArgs e) { base.OnResize(e); Reround(); }
  protected override void OnShown(EventArgs e) { base.OnShown(e); Reround(); }
  protected override void WndProc(ref Message m) {
    if (m.Msg == WM_GETMINMAXINFO) {
      IntPtr mon = MonitorFromWindow(this.Handle, 2);
      MONITORINFO mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
      if (GetMonitorInfo(mon, ref mi)) {
        MINMAXINFO mmi = (MINMAXINFO)Marshal.PtrToStructure(m.LParam, typeof(MINMAXINFO));
        mmi.ptMaxPosition.x = mi.rcWork.left - mi.rcMonitor.left; mmi.ptMaxPosition.y = mi.rcWork.top - mi.rcMonitor.top;
        mmi.ptMaxSize.x = mi.rcWork.right - mi.rcWork.left; mmi.ptMaxSize.y = mi.rcWork.bottom - mi.rcWork.top;
        Marshal.StructureToPtr(mmi, m.LParam, false);
      }
      return;
    }
    if (m.Msg == WM_NCHITTEST && this.WindowState == FormWindowState.Normal) {
      int lp = m.LParam.ToInt32();
      Point p = this.PointToClient(new Point((short)(lp & 0xFFFF), (short)((lp >> 16) & 0xFFFF)));
      int w=this.ClientSize.Width, h=this.ClientSize.Height, g=this.Grip, res=HTCLIENT;
      bool L=p.X<=g, R=p.X>=w-g, T=p.Y<=g, B=p.Y>=h-g;
      if (T&&L) res=HTTOPLEFT; else if (T&&R) res=HTTOPRIGHT; else if (B&&L) res=HTBOTTOMLEFT; else if (B&&R) res=HTBOTTOMRIGHT;
      else if (L) res=HTLEFT; else if (R) res=HTRIGHT; else if (T) res=HTTOP; else if (B) res=HTBOTTOM;
      if (res != HTCLIENT) { m.Result = (IntPtr)res; return; }
    }
    base.WndProc(ref m);
  }
}
"@

# ============================================================
#  Backend : scan GGUF, presets, lancer/arreter llama, test, Docker, polling
# ============================================================
$EXE='C:\Odysseus\llama-win\llama-server.exe'
$SCANDIRS=@('C:\Odysseus\data\huggingface','C:\Odysseus\data\local')
$ODYDIR='C:\Odysseus'
$PREFS='C:\Odysseus\data\user_prefs.json'
$PRESETS=@{
  'Gemma 4'=@{t=1.0;p=0.95;k=64;mp=0.0;rp=1.0;note='Defaults Google : creatif & multilingue.'}
  'Gemma 3'=@{t=1.0;p=0.95;k=64;mp=0.0;rp=1.0;note='Defaults Google : temp 1.0 / top-k 64 / top-p 0.95.'}
  'Qwen Coder'=@{t=0.2;p=0.9;k=40;mp=0.0;rp=1.05;note='CODE : temperature basse = code plus fiable.'}
  'Qwen3'=@{t=0.7;p=0.8;k=20;mp=0.0;rp=1.0;note='Qwen3 : top-k 20 / top-p 0.8. Baisse temp a 0.2 pour du code.'}
  'Qwen'=@{t=0.7;p=0.8;k=20;mp=0.0;rp=1.0;note='Qwen : top-k 20 / top-p 0.8.'}
  'NemoMix'=@{t=1.0;p=1.0;k=0;mp=0.05;rp=1.0;note='NemoMix-Unleashed : merge creatif/RP -> temp 1.0 + min-p 0.05. Pour du factuel, baisse temp a ~0.35.'}
  'Mistral Nemo'=@{t=0.35;p=1.0;k=0;mp=0.0;rp=1.0;note='Mistral : temp basse (~0.3). Bon en francais.'}
  'Mistral Small'=@{t=0.3;p=1.0;k=0;mp=0.0;rp=1.0;note='Mistral Small : temp basse (~0.15-0.3) = plus fiable.'}
  'Mistral'=@{t=0.6;p=0.9;k=0;mp=0.0;rp=1.0;note='Mistral / 7B : temp 0.6 / top-p 0.9.'}
  'Mixtral'=@{t=0.7;p=0.95;k=0;mp=0.0;rp=1.0;note='Mixtral MoE : temp 0.7 / top-p 0.95.'}
  'DeepSeek'=@{t=0.6;p=0.95;k=0;mp=0.0;rp=1.0;note='DeepSeek : temp 0.6 / top-p 0.95. R1 = raisonnement.'}
  'Yi'=@{t=0.7;p=0.8;k=40;mp=0.0;rp=1.0;note='Yi (01-AI) : temp 0.7 / top-p 0.8.'}
  'LFM (Liquid)'=@{t=0.3;p=1.0;k=0;mp=0.15;rp=1.05;note='LFM2 : temp 0.3 / min-p 0.15 / repeat 1.05. Rapide.'}
  'Llama'=@{t=0.6;p=0.9;k=0;mp=0.0;rp=1.0;note='Llama : temp 0.6 / top-p 0.9.'}
  'Phi'=@{t=0.7;p=0.9;k=40;mp=0.0;rp=1.0;note='Phi : usage general.'}
  'Defaut'=@{t=0.7;p=0.95;k=40;mp=0.0;rp=1.0;note='Reglage neutre par defaut.'}
}
function Get-Family([string]$name){ $n=$name.ToLower()
  if($n -match 'gemma[-_]?4'){return 'Gemma 4'}; if($n -match 'gemma'){return 'Gemma 3'}
  if($n -match 'coder'){return 'Qwen Coder'}; if($n -match 'qwen3'){return 'Qwen3'}; if($n -match 'qwen'){return 'Qwen'}
  if($n -match 'nemomix' -or $n -match 'unleashed'){return 'NemoMix'}; if($n -match 'nemo'){return 'Mistral Nemo'}; if($n -match 'lfm' -or $n -match 'liquid'){return 'LFM (Liquid)'}
  if($n -match 'deepseek'){return 'DeepSeek'}; if($n -match 'mistral[-_ ]?small'){return 'Mistral Small'}; if($n -match 'mixtral'){return 'Mixtral'}; if($n -match 'mistral'){return 'Mistral'}; if($n -match '(^|[-_ ])yi[-_]'){return 'Yi'}
  if($n -match 'llama'){return 'Llama'}; if($n -match 'phi'){return 'Phi'}; return 'Defaut' }
function Get-DefaultCtx([string]$name){ $n=$name.ToLower(); $b=0.0
  if($n -match '(\d+(?:\.\d+)?)\s*b'){ $b=[double]$Matches[1] }
  if($b -eq 0 -and $n -match 'nemo'){ $b=12 }   # Mistral Nemo = 12B (pas de taille dans le nom)
  if($b -ge 13){ return 8192 }                  # 13B+ : trop gros pour 16384 sur 12 Go de VRAM
  return 16384 }
function Scan-Models{ $list=@(); foreach($d in $SCANDIRS){ if(Test-Path $d){
  Get-ChildItem -Path $d -Recurse -Filter *.gguf -EA SilentlyContinue | ForEach-Object {
    if($_.Name -notmatch '(?i)mmproj'){ $list += [PSCustomObject]@{ Name=$_.Name; Path=$_.FullName; Size=[long]$_.Length } } } } }
  return $list | Sort-Object Name -Unique }
$models=@(Scan-Models)
DLog "scan: $($models.Count) modeles"

# etat partage + runspace polling (I/O hors thread UI)
$S=[hashtable]::Synchronized(@{ ody='Odysseus : ...'; odyUp=$false; llm='LLM : ...'; llmUp=$false
  testReq=$false; testBusy=$false; testOut=''; testLang='fr'; vramU=0; vramT=0; run=$true; exe=$EXE; launchReq=$false; launchArgs=@(); stopReq=$false; llmLog=''; llmLogFile=$LLMLOG; errLogFile=$ERRLOG; outLogFile=$OUTLOG
  llamaReq=''; llamaPush=''; llamaSeq=0; updScript='C:\Odysseus\Update-LlamaServer.ps1'
  testPrompt=''; testMeta=''; testSeq=0; gpuT=0; dlReq=''; dlCancel=$false; dlState=''; dlSeq=0 })
$pollRs=[runspacefactory]::CreateRunspace(); $pollRs.ApartmentState='MTA'; $pollRs.ThreadOptions='ReuseThread'; $pollRs.Open()
$pollRs.SessionStateProxy.SetVariable('S',$S)
$pollPs=[powershell]::Create(); $pollPs.Runspace=$pollRs
[void]$pollPs.AddScript({
  while($S.run){
    # stop & launch sont geres directement dans WebMessageReceived (instantanes, jamais bloques par un test en cours)
    try{ $tc=New-Object System.Net.Sockets.TcpClient; $iar=$tc.BeginConnect('127.0.0.1',7000,$null,$null)
      if($iar.AsyncWaitHandle.WaitOne(600) -and $tc.Connected){$S.odyUp=$true}else{$S.odyUp=$false}; $tc.Close() }catch{ $S.odyUp=$false }
    $S.ody = if($S.odyUp){'En ligne - :7000'}else{'Arrete / injoignable'}
    # VRAM (toujours, pour la jauge -- pas seulement quand un modele est charge)
    $vram=''
    try{ $psi=New-Object System.Diagnostics.ProcessStartInfo; $psi.FileName='nvidia-smi'
      $psi.Arguments='--query-gpu=memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits'
      $psi.RedirectStandardOutput=$true; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
      $pr=[System.Diagnostics.Process]::Start($psi); $o=$pr.StandardOutput.ReadToEnd(); $pr.WaitForExit()
      $aa=($o.Trim() -split ','); if($aa.Count -ge 3){ $S.vramU=[int]($aa[0].Trim()); $S.vramT=[int]($aa[1].Trim()); $S.gpuT=[int]($aa[2].Trim()); $vram="  |  VRAM $($aa[0].Trim())/$($aa[1].Trim()) Mo  $($aa[2].Trim())C" } }catch{}
    try{ $m=Invoke-RestMethod -Uri 'http://127.0.0.1:8000/v1/models' -TimeoutSec 1
      $nm=($m.data | Select-Object -First 1).id
      $S.llm="$nm @ :8000$vram"; $S.llmUp=$true
    }catch{ $S.llm='aucun serveur sur :8000 (clique Lancer / Recharger)'; $S.llmUp=$false }
    if($S.testReq){ $S.testReq=$false; $S.testBusy=$true; $S.testOut='__TESTING__'
      try{
        # identite reelle du modele charge (recupere via /v1/models -> evite le "je suis ChatGPT")
        $mid='this local model'
        try{ $mr=Invoke-RestMethod -Uri 'http://127.0.0.1:8000/v1/models' -TimeoutSec 2
          $rid=([string](($mr.data | Select-Object -First 1).id))
          if($rid){ $mid=(Split-Path $rid -Leaf) -replace '\.gguf$','' -replace '(?i)[-_.](Q\d+[_a-z0-9]*|IQ\d+[_a-z0-9]*|f16|bf16|fp16|mxfp4)$','' } }catch{}
        # langue de l'UI -> la reponse sort dans cette langue
        $langMap=@{ fr='French'; en='English'; es='Spanish'; de='German'; it='Italian'; pt='Portuguese'; nl='Dutch'; ru='Russian'; zh='Chinese'; ja='Japanese' }
        $lc=([string]$S.testLang).ToLower().Trim(); if(-not $lc){ $lc='fr' }
        $lang=$langMap[$lc]; if(-not $lang){ $lang='French' }
        # prompt perso (champ "Réponse du test") : s'il est rempli, on l'envoie tel quel ; sinon presentation auto
        $cp=([string]$S.testPrompt).Trim()
        if($cp){
          $sys="You are $mid, a local AI model served via llama.cpp, tested from the Odysseus dashboard. Be truthful about your identity. Answer the user directly and helpfully in the language of their message - do not think out loud or show any reasoning."
          $usr=$cp
        } else {
          $sys="You are $mid, a local AI model served via llama.cpp and tested from the Odysseus dashboard. Speak in the first person, be truthful about your identity, and never claim to be a different model. Answer immediately and directly - do not think out loud, deliberate, plan, or show any reasoning, drafts, headings or word counts. Output only the finished introduction."
          $usr="Give a detailed, first-person self-introduction in $lang. In about 6 sentences total, cover concretely and in flowing prose: who you are and your model family; what you can genuinely do, with your real strengths and capabilities; and the kinds of tasks you are best suited for and why. Be substantial but do not write a novel, do not pad, and do not list constraints. Write the whole introduction between the markers <<INTRO>> and <</INTRO>> and put nothing else between them."
        }
        $body=@{ messages=@(@{role='system';content=$sys},@{role='user';content=$usr}); max_tokens=1536; chat_template_kwargs=@{ enable_thinking=$false } } | ConvertTo-Json -Depth 6
        $sw=[System.Diagnostics.Stopwatch]::StartNew()
        $r=Invoke-RestMethod -Uri 'http://127.0.0.1:8000/v1/chat/completions' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 150
        $sw.Stop(); $mm=$r.choices[0].message; $msg=("$($mm.content)").Trim(); if(-not $msg){ $msg=("$($mm.reasoning_content)").Trim() }
        $msg=[regex]::Replace($msg,'(?is)<think>.*?</think>','').Trim()
        if(-not $cp){   # les marqueurs <<INTRO>> n'existent que pour la presentation auto
          $mk=[regex]::Matches($msg,'(?is)<<INTRO>>(.*?)<</INTRO>>')
          if($mk.Count -gt 0){ $msg=$mk[$mk.Count-1].Groups[1].Value.Trim() } elseif($msg -match '(?is)<<INTRO>>(.*)$'){ $msg=$Matches[1].Trim() }
          $msg=[regex]::Replace($msg,'(?is)<+\s*/?\s*INTRO\s*>+','').Trim()
        }
        $tps=[math]::Round([double]$r.timings.predicted_per_second,1)
        if(-not $msg){ $S.testOut='__TEST_EMPTY__' } else {
          $S.testOut="$msg`r`n`r`n[$mid - $tps tok/s - $([math]::Round($sw.Elapsed.TotalSeconds,1))s]"
          # meta structuree -> garage / sparkline cote JS
          $S.testSeq=[int]$S.testSeq+1
          try{ $S.testMeta=(@{ tps=$tps; pps=[math]::Round([double]$r.timings.prompt_per_second,0); n=[int]$r.timings.predicted_n
            secs=[math]::Round($sw.Elapsed.TotalSeconds,1); model=$mid; seq=[int]$S.testSeq } | ConvertTo-Json -Compress) }catch{}
        }
      }catch{ $S.testOut='__TEST_NOSERVER__' }
      $S.testBusy=$false }
    Start-Sleep -Milliseconds 600
  }
})
[void]$pollPs.BeginInvoke()

# runspace DEDIE aux logs llama (independant du poll -> jamais bloque par un test 150s, tail temps-reel ~300ms)
$logRs=[runspacefactory]::CreateRunspace(); $logRs.ApartmentState='MTA'; $logRs.ThreadOptions='ReuseThread'; $logRs.Open()
$logRs.SessionStateProxy.SetVariable('S',$S)
$logPs=[powershell]::Create(); $logPs.Runspace=$logRs
[void]$logPs.AddScript({
  function _readShared($path,$maxBytes){ if(-not $path -or -not (Test-Path -LiteralPath $path)){ return '' }
    try{ $fs=[System.IO.File]::Open($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
      try{ if($fs.Length -gt $maxBytes){ [void]$fs.Seek(-$maxBytes,[System.IO.SeekOrigin]::End) }; $sr=New-Object System.IO.StreamReader($fs); $t=$sr.ReadToEnd(); $sr.Close(); return $t } finally { $fs.Dispose() } }catch{ return '' } }
  function _tailLog{ $t=_readShared $S.llmLogFile 24000; if(-not ([string]$t).Trim()){ $t=_readShared $S.errLogFile 24000 }; if(-not ([string]$t).Trim()){ $t=_readShared $S.outLogFile 24000 }
    $lines=@(($t -split "\r?\n") | Where-Object { $_.Trim() -ne '' }); if($lines.Count -gt 160){ $lines=$lines[($lines.Count-160)..($lines.Count-1)] }; return ($lines -join "`n") }
  while($S.run){ try{ $S.llmLog = _tailLog }catch{}; Start-Sleep -Milliseconds 300 }
})
[void]$logPs.BeginInvoke()

# runspace DEDIE check/update llama-server (Update-LlamaServer.ps1 partage avec Aether) :
# un download de ~260 Mo ne doit bloquer ni le poll ni les logs. Process externe -> l'exe hote ne risque rien.
$updRs=[runspacefactory]::CreateRunspace(); $updRs.ApartmentState='MTA'; $updRs.ThreadOptions='ReuseThread'; $updRs.Open()
$updRs.SessionStateProxy.SetVariable('S',$S)
$updPs=[powershell]::Create(); $updPs.Runspace=$updRs
[void]$updPs.AddScript({
  while($S.run){
    if($S.llamaReq){
      $act=[string]$S.llamaReq; $S.llamaReq=''
      $S.llamaSeq=[int]$S.llamaSeq + 1   # rend chaque reponse unique -> le uiTimer la pousse meme si identique
      $sw = if($act -eq 'update'){'-Update'}else{'-Check'}
      try{
        $psi=New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName='powershell.exe'
        $psi.Arguments='-NoProfile -ExecutionPolicy Bypass -File "' + [string]$S.updScript + '" ' + $sw
        $psi.RedirectStandardOutput=$true; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
        $pr=[System.Diagnostics.Process]::Start($psi); $o=$pr.StandardOutput.ReadToEnd(); $pr.WaitForExit()
        $kv=@{}; foreach($ln in ($o -split "`r?`n")){ if($ln -match '^([A-Z_]+)=(.*)$'){ $kv[$Matches[1]]=$Matches[2].Trim() } }
        $state='error'
        switch([string]$kv['RESULT']){
          'CHECK_OK'   { if($kv['UPDATE_AVAILABLE'] -eq 'true'){ $state='available' } else { $state='uptodate' } }
          'UP_TO_DATE' { $state='uptodate' }
          'UPDATED'    { $state='updated' }
        }
        $S.llamaPush=(@{ state=$state; local=[string]$kv['LOCAL_BUILD']; remote=[string]$kv['REMOTE_BUILD']
          tag=[string]$kv['REMOTE_TAG']; wasRunning=([string]$kv['SERVER_WAS_RUNNING'] -eq 'True'); seq=[int]$S.llamaSeq } | ConvertTo-Json -Compress)
      }catch{ $S.llamaPush=(@{ state='error'; seq=[int]$S.llamaSeq } | ConvertTo-Json -Compress) }
    }
    Start-Sleep -Milliseconds 250
  }
})
[void]$updPs.BeginInvoke()

# runspace DEDIE telechargement GGUF (URL HuggingFace -> data\local) : progression via $S.dlState,
# annulable ($S.dlCancel), fichier .part renomme a la fin seulement (jamais de gguf corrompu visible).
$dlRs=[runspacefactory]::CreateRunspace(); $dlRs.ApartmentState='MTA'; $dlRs.ThreadOptions='ReuseThread'; $dlRs.Open()
$dlRs.SessionStateProxy.SetVariable('S',$S)
$dlPs=[powershell]::Create(); $dlPs.Runspace=$dlRs
[void]$dlPs.AddScript({
  try{ Add-Type -AssemblyName System.Net.Http }catch{}
  function _push($st,$extra){ $o=@{ state=$st; seq=[int]$S.dlSeq }; if($extra){ foreach($k in $extra.Keys){ $o[$k]=$extra[$k] } }; $S.dlState=($o | ConvertTo-Json -Compress) }
  while($S.run){
    if($S.dlReq){
      $url=[string]$S.dlReq; $S.dlReq=''; $S.dlCancel=$false; $S.dlSeq=[int]$S.dlSeq+1
      $name=''; $u=$null
      try{ $u=[Uri]$url; $name=[System.IO.Path]::GetFileName($u.AbsolutePath) }catch{}
      if(-not $u -or $u.Scheme -ne 'https' -or $name -notmatch '(?i)\.gguf$'){ _push 'badurl' $null }
      else{
        $dest=Join-Path 'C:\Odysseus\data\local' $name
        if(Test-Path -LiteralPath $dest){ _push 'exists' @{ name=$name } }
        else{
          $tmp="$dest.part"
          try{
            $hc=New-Object System.Net.Http.HttpClient
            $hc.Timeout=[System.Threading.Timeout]::InfiniteTimeSpan
            try{ $hc.DefaultRequestHeaders.UserAgent.ParseAdd('OdysseusDashboard/1.0') }catch{}
            $resp=$hc.GetAsync($url,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
            if(-not $resp.IsSuccessStatusCode){ throw ("HTTP " + [int]$resp.StatusCode) }
            $tot=[long]0; try{ if($resp.Content.Headers.ContentLength){ $tot=[long]$resp.Content.Headers.ContentLength } }catch{}
            $free=[long](Get-PSDrive C).Free
            if($tot -gt 0 -and $free -lt ($tot + 2GB)){ _push 'space' @{ name=$name }; $resp.Dispose(); $hc.Dispose() }
            else{
              $in=$resp.Content.ReadAsStreamAsync().Result
              $out=[System.IO.File]::Create($tmp)
              $buf=New-Object byte[] (1MB); $done=[long]0
              $swd=[System.Diagnostics.Stopwatch]::StartNew(); $lastMs=0.0; $lastB=[long]0
              _push 'dl' @{ name=$name; pct=0; mb=0; mbTot=[math]::Round($tot/1MB,0); mbps=0 }
              while($true){
                if($S.dlCancel){ break }
                $n=$in.Read($buf,0,$buf.Length); if($n -le 0){ break }
                $out.Write($buf,0,$n); $done+=$n
                $ms=$swd.Elapsed.TotalMilliseconds
                if(($ms-$lastMs) -gt 450){
                  $mbps=[math]::Round((($done-$lastB)/1MB)/(($ms-$lastMs)/1000.0),1); $lastMs=$ms; $lastB=$done
                  $pct = if($tot -gt 0){ [math]::Round($done*100.0/$tot,1) } else { -1 }
                  _push 'dl' @{ name=$name; pct=$pct; mb=[math]::Round($done/1MB,0); mbTot=[math]::Round($tot/1MB,0); mbps=$mbps }
                }
              }
              $out.Close(); try{ $in.Dispose(); $resp.Dispose(); $hc.Dispose() }catch{}
              if($S.dlCancel){ try{ Remove-Item -LiteralPath $tmp -Force }catch{}; _push 'cancelled' @{ name=$name } }
              elseif($tot -gt 0 -and $done -lt $tot){ try{ Remove-Item -LiteralPath $tmp -Force }catch{}; _push 'neterr' @{ name=$name } }
              else{ Move-Item -Force -LiteralPath $tmp -Destination $dest; _push 'done' @{ name=$name; mb=[math]::Round($done/1MB,0) } }
            }
          }catch{ try{ if(Test-Path -LiteralPath $tmp){ Remove-Item -LiteralPath $tmp -Force } }catch{}; _push 'neterr' @{ name=$name } }
        }
      }
    }
    Start-Sleep -Milliseconds 250
  }
})
[void]$dlPs.BeginInvoke()

# push PS -> JS
$script:wvReady=$false
$script:lastTest=''
$script:lastLog=''
$script:lastLlama=''
$script:lastMeta=''
$script:lastDl=''
function JsCall($js){ if($script:wvReady -and $script:core){ try{ [void]$script:core.ExecuteScriptAsync($js) }catch{} } }
function Push-Init{
  $arr=@(); foreach($m in $models){ $fam=Get-Family $m.Name; $p=$PRESETS[$fam]; if(-not $p){$p=$PRESETS['Defaut']}
    $arr += @{ name=$m.Name; path=$m.Path; size=[long]$m.Size; family=$fam; note=$p.note; t=$p.t; p=$p.p; k=$p.k; mp=$p.mp; rp=$p.rp; ctx=(Get-DefaultCtx $m.Name) } }
  $j=@{ models=$arr; exe=$EXE } | ConvertTo-Json -Depth 6 -Compress
  DLog "push-init: $($arr.Count) modeles vers le HTML (wvReady=$($script:wvReady))"
  JsCall ("window.dashInit && window.dashInit($j)")
  Push-CustomThemes
}
# ---- Themes custom PARTAGES avec Odysseus (data/user_prefs.json, meme format) ----
function _PrefsFirstUser($p){ if($p -and $p._users){ return ($p._users.PSObject.Properties.Name | Select-Object -First 1) }; return $null }
function Read-CustomThemes{
  try{ $p=Get-Content $PREFS -Raw -EA Stop | ConvertFrom-Json; $u=_PrefsFirstUser $p
    if($u){ $uo=$p._users.$u; if($uo.PSObject.Properties['custom-themes']){ return $uo.'custom-themes' } } }catch{}
  return ([PSCustomObject]@{}) }
function Write-CustomTheme($name,$colors,$del){
  try{
    if(Test-Path $PREFS){ $p=Get-Content $PREFS -Raw | ConvertFrom-Json } else { $p=[PSCustomObject]@{} }
    if(-not $p.PSObject.Properties['_users']){ $p | Add-Member -NotePropertyName '_users' -NotePropertyValue ([PSCustomObject]@{}) -Force }
    $u=_PrefsFirstUser $p; if(-not $u){ $u='palpatinerex'; $p._users | Add-Member -NotePropertyName $u -NotePropertyValue ([PSCustomObject]@{}) -Force }
    $uo=$p._users.$u
    if(-not $uo.PSObject.Properties['custom-themes']){ $uo | Add-Member -NotePropertyName 'custom-themes' -NotePropertyValue ([PSCustomObject]@{}) -Force }
    $ct=$uo.'custom-themes'
    if($ct.PSObject.Properties["$name"]){ $ct.PSObject.Properties.Remove("$name") }
    if(-not $del){ $e=[PSCustomObject]@{ bg=[string]$colors.bg; fg=[string]$colors.fg; panel=[string]$colors.panel; border=[string]$colors.border; red=[string]$colors.red }; if($colors.bgPattern -and $colors.bgPattern -ne 'none'){ $e | Add-Member -NotePropertyName 'bgPattern' -NotePropertyValue ([string]$colors.bgPattern) -Force }; if($null -ne $colors.bgEffectIntensity -and [double]$colors.bgEffectIntensity -ne 1){ $e | Add-Member -NotePropertyName 'bgEffectIntensity' -NotePropertyValue ([double]$colors.bgEffectIntensity) -Force }; if($null -ne $colors.bgEffectSpeed -and [double]$colors.bgEffectSpeed -ne 1){ $e | Add-Member -NotePropertyName 'bgEffectSpeed' -NotePropertyValue ([double]$colors.bgEffectSpeed) -Force }; $ct | Add-Member -NotePropertyName "$name" -NotePropertyValue $e -Force }
    $tmp="$PREFS.dashtmp"; ($p | ConvertTo-Json -Depth 12) | Set-Content -Path $tmp -Encoding UTF8; Move-Item -Force -LiteralPath $tmp -Destination $PREFS
    return $true
  }catch{ DLog ("theme write err: " + $_.Exception.Message); return $false } }
function Push-CustomThemes{
  $ct = Read-CustomThemes
  $j = @{ themes=$ct } | ConvertTo-Json -Depth 8 -Compress
  JsCall ("window.dashCustomThemes && window.dashCustomThemes($j)") }

# ---- Form + barre de titre + WebView2 plein ecran ----
$form = New-Object OdyForm
$form.Text = 'Odysseus Dashboard'
$form.MinimumSize = New-Object System.Drawing.Size(300, 400)
# --- restaure taille+position de la derniere session ; sinon centre sur l'ecran PRINCIPAL ---
$script:applyMax = $false
$geoOK = $false
try {
  if (Test-Path $GEO) {
    $geo = Get-Content $GEO -Raw -EA Stop | ConvertFrom-Json
    $gx=[int]$geo.x; $gy=[int]$geo.y; $gw=[int]$geo.w; $gh=[int]$geo.h
    if ($gw -ge 200 -and $gh -ge 200) {
      $rect = New-Object System.Drawing.Rectangle($gx,$gy,$gw,$gh)
      foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) { if ($scr.WorkingArea.IntersectsWith($rect)) { $geoOK = $true; break } }
      if ($geoOK) {
        $form.StartPosition = 'Manual'
        $form.Size     = New-Object System.Drawing.Size($gw, $gh)
        $form.Location = New-Object System.Drawing.Point($gx, $gy)
        if ($geo.max) { $script:applyMax = $true }
      }
    }
  }
} catch { $geoOK = $false }
if (-not $geoOK) {
  $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $dw = [Math]::Min(1120, [Math]::Max(820, $wa.Width  - 40))
  $dh = [Math]::Min(920,  [Math]::Max(640, $wa.Height - 40))
  $form.StartPosition = 'Manual'
  $form.Size     = New-Object System.Drawing.Size($dw, $dh)
  $form.Location = New-Object System.Drawing.Point(($wa.X + [int](($wa.Width-$dw)/2)), ($wa.Y + [int](($wa.Height-$dh)/2)))
}
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#0a0a0f')
try { $form.Icon = New-Object System.Drawing.Icon('C:\Odysseus\odysseus.ico') } catch {}

$g = 6
# Plus de barre WinForms : la barre de titre vit dans le HTML (.topbar). Les boutons fenetre (min/max/close)
# + le drag passent par postMessage -> voir les cas 'win' / 'drag' du WebMessageReceived plus bas.
# WebView2 remplit donc TOUTE la fenetre (moins la bordure de redimensionnement $g) = plus de double-barre.
$host2 = New-Object System.Windows.Forms.Panel
$host2.Location = New-Object System.Drawing.Point($g, $g)
$host2.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 2*$g), ($form.ClientSize.Height - 2*$g))
$host2.Anchor = 'Top,Bottom,Left,Right'
$form.Controls.Add($host2)

$script:wv = $null; $script:core = $null
if ($script:wvOK) {
  try {
    $wv = New-Object Microsoft.Web.WebView2.WinForms.WebView2
    $wv.Dock = 'Fill'; $host2.Controls.Add($wv)
    $wv.add_CoreWebView2InitializationCompleted({ param($s,$e)
      DLog "init IsSuccess=$($e.IsSuccess) $(if(-not $e.IsSuccess){ $e.InitializationException.Message })"
      if ($e.IsSuccess) {
        $script:core = $wv.CoreWebView2
        try { $wv.DefaultBackgroundColor = [System.Drawing.ColorTranslator]::FromHtml('#0a0a0f') } catch {}
        try { $script:core.SetVirtualHostNameToFolderMapping('odyfx.local', $STATIC, [Microsoft.Web.WebView2.Core.CoreWebView2HostResourceAccessKind]::Allow) } catch {}
        $script:core.add_NavigationCompleted({ param($a,$b) $script:wvReady = $true; DLog "nav done"; Push-Init })
        # messages venant du HTML (actions, theme) -> a cabler au backend ensuite
        $script:core.add_WebMessageReceived({ param($a,$b) try {
          $msg = $b.TryGetWebMessageAsString() | ConvertFrom-Json
          switch ($msg.type) {
            'ready' { Push-Init }
            'win' {
              switch ([string]$msg.action) {
                'minimize' { $form.WindowState = 'Minimized' }
                'maximize' { if ($form.WindowState -eq 'Maximized') { $form.WindowState = 'Normal' } else { $form.WindowState = 'Maximized' } }
                'close'    { $form.Close() }
              }
            }
            'drag' { [WinDrag]::ReleaseCapture() | Out-Null; [void][WinDrag]::SendMessage($form.Handle, 0xA1, 0x2, 0) }
            'launch' {
              $aa = @('-m',[string]$msg.path,'-ngl',[string][int]$msg.ngl,'-c',[string][int]$msg.ctx,
                '--temp',[string]$msg.temp,'--top-p',[string]$msg.topp,'--top-k',[string][int]$msg.topk,
                '--min-p',[string]$msg.minp,'--repeat-penalty',[string]$msg.rep,'--host','0.0.0.0','--port',[string][int]$msg.port)
              if ($msg.fast) { $aa += @('--jinja','--reasoning','off') }
              # Auto-offload gros MoE : un modele > 10 Go ne tient pas en VRAM 12 Go -> experts en RAM (--cpu-moe), le reste sur GPU.
              # + --no-mmap seulement si la RAM est large (plus rapide) -> s'activera tout seul apres l'upgrade 64 Go.
              try { $mf = Get-Item -LiteralPath ([string]$msg.path) -EA Stop
                if ($mf.Length -gt 10GB) { $aa += '--cpu-moe'
                  $freeGB = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB / 1GB
                  if ($freeGB -gt ($mf.Length/1GB + 4)) { $aa += '--no-mmap'; DLog 'auto: --cpu-moe + --no-mmap (RAM large)' } else { DLog 'auto: --cpu-moe (mmap, RAM juste)' } } } catch {}
              try{ Stop-Process -Name 'llama-server' -Force -EA SilentlyContinue }catch{}
              Start-Sleep -Milliseconds 800
              try{ '' | Set-Content -LiteralPath $LLMLOG -EA SilentlyContinue; '' | Set-Content -LiteralPath $OUTLOG -EA SilentlyContinue; '' | Set-Content -LiteralPath $ERRLOG -EA SilentlyContinue }catch{}
              $aa += @('--log-file',$LLMLOG,'--log-colors','off','--log-timestamps')
              try{ Start-Process -FilePath $EXE -ArgumentList $aa -WindowStyle Hidden -RedirectStandardOutput $OUTLOG -RedirectStandardError $ERRLOG; DLog "launched (hidden+logfile)" }catch{ DLog ("launch err: " + $_.Exception.Message) }
            }
            'stop' { try{ Stop-Process -Name 'llama-server' -Force -EA SilentlyContinue }catch{}; DLog "stopped" }
            'test' { $S.testLang = [string]$msg.lang; $S.testPrompt = [string]$msg.prompt; $S.testReq = $true }
            'dl'   { if([string]$msg.act -eq 'cancel'){ $S.dlCancel = $true } elseif([string]$msg.url){ $S.dlReq = [string]$msg.url } }
            'llama' { $S.llamaReq = [string]$msg.act }   # check / update -> traite par le runspace updater
            'savetheme' { if(Write-CustomTheme ([string]$msg.name) $msg.colors $false){ Push-CustomThemes } }
            'deltheme'  { if(Write-CustomTheme ([string]$msg.name) $null $true){ Push-CustomThemes } }
            'ody'  { switch ($msg.act) {
              'start'  { Start-Process -FilePath (Join-Path $ODYDIR 'Odysseus.bat') -WorkingDirectory $ODYDIR }
              'stop'   { Start-Process -FilePath (Join-Path $ODYDIR 'Odysseus-Stop.bat') -WorkingDirectory $ODYDIR }
              'update' { if ([System.Windows.Forms.MessageBox]::Show('Update: stop the stack, git pull, then rebuild. Continue?','Update Odysseus',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning) -eq 'Yes') { Start-Process -FilePath (Join-Path $ODYDIR 'Odysseus-Update.bat') -WorkingDirectory $ODYDIR } }
              'open'   { Start-Process 'http://localhost:7000' }
            } }
          }
        } catch { DLog "msg err: $($_.Exception.Message)" } })
        $script:core.Navigate("https://odyfx.local/dashboard.html?v=$([DateTime]::Now.Ticks)"); DLog "navigate sent"
      }
    })
    DLog "creating env udf=$UDF"
    try { Remove-Item -Recurse -Force (Join-Path $UDF 'EBWebView\Default\Cache') -EA SilentlyContinue } catch {}
    try { Remove-Item -Recurse -Force (Join-Path $UDF 'EBWebView\Default\Code Cache') -EA SilentlyContinue } catch {}
    $envT = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($null, $UDF, $null)
    $envT.Wait()
    DLog "env ok; ensure"
    $null = $wv.EnsureCoreWebView2Async($envT.Result)
  } catch { DLog "WV CATCH: $($_.Exception.Message)" }
}

# Timer UI : pousse le statut (poll) vers le HTML — zero I/O sur le thread UI
$uiTimer = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 600
$uiTimer.add_Tick({
  if (-not $script:wvReady) { return }
  $payload = @{ ody=[string]$S.ody; odyUp=[bool]$S.odyUp; llm=[string]$S.llm; llmUp=[bool]$S.llmUp; vramU=[int]$S.vramU; vramT=[int]$S.vramT; gpuT=[int]$S.gpuT } | ConvertTo-Json -Compress
  JsCall ("window.dashStatus && window.dashStatus($payload)")
  if ($S.testOut -ne $script:lastTest) {
    $script:lastTest = $S.testOut
    $tj = @{ test=[string]$S.testOut } | ConvertTo-Json -Compress
    JsCall ("window.dashTest && window.dashTest($tj)")
  }
  if ($S.testMeta -and $S.testMeta -ne $script:lastMeta) {
    $script:lastMeta = $S.testMeta
    JsCall ("window.dashTestMeta && window.dashTestMeta($($S.testMeta))")
  }
  if ($S.dlState -and $S.dlState -ne $script:lastDl) {
    $script:lastDl = $S.dlState
    JsCall ("window.dashDl && window.dashDl($($S.dlState))")
    if ($S.dlState -match '"state":"done"') { try { $script:models=@(Scan-Models); Push-Init } catch {} }
  }
  if ($S.llmLog -ne $script:lastLog) {
    $script:lastLog = $S.llmLog
    $lj = @{ log=[string]$S.llmLog } | ConvertTo-Json -Compress
    JsCall ("window.dashLog && window.dashLog($lj)")
  }
  if ($S.llamaPush -and $S.llamaPush -ne $script:lastLlama) {
    $script:lastLlama = $S.llamaPush
    JsCall ("window.dashLlama && window.dashLlama($($S.llamaPush))")
  }
})
$uiTimer.Start()
$form.add_FormClosing({
  try {
    $st = [string]$form.WindowState
    $rb = if ($st -eq 'Normal') { $form.Bounds } else { $form.RestoreBounds }
    @{ x=$rb.X; y=$rb.Y; w=$rb.Width; h=$rb.Height; max=($st -eq 'Maximized') } | ConvertTo-Json -Compress | Set-Content -Path $GEO -Encoding UTF8
  } catch {}
  $S.run = $false; try { $uiTimer.Stop() } catch {}
})

if ($script:applyMax) { [void]$form.add_Shown({ try { $form.WindowState = 'Maximized' } catch {} }) }
[System.Windows.Forms.Application]::EnableVisualStyles()
[void]$form.ShowDialog()
$S.run = $false
try { Start-Sleep -Milliseconds 250; $pollPs.Dispose(); $pollRs.Close() } catch {}
try { $logPs.Dispose(); $logRs.Close() } catch {}
try { $updPs.Dispose(); $updRs.Close() } catch {}
try { $dlPs.Dispose(); $dlRs.Close() } catch {}
