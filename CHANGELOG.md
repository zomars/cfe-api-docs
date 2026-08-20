# Changelog

Cambios visibles para consumidores de la CFE API. Fechas en horario de México.

## 2026-08-20

### Nuevo
- **Consultas de periodos anteriores** con `"periodo": "YYYY-MM"` en `POST /api/v1/consulta`. Devuelve el recibo **completo** de ese mes — en tarifas horarias (GDMTH) incluye su `desglose` de consumo y demanda por periodo horario, el dato que el `historial` del recibo vigente no trae. Cobro: 1 crédito por (api_key, RPU, periodo); repetir un periodo ya consultado es gratis para siempre (los recibos pasados son inmutables). El portal de CFE sólo expone los recibos más recientes (~4–5 meses en tarifas mensuales, ~1–2 años en bimestrales); un periodo fuera de esa ventana regresa `404` con la lista de periodos disponibles, sin cobrar. Requiere `nombre`. La respuesta incluye el campo `periodo` como eco.
- **`pdf_url` ahora sirve el PDF oficial de CFE** (el CFDI real con Cadena Original, Folio Fiscal y sello del SAT) también para recibos obtenidos por el proveedor GMX, no solo LISA. El archivo se procura en segundo plano al momento de la consulta y se sirve en la misma URL; `pdf_url` nunca es `null`.
- **`request_id`** en cada respuesta de `/api/v1/consulta`, devuelto también en el header `X-Request-ID`. Puedes enviar el tuyo (`X-Request-ID`, alfanumérico ≤64 chars) para correlacionar con tus sistemas. Inclúyelo al reportar problemas.
- **`xml_url`** y **`pdf_url`** documentados como campos a nivel raíz de la respuesta (URLs firmadas temporales al CFDI XML y al PDF oficial).

### Cambios de comportamiento
- **Fallo rápido ante RPU/nombre incorrectos.** Antes una consulta con nombre equivocado podía colgarse varios minutos (reintentos internos + proveedor de respaldo). Ahora responde en un solo intento:
  - Nombre vacío o inválido (p. ej. el literal `"null"`, `"undefined"`) → **400** inmediato.
  - RPU y nombre que no coinciden, o recibo no entregado por CFE → **404** rápido, sin colgarse.
- Se agregaron los estados **`404`** y **`504`** a la tabla de errores; el caso "RPU/nombre no coinciden" pasó de `502` a `404`.

## 2026-07-24 → 2026-08-19

### Nuevo
- **Desglose Base / Intermedia / Punta** (consumo y demanda) para tarifas horarias como **GDMTH**, en el objeto `data.desglose` y en cada entrada de `data.historial`. El histórico incluye solo demanda (CFE no desglosa el consumo histórico por periodo). En tarifas no horarias `desglose` es `null`.
- **`tarifa_reg`** — nombre regulado vigente de la tarifa. Los recibos GDMTH traen `tarifa: "HM"` (código legado) y `tarifa_reg: "GDMTH"`.
- **`hilos`** — hilos del servicio cuando CFE los incluye en el recibo (`null` si no).
