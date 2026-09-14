# CFE API

API self-serve para obtener datos de recibos de luz de CFE (Comisión Federal de Electricidad, México) en JSON estructurado.

**🔗 Landing y registro:** https://cfe-api.fly.dev

---

## Qué resuelve

Le pasas el **RPU** (12 dígitos del servicio) y el **nombre del titular**, y te regresa el recibo más reciente parseado:

- Consumo histórico hasta 24 meses (mensual o bimestral según tarifa)
- Lecturas del medidor, demanda, factor de potencia
- Tarifa, uso (Doméstico, Comercial...), tipo de consumo (BÁSICO/INTERMEDIO/EXCEDENTE)
- Esquema de generación distribuida (`NETMET` para usuarios con paneles solares) y banco de energía
- Hilos del servicio cuando CFE los incluye en el recibo
- Desglose Base / Intermedia / Punta (consumo y demanda) en tarifas horarias como GDMTH
- Conceptos de facturación, subsidios, DAP
- Fechas de corte, límite y periodo en **ISO 8601**
- URLs firmadas al **XML (CFDI)** y al **PDF oficial del recibo de CFE**

Funciona para tarifas residenciales (1, 1A–1F, DAC) y comerciales (GDMTO, GDMTH, PDBT, etc.).

## Casos de uso

- **Cotizadores de paneles solares** que necesitan consumo anual y tipo de tarifa
- **Apps de finanzas personales** que importan recibos de servicios
- **Análisis de eficiencia energética** para empresas con múltiples sucursales
- **Validación de identidad** por dirección de servicio
- **Dashboards** de consumo para administradores de propiedades

## Cómo funciona

1. Te registras en https://cfe-api.fly.dev con tu correo
2. Pagas el saldo inicial vía Stripe (tarjeta queda guardada)
3. Recibes una API key `cfe_...` al instante
4. Llamas al endpoint con `X-API-Key` y obtienes JSON

Cuando se acaban los créditos prepagados, se factura por uso al cierre del mes (suscripción metered en Stripe). **Errores no se cobran.** Re-consultar el mismo RPU dentro del mismo periodo es gratis para tu cuenta (caché por (api_key, RPU) hasta `fecha_corte`).

## Endpoints

### `POST /api/v1/consulta`

```http
POST /api/v1/consulta
X-API-Key: cfe_xxxxxxxx
Content-Type: application/json

{"rpu": "123456789012", "nombre": "JUAN PEREZ"}
```

Opcionalmente acepta `"periodo": "YYYY-MM"` para pedir el recibo completo de un periodo anterior (incluye su `desglose` horario en tarifas como GDMTH). Se cobra 1 crédito por (api_key, RPU, periodo) y repetir un periodo ya consultado es gratis para siempre; el portal de CFE sólo expone los recibos recientes (~4–5 meses en tarifas mensuales), y un periodo fuera de esa ventana regresa `404` con la lista de disponibles, sin cobrar.

**Proveedor de recibos (MiCFE).** El endpoint acepta opcionalmente el proveedor con el campo `"provider"` en el cuerpo o el header `X-CFE-Provider` (valores: `gmx`, `micfe`, `auto`). El proveedor **`micfe`** es la vía soportada de aquí en adelante: en lugar de una búsqueda anónima por RPU + nombre, **enrola el RPU como un "servicio"** en una cuenta de CFE (MiEspacio) y luego descarga su recibo. Enrolar exige un campo adicional **`total_a_pagar`** (string, el monto actual a pagar del recibo, sin decimales) — **requerido cuando el proveedor efectivo es `micfe`** — que CFE valida junto con el `rpu` y el `nombre` (que debe coincidir con la **razón social** registrada por CFE, más estricta que el nombre impreso). El proveedor `micfe` entrega solo el recibo más reciente: no acepta `periodo`.

```http
POST /api/v1/consulta
X-API-Key: cfe_xxxxxxxx
X-CFE-Provider: micfe
Content-Type: application/json

{"rpu": "123456789012", "nombre": "JUAN PEREZ", "total_a_pagar": "1234"}
```

Respuesta (resumida):

```json
{
  "cached": false,
  "metered": false,
  "charged_cents": 500,
  "fetched_at": 1777415627,
  "expires_at": 1780012799,
  "data": {
    "rpu": "123456789012",
    "nombre": "JUAN PEREZ",
    "tarifa": "1F",
    "uso": "Doméstico",
    "esquema": "NETMET",
    "hilos": "3F-4H",
    "consumo_kwh": 879,
    "annual_kwh": 18027,
    "fecha_corte": "2026-03-31",
    "periodo_desde": "2026-01-14",
    "periodo_hasta": "2026-03-12",
    "historial": [
      {"mes": "ENE", "año": "2026", "consumo_kwh": 633, "bimonthly": true,
       "periodo_desde": "2025-11-13", "periodo_hasta": "2026-01-14"}
    ],
    "conceptos": [
      {"descripcion": "Energía", "importe": 55.65},
      {"descripcion": "IVA 16%", "importe": 8.90}
    ]
  }
}
```

`data.hilos` puede venir como string cuando CFE incluye el dato, o como `null` cuando no aparece en el recibo. Este campo es adicional y no cambia la estructura existente de la respuesta.

#### Campos a nivel raíz

Además de `data`, la respuesta incluye:

- **`request_id`** — identificador de la consulta. Inclúyelo al reportar cualquier problema. También puedes mandar el tuyo en el header `X-Request-ID` (alfanumérico, ≤64 chars) y se te regresa en el body y en el header de respuesta.
- **`xml_url`** — URL firmada temporal al **XML (CFDI)** del recibo.
- **`pdf_url`** — URL firmada temporal al **PDF oficial del recibo de CFE** (el CFDI con Cadena Original, Folio Fiscal y sello del SAT). Es una URL estable: el archivo se procura en segundo plano al momento de la consulta, así que al abrirla obtienes el documento ya listo. **Nunca es `null`.**

```json
{
  "request_id": "a1b2c3d4e5f60718",
  "xml_url": "https://cfe-api.fly.dev/api/v1/xml/123456789012/2026-03-31?e=...&s=...",
  "pdf_url": "https://cfe-api.fly.dev/api/v1/recibo/123456789012/2026-03-31?e=...&s=..."
}
```

#### Desglose horario (tarifas GDMTH y similares)

En tarifas horarias, `data` incluye además `tarifa_reg` (nombre regulado — estos recibos traen `tarifa: "HM"`, el código legado, y `tarifa_reg: "GDMTH"`) y el objeto `desglose` con consumo y demanda por periodo:

```json
{
  "tarifa": "HM",
  "tarifa_reg": "GDMTH",
  "consumo_kwh": 24685,
  "demanda_kw": 139,
  "desglose": {
    "base":       {"consumo_kwh": 2690,  "demanda_kw": 68},
    "intermedia": {"consumo_kwh": 21472, "demanda_kw": 139},
    "punta":      {"consumo_kwh": 523,   "demanda_kw": 14}
  },
  "historial": [
    {"mes": "JUL", "año": "2025", "consumo_kwh": 20312, "demanda_kw": 120,
     "desglose": {"base": {"demanda_kw": 74}, "intermedia": {"demanda_kw": 120}, "punta": {"demanda_kw": 11}}}
  ]
}
```

La suma del consumo de los periodos es igual a `consumo_kwh` y el máximo de las demandas es igual a `demanda_kw`. En el `historial` el desglose incluye sólo demanda (el recibo de CFE no desglosa el consumo histórico por periodo). En tarifas no horarias `desglose` es `null` y el historial no cambia.

### `GET /api/v1/balance`

Devuelve créditos restantes, estado de billing metered y `billing_portal`: la URL del [portal de facturación de Stripe](https://billing.stripe.com/p/login/14AeVfcp14jd3l8fgu8IU00), donde puedes ver tus facturas, descargar recibos de pago y actualizar tu tarjeta (login con el correo de registro; Stripe envía un código de acceso). En keys sin billing metered el campo es `null`.

## Ejemplos por lenguaje

- [Python](examples/python.py)
- [Node.js](examples/node.js)
- [cURL](examples/curl.sh)
- [Go](examples/go.go)

## Errores

Todas las respuestas de error usan la forma `{"error": "<mensaje en español>", "code": "<código estable>"}`. El `code` (snake_case) es el contrato para máquinas: haz branching sobre él, no sobre el mensaje. La lista completa de códigos está en [llms.txt](llms.txt); trata un código no reconocido como un error genérico de su status.

| Status | Códigos | Cuándo |
|---|---|---|
| `202` | — | Solo en `GET pdf_url`: el PDF oficial aún se está generando. Reintenta tras el `Retry-After` (cuerpo `{"status": "pending"}`) |
| `400` | `invalid_request`, `total_a_pagar_required`, `name_mismatch`, `total_mismatch`, `enroll_rejected`, `periodo_not_supported` | RPU malformado, o nombre vacío / inválido (p. ej. el literal `"null"`). Con `micfe`: falta `total_a_pagar`, o CFE rechaza el enrolamiento porque el nombre (razón social) o el total no coinciden con su registro (el mensaje trae el texto de CFE) |
| `401` | `invalid_api_key`, `cfe_credentials` | API key faltante o inválida; o, con `micfe`, no hay credenciales de CFE válidas para atender la consulta |
| `402` | `no_subscription`, `billing_failed` | Sin saldo y sin suscripción metered activa |
| `404` | `not_found` | No se encontró el recibo — el RPU y el nombre del titular no coinciden (falla rápido, sin colgarse), o el `periodo` pedido ya no está disponible |
| `409` | `action_required` | (proveedor `micfe`) La cuenta de CFE requiere un cambio de contraseña obligatorio; actualízala en el portal de CFE (MiEspacio) y reintenta |
| `502` | `provider_error` | El proveedor de recibos falló tras reintentos (error inesperado) |
| `503` | `upstream_unavailable` | El portal de CFE está temporalmente fuera de servicio o inaccesible (incluye el bloqueo temporal de MiEspacio con `micfe`) — no es un problema con tus datos; reintenta después del tiempo del header `Retry-After` (segundos). Tras fallos consecutivos la API responde `503` de inmediato hasta que expira esa ventana |

## Cambios

Ver [CHANGELOG.md](CHANGELOG.md) para las novedades de la API.

## Documentación para LLMs/agentes

Disponible en https://cfe-api.fly.dev/llms.txt — formato [llmstxt.org](https://llmstxt.org).

## Soporte

¿Bugs, dudas, requests de campos adicionales? Abre un [issue](https://github.com/zomars/cfe-api-docs/issues).

---

> Originalmente armado para un cotizador solar — abierto al público para que nadie más tenga que pelearse con scraping ni esperar webservices de CFE que no llegan.
