import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { StorageService, FileType } from '../services/storage';

const prisma = new PrismaClient();

export default async function fileRoutes(fastify: FastifyInstance) {
  
  fastify.post('/upload', async (request, reply) => {
    const userId = (request as any).userId;
    if (!userId) return reply.code(401).send({ success: false, error: 'Unauthorized' });

    const data = await request.file();
    if (!data) return reply.code(400).send({ success: false, error: 'No file uploaded' });

    const fields = (data as any).fields;
    const fileType = fields.file_type?.value as FileType || 'receipt';
    const buffer = await data.toBuffer();

    try {
      const result = await StorageService.upload(buffer, fileType, data.mimetype);

      const fileRecord = await prisma.file.create({
        data: {
          id: result.fileId,
          uploaderId: userId,
          fileType: fileType.toUpperCase(),
          storagePath: result.storagePath,
          mimeType: result.mimeType,
          sizeBytes: result.sizeBytes,
          publicUrl: result.publicUrl
        }
      });

      return reply.code(201).send({
        success: true,
        data: {
          file_id: fileRecord.id,
          url: fileRecord.publicUrl
        }
      });
    } catch (e) {
      request.log.error(e);
      return reply.code(500).send({ success: false, error: 'File processing failed' });
    }
  });

  fastify.delete('/:id', async (request, reply) => {
    const userId = (request as any).userId;
    const { id } = request.params as any;

    const file = await prisma.file.findUnique({ where: { id } });
    if (!file) return reply.code(404).send({ success: false });
    if (file.uploaderId !== userId) return reply.code(403).send({ success: false });

    await prisma.file.update({
      where: { id },
      data: { deletedAt: new Date() }
    });

    return reply.send({ success: true });
  });
}
