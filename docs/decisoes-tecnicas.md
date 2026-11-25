# Decisões técnicas

Cada decisão registra o que foi escolhido, por quê e o que se perde com a escolha.

## Aplicação

| Decisão | Motivo | Custo |
|---|---|---|
| ASP.NET Core 8 com Minimal APIs | Pouco código para um CRUD, Swagger e health checks nativos, testes com `WebApplicationFactory` | Menos estrutura que controllers se a API crescer |
| Validação por Data Annotations em `MatchInput` | Rejeita entrada inválida com 400 e mensagens por campo antes de tocar o banco | Regras simples apenas |
| `EnsureCreated` para criar o schema | Sem etapa extra de migração no deploy | Para evoluir o modelo, migrar para EF Core migrations |
| Logs em JSON no stdout | O Alloy coleta direto dos containers e o Loki indexa sem parser | Menos legível no terminal |
| Métricas com prometheus-net | `UseHttpMetrics` gera contagem, latência e status por rota sem código manual | `/metrics` aberto na porta 8080, protegido só pelo security group |
| Nginx serve o frontend e faz proxy de `/api` | Uma origem só (sem CORS) e o ALB checa a pilha inteira em `/api/health` | O Nginx depende do container `backend` na mesma rede |

## Infraestrutura

| Decisão | Motivo | Custo |
|---|---|---|
| Instâncias em sub-rede pública, sem NAT gateway | O NAT custa ~US$ 32/mês e consumiria o orçamento do lab | As instâncias têm IP público; o security group só aceita o ALB e o monitoramento |
| RDS em sub-rede privada, uma zona, sem backup | `destroy` limpo e barato | Não é configuração de produção (ativar `multi_az` e backups) |
| State no S3 com `use_lockfile` | Lock nativo do Terraform ≥ 1.10, sem DynamoDB | Exige Terraform recente |
| Bucket do state criado por script (`bootstrap.sh`) | A política do Learner Lab nega `s3:GetBucketObjectLockConfiguration`, que o provider AWS chama ao gerenciar buckets | O bucket fica fora do Terraform |
| `LabInstanceProfile` no Learner Lab | O lab bloqueia a criação de IAM | Permissões mais amplas que o necessário; `iam.tf` tem a role de mínimo privilégio para contas comuns (`create_iam_resources = true`) |
| Deploy por SSM Run Command, sem SSH | Nenhuma porta 22 aberta, nenhuma chave para guardar, comando auditável no console | Depende do agente SSM e das credenciais do lab |
| Script de deploy gerado pelo `user_data` | Uma única fonte para o primeiro boot e para o pipeline | Mudar o script recria as instâncias |
| ECR com varredura no push e limpeza (10 imagens) | Registro privado na mesma conta, scan de vulnerabilidades gratuito | — |

## CI/CD

| Decisão | Motivo | Custo |
|---|---|---|
| `deploy.yml` reutiliza o `ci.yml` (`workflow_call`) | Uma execução mostra CI e deploy juntos; teste quebrado = deploy pulado | Push na `main` não dispara o `ci.yml` sozinho (evita rodar duas vezes) |
| Tag da imagem = SHA do commit, além de `latest` | Rastreabilidade e rollback por tag | — |
| Deploy uma instância por vez (`--max-concurrency 1`) e health check local no script | A outra instância continua servindo; uma versão quebrada para na primeira | Deploy mais lento |
| Credenciais da AWS no Infisical, não no GitHub | As credenciais do lab mudam a cada sessão; atualizar o Infisical não exige ser admin do repositório e mantém um único lugar para segredos | O pipeline só funciona com o lab ligado e `lab-creds.sh` rodado na sessão |
| Terraform fora do pipeline | O `apply` depende da sessão do lab e cria recursos caros; fica manual e consciente | A infraestrutura não é recriada automaticamente |

## Observabilidade

| Decisão | Motivo | Custo |
|---|---|---|
| Instância dedicada `t3.small` | Prometheus, Loki e Grafana não cabem bem em 1 GB junto com a aplicação | Mais uma instância no orçamento |
| Grafana Alloy em vez do Promtail | O Promtail chegou ao fim de suporte em março de 2026; o Alloy é o sucessor oficial | — |
| Arquivos de `observability/` embutidos no `user_data` (gzip) | Configuração versionada no Git, sem bucket nem clone do repositório | Mudar um arquivo recria a instância de monitoramento (perde o histórico) |
| Alvos do Prometheus por arquivo (`targets.json`) gerado pelo Terraform | IPs privados conhecidos no `apply`, sem permissão extra de `ec2:Describe*` | — |
| URL do Loki em um parâmetro SSM lido no deploy | Evita dependência circular (o monitoramento já depende dos IPs das instâncias) | Os logs só começam depois do primeiro deploy após o `apply` |

## Desvios da proposta

| Proposta | Implementado | Motivo |
|---|---|---|
| Deploy com Ansible | `user_data` + SSM Run Command | Sem SSH no Learner Lab e menos uma ferramenta para manter; o script é idempotente como um playbook |
| HTTPS no ALB | Só HTTP | Exige domínio e certificado (ACM), indisponíveis no lab |
| RDS Multi-AZ | Uma zona | Custo e tempo de criação/destruição |
