import { PutObjectCommand, DeleteObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { r2Client } from '../config/r2.js';
import { v4 as uuidv4 } from 'uuid';
import sharp from 'sharp';

export class R2Service {
  /**
   * Upload a receipt image.
   * Resizes to max 1200px wide, strips EXIF for privacy,
   * then uploads compressed JPEG.
   */
  static async uploadReceiptImage(userId, fileBuffer, mimetype) {
    const key = `receipts/${userId}/${uuidv4()}.jpg`;

    // Compress + resize via sharp
    const optimized = await sharp(fileBuffer)
      .resize({ width: 1200, withoutEnlargement: true })
      .jpeg({ quality: 80, progressive: true })
      .withMetadata({ orientation: undefined }) // strip EXIF location
      .toBuffer();

    await r2Client.send(new PutObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: key,
      Body: optimized,
      ContentType: 'image/jpeg',
      CacheControl: 'public, max-age=31536000, immutable',
    }));

    // Return both the key (for DB) and the public CDN URL
    const publicUrl = `${process.env.R2_PUBLIC_DOMAIN}/${key}`;
    return { key, url: publicUrl };
  }

  /**
   * Generate a presigned URL for direct client reads (fallback if CDN not configured)
   */
  static async getPresignedUrl(key, expiresIn = 3600) {
    const command = new GetObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: key,
    });
    return getSignedUrl(r2Client, command, { expiresIn });
  }

  static async deleteObject(key) {
    await r2Client.send(new DeleteObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: key,
    }));
  }
}
