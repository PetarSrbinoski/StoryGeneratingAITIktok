param(
  [string]$Background = "C:\creator\in\background.mp4",
  [string]$Model      = "mixtral:8x7b",
  [string]$Voice      = "C:\creator\voices\en_US-ryan-high\en_US-ryan-high.onnx",
  [string]$Prompt     = $null,
  [switch]$ForceGPU = $true,
  [switch]$ShowGPU  = $false,
  [switch]$StopOllama = $false
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$UTF8 = [System.Text.Encoding]::UTF8

$root   = "C:\creator"
$outDir = Join-Path $root "out"
$temp   = Join-Path $root "temp"
$piper  = "C:\creator\bin\piper\piper.exe"

# Create main folders
New-Item -Force -ItemType Directory -Path $outDir,$temp | Out-Null

# Dedicated folder for final videos
$videosDir = Join-Path $outDir "videos"
if (-not (Test-Path $videosDir)) {
  New-Item -Force -ItemType Directory -Path $videosDir | Out-Null
}

function Get-JsonValue([object]$obj, [string]$name, [string]$fallback) {
  if ($null -eq $obj) { return $fallback }
  $prop = $obj.PSObject.Properties[$name]
  if ($null -ne $prop -and $null -ne $prop.Value -and -not [string]::IsNullOrWhiteSpace("$($prop.Value)")) {
    return "$($prop.Value)"
  }
  return $fallback
}

function Get-NextIndex([string]$dir) {
  $files = Get-ChildItem -Path $dir -Filter 'final-*.mp4' -ErrorAction SilentlyContinue
  if (-not $files) { return 1 }
  $nums = @()
  foreach ($f in $files) {
    if ($f.BaseName -match 'final-(\d{3})') { $nums += [int]$matches[1] }
  }
  if (-not $nums -or $nums.Count -eq 0) { return 1 }
  $max = ($nums | Measure-Object -Maximum).Maximum
  return ([int]$max) + 1
}

function Start-OllamaBackground {
  param([switch]$ForceGPU)

  $portOk = $false
  try { $portOk = (Test-NetConnection -ComputerName localhost -Port 11434 -WarningAction SilentlyContinue).TcpTestSucceeded } catch {}

  if ($portOk) {
    Write-Host "Ollama already running on http://localhost:11434"
    return
  }

  $envForProc = @{}
  if ($ForceGPU.IsPresent) {
    $env:OLLAMA_NUM_GPU = "999"
    $envForProc["OLLAMA_NUM_GPU"] = "999"
    Write-Host "Forcing GPU offload: OLLAMA_NUM_GPU=999"
  } else {
    Write-Host "Starting Ollama without explicit GPU forcing."
  }

  try {
    Start-Process -WindowStyle Hidden -FilePath "ollama" -ArgumentList "serve" -Env $envForProc | Out-Null
    Start-Sleep 2
    $portOk = (Test-NetConnection -ComputerName localhost -Port 11434 -WarningAction SilentlyContinue).TcpTestSucceeded
    if ($portOk) {
      Write-Host "✅ Ollama server started."
    } else {
      Write-Warning "Ollama did not open port 11434 yet. It may still be starting."
    }
  } catch {
    throw "Failed to start Ollama: $($_.Exception.Message)"
  }
}

function Stop-OllamaAll {
  Write-Host "Stopping all Ollama processes..."
  Get-Process -Name ollama -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue; Write-Host "Stopped PID $($_.Id)" } catch {}
  }
}

Start-OllamaBackground -ForceGPU:$ForceGPU

$gpuMonProc = $null
if ($ShowGPU) {
  try {
    $gpuMonProc = Start-Process -PassThru -WindowStyle Normal -FilePath "cmd.exe" -ArgumentList "/c nvidia-smi -l 1"
    Write-Host "Opened live GPU monitor (nvidia-smi). It will close after render."
  } catch {
    Write-Warning "Could not open nvidia-smi. Is NVIDIA driver installed and on PATH?"
  }
}

if ([string]::IsNullOrWhiteSpace($Prompt)) {
  $prompt = @"
Write a really good and engaging short horror/mystery story in first person that will keep the reader engaged. Around 300-400 words. Make it tense and make the reader feel uneasy. For the ending either make it open to interpretation or finish it really scary and strong.

OUTPUT FORMAT:
Return ONLY valid JSON in this exact structure:
{
  "title": "5-8 word cinematic title",
  "story": "Full, coherent story text (180–250 words, following all style rules)",
  "hashtags": "#storytime #writing #shortstory #cinematic #fyp"
}
"@
} else {
  $prompt = $Prompt + @"
SYSTEM: Reply with JSON only. One coherent cinematic horror story with strong hook and satisfying/twist ending.
TARGET: 180-250 words (~2 minutes). No emojis/hashtags in the story text.
Return JSON:
{
  "title": "...",
  "story": "...",
  "hashtags": "#storytime #writing #shortstory #cinematic #fyp"
}
"@
}

function Invoke-Ollama([hashtable]$body) {
  $json  = ($body | ConvertTo-Json -Depth 10)
  $bytes = $UTF8.GetBytes($json)
  $resp  = Invoke-WebRequest -Uri "http://localhost:11434/api/generate" -Method Post -Body $bytes -ContentType "application/json; charset=utf-8"
  return $resp.Content
}

$idx = Get-NextIndex $videosDir
$tag = ('{0:000}' -f $idx)
$raw1 = Join-Path $outDir ("ollama_raw1_{0}.txt" -f $tag)
$raw2 = Join-Path $outDir ("ollama_raw2_{0}.txt" -f $tag)

$jsonText = $null
$fallbackText = $null
try {
  $content1 = Invoke-Ollama @{
    model=$Model; prompt=$prompt; stream=$false; format="json";
    options=@{ temperature=0.62; top_p=0.9; repeat_penalty=1.12; mirostat=0 }
  }
  $content1 | Set-Content -Encoding UTF8 -Path $raw1
  $o1 = $content1 | ConvertFrom-Json
  if ($null -ne $o1.response) { $jsonText = $o1.response }
} catch { Write-Warning "format=json failed; trying plain text and extracting JSON." }

if (-not $jsonText) {
  $content2 = Invoke-Ollama @{
    model=$Model; prompt=$prompt; stream=$false;
    options=@{ temperature=0.62; top_p=0.9; repeat_penalty=1.12; mirostat=0 }
  }
  $content2 | Set-Content -Encoding UTF8 -Path $raw2
  $o2  = $content2 | ConvertFrom-Json
  $txt = [string]$o2.response
  $m   = [regex]::Match($txt, '\{(?:[^{}]|(?<o>\{)|(?<-o>\}))+(?(o)(?!))\}')
  if ($m.Success) { $jsonText = $m.Value } else { $fallbackText = $txt }
}

function Build-FromText([string]$txt) {
  $t = ($txt -replace '\s+', ' ').Trim()
  if ([string]::IsNullOrWhiteSpace($t)) {
    $t = 'The train doors part like a breath held too long. I step into brighter light but the air feels wrong. My name echoes—my own voice, older. I turn, heart pounding. The reflection in the window waits to speak.'
  }
  $first = ($t -split '[\.\!\?]' | Where-Object { $_ -and $_.Trim().Length -gt 0 } | Select-Object -First 1).Trim()
  if (-not $first) { $first = $t.Substring(0,[Math]::Min(40,$t.Length)) }
  $titleWords = ($first -split '\s+' | Select-Object -First 7) -join ' '
  [pscustomobject]@{ title=$titleWords; story=$t; hashtags='#storytime #writing #shortstory #cinematic #fyp' }
}

$storyObj = $null
if ($jsonText) { try { $storyObj = $jsonText | ConvertFrom-Json } catch { $storyObj = $null } }
if ($null -eq $storyObj -and $fallbackText) { $storyObj = Build-FromText $fallbackText }
if ($null -eq $storyObj) { throw "No usable response. See $raw1 / $raw2." }

$title    = Get-JsonValue $storyObj 'title'    'Untitled'
$story    = Get-JsonValue $storyObj 'story'    'I am speaking.'
$hashtags = Get-JsonValue $storyObj 'hashtags' '#storytime #writing #shortstory #cinematic #fyp'

$storyTxt  = Join-Path $outDir ("story_{0}.txt"    -f $tag)
$storyJson = Join-Path $outDir ("story_{0}.json"   -f $tag)
$capsSrt   = Join-Path $outDir ("captions-{0}.srt" -f $tag)
$voiceWav  = Join-Path $outDir ("voice-{0}.wav"    -f $tag)
$finalMp4  = Join-Path $videosDir ("final-{0}.mp4" -f $tag)

(@{title=$title; story=$story; hashtags=$hashtags} | ConvertTo-Json -Depth 6) | Set-Content -Encoding UTF8 -Path $storyJson
$story | Set-Content -Encoding UTF8 -Path $storyTxt

Write-Host "Index: $tag"
Write-Host "Title: $title"
Write-Host "Hashtags: $hashtags"
Write-Host "Voice: $Voice"
Write-Host "Model: $Model  (GPU forcing: $($ForceGPU.IsPresent))"

if (-not (Test-Path $piper)) { throw "piper.exe not found at $piper" }
$clean = [regex]::Replace((Get-Content $storyTxt -Raw), "\p{M}", "")
$clean | Set-Content -Encoding UTF8 -Path $storyTxt
Get-Content $storyTxt -Raw | & $piper -m $Voice --length_scale 1.05 --sentence_silence 0.45 -f $voiceWav
if (-not (Test-Path $voiceWav)) { throw "Piper did not produce $voiceWav" }

$procWav = Join-Path $outDir ("voice-processed-{0}.wav" -f $tag)
Remove-Item -Force -ErrorAction SilentlyContinue $procWav

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  Write-Warning "FFmpeg not found in PATH; skipping voice post-process."
  $audioToUse = $voiceWav
} else {
  function Run-FFMpeg([string]$argLine) {
    $p = Start-Process -FilePath ffmpeg -ArgumentList $argLine -NoNewWindow -Wait -PassThru `
         -RedirectStandardOutput "$env:TEMP\ffmpeg_out.log" -RedirectStandardError "$env:TEMP\ffmpeg_err.log"
    return $p.ExitCode
  }
  $rbArgs = '-y -hide_banner -loglevel error -i "' + $voiceWav + '" -af "rubberband=pitch=0.97,dynaudnorm=f=200:g=10" "' + $procWav + '"'
  $code = Run-FFMpeg $rbArgs
  if ($code -ne 0 -or -not (Test-Path $procWav)) {
    $audioToUse = $voiceWav
  } else {
    $audioToUse = $procWav
  }
}

function Get-AudioDurationSeconds([string]$path) {
  $d = & ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 -- "$path" 2>$null
  [double]::Parse($d, [Globalization.CultureInfo]::InvariantCulture)
}
$duration = Get-AudioDurationSeconds $audioToUse
if ($duration -lt 1) { $duration = 60 }

$words = ($story -replace "\s+", " ").Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
$total = $words.Length
if ($total -eq 0) { $words = @("..."); $total = 1 }

$spw = $duration / [double]$total
if ($spw -lt 0.18) { $spw = 0.18 }
if ($spw -gt 0.60) { $spw = 0.60 }

$chunkSize = 3
$chunks = @()
for ($i=0; $i -lt $total; $i += $chunkSize) {
  $end = [math]::Min($i+$chunkSize-1,$total-1)
  $chunks += ($words[$i..$end] -join " ")
}

function ToSrtTime($sec) {
  if ($sec -lt 0) { $sec = 0 }
  $ts = [TimeSpan]::FromSeconds($sec)
  ('{0:00}:{1:00}:{2:00},{3:000}' -f $ts.Hours,$ts.Minutes,$ts.Seconds,[int]$ts.Milliseconds)
}

$srt = New-Object System.Collections.Generic.List[string]
$t = 0.00
$minDur = 0.40
$maxDur = 1.50
for ($i=0; $i -lt $chunks.Count; $i++) {
  $text = $chunks[$i]
  $wcount = ($text -split '\s+').Count
  $dur = [double]$wcount * $spw
  if ($text -match '[\.\!\?]$') { $dur += 0.18 }
  elseif ($text -match '[,;:]$') { $dur += 0.10 }
  if ($dur -lt $minDur) { $dur = $minDur }
  if ($dur -gt $maxDur) { $dur = $maxDur }
  $start = $t
  $end   = $t + $dur
  if ($end -gt $duration - 0.01) { $end = $duration }
  if ($end -le $start) { $end = $start + 0.25 }
  $srt.Add(($i+1).ToString())
  $srt.Add("$(ToSrtTime $start) --> $(ToSrtTime $end)")
  $srt.Add($text)
  $srt.Add("")
  $t = $end
  if ($t -ge $duration) { break }
}
$srt | Set-Content -Encoding UTF8 -Path $capsSrt

if (-not (Test-Path $Background)) { throw "Missing background video: $Background" }
Push-Location $outDir

$subsUnix = ($capsSrt -replace '\\','/')
$subsEsc  = ($subsUnix -replace '^([A-Za-z]):', '$1\:/')
$style = "Alignment=2,Fontname=Comic Sans MS,Fontsize=22,PrimaryColour=&H00FFFFFF,OutlineColour=&H00008000,BorderStyle=1,Outline=1,Shadow=1,MarginV=60"
$vf = "scale='if(gte(a,9/16),-2,1080)':'if(gte(a,9/16),1920,-2)',crop=1080:1920,setsar=1,subtitles=filename='$subsEsc':force_style='$style'"

ffmpeg -y `
  -stream_loop -1 -i "$Background" `
  -i "$audioToUse" `
  -map 0:v:0 -map 1:a:0 `
  -shortest `
  -vf "$vf" `
  -c:v h264_nvenc -preset p4 -rc vbr -cq 21 -b:v 0 -tune hq -pix_fmt yuv420p `
  -c:a aac -b:a 192k -movflags +faststart `
  "$finalMp4"

Pop-Location

Write-Host "`nDONE! => $finalMp4"
Write-Host "Title: $title"
Write-Host "Hashtags: $hashtags"

if ($gpuMonProc -ne $null) {
  try { $gpuMonProc.CloseMainWindow() | Out-Null; Start-Sleep 1; if (!$gpuMonProc.HasExited) { $gpuMonProc.Kill() } } catch {}
}

if ($StopOllama) { Stop-OllamaAll }
