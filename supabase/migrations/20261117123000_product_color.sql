ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS color text;
ALTER TABLE public.productos
  ALTER COLUMN color DROP DEFAULT,
  ALTER COLUMN color DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'productos_color_hex_check'
      AND conrelid = 'public.productos'::regclass
  ) THEN
    ALTER TABLE public.productos
      ADD CONSTRAINT productos_color_hex_check
      CHECK (color ~ '^#[0-9A-Fa-f]{6}$');
  END IF;
END;
$$;

UPDATE public.productos AS p
SET color = colors.hex
FROM (
  VALUES
    ('Shawarma de pollo', '#2EAD68'),
    ('Bocadillo Italiano de pavo', '#2EAD68'),
    ('Bocadillo vegetal', '#2EAD68'),
    ('Bocadillo de jamón', '#D9534F'),
    ('Bocadillo de Lomo', '#D9534F'),
    ('Bocadillo César', '#D9534F'),
    ('Santóña con bonito', '#8A94A6'),
    ('Pollo al curry', '#8A94A6'),
    ('Campero de pollo', '#8A94A6'),
    ('Sandwich Quesucos y Nueces', '#8A94A6'),
    ('Sandwich Serranito', '#8A94A6'),
    ('Playero de ensaladilla', '#8A94A6'),
    ('Sándwich mixto', '#2EAD68'),
    ('Sandwich Nórdico de salmón', '#2EAD68'),
    ('Sándwich club', '#2EAD68'),
    ('Bocadillo de tortilla de patatas', '#2EAD68'),
    ('Burrito Texmex de cerdo', '#2EAD68'),
    ('Bocadillo de pollo', '#2EAD68'),
    ('Bocadillo Cubano', '#2EAD68'),
    ('Gyros de pavo', '#D9534F'),
    ('Mollete piripi', '#D9534F'),
    ('Combo Fuji', '#D9534F'),
    ('Combo Tokio', '#1976D2'),
    ('Combo California Teriyaki Pollo', '#1976D2'),
    ('Poke Maui de salmón', '#1976D2'),
    ('Albóndigas', '#D9534F'),
    ('Moussaka de berenjena', '#D9534F'),
    ('Lasaña', '#D9534F'),
    ('Noodles Thai con curry verde', '#1976D2'),
    ('Arroz del pastor vasco', '#D9534F'),
    ('Risotto de calabaza', '#D9534F'),
    ('Fideuá a la navarra', '#D9534F'),
    ('Arroz integral de la huerta', '#D9534F'),
    ('Arroz marinero', '#D9534F'),
    ('Fideuá de Pedreña', '#D9534F'),
    ('Arroz otoñal integral', '#D9534F'),
    ('Arroz rossejat', '#D9534F'),
    ('Arroz a la gallega', '#D9534F'),
    ('Fideuá campera', '#D9534F'),
    ('Tortilla de patata', '#1976D2'),
    ('Tortilla de patata y chorizo', '#1976D2'),
    ('Crema de calabacín', '#F9A825'),
    ('Cuchara del día', '#F9A825'),
    ('Green detox de manzana', '#F9A825'),
    ('Antioxidante zanahoria', '#F9A825'),
    ('Smoothie proteico multifruta', '#F9A825'),
    ('Smoothie proteico de plátano', '#F9A825'),
    ('Smoothie de mango', NULL),
    ('Smoothie proteico de frutos rojos', NULL),
    ('Hummus', '#F9A825'),
    ('Ensaladilla tradicional', '#2EAD68'),
    ('Fruta del día', NULL),
    ('Bocadillo SIN GLUTEN 1 California', '#D9534F'),
    ('Bocadillo SIN GLUTEN 2 Italiano', '#D9534F'),
    ('Salad bar', '#2EAD68')
) AS colors(nombre, hex)
WHERE p.nombre = colors.nombre;

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
    RAISE EXCEPTION 'El color debe ser un valor hexadecimal de seis dígitos.';
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
    RAISE EXCEPTION 'El color debe ser un valor hexadecimal de seis dígitos.';
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
