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
- Conceptos de facturación, subsidios, DAP
- Fechas de corte, límite y periodo en **ISO 8601**

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
| `400` | RPU malformado o nombre vacío |
| `401` | API key faltante o inválida |
| `402` | Sin saldo y sin suscripción metered activa |
| `502` | No se pudo obtener el recibo (RPU/nombre no coinciden, o el portal de CFE está caído) |

## Documentación para LLMs/agentes

Disponible en https://cfe-api.fly.dev/llms.txt — formato [llmstxt.org](https://llmstxt.org).

## Soporte

¿Bugs, dudas, requests de campos adicionales? Abre un [issue](https://github.com/zomars/cfe-api-docs/issues).

---

> Originalmente armado para un cotizador solar — abierto al público para que nadie más tenga que pelearse con scraping ni esperar webservices de CFE que no llegan.
