ALTER TABLE public.previsiones ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'previsiones'
      AND policyname = 'previsiones_public_select'
  ) THEN
    CREATE POLICY previsiones_public_select
      ON public.previsiones
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'previsiones'
      AND policyname = 'previsiones_public_insert'
  ) THEN
    CREATE POLICY previsiones_public_insert
      ON public.previsiones
      FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'previsiones'
      AND policyname = 'previsiones_public_update'
  ) THEN
    CREATE POLICY previsiones_public_update
      ON public.previsiones
      FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END;
$$;

GRANT SELECT, INSERT, UPDATE ON TABLE public.previsiones TO anon, authenticated;
