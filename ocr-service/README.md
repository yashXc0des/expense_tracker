# Receipt OCR Microservice

Python microservice for extracting structured data from receipt images using OpenCV + Tesseract OCR.

## Features

- **Image Preprocessing**: OpenCV pipeline for deskewing, denoising, and adaptive thresholding
- **Robust OCR**: Tesseract with LSTM + legacy models for better accuracy
- **Smart Extraction**: Regex patterns to extract:
  - Total amount (handles multiple formats: ₹, INR, Rs., etc.)
  - Transaction date (supports DD/MM/YYYY, ISO, month names)
  - Merchant/shop name
- **Confidence Scoring**: 0-1 confidence score for OCR accuracy
- **Non-blocking**: Failures in OCR don't block expense creation on the backend

## Prerequisites

- Python 3.10+
- Tesseract OCR installed on your system

### Install Tesseract

**Ubuntu/Debian:**
```bash
sudo apt-get install tesseract-ocr
```

**macOS:**
```bash
brew install tesseract
```

**Windows:**
Download installer from: https://github.com/UB-Mannheim/tesseract/wiki

## Setup

```bash
# Create virtual environment
python -m venv venv

# Activate
# On macOS/Linux:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Running

### Development
```bash
uvicorn main:app --reload --port 8000
```

### Production
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

The service will be available at `http://localhost:8000`

## API Endpoints

### POST `/extract`

Upload a receipt image and extract structured data.

**Request:**
```bash
curl -X POST "http://localhost:8000/extract" \
  -F "image=@receipt.jpg"
```

**Response:**
```json
{
  "raw_text": "Full OCR output text...",
  "total_amount": 542.50,
  "date": "2024-05-17T00:00:00",
  "merchant_name": "Pizza Paradise",
  "confidence": 0.92
}
```

### GET `/health`

Health check endpoint for monitoring.

```bash
curl "http://localhost:8000/health"
```

Response:
```json
{
  "status": "ok",
  "service": "Receipt OCR"
}
```

## Integration with Backend

The Node.js backend calls this service automatically when creating expenses with images:

1. Client uploads receipt image with expense form
2. Backend calls `POST /api/expenses` with the image
3. Backend forwards image to this OCR service (async)
4. OCR returns extracted data (amount, date, merchant)
5. Backend stores OCR results with the expense (non-blocking if OCR fails)

**Backend Environment Variable:**
```bash
OCR_SERVICE_URL=http://localhost:8000
```

## Architecture

```
Receipt Image
    ↓
[OpenCV Preprocessor]
  - Deskew (correct ~45° tilt)
  - Denoise
  - Adaptive Threshold
    ↓
Binary Image
    ↓
[Tesseract OCR]
  - Read text + confidence
    ↓
Raw Text + Confidence Scores
    ↓
[Regex Extractors]
  - Amount Pattern Matching
  - Date Pattern Matching
  - Merchant Name Extraction
    ↓
Structured JSON Response
```

## Troubleshooting

### "ModuleNotFoundError: No module named 'pytesseract'"
```bash
pip install pytesseract
```

### "tesseract is not installed or it's not in your PATH"
Ensure Tesseract is installed and in your system PATH.

**Check if installed:**
```bash
tesseract --version
```

### Low accuracy on crumpled/angled receipts
The OpenCV preprocessor handles:
- Deskewing up to ~45°
- Lighting variations (adaptive threshold)
- Noise reduction

If accuracy is still low:
1. Ensure good lighting when capturing
2. Frame entire receipt in camera
3. Avoid reflections/shadows

### Want to fine-tune?
Edit `ocr/preprocessor.py`:
- `cv2.Canny()` parameters for edge detection
- `cv2.adaptiveThreshold()` blockSize and C values
- `cv2.fastNlMeansDenoising()` h parameter for denoising strength

## Performance

- Single receipt: ~2-5 seconds (depending on image size)
- Parallel processing: FastAPI + Uvicorn support concurrent requests
- Timeout: 15 seconds (configurable in backend)

## Deployment

### Docker
```dockerfile
FROM python:3.10-slim

RUN apt-get update && apt-get install -y tesseract-ocr && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Build & Run
```bash
docker build -t receipt-ocr .
docker run -p 8000:8000 receipt-ocr
```

### Cloud Platforms
- **Google Cloud Run**: Set memory to 512MB+, concurrency to 10
- **AWS Lambda**: Use container image, layer size < 500MB
- **Render/Railway**: Direct `uvicorn main:app` command

---

**Support:** For issues or improvements, check the main repository or open an issue.
