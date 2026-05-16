-- ============================================================
-- Migração 002: Atualização de Perfis e Storage de Avatares
-- ============================================================

-- 1. Adicionar colunas novas à tabela profiles com valores padrão
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS sexo TEXT DEFAULT 'Outro';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS idade INT DEFAULT 18;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Definir valor padrão para a coluna nome
ALTER TABLE public.profiles ALTER COLUMN nome SET DEFAULT 'Atleta';

-- 3. Atualizar registros existentes onde os valores estão nulos
UPDATE public.profiles SET nome = 'Atleta' WHERE nome IS NULL;
UPDATE public.profiles SET sexo = 'Outro' WHERE sexo IS NULL;
UPDATE public.profiles SET idade = 18 WHERE idade IS NULL;

-- 4. Criar o bucket de storage para os avatares (se não existir)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 5. Configurar políticas de segurança para o bucket 'avatars'
-- Permitir leitura pública dos avatares
CREATE POLICY "Allow public select on avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Permitir qualquer operação por usuários autenticados no próprio bucket
CREATE POLICY "Allow authenticated insert on avatars"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Allow authenticated update on avatars"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'avatars');

CREATE POLICY "Allow authenticated delete on avatars"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'avatars');
