-- ============================================================
-- Run App — Schema Inicial
-- ============================================================

-- Habilitar UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -------------------------------------------------------
-- PROFILES (espelho de auth.users para dados extras)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT,
  nome        TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Trigger: criar profile automaticamente após signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -------------------------------------------------------
-- CICLOS
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ciclos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nome             TEXT NOT NULL,
  detalhamento_md  TEXT,                          -- conteúdo bruto do arquivo .md
  ativo            BOOLEAN DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ciclos_user_id ON public.ciclos(user_id);

-- -------------------------------------------------------
-- TREINOS
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.treinos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ciclo_id       UUID NOT NULL REFERENCES public.ciclos(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dia_numero     INT,
  dia_semana     TEXT,                            -- "Seg", "Ter", etc.
  data_treino    DATE NOT NULL,
  prioridade_1   TEXT,                            -- "Corrida E (35')"
  prioridade_2   TEXT,                            -- "Treino A (Core/Sup)"
  terreno        TEXT,
  duracao_total  TEXT,
  created_at     TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_treinos_ciclo_id   ON public.treinos(ciclo_id);
CREATE INDEX IF NOT EXISTS idx_treinos_user_id    ON public.treinos(user_id);
CREATE INDEX IF NOT EXISTS idx_treinos_data       ON public.treinos(data_treino);

-- -------------------------------------------------------
-- REGISTROS (treino concluído)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.registros (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  treino_id     UUID NOT NULL REFERENCES public.treinos(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  anotacao      TEXT,
  concluido_em  TIMESTAMPTZ DEFAULT now(),
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_registros_treino_id ON public.registros(treino_id);
CREATE INDEX IF NOT EXISTS idx_registros_user_id ON public.registros(user_id);

-- -------------------------------------------------------
-- RLS — Row Level Security
-- -------------------------------------------------------
ALTER TABLE public.profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ciclos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treinos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registros ENABLE ROW LEVEL SECURITY;

-- PROFILES
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- CICLOS
CREATE POLICY "ciclos_select_own" ON public.ciclos
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "ciclos_insert_own" ON public.ciclos
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ciclos_update_own" ON public.ciclos
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "ciclos_delete_own" ON public.ciclos
  FOR DELETE USING (auth.uid() = user_id);

-- TREINOS
CREATE POLICY "treinos_select_own" ON public.treinos
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "treinos_insert_own" ON public.treinos
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "treinos_update_own" ON public.treinos
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "treinos_delete_own" ON public.treinos
  FOR DELETE USING (auth.uid() = user_id);

-- REGISTROS
CREATE POLICY "registros_select_own" ON public.registros
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "registros_insert_own" ON public.registros
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "registros_update_own" ON public.registros
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "registros_delete_own" ON public.registros
  FOR DELETE USING (auth.uid() = user_id);
