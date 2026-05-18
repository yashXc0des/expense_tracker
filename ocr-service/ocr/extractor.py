import re
import os
import pytesseract
import numpy as np
from datetime import datetime
from PIL import Image


# Ensure pytesseract can find Tesseract on Windows even when PATH is stale.
if os.name == 'nt':
    default_tesseract = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
    if os.path.exists(default_tesseract):
        pytesseract.pytesseract.tesseract_cmd = default_tesseract


# Regex patterns for extracting amounts (handles various formats)
AMOUNT_PATTERNS = [
    # Pattern 1: Keywords like "total", "amount", "grand total", etc. with optional currency
    r'(?:total|amount|grand\s*total|amt|sum|payable|due|pay)[:\s]*(?:rs\.?|inr|₹)?\s*([\d,]+\.?\d{0,2})',
    # Pattern 2: Currency symbol at start, before amount
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    # Pattern 3: Amount followed by currency symbol or text
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs|rupees|inr|₹)',
    # Pattern 4: Line that starts with just the amount (common in Indian receipts)
    r'^\s*([\d,]+(?:\.\d{1,2})?)\s*$',
    # Pattern 5: Large currency amounts (more than 2 digits, indicating it's likely a total)
    r'\b([\d]{3,}(?:,[\d]{3})*(?:\.\d{1,2})?)\b',
    # Pattern 6: Any number format
    r'\b([\d,]+(?:\.\d{1,2})?)\b',
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
    
    confidences = []
    for c in data.get('conf', []):
        try:
            val = float(c)
            if val >= 0:
                confidences.append(val)
        except (TypeError, ValueError):
            continue
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
    If all patterns fail, returns the largest number (usually the total).
    """
    lower = text.lower()
    
    # Try all regex patterns first
    for pattern in AMOUNT_PATTERNS[:-1]:  # Skip the last pattern for now
        try:
            # Use MULTILINE flag for line-based patterns
            match = re.search(pattern, lower, re.MULTILINE)
            if match:
                try:
                    amount_str = match.group(1).replace(',', '')
                    val = float(amount_str)
                    # Filter out obviously wrong amounts (too small or negative)
                    if val > 0.01:
                        return val
                except (ValueError, IndexError):
                    continue
        except re.error:
            continue
    
    # Fallback: Find the largest number in the text (often the total on a receipt)
    # This handles cases like "Total 1234" or "Amount: 5000" without keywords
    numbers = re.findall(r'[\d,]+(?:\.\d{1,2})?', text)
    if numbers:
        amounts = []
        for num_str in numbers:
            try:
                val = float(num_str.replace(',', ''))
                if val > 0.01:  # Filter out tiny numbers (like prices of individual items)
                    amounts.append(val)
            except ValueError:
                continue
        
        # Return the largest amount (usually the total)
        if amounts:
            largest = max(amounts)
            # But filter out suspiciously large amounts (likely quantities)
            # For Indian context, reasonable totals are usually < 999,999
            if largest < 999999:
                return largest
    
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
