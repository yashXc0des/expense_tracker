import re
import pytesseract
import numpy as np
from datetime import datetime
from PIL import Image


# Regex patterns for extracting amounts (handles various formats)
AMOUNT_PATTERNS = [
    r'(?:total|amount|grand\s*total|amt|sum)[:\s]*(?:rs\.?|inr|₹)?\s*([\d,]+\.?\d{0,2})',
    r'(?:rs\.?|inr|₹)\s*([\d,]+\.?\d{0,2})',
    r'\b([\d,]+\.\d{2})\b',  # fallback: any decimal number
]

# Regex patterns for dates
DATE_PATTERNS = [
    r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})',
    r'(\d{4}[\/\-\.]\d{2}[\/\-\.]\d{2})',
    r'(\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+\d{2,4})',
]

# Words to ignore when extracting merchant name
MERCHANT_STOPWORDS = {
    'receipt', 'invoice', 'bill', 'gst', 'tax', 'total', 'date', 
    'time', 'amount', 'thanks', 'thank', 'you', 'visit'
}


def extract_receipt_data(binary_image: np.ndarray) -> dict:
    """
    Extract structured data from preprocessed receipt image.
    Uses Tesseract OCR + regex patterns for amount, date, merchant.
    """
    pil_img = Image.fromarray(binary_image)

    # Run tesseract with receipt-optimized config
    # PSM 6: Assume a single uniform block of text
    # OEM 3: Use both legacy and LSTM models
    custom_config = r'--oem 3 --psm 6 -l eng'
    raw_text = pytesseract.image_to_string(pil_img, config=custom_config)

    # Get confidence scores for all detected text
    data = pytesseract.image_to_data(
        pil_img, 
        config=custom_config,
        output_type=pytesseract.Output.DICT
    )
    
    confidences = [c for c in data['conf'] if c != -1]
    avg_confidence = (
        sum(confidences) / len(confidences) / 100 
        if confidences 
        else 0
    )

    return {
        'raw_text': raw_text,
        'total_amount': _extract_amount(raw_text),
        'date': _extract_date(raw_text),
        'merchant_name': _extract_merchant(raw_text),
        'confidence': round(avg_confidence, 3),
    }


def _extract_amount(text: str):
    """
    Extract total amount from receipt text.
    Tries multiple patterns to handle different receipt formats.
    """
    lower = text.lower()
    
    for pattern in AMOUNT_PATTERNS:
        match = re.search(pattern, lower)
        if match:
            try:
                amount_str = match.group(1).replace(',', '')
                return float(amount_str)
            except ValueError:
                continue
    
    return None


def _extract_date(text: str):
    """
    Extract date from receipt text.
    Returns ISO format date string or None.
    """
    for pattern in DATE_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            raw = match.group(1)
            
            # Try multiple date formats
            formats = [
                '%d/%m/%Y', '%d-%m-%Y', '%Y-%m-%d',
                '%d/%m/%y', '%d %b %Y', '%d %B %Y',
                '%m/%d/%Y', '%m-%d-%Y',
            ]
            
            for fmt in formats:
                try:
                    dt = datetime.strptime(raw, fmt)
                    return dt.isoformat()
                except ValueError:
                    continue
    
    return None


def _extract_merchant(text: str):
    """
    Extract merchant/shop name from receipt text.
    Usually appears in first few lines, filters out common keywords.
    """
    lines = [
        l.strip() 
        for l in text.splitlines() 
        if l.strip() and len(l.strip()) > 3
    ]
    
    # Merchant name usually in first 5 lines
    for line in lines[:5]:
        words = line.lower().split()
        
        # Skip lines that are mostly stop words
        if not any(w in MERCHANT_STOPWORDS for w in words):
            return line.title()
    
    return None
