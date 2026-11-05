# TennisLog

API REST + tela web para registrar partidas e treinos de tênis (projeto de Computação em Nuvem).

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `app/` | Backend (ASP.NET Core, C#) e frontend (HTML/JS estático) |
| `infra/` | IaC (Terraform): rede, EC2, RDS, security groups |
| `.github/workflows/` | Pipelines CI/CD (GitHub Actions) |
| `ansible/` | Playbooks de configuração e deploy das instâncias |
| `observability/` | Prometheus, Grafana, alertas, logs |
| `docs/` | Proposta, diagramas e relatórios das fases |

## Fases
- [x] Fase 0: Definição (`docs/proposta.md`)
