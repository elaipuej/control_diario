-- Ejecutar una vez en Supabase > SQL Editor.
-- La página usa la clave publicable sin inicio de sesión; estas funciones
-- permiten solo insertar productos activos y desactivar productos existentes.

CREATE OR REPLACE FUNCTION public.agregar_producto(p_nombre text)
RETURNS SETOF public.productos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_nombre text := pg_catalog.btrim(p_nombre);
  v_producto public.productos;
BEGIN
  IF v_nombre IS NULL OR v_nombre = '' OR pg_catalog.char_length(v_nombre) > 120 THEN
    RAISE EXCEPTION 'El nombre debe tener entre 1 y 120 caracteres.'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.productos AS p
    WHERE p.activo IS TRUE
      AND pg_catalog.lower(pg_catalog.btrim(p.nombre)) = pg_catalog.lower(v_nombre)
  ) THEN
    RAISE EXCEPTION 'Ya existe un producto activo con ese nombre.'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.productos (nombre, activo, orden)
  SELECT v_nombre, TRUE, COALESCE(MAX(p.orden), 0) + 1
  FROM public.productos AS p
  RETURNING * INTO v_producto;

  RETURN NEXT v_producto;
END;
$function$;

CREATE OR REPLACE FUNCTION public.quitar_producto(p_producto_id bigint)
RETURNS SETOF public.productos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_producto public.productos;
BEGIN
  UPDATE public.productos AS p
  SET activo = FALSE
  WHERE p.id = p_producto_id
    AND p.activo IS TRUE
  RETURNING p.* INTO v_producto;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontró un producto activo con ese identificador.'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN NEXT v_producto;
END;
$function$;

REVOKE ALL ON FUNCTION public.agregar_producto(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.quitar_producto(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.agregar_producto(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.quitar_producto(bigint) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
