# WeatherWatch — Capstone (Phase 2)

Serverless weather poller on AWS, managed with Terraform (us-east-1):
**API Gateway (HTTP API) → Lambda (LabRole) → reads key from Secrets Manager →
calls OpenWeatherMap once → stores result in on-demand DynamoDB.**

## Capstone review deliverables
- `01-architecture-and-decisions.pdf` — architecture diagram + three decisions (chose / rejected / pillar).
- `02-review-and-fix.pdf` — self-review findings (accept / push-back) + the fix.

## The fix
Self-review finding **F2**: the public `GET /weather` route was unauthenticated with
no throttling. Fixed by adding stage-level throttling (10 req/s, burst 5) in `main.tf`
— see the commit titled *"Fix (self-review F2): throttle public API Gateway route"*.

## Run
```bash
terraform init && terraform apply
curl "$(terraform output -raw weather_endpoint)"
```
