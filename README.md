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

Devuelve créditos restantes y estado de billing metered.

## Ejemplos por lenguaje

- [Python](examples/python.py)
- [Node.js](examples/node.js)
- [cURL](examples/curl.sh)
- [Go](examples/go.go)

## Errores

Todas las respuestas de error usan la forma `{"error": "<mensaje en español>"}`.

| Status | Cuándo |
|---|---|
| `400` | RPU malformado, o nombre vacío / inválido (p. ej. el literal `"null"`) |
| `401` | API key faltante o inválida |
| `402` | Sin saldo y sin suscripción metered activa |
| `404` | No se encontró el recibo — el RPU y el nombre del titular no coinciden, o el portal de CFE no lo entregó (falla rápido, sin colgarse) |
| `502` | El proveedor de recibos falló tras reintentos (p. ej. el portal de CFE caído) |
| `504` | El recibo no estuvo listo antes del timeout |

## Cambios

Ver [CHANGELOG.md](CHANGELOG.md) para las novedades de la API.

## Documentación para LLMs/agentes

Disponible en https://cfe-api.fly.dev/llms.txt — formato [llmstxt.org](https://llmstxt.org).

## Soporte

¿Bugs, dudas, requests de campos adicionales? Abre un [issue](https://github.com/zomars/cfe-api-docs/issues).

---

> Originalmente armado para un cotizador solar — abierto al público para que nadie más tenga que pelearse con scraping ni esperar webservices de CFE que no llegan.
