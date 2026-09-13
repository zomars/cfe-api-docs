// CFE API - Go example.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

const api = "https://cfe-api.fly.dev"

// provider and totalAPagar are optional (pass ""). total_a_pagar (monto actual a
// pagar, sin decimales) es requerido cuando el proveedor efectivo es "micfe":
// CFE valida rpu + nombre (razón social) + total.
func consulta(rpu, nombre, provider, totalAPagar string) (map[string]any, error) {
	payload := map[string]string{"rpu": rpu, "nombre": nombre}
	if provider != "" {
		payload["provider"] = provider
	}
	if totalAPagar != "" {
		payload["total_a_pagar"] = totalAPagar
	}
	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", api+"/api/v1/consulta", bytes.NewReader(body))
	req.Header.Set("X-API-Key", os.Getenv("CFE_API_KEY"))
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var out map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("%d: %v", resp.StatusCode, out["error"])
	}
	return out, nil
}

func main() {
	result, err := consulta("123456789012", "JUAN PEREZ", "", "")
	if err != nil {
		panic(err)
	}
	data := result["data"].(map[string]any)
	fmt.Printf("Tarifa: %v  Anual: %v kWh\n", data["tarifa"], data["annual_kwh"])
	if hilos, ok := data["hilos"]; ok && hilos != nil {
		fmt.Printf("Hilos: %v\n", hilos)
	} else {
		fmt.Println("Hilos: no disponible")
	}
}
