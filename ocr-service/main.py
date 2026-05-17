from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from ocr.preprocessor import preprocess_receipt
from ocr.extractor import extract_receipt_data

app = FastAPI(
    title='Receipt OCR Service',
    version='1.0.0',
    description='OpenCV + Tesseract OCR microservice for receipt data extraction'
)


@app.post('/extract', summary='Extract data from receipt image')
async def extract(image: UploadFile = File(...)):
    """
    Upload a receipt image and extract structured data.
    
    Returns:
    - raw_text: Full OCR output
    - total_amount: Detected total/grand total amount
    - date: Transaction date in ISO format
    - merchant_name: Extracted shop/restaurant name
    - confidence: 0-1 confidence score for OCR accuracy
    """
    if not image.content_type.startswith('image/'):
        raise HTTPException(400, 'File must be an image (JPEG, PNG, etc.)')

    try:
        contents = await image.read()
        
        # Preprocess image with OpenCV
        binary = preprocess_receipt(contents)
        
        # Extract structured data with Tesseract + regex
        result = extract_receipt_data(binary)
        
        return JSONResponse(result)
        
    except ValueError as e:
        raise HTTPException(400, f'Invalid image: {str(e)}')
    except Exception as e:
        raise HTTPException(500, f'OCR processing failed: {str(e)}')


@app.get('/health', summary='Health check endpoint')
async def health():
    """Simple health check for deployment monitoring."""
    return {'status': 'ok', 'service': 'Receipt OCR'}


if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=8000)
