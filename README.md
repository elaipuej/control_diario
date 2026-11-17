# Control Diario

Aplicación web para registrar el control diario de productos, consultar el consumo y la merma, y obtener una previsión de preparación para el día siguiente. Los datos se comparten mediante Supabase.

## Abrir la aplicación

Abre `index.html` para registrar el control diario. Desde esa página, selecciona **Abrir Dashboard** para consultar el análisis. Se necesita conexión a internet para cargar y sincronizar los datos con Supabase.

## Registrar el control del día

1. Selecciona la **Fecha** y el **Tipo de día**. Los tipos disponibles son Normal, Festivo, Evento y Cierre parcial.
2. Selecciona el **Usuario** que realiza el registro.
3. Abre **Seleccionar productos del día**. Busca los productos que necesitas y marca sus casillas. Puedes usar **Seleccionar todos** o **Desmarcar todos**.
4. Pulsa **APLICAR SELECCIÓN** para guardar en Supabase los productos que se usarán para esa fecha. La selección se conserva por fecha; para fechas nuevas se toma la última selección anterior.
5. Abre **Productos del control** e introduce los valores:
   - **Inicial**: unidades disponibles al comienzo.
   - **Reposición**: unidades añadidas durante el día.
   - **Sobrante**: unidades que quedan al final.
   - **Merma**: unidades perdidas o descartadas.
6. Los valores se guardan automáticamente tras dejar de escribir un momento. También puedes pulsar **GUARDAR CONTROL**. La aplicación valida que no haya valores negativos y que el sobrante más la merma no superen Inicial + Reposición.

El consumo que muestra la aplicación se calcula como **Inicial + Reposición − Sobrante − Merma**, con un mínimo de cero. Es una aproximación a las unidades vendidas, no una lectura del sistema de caja. La merma porcentual se calcula sobre Inicial + Reposición.

El indicador de progreso cuenta los productos que tienen al menos un campo rellenado; no necesariamente significa que todos sus campos estén completos. Si no hay conexión, los cambios pendientes se guardan temporalmente en el navegador y se reenvían cuando vuelva internet. No borres los datos del navegador mientras haya registros pendientes.

**Limpiar formulario** borra los campos visibles, no los registros ya guardados. Si vuelves a cargar la misma fecha y usuario, se consultan los datos guardados.

## Gestionar el catálogo

En **Seleccionar productos del día**, la sección **Gestionar catálogo de productos** permite:

- **Añadir** un producto por su nombre y asignándole una categoría existente. La opción **Nueva categoría...** permite crear otra categoría.
- **Cambiar la categoría** de un producto desde el desplegable junto a su nombre. Las categorías nuevas se pueden crear al asignarlas.
- **Quitar** un producto del catálogo activo usando el botón junto a su nombre. La aplicación pide confirmación y conserva los registros históricos del producto.

Los productos se ordenan por categoría (**PANINI CLUB**, **SANDWICH PANINI GRILL**, **POKE & FRIENDS**, **CRAB & GO**, **THE SPOON** y **CELIACO**), después las categorías nuevas en orden alfabético y, al final, **Sin categoría**. Cada categoría tiene un distintivo de color consistente en el control diario y el Dashboard; las categorías nuevas reciben un color automáticamente. Es una ayuda visual y no requiere guardar colores en Supabase. Para habilitar la clasificación, ejecuta `supabase/migrations/20261117140000_product_category.sql` en **Supabase → SQL Editor**. Esta migración añade `productos.categoria`, importa las asignaciones exactas de `productos_con_categoria.xlsx` y crea las funciones para añadir productos y actualizar categorías. Los nombres que no coincidan exactamente con los de la hoja conservan **Sin categoría**. La columna antigua `productos.color` no se borra, pero deja de utilizarse en la aplicación. La migración está en una carpeta excluida de Git por petición del usuario; hay que ejecutarla desde el archivo local, no se incluirá al publicar el código. La gestión modifica el catálogo compartido, no solo el formulario local.

## Consultar el Dashboard

En `dashboard.html` puedes filtrar los resúmenes por periodo y trabajador. En los periodos personalizados, indica las fechas **Desde** y **Hasta**.

El Dashboard muestra:

- **Resumen del periodo**: consumo estimado, merma, registros, días con datos, unidades iniciales, reposición y sobrante.
- **Comparativas y gráficos**: consumo por trabajador y producto, y los productos con más y menos consumo; las tablas y previsiones muestran la categoría de cada producto.
- **Previsión para mañana**: utiliza el consumo estimado (descontando sobrante y merma) de hasta 12 registros de los últimos 120 días del mismo día de la semana. Si hay menos de dos registros, no presenta una estimación; con dos o tres, la marca como provisional. Si hay menos de dos de ese día de la semana, puede recurrir a hasta 12 registros de otros días, indicado con `*`.
- **Preparar**: consumo estimado para mañana menos el sobrante registrado hoy, con un mínimo de cero.
- **Precisión de la previsión** e **Historial reciente**.
- **Exportar CSV**: descarga los registros para abrirlos en una hoja de cálculo, incluida la categoría del producto.

El Excel generado desde el control diario también incluye una columna de categoría y ordena los productos por categoría.

La previsión es orientativa. No cambia al filtrar por trabajador: se calcula para toda la tienda. El sobrante de hoy se suma entre los registros de los usuarios.

La precisión se expresa como error absoluto medio en unidades y error porcentual ponderado, incluyendo comparaciones cuyo consumo real fue cero. Las etiquetas de fiabilidad describen la cantidad y variabilidad de la muestra; no garantizan la precisión. Al cambiar la definición de consumo, la comparación histórica solo considera previsiones guardadas con la fórmula nueva.

Para guardar previsiones y habilitar la comparación de precisión, ejecuta `supabase/migrations/20261117132000_public_forecast_writes.sql` en **Supabase → SQL Editor**. Esta política permite a cualquier visitante leer, insertar y actualizar filas de `previsiones`, necesario para el `upsert` del Dashboard. No da acceso de escritura a otras tablas, pero las previsiones públicas pueden ser modificadas por cualquier visitante; para una protección más estricta se necesita autenticación.

## Festivos de la Comunidad de Madrid

El Dashboard excluye de la previsión las fechas de la tabla `dias_especiales` cuyo tipo no sea `Normal`. Para que los festivos se excluyan, deben estar cargados en Supabase. La siguiente consulta añade los festivos laborales nacionales y autonómicos aplicables en la Comunidad de Madrid en 2026. Se puede ejecutar en **Supabase → SQL Editor** y repetir sin duplicar fechas:

```sql
INSERT INTO public.dias_especiales (fecha, tipo, actualizado_en)
VALUES
  ('2026-01-01', 'Festivo', NOW()), -- Año Nuevo
  ('2026-01-06', 'Festivo', NOW()), -- Epifanía del Señor
  ('2026-04-02', 'Festivo', NOW()), -- Jueves Santo
  ('2026-04-03', 'Festivo', NOW()), -- Viernes Santo
  ('2026-05-01', 'Festivo', NOW()), -- Fiesta del Trabajo
  ('2026-05-02', 'Festivo', NOW()), -- Día de la Comunidad de Madrid
  ('2026-08-15', 'Festivo', NOW()), -- Asunción de la Virgen
  ('2026-10-12', 'Festivo', NOW()), -- Fiesta Nacional de España
  ('2026-11-02', 'Festivo', NOW()), -- Traslado de Todos los Santos
  ('2026-12-07', 'Festivo', NOW()), -- Traslado del Día de la Constitución
  ('2026-12-08', 'Festivo', NOW()), -- Inmaculada Concepción
  ('2026-12-25', 'Festivo', NOW())  -- Navidad
ON CONFLICT (fecha) DO UPDATE
SET tipo = EXCLUDED.tipo,
    actualizado_en = NOW();
```

La consulta no incluye los festivos locales, que dependen del municipio. Añádelos también a `dias_especiales` si deben excluirse de las previsiones. Mantén actualizado el calendario para cada año.
