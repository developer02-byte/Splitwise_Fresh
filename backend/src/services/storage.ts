import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import sharp from 'sharp';

export type FileType = 'avatar' | 'receipt' | 'cover' | 'attachment';

export interface UploadResult {
  fileId: string;
  storagePath: string;
  publicUrl: string;
  mimeType: string;
  sizeBytes: number;
}

export class StorageService {
  private static uploadDir = path.join(__dirname, '../../uploads');

  static async init() {
    await fs.mkdir(this.uploadDir, { recursive: true });
    await fs.mkdir(path.join(this.uploadDir, 'avatars'), { recursive: true });
    await fs.mkdir(path.join(this.uploadDir, 'receipts'), { recursive: true });
    await fs.mkdir(path.join(this.uploadDir, 'covers'), { recursive: true });
    await fs.mkdir(path.join(this.uploadDir, 'attachments'), { recursive: true });
  }

  static async upload(buffer: Buffer, type: FileType, originalMime: string): Promise<UploadResult> {
    const fileId = uuidv4();
    const folder = `${type}s`;
    const filename = `${fileId}.webp`;
    const relativePath = path.join(folder, filename);
    const fullPath = path.join(this.uploadDir, relativePath);

    let processor = sharp(buffer);

    // Resize based on type as per spec
    if (type === 'avatar') {
      processor = processor.resize(256, 256, { fit: 'cover' });
    } else if (type === 'cover') {
      processor = processor.resize(1200, 675, { fit: 'cover' }); // 16:9
    } else {
      processor = processor.resize(2048, null, { withoutEnlargement: true });
    }

    const outputBuffer = await processor.webp({ quality: 80 }).toBuffer();
    await fs.writeFile(fullPath, outputBuffer);

    return {
      fileId,
      storagePath: relativePath,
      publicUrl: `/uploads/${relativePath.replace(/\\/g, '/')}`,
      mimeType: 'image/webp',
      sizeBytes: outputBuffer.length
    };
  }
}
