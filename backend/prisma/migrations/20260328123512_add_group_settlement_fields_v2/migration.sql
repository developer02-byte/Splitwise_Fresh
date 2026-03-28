-- AlterTable
ALTER TABLE "groups" ADD COLUMN     "settlement_threshold" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "simplified_settlement" BOOLEAN NOT NULL DEFAULT true;
