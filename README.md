# Reserva dos Computadores de Processamento

[![Página institucional](https://img.shields.io/badge/GitHub%20Pages-ao%20vivo-0f7a58?logo=github&logoColor=white)](https://moquedace.github.io/lab-processing-scheduler/)
[![App Shiny](https://img.shields.io/badge/shinyapps.io-ao%20vivo-174c78?logo=rstudio&logoColor=white)](https://moquedace.shinyapps.io/lab-processing-scheduler/)
[![Linguagem](https://img.shields.io/badge/R-%3E%3D%204.0-276DC3?logo=r&logoColor=white)](https://www.r-project.org/)

Sistema institucional de reserva e monitoramento das estações de processamento do **GeoCiS — Grupo de Geotecnologias em Ciência do Solo**, Departamento de Ciência do Solo, ESALQ/USP.

![Preview](docs/assets/img/og-preview.png)

---

## Sobre o projeto

O sistema centraliza o agendamento dos computadores de alto desempenho do grupo, com foco em transparência, rastreabilidade e facilidade de uso. O backend é o Google Sheets; a interface é um app Shiny publicado no shinyapps.io; a página institucional é servida pelo GitHub Pages.

**O que o sistema faz:**

- Consulta pública de disponibilidade e próximas reservas aprovadas
- Formulário de solicitação com prévia automática (computador sugerido, prioridade calculada, decisão preliminar)
- Aprovação automática ou manual conforme regras configuráveis
- Painel administrativo protegido por senha (aprovar, rejeitar, cancelar, iniciar uso, finalizar uso)
- Registro de auditoria de todas as ações administrativas
- Log de uso com horário real de início e fim

---

## Arquitetura

```
GitHub Pages (docs/)          →  página institucional estática
Shiny app (shinyapps.io)      →  interface operacional
Google Sheets                 →  banco de dados (8 abas)
gargle / service account      →  autenticação sem interação humana
```

**Fluxo de dados no app:**

```
Google Sheets
  └─ static_tables (users, computers, lists, priority_rules, settings)
       relidas apenas em reload explícito — economiza chamadas à API
  └─ dynamic_tables (reservations, usage_log, audit_log)
       relidas a cada 60 s + reload explícito
```

---

## Estrutura do repositório

```
lab-processing-scheduler/
|-- docs/                        # GitHub Pages (gerado por scripts/06)
|   |-- index.html
|   `-- assets/
|       |-- css/
|       `-- img/                 # logos + og-preview.png
|-- scripts/                     # utilitários, testes e deploy
|   |-- 01_validate_database.R
|   |-- 02_test_google_sheets_connection.R
|   |-- 03_test_google_sheets_service_account.R
|   |-- 04_prepare_shinyapps_files.R
|   |-- 05_deploy_shinyapps.R
|   |-- 06_update_github_page.R
|   |-- 07_test_shiny_app_logic.R
|   |-- 08_generate_og_image.R
|   |-- 08_test_shiny_ui.R
|   |-- 09_cleanup_shiny_test_rows.R
|   |-- 10_run_ui_test_with_first_user.R
|   |-- 11_migrate_usage_log_schema.R
|   `-- 12_run_regression_suite.R
|-- shiny_app/
|   |-- app.R                    # servidor principal
|   |-- R/                       # módulos carregados pelo app.R
|   |   |-- 01_sheets.R
|   |   |-- 02_settings_lists.R
|   |   |-- 03_priority.R
|   |   |-- 04_public_formatting.R
|   |   |-- 05_reservations.R
|   |   |-- 06_ui_components.R
|   |   |-- 07_theme.R
|   |   |-- 08_ui.R
|   |   `-- 09_server_public.R
|   |-- www/img/                 # logos servidos pelo Shiny
|   `-- secrets/                 # nunca vai ao Git (ver .gitignore)
`-- .gitignore
```

---

## Módulos do app (`shiny_app/R/`)

| Módulo | Responsabilidade |
|---|---|
| `01_sheets.R` | Leitura e escrita no Google Sheets; separação static/dynamic |
| `02_settings_lists.R` | Acesso a settings e listas de valores configuráveis |
| `03_priority.R` | Cálculo de pontuação de prioridade por regras |
| `04_public_formatting.R` | Formatação das tabelas públicas (respeita settings) |
| `05_reservations.R` | Criação, atualização, auditoria e log de uso de reservas |
| `06_ui_components.R` | Componentes de UI reutilizáveis (hero, cards, prévia, rodapé) |
| `07_theme.R` | Tema bslib + CSS customizado (identidade visual sharp-corporate) |
| `08_ui.R` | Definição da UI principal (`bslib::page_navbar`) |
| `09_server_public.R` | Outputs do painel público (status dos computadores, tabelas) |

---

## Scripts (`scripts/`)

| Script | Quando usar |
|---|---|
| `01_validate_database.R` | Verificar integridade das abas do Google Sheets |
| `02_test_google_sheets_connection.R` | Testar conectividade com a planilha |
| `03_test_google_sheets_service_account.R` | Validar autenticação via service account |
| `04_prepare_shinyapps_files.R` | Preparar arquivos para o bundle de deploy |
| `05_deploy_shinyapps.R` | Publicar o app no shinyapps.io |
| `06_update_github_page.R` | Regenerar `docs/index.html` a partir do template R |
| `07_test_shiny_app_logic.R` | Suite de testes de lógica pura (21 casos, sem credenciais) |
| `08_generate_og_image.R` | Gerar imagem de preview Open Graph (1200×630 px) |
| `08_test_shiny_ui.R` | Testes de jornada UI/admin com `shinytest2`, incluindo início/fim de uso (requer credenciais) |
| `09_cleanup_shiny_test_rows.R` | Remover linhas de teste do Google Sheets |
| `10_run_ui_test_with_first_user.R` | Executar teste UI completo com o primeiro usuário ativo |
| `11_migrate_usage_log_schema.R` | Migrar `usage_log` do schema antigo para o schema de início/fim de uso |
| `12_run_regression_suite.R` | Rodar validação do banco, testes de lógica e jornada UI em sequência |

---

## Configuração

### Variáveis de ambiente

Crie `shiny_app/.Renviron` com o conteúdo abaixo (**nunca commitar este arquivo**):

```
LAB_SCHEDULER_SHEET_URL=https://docs.google.com/spreadsheets/d/SEU_ID_AQUI
LAB_SCHEDULER_ADMIN_PASSWORD=sua_senha_administrativa
```

### Service account

Coloque o arquivo JSON da service account do Google em:

```
shiny_app/secrets/google_service_account.json
```

A service account precisa ter acesso de **Editor** à planilha do Google Sheets.

### Executar localmente

```r
# No diretório shiny_app/
shiny::runApp()

# Ou a partir da raiz do projeto
shiny::runApp("shiny_app")
```

---

## Deploy

```r
# Publicar no shinyapps.io
source("scripts/05_deploy_shinyapps.R")

# Atualizar a página do GitHub Pages
source("scripts/06_update_github_page.R")
# → commitar e fazer push de docs/index.html

# Regenerar imagem de preview (og:image)
source("scripts/08_generate_og_image.R")
# → commitar e fazer push de docs/assets/img/og-preview.png
```

---

## Testes

```r
# Testes de lógica pura — roda sem credenciais, sem escrita no Sheets
source("scripts/07_test_shiny_app_logic.R")

# Testes de jornada UI — requer .Renviron e service account configurados
source("scripts/10_run_ui_test_with_first_user.R")
```

---

## Segurança

| Nunca vai ao Git | Motivo |
|---|---|
| `shiny_app/secrets/` | Service account JSON com acesso ao Google Sheets |
| `shiny_app/.Renviron` | URL da planilha e senha administrativa |
| `secrets/` | Qualquer credencial adicional |
| `*.json` | Arquivos de credenciais |

Todas as credenciais são lidas via `Sys.getenv()` em runtime.
O `.gitignore` já exclui esses caminhos.

---

## Tecnologias

| Camada | Tecnologia |
|---|---|
| Interface | R Shiny + bslib (Bootstrap 5) |
| Banco de dados | Google Sheets via `googlesheets4` |
| Autenticação | Google service account via `gargle` |
| Tabelas interativas | DT (DataTables) |
| Testes | `shinytest2` + suite de lógica pura em R |
| Deploy do app | shinyapps.io via `rsconnect` |
| Página institucional | GitHub Pages (HTML/CSS estático gerado em R) |

---

## Instituição

Desenvolvido para o **GeoCiS — Grupo de Geotecnologias em Ciência do Solo**  
Departamento de Ciência do Solo · ESALQ · Universidade de São Paulo  

Com apoio da **FAPESP**.

---

## Comando principal de teste

```r
source("scripts/12_run_regression_suite.R")
```

Esse runner executa validação do Google Sheets, testes de lógica e jornada UI/admin
com limpeza automática das linhas criadas pelo teste.

---

## Checklist de publicação

```r
source("scripts/12_run_regression_suite.R")
source("scripts/04_prepare_shinyapps_files.R")
source("scripts/05_deploy_shinyapps.R")
source("scripts/06_update_github_page.R")
source("scripts/08_generate_og_image.R")
```

Depois disso, revisar `docs/index.html`, `docs/assets/img/og-preview.png` e fazer
commit/push para atualizar o GitHub Pages. O deploy do Shiny usa preflight por
padrão e só deve ser pulado com `LAB_SCHEDULER_DEPLOY_SKIP_PREFLIGHT=TRUE`.
