"""CFE API - Python example.

Requirements: requests (`pip install requests`).
"""
import os
import requests

API = "https://cfe-api.fly.dev"
API_KEY = os.environ["CFE_API_KEY"]


def consulta(rpu: str, nombre: str) -> dict:
    r = requests.post(
        f"{API}/api/v1/consulta",
        headers={"X-API-Key": API_KEY},
        json={"rpu": rpu, "nombre": nombre},
        timeout=120,
    )
    r.raise_for_status()
    return r.json()


def balance() -> dict:
    r = requests.get(f"{API}/api/v1/balance", headers={"X-API-Key": API_KEY})
    r.raise_for_status()
    return r.json()


if __name__ == "__main__":
    result = consulta("123456789012", "JUAN PEREZ")
    data = result["data"]
    print(f"Tarifa: {data['tarifa']}  Anual: {data['annual_kwh']} kWh")
    print(f"Cobrado: {result['charged_cents']/100:.2f} MXN  Cache: {result['cached']}")
