# Changelog

Cambios visibles para consumidores de la CFE API. Fechas en horario de México.

## 2026-09-13

### Nuevo
- **Onboarding de credenciales CFE.** Nuevos endpoints `POST` / `GET` / `DELETE /api/v1/cfe-credentials` (autenticados con tu API key) para registrar tu propia cuenta de CFE (MiEspacio). Al registrarla, `/consulta` usa tu cuenta —donde tus RPU ya están enrolados— en lugar de la cuenta compartida. La contraseña nunca se devuelve en las respuestas.

## 2026-09-12

### Nuevo
- **Proveedor `micfe` (enrolamiento en MiCFE/MiEspacio) — la vía soportada de aquí en adelante.** CFE retiró el portal público anónimo que usaba el proveedor `gmx` (búsqueda por RPU + nombre). El nuevo proveedor `micfe` no hace una búsqueda anónima: **enrola el RPU como un "servicio"** en una cuenta de CFE y luego descarga su recibo. Se activa con `"provider": "micfe"` en el cuerpo o el header `X-CFE-Provider: micfe` en `POST /api/v1/consulta`. El proveedor por defecto sigue siendo `gmx`; `micfe` es opt-in.
- **Nuevo campo `total_a_pagar` en `POST /api/v1/consulta`.** String con el monto actual a pagar del recibo, **sin decimales**. Es **requerido cuando el proveedor efectivo es `micfe`**: CFE lo valida junto con el `rpu` y el `nombre` (que debe coincidir con la **razón social** registrada, más estricta que el nombre impreso). Con el proveedor por defecto no es necesario.

### Cambios de comportamiento
- **El proveedor `micfe` entrega solo el recibo más reciente.** No acepta `"periodo": "YYYY-MM"`; una consulta con `periodo` por `micfe` responde `400`.
- **Semántica de errores del enrolamiento `micfe`:**
  - `400` — falta `total_a_pagar`, o CFE rechaza el enrolamiento porque el `nombre` (razón social) o el `total_a_pagar` no coinciden con su registro (el mensaje trae el texto de CFE).
  - `401` — no hay credenciales de CFE válidas para atender la consulta (falta la credencial o CFE rechazó el login).
  - `409` (nuevo) — la cuenta de CFE requiere un cambio de contraseña obligatorio antes de poder usarse; actualízala en el portal de CFE (MiEspacio) y reintenta.
  - `503` — MiEspacio bloqueó temporalmente el acceso; reintenta tras el `Retry-After` (segundos).

## 2026-09-04

### Cambios de comportamiento
- **`pdf_url` sirve solo el PDF oficial de CFE (CFDI), nunca un facsímil.** Antes, si la generación del PDF oficial fallaba, el servicio servía un render sintético visualmente equivalente. Ahora `pdf_url` entrega **únicamente** el CFDI oficial (con Cadena Original, Folio Fiscal y sello del SAT). Mientras se está generando, un `GET` a `pdf_url` responde **`202`** con header `Retry-After` (segundos) y cuerpo `{"status": "pending"}` — haz polling hasta el `200` con el `application/pdf` oficial. `pdf_url` sigue sin ser nunca `null`.

## 2026-09-02

### Nuevo
- **Portal de facturación self-serve.** Facturas mensuales, recibos de pago y método de pago se administran ahora en el [portal de facturación de Stripe](https://billing.stripe.com/p/login/14AeVfcp14jd3l8fgu8IU00) (login con el correo de registro; Stripe envía un código de acceso). `GET /api/v1/balance` incluye la URL en el nuevo campo `billing_portal` (`null` en keys sin billing metered).

### Cambios de comportamiento
- **Nuevo estado `503` cuando el portal de CFE está fuera de servicio.** Cuando el portal responde con su propio aviso "Por el momento el servicio no se encuentra disponible", la API ahora responde **`503`** con el header `Retry-After` (segundos), en lugar del `404` genérico de antes. El `404` queda reservado para datos que realmente no coinciden (RPU/nombre) o periodos no disponibles: si recibes `503`, tus datos pueden estar bien — solo reintenta más tarde.
- **Pausa automática ante fallos consecutivos del portal.** Tras fallos consecutivos del portal de CFE, la API deja de intentar contra el portal durante una ventana (minutos) y responde `503` de inmediato; `Retry-After` indica cuánto falta. Reintentar antes de esa ventana no acelera nada — el primer intento después de `Retry-After` es el que vuelve a probar el portal.

## 2026-08-28

### Cambios de comportamiento
- **El proveedor `lisa` fue retirado.** GMX (el portal de CFE) es ahora el único proveedor; `provider: "auto"` equivale a `gmx`. Enviar `provider: "lisa"` (en el body o en el header `X-CFE-Provider`) responde `400` con un mensaje explícito de retiro.
- **`nombre` es siempre requerido en `POST /api/v1/consulta`.** Antes, una consulta sin `nombre` se atendía por el proveedor de respaldo (mucho más lento); ahora responde `400` pidiendo el nombre del titular.
- Se retiró el estado **`504`** de la tabla de errores: sólo lo producía el proveedor retirado.
- **La caché ya no sobrevive a la emisión del siguiente recibo.** Antes, un recibo consultado después de su `fecha_corte` se cacheaba 30 días fijos, lo que podía servir un recibo viejo hasta ~3 semanas después de que CFE emitiera el siguiente (notorio en tarifas mensuales como GDMTH). Ahora la expiración se limita a la fecha estimada de emisión del siguiente recibo (fin del siguiente ciclo de facturación + unos días de margen); si el siguiente recibo ya debería existir pero el portal aún no lo publica, la caché expira en 1 día para reintentarlo pronto. El campo `expires_at` de la respuesta refleja este límite.

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
