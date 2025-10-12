# Local AI Horror Video Generator (Windows, PowerShell)

Generate short vertical videos entirely offline:
- AI-written stories via **Ollama**
- Narration via **Piper TTS**
- Subtitles and render via **FFmpeg**
- GPU acceleration (NVENC and Ollama GPU offload)

Final videos are saved to `C:\creator\out\videos`.

---

## Folder Structure

C:\creator\
├─ make-video.ps1
├─ in\
│  └─ background.mp4
├─ bin\
│  └─ piper\piper.exe
├─ voices\
│  └─ en_US-ryan-high\
│     ├─ en_US-ryan-high.onnx
│     └─ en_US-ryan-high.onnx.json
└─ out\
   ├─ videos\                 # final-XXX.mp4
   ├─ story_XXX.txt/.json     # generated story
   ├─ captions-XXX.srt        # subtitles
   ├─ voice-XXX.wav           # narration
   └─ ollama_raw*.txt         # raw model responses

Create missing folders:
powershell
New-Item -Force -ItemType Directory -Path C:\creator\in,C:\creator\bin\piper,C:\creator\voices,C:\creator\out\videos | Out-Null

---

## Requirements

1) Windows 10/11 with PowerShell 5.1+
2) NVIDIA GPU and drivers (recommended)
3) FFmpeg in PATH
   - Download a static build (e.g., Gyan.dev), unzip, add its `bin` to PATH
4) Ollama
   - Install:
     winget install Ollama.Ollama
5) Piper (prebuilt Windows binary)
   - Download `piper_windows_amd64.zip` from:
     https://github.com/rhasspy/piper/releases
   - Extract to:
     C:\creator\bin\piper
6) Piper voice model (example: Ryan, US male)
   - Place in:
     C:\creator\voices\en_US-ryan-high\
     Files required:
       en_US-ryan-high.onnx
       en_US-ryan-high.onnx.json

---

## Pull Models (Ollama)

Recommended:
- llama3.1:8b  (faster)
- mixtral:8x7b (default in script, stronger)

powershell
ollama pull llama3.1:8b
ollama pull mixtral:8x7b

---

## Background Video

Place your background clip at:
C:\creator\in\background.mp4

Any 16:9 or 9:16 source works. The script scales/crops to 1080x1920.

---

## Usage

Run (default model: mixtral:8x7b):
powershell
powershell -ExecutionPolicy Bypass -File C:\creator\make-video.ps1

Options:
- Model         Choose Ollama model (e.g., "llama3.1:8b" or "mixtral:8x7b")
- Voice         Path to Piper voice .onnx
- Prompt        Custom seed/theme text appended to the internal prompt
- ShowGPU       Opens a live nvidia-smi window during generation
- StopOllama    Stops all Ollama processes when finished
- ForceGPU      Force GPU offload for Ollama (default: on). Disable with -ForceGPU:$false

Examples:
powershell
### Faster run with smaller model
powershell -ExecutionPolicy Bypass -File C:\creator\make-video.ps1 -Model "llama3.1:8b"

### Use a different voice
powershell -ExecutionPolicy Bypass -File C:\creator\make-video.ps1 -Voice "C:\creator\voices\en_US-amy-high\en_US-amy-high.onnx"

### Provide a custom theme
powershell
powershell -ExecutionPolicy Bypass -File C:\creator\make-video.ps1 -Prompt "put your prompt here."

Output files:
- Final video: C:\creator\out\videos\final-XXX.mp4
- Story/Captions/Audio: C:\creator\out\

---

## GPU Acceleration

The script starts Ollama (if needed) and, by default, sets:
OLLAMA_NUM_GPU=999

Verify GPU usage:
powershell
nvidia-smi

You should see `ollama` and `ffmpeg` listed during generation/render.

---

## License Notes

This setup is for local/personal use. Dependencies retain their original licenses:
- Ollama (Apache 2.0)
- Piper (MIT)
- FFmpeg (LGPL/GPL depending on build)

---
## 🧑‍💻 Author

**Petar Srbinoski**  
Faculty of Computer Science and Engineering (FINKI), UKIM  
petar.srbinoski@gmail.com