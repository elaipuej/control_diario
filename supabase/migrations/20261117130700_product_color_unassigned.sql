ALTER TABLE public.productos
  ALTER COLUMN color DROP DEFAULT,
  ALTER COLUMN color DROP NOT NULL;

UPDATE public.productos
SET color = NULL
WHERE nombre IN ('Smoothie de mango', 'Smoothie proteico de frutos rojos', 'Fruta del día');

CREATE OR REPLACE FUNCTION public.agregar_producto_con_color(p_nombre text, p_color text)
RETURNS SETOF public.productos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  producto_id_nuevo public.productos.id%TYPE;
BEGIN
  IF p_color IS NOT NULL AND p_color !~ '^#[0-9A-Fa-f]{6}$' THEN
    RAISE EXCEPTION 'El color debe ser un valor hexadecimal de seis dígitos o NULL.';
  END IF;

  SELECT nuevo.id
  INTO producto_id_nuevo
  FROM public.agregar_producto(p_nombre) AS nuevo
  LIMIT 1;

  IF producto_id_nuevo IS NULL THEN
    RAISE EXCEPTION 'No se pudo crear el producto.';
  END IF;

  RETURN QUERY
  UPDATE public.productos
  SET color = p_color
  WHERE id = producto_id_nuevo
  RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION public.actualizar_color_producto(p_producto_id bigint, p_color text)
RETURNS SETOF public.productos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_color IS NOT NULL AND p_color !~ '^#[0-9A-Fa-f]{6}$' THEN
    RAISE EXCEPTION 'El color debe ser un valor hexadecimal de seis dígitos o NULL.';
  END IF;

  RETURN QUERY
  UPDATE public.productos
  SET color = p_color
  WHERE id = p_producto_id
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION public.agregar_producto_con_color(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_color_producto(bigint, text) TO anon, authenticated;
