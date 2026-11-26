# Segurança

## Segredos

- Nenhum segredo no repositório. `.env`, `*.tfvars`, `backend.hcl`, `*.tfstate*` e `*.pem` estão no `.gitignore`; só existem os `*.example`.
- Fonte única: **Infisical**.
  - Local: `infisical run --env=dev` injeta as variáveis no compose.
  - Terraform: provider `infisical` com machine identity (Universal Auth, papel Viewer).
  - Pipeline: `Infisical/secrets-action`; o GitHub guarda só o Client ID e o Client Secret da identity.
- As senhas do banco e do Grafana vão do Infisical para o **SSM Parameter Store** (SecureString) e são lidas pelas instâncias na hora do deploy. Elas nunca aparecem no `user_data`, que é visível no console da EC2.
- O GitHub mascara os valores vindos do Infisical nos logs (`infisical-check.yml` demonstra).
- Varredura de vazamentos: `docker run --rm -v "$PWD":/repo zricethezav/gitleaks detect --source /repo -v` (sem achados no histórico).

**Limite conhecido:** o valor lido do Infisical fica no state do Terraform. O bucket é privado, com acesso público bloqueado, versionado e com criptografia (`encrypt = true`).

## Rede

| Origem | Destino | Porta |
|---|---|---|
| Internet | ALB | 80 |
| ALB | Instâncias de aplicação | 80 |
| Instâncias de aplicação | RDS | 5432 |
| Monitoramento | Instâncias de aplicação (`/metrics`) | 8080 |
| Instâncias de aplicação | Loki | 3100 |
| `admin_cidr` (seu IP) | Grafana / Prometheus | 3000 / 3001 |

- RDS em sub-rede privada, sem rota para a internet e `publicly_accessible = false`.
- Nenhuma porta 22: acesso e deploy por SSM.
- O Terraform recusa `admin_cidr = 0.0.0.0/0`.

## Instâncias e containers

- IMDSv2 obrigatório (`http_tokens = "required"`).
- Discos (EC2 e RDS) criptografados.
- API roda como usuário não root (`USER app` no Dockerfile).
- Conexão com o RDS em TLS (`SSL Mode=Require`).
- Nginx envia `X-Content-Type-Options`, `X-Frame-Options` e `Referrer-Policy`.
- Imagens no ECR com varredura de vulnerabilidades no push.

## IAM

- Learner Lab: `LabInstanceProfile` (o lab bloqueia a criação de IAM).
- Contas comuns: `create_iam_resources = true` cria a role de mínimo privilégio de `iam.tf`: SSM Session Manager, pull só dos dois repositórios ECR, leitura só dos três parâmetros do projeto e `kms:Decrypt` apenas via SSM.
- Pipeline: `GITHUB_TOKEN` com `contents: read`.

## Aplicação

- Validação de entrada (Data Annotations) com 400 e mensagens por campo.
- Tamanhos máximos iguais na validação e no banco.
- EF Core com consultas parametrizadas (sem SQL montado à mão).

## O que falta para produção

HTTPS (ACM + domínio), WAF no ALB, RDS Multi-AZ com backups, instâncias em sub-rede privada com NAT, autenticação na API e rotação automática de segredos.
