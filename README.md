# control_diario
Aplicación de control diario de productos

Desde “Seleccionar productos del día” se pueden añadir productos al catálogo compartido o quitarlos del catálogo activo. Al quitarlos, sus registros históricos se conservan.

Para habilitar la gestión del catálogo con la clave publicable, ejecuta una vez [`supabase_catalog_public_access.sql`](./supabase_catalog_public_access.sql) en Supabase, en **SQL Editor**. El script permite a visitantes sin iniciar sesión añadir productos y desactivar productos activos mediante funciones RPC limitadas; no concede acceso público directo de escritura a la tabla. Esta opción permite que cualquier persona con acceso a la página modifique el catálogo.
