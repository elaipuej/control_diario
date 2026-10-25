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
6. Los valores se guardan automáticamente tras dejar de escribir un momento. También puedes pulsar **GUARDAR CONTROL**. La aplicación valida que no haya valores negativos y que el sobrante y la merma no superen Inicial + Reposición.

El consumo que muestra la aplicación se calcula como **Inicial + Reposición − Sobrante**. Es una aproximación a las unidades vendidas, no una lectura del sistema de caja. La merma porcentual se calcula sobre Inicial + Reposición.

El indicador de progreso cuenta los productos que tienen al menos un campo rellenado; no necesariamente significa que todos sus campos estén completos. Si no hay conexión, los cambios pendientes se guardan temporalmente en el navegador y se reenvían cuando vuelva internet. No borres los datos del navegador mientras haya registros pendientes.

**Limpiar formulario** borra los campos visibles, no los registros ya guardados. Si vuelves a cargar la misma fecha y usuario, se consultan los datos guardados.

## Gestionar el catálogo

En **Seleccionar productos del día**, la sección **Gestionar catálogo de productos** permite:

- **Añadir** un producto por su nombre. Después de añadirlo, queda marcado para la fecha seleccionada; pulsa **APLICAR SELECCIÓN** para incluirlo en ese día.
- **Quitar** un producto del catálogo activo usando el botón junto a su nombre. La aplicación pide confirmación y conserva los registros históricos del producto.

La gestión modifica el catálogo compartido, no solo el formulario local. Si no puedes añadir o quitar un producto y aparece un error, avisa a la persona responsable de la aplicación.

## Consultar el Dashboard

En `dashboard.html` puedes filtrar los resúmenes por periodo y trabajador. En los periodos personalizados, indica las fechas **Desde** y **Hasta**.

El Dashboard muestra:

- **Resumen del periodo**: consumo estimado, merma, registros, días con datos, unidades iniciales, reposición y sobrante.
- **Comparativas y gráficos**: consumo por trabajador y producto, y los productos con más y menos consumo.
- **Previsión para mañana**: utiliza hasta cuatro registros de los últimos 120 días del mismo día de la semana. Si hay menos de dos registros, no presenta una estimación; con dos o tres, la marca como provisional. Si hay pocos datos para ese día de la semana, puede usar el historial de otros días, indicado con `*`.
- **Preparar**: consumo estimado para mañana menos el sobrante registrado hoy, con un mínimo de cero.
- **Precisión de la previsión** e **Historial reciente**.
- **Exportar CSV**: descarga los registros para abrirlos en una hoja de cálculo.

La previsión es orientativa. No cambia al filtrar por trabajador: se calcula para toda la tienda. El sobrante de hoy se suma entre los registros de los usuarios.

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
