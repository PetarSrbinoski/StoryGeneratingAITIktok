# AI Story Video Generator (Windows)

Generates vertical TikTok-style videos from AI-written stories.
Runs fully locally using Ollama, Piper, and FFmpeg.

---

## Requirements

- Windows 10 / 11
- Ollama (installed and running)
- FFmpeg (available in PATH)
- Piper TTS with at least one .onnx voice model

Tested model:
- qwen2.5:7b-instruct

---

## Folder Structure (example)

C:\creator
├─ make-video.ps1
├─ in\background.mp4
├─ out\videos
├─ temp
└─ bin\piper\piper.exe + voice.onnx

---

## One-Time Setup

Start Ollama:
ollama serve

Verify model exists:
ollama list

---

## Run (Basic)

cd /d C:\creator
powershell -ExecutionPolicy Bypass -File .\make-video.ps1 `
  -Model "qwen2.5:7b-instruct"

---

## Run with Custom Model

cd /d C:\creator
powershell -ExecutionPolicy Bypass -File .\make-video.ps1 `
  -Model "phi3:mini"

---

## Run with Custom Prompt (Story Theme)
   powershell -ExecutionPolicy Bypass -File .\make-video.ps1 `
  -Model "qwen2.5:7b-instruct" `
  -Prompt "A small town where everyone wakes up at 3:17 AM every night"

---

## Run with Custom Prompt + Background + Voice
```powershell -ExecutionPolicy Bypass -File .\make-video.ps1 `
  -Model "qwen2.5:7b-instruct" `
  -Prompt "An abandoned hospital with a locked basement floor" `
  -Background "C:\creator\in\background.mp4" `
  -Voice "C:\creator\bin\piper\voice.onnx"```

---

## Optional Flags

-ShowGPU        Show GPU usage (nvidia-smi)
-ForceGPU       Force Ollama GPU offload
-StopOllama     Stop Ollama after finishing

---

## Output

Final videos are saved to:
C:\creator\out\videos\final-XXX.mp4
