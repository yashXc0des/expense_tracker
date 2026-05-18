import axios from 'axios';
import FormData from 'form-data';

export class OcrService {
  static async extractReceiptData(imageBuffer) {
    try {
      const form = new FormData();
      form.append('image', imageBuffer, {
        filename: 'receipt.jpg',
        contentType: 'image/jpeg',
      });

      const { data } = await axios.post(
        `${process.env.OCR_SERVICE_URL}/extract`,
        form,
        { headers: form.getHeaders(), timeout: 15000 }
      );

      return {
        rawText: data.raw_text ?? '',
        merchantName: data.merchant_name ?? null,
        detectedAmount: data.total_amount ?? null,
        detectedDate: data.date ? new Date(data.date) : null,
        confidence: data.confidence ?? 0,
      };
    } catch (err) {
      console.warn('OCR service unavailable, skipping:', err.message);
      return null; // OCR failure must not block expense creation
    }
  }
}
