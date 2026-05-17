import cv2
import numpy as np


def preprocess_receipt(image_bytes: bytes) -> np.ndarray:
    """
    Full OpenCV pipeline for receipt OCR preprocessing:
    1. Decode
    2. Deskew (correct tilt up to ~45°)
    3. Denoise
    4. Adaptive threshold (handles uneven lighting)
    """
    # Decode image from bytes
    arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    
    if img is None:
        raise ValueError("Failed to decode image")

    # Resize to consistent width for tesseract
    h, w = img.shape[:2]
    if w > 1200:
        scale = 1200 / w
        img = cv2.resize(img, (1200, int(h * scale)), interpolation=cv2.INTER_AREA)

    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Deskew (correct paper tilt)
    gray = _deskew(gray)

    # Denoise
    gray = cv2.fastNlMeansDenoising(
        gray, 
        h=10, 
        templateWindowSize=7, 
        searchWindowSize=21
    )

    # Adaptive threshold — handles shadows and creased paper
    binary = cv2.adaptiveThreshold(
        gray, 
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        blockSize=31, 
        C=10
    )

    # Morphological cleanup
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 1))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

    return binary


def _deskew(gray: np.ndarray) -> np.ndarray:
    """
    Detect dominant text angle and rotate to correct skew.
    Corrects paper tilt/rotation up to ~45 degrees.
    """
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(
        edges, 
        1, 
        np.pi / 180,
        threshold=80, 
        minLineLength=50, 
        maxLineGap=10
    )
    
    if lines is None:
        return gray

    angles = []
    for line in lines:
        x1, y1, x2, y2 = line[0]
        if x2 - x1 != 0:
            angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
            # Only consider near-horizontal lines (text is mostly horizontal)
            if -45 < angle < 45:
                angles.append(angle)

    if not angles:
        return gray

    # Use median angle to reduce outliers
    median_angle = np.median(angles)
    
    # Skip rotation if angle is very small
    if abs(median_angle) < 0.5:
        return gray

    h, w = gray.shape
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, median_angle, 1.0)
    
    return cv2.warpAffine(
        gray, 
        M, 
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REPLICATE
    )
