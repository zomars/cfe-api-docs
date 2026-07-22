// CFE API - Node.js example (Node 18+, uses built-in fetch).

const API = "https://cfe-api.fly.dev";
const API_KEY = process.env.CFE_API_KEY;

async function consulta(rpu, nombre) {
  const r = await fetch(`${API}/api/v1/consulta`, {
    method: "POST",
    headers: { "X-API-Key": API_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ rpu, nombre }),
  });
  if (!r.ok) throw new Error(`${r.status} ${(await r.json()).error}`);
  return r.json();
}

async function balance() {
  const r = await fetch(`${API}/api/v1/balance`, {
    headers: { "X-API-Key": API_KEY },
  });
  return r.json();
}

(async () => {
  const result = await consulta("123456789012", "JUAN PEREZ");
  const { data } = result;
  console.log(`Tarifa: ${data.tarifa}  Anual: ${data.annual_kwh} kWh`);
  console.log(`Hilos: ${data.hilos ?? "no disponible"}`);
  console.log(`Cobrado: ${(result.charged_cents / 100).toFixed(2)} MXN  Cache: ${result.cached}`);
})();
