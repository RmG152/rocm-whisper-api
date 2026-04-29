import whisper
import torch
import os
import traceback
import tempfile
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from app import __version__

# --------------------------------------------------------------------------
# 1. Model and device setup
# --------------------------------------------------------------------------

# Check if ROCm is available and set device
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Select Whisper model to use
MODEL_NAME = os.getenv("WHISPER_MODEL", "base")
model = None

# --------------------------------------------------------------------------
# 2. FastAPI application initialization and model loading
# --------------------------------------------------------------------------
app = FastAPI(
    title="ROCm Whisper API",
    description="An API to transcribe audio files using OpenAI's Whisper on ROCm.",
    version=__version__
)

@app.on_event("startup")
def load_whisper_model():
    """
    Load Whisper model when FastAPI app starts.
    """
    global model
    try:
        print("="*50)
        print(f"PyTorch version: {torch.__version__}")
        if hasattr(torch.version, 'hip'):
            print(f"Torch is built with ROCm: {torch.version.hip}")
        print(f"Is ROCm (GPU) available? -> {torch.cuda.is_available()}")
        if torch.cuda.is_available():
            print(f"Current device: {torch.cuda.current_device()}")
            print(f"Device name: {torch.cuda.get_device_name(0)}")
        print(f"Attempting to load Whisper model: '{MODEL_NAME}'")
        print("="*50)

        # Step 1: Load model onto CPU first
        print(f"Step 1: Loading model '{MODEL_NAME}' onto CPU...")
        cpu_model = whisper.load_model(MODEL_NAME, device="cpu")
        print("Step 1: Model loaded on CPU successfully.")

        # Step 2: Move model to GPU if available
        if DEVICE == "cuda":
            print(f"Step 2: Moving model to GPU ({DEVICE})...")
            model = cpu_model.to(DEVICE)
            print("Step 2: Model moved to GPU successfully.")
        else:
            model = cpu_model
        
        print(f"\n✅ Whisper model '{MODEL_NAME}' is ready on device: {DEVICE}.\n")

    except Exception as e:
        print("="*50)
        print("❌ FAILED TO LOAD WHISPER MODEL ❌")
        traceback.print_exc()
        print("="*50)
        model = None


@app.get("/", summary="Health Check", description="Check API server status.")
def read_root():
    status = "running"
    model_status = "loaded" if model else "failed_to_load"
    return {"status": status, "model_status": model_status, "model_name": MODEL_NAME}


@app.post("/transcribe", summary="Transcribe Audio File", description="Convert audio file to text.")
async def transcribe_audio(file: UploadFile = File(...)):
    if not model:
        raise HTTPException(status_code=503, detail="Whisper model is not available. Check server logs for details.")
    
    contents = await file.read()

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as temp_audio_file:
            temp_audio_file.write(contents)
            temp_path = temp_audio_file.name
        
        print(f"Transcribing file: {file.filename}")
        
        result = model.transcribe(temp_path, fp16=False)

        # [Added] Calculate total playback time of audio file
        duration = 0
        # Check if 'segments' info exists, and if so, get the 'end' time of the last segment
        if result.get("segments"):
            last_segment = result["segments"][-1]
            duration = last_segment["end"]

        print("Transcription successful.")

        # [Modified] Add 'duration_seconds' field to JSON response
        return JSONResponse(content={
            "filename": file.filename,
            "duration_seconds": round(duration, 2),
            "language": result["language"],
            "text": result["text"]
        })
    except Exception as e:
        print(f"❌ An error occurred during transcription: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if 'temp_path' in locals() and os.path.exists(temp_path):
            os.remove(temp_path)

