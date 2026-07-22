#!/bin/sh
# CFE API - cURL example

API_KEY="cfe_xxxxxxxx"
RPU="123456789012"
NOMBRE="JUAN PEREZ"

# Consulta
curl -X POST https://cfe-api.fly.dev/api/v1/consulta \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"rpu\":\"$RPU\",\"nombre\":\"$NOMBRE\"}"
# La respuesta incluye data.hilos cuando CFE lo publica; si no, data.hilos es null.

# Saldo
curl https://cfe-api.fly.dev/api/v1/balance \
  -H "X-API-Key: $API_KEY"
