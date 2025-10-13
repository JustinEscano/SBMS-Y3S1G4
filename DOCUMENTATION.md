# SBMS LLM - Full Documentation

## 1) Overview

This LLM service analyzes sensor, maintenance, and energy data to produce: anomalies, insights, weekly summaries, energy reports (daily/monthly/yearly), and billing suggestions. It connects to PostgreSQL (via Django/psycopg2), and serves a Flask API consumed by the web UI.

Key data sources (matching Fake2.sql):
- `core_sensorlog` – raw sensor readings
- `core_alert` – system alerts (temperature_high, energy_anomaly, etc.)
- `core_energysummary` – aggregated energy per period (daily)
- `core_billingrate` – rates per room or global (currency, time window, validity)

## 2) Architecture

- Backend: `llm/static_remote_LLM/apillm.py` (Flask endpoints)
- LLM/handlers: `llm/static_remote_LLM/main.py`, `advanced_llm_handlers.py`, `prompts_config.py`
- DB access: `llm/static_remote_LLM/database_adapter.py`
- Frontend: `web/src/features/pages/LLMChatPage.tsx`

DB connection (default): host=localhost, database=sbmsdb, user=postgres, password=9609, port=5432
Ensure Fake2.sql is imported into that database, or update these values accordingly.

## 3) Endpoints

- POST /llmquery
  - Body: { "query": string, "user_id": string, "username": string }
  - Returns: { answer, sources?, anomalies?, metrics? }

- POST /anomalies/detect
  - Headers: X-User-Role: technician|facility_manager|...
  - Body: { "sensitivity"?: number }
  - Returns: { summary { total_anomalies, critical, high, medium }, anomalies[], alerts[], next_steps[] }

- POST /insights/energy
  - Body: { "query"?: string }
  - Returns: energy analysis and patterns

- POST /energy/report
  - Body: { period: "daily"|"monthly"|"yearly", room_id?: string, start?: ISO, end?: ISO }
  - Returns: { totals { total_energy, total_cost }, groups[] by period + room }

- POST /maintenance/predict
  - Predictive maintenance with fallbacks

- POST /reports/weekly
  - Weekly executive summary

- POST /rooms/utilization
  - Room usage metrics

- POST /context/analyze
  - Current system context

- POST /billing/rates
  - Body: { room_id?: string, at?: ISO }
  - Returns: { rates[] (with effective_rate_php), suggestions[] }

### CLI Examples

```bash
curl -X POST http://localhost:5000/anomalies/detect \
  -H 'Content-Type: application/json' -H 'X-User-Role: facility_manager' \
  -d '{"sensitivity":0.85}'

curl -X POST http://localhost:5000/energy/report \
  -H 'Content-Type: application/json' -H 'X-User-Role: energy_analyst' \
  -d '{"period":"monthly","room_id":"f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c"}'

curl -X POST http://localhost:5000/billing/rates \
  -H 'Content-Type: application/json' -H 'X-User-Role: energy_analyst' \
  -d '{"room_id":"f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c","at":"2025-10-04T12:00:00Z"}'
```
  - Current system context

## 4) What you can ask (prompts)

- "Detect any anomalies"
- "Show unresolved alerts"
- "Which room has highest energy this week?"
- "Generate weekly summary"
- "What's the current room status?"
- "Show me energy consumption trends"
- "Give me a daily energy report"
- "Monthly energy cost for Conference Room A"
- "List active billing rates and suggestions"

## 5) Alerts & Anomalies

- Alerts from `core_alert` are converted to anomaly entries and counted in totals (severity mapping: high→Critical, medium→High, low→Medium).
- Actionable next steps are generated for unresolved/high alerts (temperature, humidity, energy, motion).
- Sensitivity can be tuned via request body (default 0.8).

## 6) Energy & Billing

- Energy anomaly costs prefer room-specific `core_billingrate`. Currency coerced to PHP; USD converted (~×56).
- If no applicable rate, a default PHP rate is used.
- `/energy/report` aggregates `core_energysummary` by day/month/year and room.
- `/billing/rates` exposes configured rates and provides optimization suggestions (e.g., convert to PHP, off-peak usage).

## 7) Frontend (LLMChatPage)

- The anomalies flow calls `/anomalies/detect` and renders anomalies, alerts, and next steps.
- Buttons in the input bar:
  - ⚠️ Detect anomalies
  - 📅 Daily energy report
  - 🗓️ Monthly energy report
  - 📆 Yearly energy report
  - 💱 Billing rates

## 8) Troubleshooting

- Totals show 0: ensure DB used by Flask contains data (e.g., loaded from `Fake2.sql`) and within time window; use sensitivity and widen days_back if needed.
- Alerts missing: verify `core_alert` column names match (type, severity, triggered_at, resolved).
- Costs look wrong: check `core_billingrate` entries and currency; PHP is expected.

## 9) Notes

- This system uses PostgreSQL via Django + psycopg2.
- All report costs are expressed in PHP for consistency.
 
## 10) FAQ

- How does the service decide the PHP rate?
  - It picks a room-specific rate valid at the query time; else a global rate; else the latest rate. Non-PHP currencies are converted to PHP.
- Can I override conversion?
  - Yes. Update the conversion logic in `advanced_llm_handlers.py` if needed.
- Can I add more prompts?
  - Extend `advanced_prompts.json` (UTF‑8) or modify `prompts_config.py` defaults.
