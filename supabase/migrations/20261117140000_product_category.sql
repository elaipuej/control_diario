ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS categoria text NOT NULL DEFAULT 'Sin categoría';

UPDATE public.productos
SET categoria = 'Sin categoría'
WHERE categoria IS NULL OR btrim(categoria) = '';

ALTER TABLE public.productos
  ALTER COLUMN categoria SET DEFAULT 'Sin categoría',
  ALTER COLUMN categoria SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'productos_categoria_not_blank_check'
      AND conrelid = 'public.productos'::regclass
  ) THEN
    ALTER TABLE public.productos
      ADD CONSTRAINT productos_categoria_not_blank_check
      CHECK (length(btrim(categoria)) > 0);
  END IF;
END;
$$;

UPDATE public.productos AS p
SET categoria = asignaciones.categoria
FROM (
  VALUES
    ('Bocadillo California York', 'Sin categoría'),
    ('Bocadillo Italiano de pavo', 'PANINI CLUB'),
    ('Bocadillo vegetal', 'PANINI CLUB'),
    ('Bocadillo de jamón', 'PANINI CLUB'),
    ('Wrap nórdico', 'Sin categoría'),
    ('Bocadillo César', 'PANINI CLUB'),
    ('Santóña con bonito', 'SANDWICH PANINI GRILL'),
    ('Pollo al curry', 'SANDWICH PANINI GRILL'),
    ('Playero de ensaladilla', 'SANDWICH PANINI GRILL'),
    ('Las Landas', 'Sin categoría'),
    ('Sándwich huevo y bacon', 'Sin categoría'),
    ('Paté de verduras', 'Sin categoría'),
    ('Bocadillo de tortilla de patatas', 'SANDWICH PANINI GRILL'),
    ('Burrito de cochinita pibil', 'Sin categoría'),
    ('Bocadillo de pollo', 'SANDWICH PANINI GRILL'),
    ('Bocadillo Cubano', 'SANDWICH PANINI GRILL'),
    ('Mollete piripi', 'SANDWICH PANINI GRILL'),
    ('Focaccia Lower East', 'Sin categoría'),
    ('Combo Fuji', 'POKE & FRIENDS'),
    ('Combo Tokio', 'POKE & FRIENDS'),
    ('Combo California Teriyaki Pollo', 'POKE & FRIENDS'),
    ('Poke Hawaiano de Pavo', 'POKE & FRIENDS'),
    ('Poke Maui de salmón', 'POKE & FRIENDS'),
    ('Arroz chaufa con ternera', 'Sin categoría'),
    ('Noodles Pad Thai con pollo', 'POKE & FRIENDS'),
    ('Tortilla de patata', 'POKE & FRIENDS'),
    ('Salmorejo cordobés', 'Sin categoría'),
    ('Crema del día (Olivo)', 'THE SPOON'),
    ('Green detox de manzana', 'CRAB & GO'),
    ('Antioxidante zanahoria', 'CRAB & GO'),
    ('Smoothie proteico de plátano', 'CRAB & GO'),
    ('Smoothie de mango', 'CRAB & GO'),
    ('Smoothie proteico de frutos rojos', 'CRAB & GO'),
    ('Hummus', 'CRAB & GO'),
    ('Ensaladilla tradicional', 'CRAB & GO'),
    ('Naranja', 'Sin categoría'),
    ('Bocadillo SIN GLUTEN 1 California', 'CELIACO'),
    ('Bocadillo SIN GLUTEN 2 Italiano', 'CELIACO'),
    ('Campero de pollo', 'Sin categoría'),
    ('Combo Ebi', 'Sin categoría'),
    ('Crema de calabaza', 'THE SPOON'),
    ('Cuchara del día', 'THE SPOON'),
    ('Focaccia pizza', 'Sin categoría'),
    ('Margarita de pesto', 'Sin categoría'),
    ('Noodles Pad Thai con ternera', 'POKE & FRIENDS'),
    ('Pollo teriyaki con arroz y verduras', 'Sin categoría'),
    ('Uvas', 'Sin categoría'),
    ('Sándwich club', 'SANDWICH PANINI GRILL'),
    ('Sandwich Quesucos y Nueces', 'SANDWICH PANINI GRILL'),
    ('Sandwich Serranito', 'SANDWICH PANINI GRILL'),
    ('Sandwich Nórdico de salmón', 'SANDWICH PANINI GRILL'),
    ('Gyros de pavo', 'SANDWICH PANINI GRILL'),
    ('Arroz del pastor vasco', 'Sin categoría'),
    ('Risotto de calabaza', 'Sin categoría'),
    ('Arroz integral de la huerta', 'Sin categoría'),
    ('Arroz marinero', 'Sin categoría'),
    ('Fideuá campera', 'Sin categoría'),
    ('Zumo rojo súper energético', 'Sin categoría'),
    ('Shawarma de pollo', 'PANINI CLUB'),
    ('Bocadillo de Lomo', 'PANINI CLUB'),
    ('Yakisoba de cerdo', 'Sin categoría'),
    ('Fideuá Gallega', 'Sin categoría'),
    ('Albóndigas', 'POKE & FRIENDS'),
    ('Lasaña', 'POKE & FRIENDS'),
    ('Arroz negro', 'Sin categoría'),
    ('Combo california', 'POKE & FRIENDS'),
    ('Sala Bar', 'Sin categoría')
) AS asignaciones(nombre, categoria)
WHERE p.nombre = asignaciones.nombre;

CREATE OR REPLACE FUNCTION public.agregar_producto_con_categoria(p_nombre text, p_categoria text)
RETURNS SETOF public.productos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  producto_id_nuevo public.productos.id%TYPE;
  categoria_nueva text := COALESCE(NULLIF(btrim(p_categoria), ''), 'Sin categoría');
BEGIN
  IF length(categoria_nueva) > 80 THEN
    RAISE EXCEPTION 'La categoría no puede superar los 80 caracteres.';
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
  SET categoria = categoria_nueva
  WHERE id = producto_id_nuevo
  RETURNING *;
END;
$$;

CREATE OR REPLACE FUNCTION public.actualizar_categoria_producto(p_producto_id bigint, p_categoria text)
RETURNS SETOF public.productos
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  categoria_nueva text := COALESCE(NULLIF(btrim(p_categoria), ''), 'Sin categoría');
BEGIN
  IF length(categoria_nueva) > 80 THEN
    RAISE EXCEPTION 'La categoría no puede superar los 80 caracteres.';
  END IF;

  RETURN QUERY
  UPDATE public.productos
  SET categoria = categoria_nueva
  WHERE id = p_producto_id
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION public.agregar_producto_con_categoria(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_categoria_producto(bigint, text) TO anon, authenticated;
