# AI Story Video Generator (TikTok-style)

This project generates vertical TikTok-style videos from AI-generated horror stories.
It uses:
- Ollama for text generation (local LLM)
- Piper for text-to-speech (local TTS)
- FFmpeg for audio/video processing

Everything runs locally on Windows.

---

## Requirements

### Operating System
- Windows 10 / 11

### Required Software

1) Ollama
   - Download: https://ollama.com
   - Must be installed and available in PATH
   - Tested with Ollama v0.14.2+

2) FFmpeg
   - Must be available in PATH
   - NVENC is supported and used automatically if available
   - Tested with ffmpeg 8.0 (gyan.dev build)

3) Piper (Text-to-Speech)
   - Download from: https://github.com/rhasspy/piper
   - Place `piper.exe` anywhere (example: C:\creator\bin\piper\piper.exe)
   - Download at least one `.onnx` voice model

---

## Verified Working Setup (Example)

This project was tested with:

- Ollama model: qwen2.5:7b-instruct
- Ollama path:
  C:\Users\petar\AppData\Local\Programs\Ollama\ollama.exe

- FFmpeg path:
  C:\Users\petar\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe

- Piper path:
  C:\creator\bin\piper\piper.exe

---

## Folder Structure

Example structure (recommended):

C:\creator
│
├─ make-video.ps1
│
├─ in
│   └─ background.mp4
│
├─ out
│   └─ videos
│
├─ temp
│
└─ bin
    └─ piper
        ├─ piper.exe
        ├─ voice.onnx
        └─ voice.onnx.json

---

## Before Running (One-Time Setup)

### 1) Verify tools in CMD

Open Command Prompt (CMD) and run:

where ollama
ollama --version
ollama list

where ffmpeg
ffmpeg -version

where piper
piper --help

All commands must work without errors.

---

### 2) Make sure the Ollama model exists

ollama list

You should see:

qwen2.5:7b-instruct

If not:

ollama pull qwen2.5:7b-instruct

---

### 3) Start Ollama server

In CMD:

ollama serve

Leave this window open.
(If Ollama is already running, this step can be skipped.)

Optional test:

curl http://localhost:11434/api/tags

---

## Running the Generator

### Basic Run (uses defaults)

cd /d C:\creator
powershell -ExecutionPolicy Bypass -File .\make-video.ps1 -Model "qwen2.5:7b-instruct"

---

### Run with GPU monitoring enabled

cd /d C:\creator
powershell -ExecutionPolicy Bypass -File .\make-video.ps1 ^
  -Model "qwen2.5:7b-instruct" ^
  -ShowGPU ^
  -ForceGPU

---

### Run with custom background and voice

cd /d C:\creator
powershell -ExecutionPolicy Bypass -File .\make-video.ps1 ^
  -Model "qwen2.5:7b-instruct" ^
  -Background "C:\creator\in\background.mp4" ^
  -Voice "C:\creator\bin\piper\voice.onnx"

---

### Run with a custom story theme

cd /d C:\creator
powershell -ExecutionPolicy Bypass -File .\make-video.ps1 ^
  -Model "qwen2.5:7b-instruct" ^
  -Prompt "A haunted village where nobody can sleep"

---

## Output

Generated files are saved to:

C:\creator\out\videos

Each run produces:
- final-XXX.mp4 (ready to upload)
- Intermediate files in temp\ for debugging

---

## Notes

- The script automatically:
  - Generates a horror story via Ollama
  - Converts text to speech via Piper
  - Generates subtitles
  - Renders a 1080x1920 vertical video
- If JSON output from the model is malformed, the script falls back safely.
- NVENC is used automatically if supported by your GPU.
- All processing is fully local (no cloud APIs).

---

## Troubleshooting

### Script blocked by execution policy

Run PowerShell as shown with:

-ExecutionPolicy Bypass

### Ollama not responding

Check:

curl http://localhost:11434/api/tags

If it fails, restart:

ollama serve

### Piper fails

Verify:
- .onnx model path is correct
- .json config exists next to the model

---

## License

Use freely. Modify as needed.
