-- Migration: enhance chat_messages with read receipts and image attachments.
-- Safe to re-run: all ALTERs use IF NOT EXISTS / ADD COLUMN IF NOT EXISTS.

-- 1. Read receipts: timestamp when the message was read by the recipient.
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS read_at timestamptz;

-- 2. Image attachments: optional image URL stored in Supabase Storage.
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS image_url text;

-- 3. Index for faster ordering and filtering.
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at
  ON public.chat_messages (created_at desc);
