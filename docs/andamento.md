# Andamento e evidências

Situação de cada fase e o que ainda precisa ser executado com o Learner Lab ligado.
O guia de uso está no [README](../README.md).

## Situação

| Fase | Peso | Código | Validado |
|---|---|---|---|
| 0. Definição | entregável 1 | Proposta pronta | Falta registrar a aprovação do professor e preencher a divisão de tarefas |
| 1. Aplicação local | 25% (+10% testes) | Pronto | Sim: compose local com segredos do Infisical, 8 testes passando |
| 2. Infraestrutura | 15% + 20% | Pronto | `apply` ok em 25/11 (40 recursos); falta `destroy` e prints |
| 3. Segredos | 5% | Pronto | Infisical local, Terraform (RDS e Grafana) e pipeline ok, `gitleaks` sem achados; falta rodar o `infisical-check` |
| 4. CI/CD | 15% | Pronto (`ci.yml`, `deploy.yml`) | Execuções com sucesso e com falha registradas (links abaixo); faltam prints |
| 5. Observabilidade | 5% | Pronto (`observability/`, `monitoring.tf`) | Na AWS: 2 alvos `up`, dashboard provisionado, logs das 2 instâncias no Loki; faltam prints |
| 6. Documentação | 5% | README, decisões técnicas e segurança | Falta a demonstração |

## Preparação (uma vez)

- [x] Machine identity no Infisical: copiar o **Client ID** e gerar um **Client Secret** (Access Control → Identities → Universal Auth).
- [x] Cadastrar no Infisical, ambiente `prod`:
  - em `/`: `GF_SECURITY_ADMIN_PASSWORD` (ex.: `openssl rand -hex 16`);
  - em `/ci`: `TF_VAR_infisical_client_id` e `TF_VAR_infisical_client_secret`.
- [x] No GitHub (dono do repositório): secrets `INFISICAL_CLIENT_ID` e `INFISICAL_CLIENT_SECRET`.
- [x] `infra/terraform.tfvars` com `infisical_workspace_id` e `admin_cidr`.

## Sessão de validação (com o lab ligado)

Siga o README, seção "Implantar na AWS", e tire os prints de cada item.

**Fase 2 e 3: infraestrutura com a senha vinda do Infisical**
- [ ] Saída do `terraform apply` (com `app_url`, `grafana_url`, `prometheus_url`).
- [ ] Console AWS: EC2 (3 instâncias), ALB com 2 alvos `healthy`, RDS, ECR com as imagens.
- [ ] `curl $(terraform output -raw app_url)/api/health` → `Healthy` e o frontend aberto pelo `app_url`.
- [ ] Actions → **infisical-check** → Run workflow: log com `POSTGRES_PASSWORD is set` e `Mask test: ***`.

**Fase 4: pipeline (entregável 3)**
- [x] Execução **com sucesso**: push na `main` → `ci` verde → `deploy` verde → `Healthy` no resumo.
- [x] Execução **com falha**: commit que quebra um teste (ex.: trocar `"Ana"` por `"X"` em `Create_PersistsAndIsReturnedByGet`) → `ci` vermelho → `deploy` pulado. Depois, `git revert` e novo push.
- [ ] Guardar os links das duas execuções aqui:
  - sucesso: https://github.com/hmccufrpe/TennisLog/actions/runs/45731551729
  - falha (teste quebrado, deploy pulado): https://github.com/hmccufrpe/TennisLog/actions/runs/45735975620

**Fase 5: observabilidade**
- [ ] Prometheus → Status → Targets: as duas instâncias `UP`.
- [ ] Grafana → dashboard **TennisLog** com tráfego (comando no README).
- [ ] Grafana → Explore → Loki: logs do `backend`.

**Fim da sessão**
- [ ] `terraform destroy` e console sem recursos do projeto (só o bucket do state).

## Fase 0

- [ ] Divisão de tarefas no README.
- [ ] Aprovação da proposta: data ____ / observações do professor: ____

## Demonstração (roteiro)

1. Mostrar o repositório e a arquitetura (README).
2. Fazer um push na `main` e acompanhar o pipeline (CI → build → deploy → health).
3. Abrir a aplicação pelo `app_url` e cadastrar uma partida.
4. Abrir o Grafana: métricas se movendo e logs da requisição que acabou de ser feita.
5. Mostrar o `infisical-check` (segredo mascarado) e o `terraform destroy` no final.

## Entregáveis

- [ ] Proposta aprovada (`docs/proposta.md` + aprovação registrada acima)
- [ ] Repositório organizado e sem segredos
- [ ] Pipeline com evidências (uma execução com falha e uma com sucesso)
- [ ] Aplicação no ar no dia da demonstração
- [ ] Documentação técnica (README, decisões técnicas, segurança)
