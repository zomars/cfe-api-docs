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

# Consulta vía el proveedor MiCFE (la vía soportada de aquí en adelante): enrola
# el RPU como servicio en una cuenta de CFE y descarga su recibo. Requiere
# total_a_pagar (monto actual a pagar del recibo, sin decimales); CFE valida
# rpu + nombre (razón social) + total_a_pagar. El nombre debe ser la razón social.
TOTAL_A_PAGAR="1234"
curl -X POST https://cfe-api.fly.dev/api/v1/consulta \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"rpu\":\"$RPU\",\"nombre\":\"$NOMBRE\",\"provider\":\"micfe\",\"total_a_pagar\":\"$TOTAL_A_PAGAR\"}"

# Consulta de un periodo anterior (recibo completo de ese mes, incl. desglose
# horario en tarifas como GDMTH). 1 crédito por periodo; repetirlo es gratis.
# Con micfe incluye total_a_pagar (el enrolamiento puede ocurrir en la llamada).
curl -X POST https://cfe-api.fly.dev/api/v1/consulta \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"rpu\":\"$RPU\",\"nombre\":\"$NOMBRE\",\"provider\":\"micfe\",\"total_a_pagar\":\"$TOTAL_A_PAGAR\",\"periodo\":\"2026-06\"}"
# El portal lista el historial mensual completo del servicio enrolado
# (típicamente varios años); un periodo fuera regresa 404 con los disponibles.

# Saldo
curl https://cfe-api.fly.dev/api/v1/balance \
  -H "X-API-Key: $API_KEY"
