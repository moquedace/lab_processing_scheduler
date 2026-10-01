# lab_processing_scheduler — contexto completo do projeto

> Documento de handoff. Objetivo: qualquer pessoa ou IA que receber este arquivo
> deve conseguir entender o projeto, o estado atual, as decisões já tomadas e
> continuar o trabalho sem precisar reconstruir nada.
>
> Gerado em **2026-09-18**, a partir do estado do repositório no commit
> `1798d2d` (branch `main`, sincronizada com `origin/main`).
> **Não contém segredos.** Nenhum valor de senha, URL de planilha ou credencial
> foi (nem deve ser) colocado aqui.

---

## 0. Leia primeiro (instruções para a IA que receber este arquivo)

1. **Idioma**: responda em português. Identificadores de código, nomes de
   arquivos, colunas e abas estão em inglês; textos de interface, mensagens ao
   usuário e comentários explicativos estão em português.
2. **Execução de R é do usuário.** Você provavelmente não tem `Rscript` no
   PATH (no ambiente onde o projeto foi desenvolvido não tinha). Não tente rodar
   scripts `.R`; entregue o comando e peça para o Cassio rodar no console do
   RStudio, depois peça o resultado.
3. **Segredos — regra inegociável.** Nunca adicionar ao Git: `secrets/`,
   `shiny_app/secrets/`, `*.json`, `shiny_app/.Renviron`, `.Renviron`. Sempre ler
   credenciais via `Sys.getenv("LAB_SCHEDULER_ADMIN_PASSWORD")` e
   `Sys.getenv("LAB_SCHEDULER_SHEET_URL")`. Nunca colar valores reais em código,
   README, commits, issues ou neste arquivo.
4. **Pipe**: usar sempre `%>%` (magrittr), nunca `|>`. Ver seção 16 — há
   violações antigas ainda não corrigidas.
5. **Estilo**: comentários de seção em linha única, minúscula, com traços até
   ~78 colunas; nada de blocos de `====`. Nomes de arquivos exportados em
   minúsculo/snake_case/sem acento.
6. **Commit e push só quando o usuário pedir.** Mensagens de commit em inglês,
   no imperativo, com corpo explicando o porquê (é o padrão do histórico).
7. **Deploy no shinyapps.io é manual** e feito pelo usuário. Push no GitHub
   atualiza o GitHub Pages sozinho, mas **não** atualiza o app Shiny.
8. **Encoding**: todos os `.R` são UTF-8 sem BOM. Se aparecer `Ã§`, `Ã£`, `Ã©`
   etc. no texto, é dupla codificação (ver seção 15).

---

## 1. Resumo executivo

Sistema institucional de **reserva e monitoramento de dois computadores de
processamento (Super 1 e Super 2)** do **GeoCiS — Grupo de Geotecnologias em
Ciência do Solo**, Departamento de Ciência do Solo, ESALQ/USP (apoio FAPESP).

Três peças:

| Peça | Tecnologia | Onde roda | URL |
|---|---|---|---|
| Página institucional (portal) | HTML/CSS estático gerado por script R | GitHub Pages, servido de `docs/` | https://moquedace.github.io/lab_processing_scheduler/ |
| App operacional | R Shiny + bslib | shinyapps.io (conta `moquedace`) | https://moquedace.shinyapps.io/lab_processing_scheduler/ |
| Banco de dados | Google Sheets (8 abas) | Google Drive | (URL fica só em variável de ambiente) |

Autenticação máquina-a-máquina no Google via **service account** (JSON), sem
interação humana. Repositório: https://github.com/moquedace/lab_processing_scheduler
(usuário GitHub `moquedace`). Responsável: Cassio, pesquisador do GeoCiS.

**Primeira versão estável fechada** (declarado pelo usuário em 2026-09-18) e
commitada no GitHub.

---

## 2. Estado atual (2026-09-18)

- Branch `main`, working tree limpo, sincronizada com `origin/main`. ~44 commits;
  o mais antigo é de 2026-05-11.
- Últimos commits relevantes (do mais novo):
  - `1798d2d` silencia (com `suppressWarnings`) o aviso esperado no teste de
    `finish_usage_row` sem linha aberta — só mexeu em `scripts/07_...`, não
    exige redeploy
  - `a7a4c6c` correções da auditoria geral (código morto, tabela de pendências,
    `warning()` em `finish_usage_row`, `time_choices` movida, `.dcf` destracked)
  - `7a57ebc` estabiliza polling do teste de UI contra escritas no Sheets
  - `9a5f350`, `b675950` correção de dupla codificação UTF-8
  - `a5582b8` tratamento de abas operacionais vazias
  - `09734d0` `05_deploy` passa a rodar `04_prepare` automaticamente
- **App no shinyapps.io**: deployado depois de `a7a4c6c`; está equivalente ao
  código atual (o commit `1798d2d` não altera o app).
- **GitHub Pages**: atualizado (deploy automático no push).
- Working copy usa **sparse-checkout**: `git rm --cached` precisa de `--sparse`
  para caminhos fora da definição.

---

## 3. Arquitetura

```
Usuário / admin
   │
   ├── GitHub Pages (docs/index.html)       portal estático, links para o app
   │
   └── shinyapps.io (shiny_app/app.R)       interface operacional
            │  googlesheets4 + gargle (service account)
            ▼
        Google Sheets  ── abas: users, computers, lists, priority_rules, settings
                                reservations, usage_log, audit_log
```

### 3.1 Fluxo de leitura no app

- **Tabelas estáticas** (`users`, `computers`, `lists`, `priority_rules`,
  `settings`): reativo `static_tables()`, depende **só** de `reload_key()`.
  Relidas apenas em recarga explícita (após envio de reserva ou ação admin).
- **Tabelas dinâmicas** (`reservations`, `usage_log`, `audit_log`): reativo
  `dynamic_tables()`, depende de `auto_refresh()` (`reactiveTimer(60000)`) e de
  `reload_key()`. Relidas a cada 60 s.
- `database()` = `c(static_tables(), dynamic_tables())` → lista nomeada com as
  8 tabelas. Derivados: `users()` (só ativos), `computers()` (ativos e
  reserváveis), `lists()` (só `active == "TRUE"`), `settings()` (idem),
  `priority_rules()`, `reservations()`, `audit_log()`.
- Motivo da separação: poupar cota da API do Google Sheets.

### 3.2 Padrão de escrita (importante)

Toda escrita é **sobrescrita da aba inteira**: `range_clear()` seguido de
`range_write()` em `A1` (função `write_sheet_to_workbook()` em `01_sheets.R`).
O fluxo é: ler snapshot reativo → `align_tables_as_character()` (alinha colunas,
tudo vira `character`) → `bind_rows()` → reescrever a aba. Consequências
registradas na seção 17 (concorrência, atomicidade).

Nomes legados: `write_sheet_to_workbook` e `database_file` vêm da fase inicial
em que o banco era um `.xlsx` local (commits de 2026-05-11/12). Hoje escrevem no
Google Sheets; `database_file` é só um alias de `sheet_url`. O `.gitignore`
ainda tem entradas `data/database/*.xlsx` dessa época.

---

## 4. Estrutura de pastas

```
lab_processing_scheduler/
├── .gitignore
├── README.md                     documentação pública do repositório
├── project_context.md            ESTE arquivo
├── lab_processing_scheduler.Rproj   UTF-8, 2 espaços, sem paths de usuário
├── docs/                         GitHub Pages (versionado)
│   ├── index.html                GERADO por scripts/06 — não editar à mão
│   └── assets/{css/main.css, img/*.png}   logos + og-preview.png
├── scripts/                      01…13 e 06b (seção 9)
├── shiny_app/
│   ├── app.R                     servidor + boot (~1270 linhas)
│   ├── R/01…09_*.R               módulos (seção 6)
│   ├── www/img/*.png             logos servidos pelo Shiny (cópia de docs/assets/img)
│   ├── secrets/                  NUNCA versionado; some após deploy (seção 12)
│   ├── .Renviron                 NUNCA versionado; escrito pelo script 05
│   └── rsconnect/                metadados de deploy (gitignored, destracked)
├── secrets/google_service_account.json   FONTE da credencial (local, gitignored)
├── .r-lib/                       biblioteca local de pacotes (gitignored)
└── (locais, gitignored) .Rproj.user/, .Rhistory, docs/index_backup_*.html
```

- `docs/index_backup_*.html`: backups automáticos gerados pelo script 06 a cada
  regeneração; ficam só na máquina do Cassio (10 arquivos em 2026-09).
- Dois backups antigos (`index_backup_20260513_004136/004157.html`) estão no
  **histórico** do Git (commitados e depois apagados em maio). São HTML estático
  sem segredos.
- As logos existem em **dois lugares**: `docs/assets/img/` (fonte) e
  `shiny_app/www/img/` (cópia feita por `scripts/04`). Se trocar uma logo, troque
  em `docs/` e rode o 04.

---

## 5. Banco de dados (Google Sheets)

Todas as colunas são lidas como texto (`col_types = "c"`), com `str_trim`, e
colunas fantasma `...N` do Sheets são descartadas. Booleanos são as strings
`"TRUE"`/`"FALSE"`. Datas/horas são texto `%Y-%m-%d %H:%M:%S` no fuso da
setting `timezone` (padrão `America/Sao_Paulo`).

O schema canônico está duplicado em **três** lugares — mudar um exige mudar os
outros: `sheet_columns` em `shiny_app/R/01_sheets.R`, `required_columns` em
`scripts/01_validate_database.R` e `required_columns` em
`scripts/13_reset_operational_sheets.R` (este só para as 3 abas operacionais);
a `usage_log` também aparece em `scripts/11_migrate_usage_log_schema.R`.

| Aba | Colunas (ordem) |
|---|---|
| `users` | user_id, full_name, email, user_level, user_level_label, advisor, project_or_group, status, can_book, priority_base, notes, created_at, updated_at |
| `computers` | computer_id, computer_name, computer_label, processor, cores, threads, ram_gb, gpu, gpu_memory_gb, main_profile, status, can_be_booked, public_description, notes |
| `reservations` | reservation_id, created_at, updated_at, user_id, computer_requested, computer_assigned, start_time, end_time, estimated_hours, main_environment, processing_type, computing_demand, uses_gpu, requires_super_2, can_be_reallocated, deadline, justification, priority_score, status, approval_mode, approved_by, approved_at, rejected_by, rejected_at, cancelled_by, cancelled_at, admin_notes, public_notes |
| `lists` | list_name, value, label, sort_order, active |
| `priority_rules` | (app) rule_id, rule_group, condition_value, user_level, points, active — (validação) rule_id, rule_group, condition_value, points, **description**, active — ver inconsistência na seção 17 |
| `usage_log` | usage_id, reservation_id, user_id, computer_id, started_at, finished_at, duration_hours, started_by, finished_by, finish_reason, notes |
| `audit_log` | log_id, event_time, event_type, reservation_id, user_id, admin_user, old_value, new_value, notes |
| `settings` | setting_name, setting_value, description, active |

### 5.1 Vocabulários usados pelo código

- **Status de reserva**: `pending`, `approved`, `rejected`, `cancelled`,
  `in_use`, `finished` (rótulos vêm da lista `reservation_status`).
- **Status de usuário**: `active` / `inactive`. **Status de computador**:
  `active` / `inactive` / `maintenance`.
- **`approval_mode`**: `automatic` / `manual`.
- **`event_type` do audit_log**: `reservation_approved`, `reservation_rejected`,
  `reservation_cancelled`, `reservation_start_use`, `reservation_finish_use`.
- **Listas (`lists.list_name`) que o app consulta**: `computer_requested`,
  `computer_assigned`, `main_environment`, `processing_type`,
  `computing_demand`, `yes_no`, `reservation_status`, `finish_reason`,
  `user_level`. `computer_requested` inclui o valor `any`.
- **Valores hardcoded que o app assume existirem nas listas**: `any`, `r`,
  `raster_processing`, `unknown`, `yes`, `no`; para `finish_reason`, o app cai em
  `"completed"` se a lista estiver vazia.
- **Níveis de usuário mencionados nos testes**: `undergraduate`, `master`,
  `phd`, `technician`.
- **Grupos de regra de prioridade**: `user_level`, `deadline_within_days`,
  `computing_demand`, `requires_super_2`, `uses_gpu`, `duration_over_hours`,
  `can_be_reallocated`, `main_environment`.
- **Settings consumidas pelo app**: `timezone`, `public_show_pending`,
  `public_show_user_level`, `public_show_processing_type`,
  `public_show_computing_demand`, `allow_auto_approval`,
  `default_auto_approved_status` (padrão `approved`),
  `default_manual_approval_status` (padrão `pending`),
  `manual_approval_user_levels` (lista separada por vírgula),
  `manual_approval_above_hours` (padrão 24),
  `manual_approval_if_requires_super_2`, `manual_approval_if_conflict`,
  `manual_approval_if_unknown_demand` (todas padrão TRUE).
  O script 01 valida como booleanas muitas outras settings
  (`public_show_email`, `maintenance_mode`, `allow_weekend_booking`…) que o app
  **ainda não consome** — existem na planilha, mas não têm efeito.
- **IDs gerados**: `res_YYYYmmdd_HHMMSS_NNNN`, `log_…`, `use_…` (sufixo = número
  aleatório 1000–9999; colisão só se duas geradas no mesmo segundo).

### 5.2 Hardware (informação pública, hardcoded em `scripts/06`)

| | Super 1 | Super 2 |
|---|---|---|
| Perfil | uso geral | alta demanda / prioritário |
| CPU | 2 × Intel Xeon Gold 5120T | AMD Ryzen Threadripper PRO 7985WX |
| Núcleos/threads | 28 / 56 | 64 / 128 |
| RAM | 128 GB | 512 GB |
| GPU | NVIDIA Quadro RTX 4000, 8 GB | NVIDIA RTX 4000 Ada, 20 GB |

A página em `docs/` lê essa lista do script 06; o app lê as specs da aba
`computers`. **Os dois podem divergir** — atualizar em ambos ao mudar hardware.
O código está preparado para um futuro "Super 3" (testes usam esse cenário; o
cabeçalho da página é gerado pela contagem de máquinas).

---

## 6. Módulos do app (`shiny_app/R/`)

`app.R` faz `source(..., local = TRUE)` nesta **ordem fixa** (vetor
`module_files`). Se criar módulo novo, registre nesse vetor **e** em
`required_modules` de `scripts/04_prepare_shinyapps_files.R`.

| Módulo | Conteúdo |
|---|---|
| `01_sheets.R` | `sheet_columns`, `normalize_sheet_schema`, `read_sheet_clean`, `read_static_tables`, `read_dynamic_tables`, `read_database`, `write_sheet_to_workbook`, `align_tables_as_character` |
| `02_settings_lists.R` | `get_active_users/computers/lists/settings`, `get_setting_value/logical/numeric/vector`, `get_choices`, `get_label_from_value` |
| `03_priority.R` | `get_rule_points`, `get_deadline_points`, `get_duration_points`, `calculate_priority_score` |
| `04_public_formatting.R` | `format_audit_public`, `format_datetime_label_vector`, `empty_public_reservation_table`, `format_public_reservations`, `public_computer_status_cards_ui` |
| `05_reservations.R` | conflito, ordem de preferência, sugestão de computador, decisão de aprovação/status, geradores de ID, `create_reservation_row`, `create_audit_row`, `create_usage_row`, `finish_usage_row`, `update_reservation_status` |
| `06_ui_components.R` | `dt_language_pt`, `institutional_header_ui`, `hero_ui`, `footer_ui`, `reservation_preview_ui` |
| `07_theme.R` | `theme_app` (bslib, Inter via Google Fonts, primary `#174c78`) e `app_css` |
| `08_ui.R` | `time_choices` (meia em meia hora) e `ui` (`bslib::page_navbar`, 4 abas) |
| `09_server_public.R` | `register_public_server_outputs()` — cards de status, tabela de próximas reservas, bloco/tabela de pendentes |

O restante da lógica de servidor (formulário, prévia, admin, tabela de reservas)
está em `app.R`.

### 6.1 Abas da UI

1. **Painel público** — hero, cards de status por computador, tabela de
   próximas reservas aprovadas/em uso, tabela de pendentes (se
   `public_show_pending`).
2. **Solicitar reserva** — usuário + confirmação de e-mail cadastrado, computador,
   data/hora de início, duração (0,5–168 h, passo 0,5), ambiente, tipo de
   processamento, demanda, GPU?, exige Super 2?, pode ser realocada?, prazo,
   justificativa, observação pública. Botão "Gerar prévia" → prévia com decisão
   preliminar → "Enviar solicitação".
3. **Reservas** — todas as reservas com status pending/approved/in_use/finished
   (sem filtro de data; rejeitadas e canceladas ocultas).
4. **Administração** — login por senha; painel de reserva selecionada com
   botões Aprovar / Rejeitar / Cancelar / Iniciar uso / Finalizar uso; sub-abas
   "Aprovadas e em uso", "Histórico" (rejected/cancelled/finished) e "Auditoria".

### 6.2 Assets estáticos

`app.R` registra `shiny::addResourcePath("site-assets", <dir>)` apontando para o
primeiro diretório existente entre `shiny_app/www/img`, `<raiz>/shiny_app/www/img`
e `docs/assets/img`. A UI referencia `site-assets/logo_*.png` (não `www/img/`).
Favicon = `site-assets/logo_geocis.png`.

---

## 7. Regras de negócio (o que o código realmente faz)

### 7.1 Conflito de horário — `check_reservation_conflict()`

Considera **apenas** reservas com status `approved` ou `in_use`, no mesmo
`computer_assigned`, com início e fim válidos. Sobreposição estrita
(`inicio_existente < fim_novo` e `fim_existente > inicio_novo`): reservas
**adjacentes não conflitam**. Reservas `pending` **não bloqueiam** ninguém.

### 7.2 Escolha do computador — `suggest_computer_assignment()`

- Candidatos = computadores `status == "active"` e `can_be_booked == "TRUE"`.
- Ordem de preferência por `resource_score = cores + threads×0,25 + ram_gb×0,5
  + gpu_memory_gb×2`: para demandas intensivas (`cpu_intensive`,
  `ram_intensive`, `raster_processing`, `large_data`, `deep_learning`) do **maior
  para o menor**; demais demandas do **menor para o maior**. Sem tabela de
  computadores há fallback fixo `super_2, super_1` / `super_1, super_2`.
- Se o usuário pediu uma máquina específica **que está na lista de candidatos**,
  ela é devolvida **sem checar conflito** (decisão de design: respeita o pedido;
  o conflito é detectado depois e força aprovação manual). Se pediu `any` (ou uma
  máquina indisponível), percorre a ordem de preferência e devolve a primeira
  sem conflito; se todas conflitam, devolve a primeira da ordem.

### 7.3 Aprovação — `decide_approval_mode()` e `decide_reservation_status()`

Aprovação **manual** se qualquer um for verdadeiro: nível do usuário em
`manual_approval_user_levels`; `estimated_hours > manual_approval_above_hours`;
`requires_super_2 == "yes"` e a setting correspondente ligada; conflito e a
setting ligada; demanda `unknown` e a setting ligada. Senão, automática.
O `status` inicial é `default_auto_approved_status` se
`automatic` **e** `allow_auto_approval`; caso contrário
`default_manual_approval_status`. As razões viram o texto "Decisão preliminar".

### 7.4 Prioridade — `calculate_priority_score()`

Soma de pontos de 8 grupos de regra em `priority_rules`. Prazo: usa a regra de
**menor limiar** que cobre os dias restantes (prazo passado = 0). Duração: usa a
regra de **maior limiar estritamente excedido**. **A pontuação é apenas
informativa** (aparece na prévia e é gravada em `priority_score`); ela **não**
participa da decisão de aprovação nem da escolha do computador.

### 7.5 Ciclo de vida de uma reserva

```
pending ──approve──▶ approved ──start_use──▶ in_use ──finish_use──▶ finished
   │                    │
   ├──reject──▶ rejected └──cancel──▶ cancelled
```

- Aprovar/rejeitar/cancelar: atualiza `reservations` + linha em `audit_log`.
- **Iniciar uso**: `status = in_use`, cria linha em `usage_log`
  (`started_at`, `started_by`), audit `reservation_start_use`.
- **Finalizar uso**: `status = finished`; **relê as abas dinâmicas** para pegar o
  `usage_log` fresco, fecha a linha aberta (`finished_at`, `duration_hours`
  em horas com 2 casas, `finished_by`, `finish_reason`), audit
  `reservation_finish_use`.
- `admin_notes` só é sobrescrito quando o admin digita algo (não apaga a nota
  anterior).
- **Não há validação de transição**: os botões funcionam para qualquer reserva
  selecionável (pending/approved/in_use). Ex.: dá para "finalizar uso" de uma
  reserva `approved` que nunca foi iniciada.

### 7.6 Painel público

Card por computador ativo: "Em uso agora" se existe reserva
`approved`/`in_use` com `início ≤ agora ≤ fim`; senão "Disponível agora" e mostra
a próxima reserva `approved` futura (ou "Nenhuma reserva aprovada futura").
Colunas das tabelas públicas dependem das settings `public_show_*`. Nome
ausente vira "Usuário não informado".

---

## 8. Identidade visual

- Tema "sharp-corporate", unificado entre a página `docs/` e o app.
- Tokens CSS em `07_theme.R`: `--primary #174c78`, `--primary-dark #0b2b45`,
  `--primary-soft #e8f2fb`, `--green #0f7a58`, `--orange #a55b12`,
  `--background #eef3f8`, `--surface #ffffff`, `--text-main #101828`,
  `--text-muted #5d6b82`, `--border #e1e8f0`. Fonte: Inter.
- Classes de badge de status: `preview-approved` (verde), `preview-pending`
  (laranja), `preview-neutral` (cinza; finished/cancelled/rejected).
  `machine-badge machine-busy|machine-free` nos cards.
- DataTables: paginação estilizada na paleta azul-marinho; `order = list()` para
  preservar a ordenação feita no R; `dt_language_pt` traduz a interface.
- **Open Graph / social preview**: `docs/index.html` tem `og:*`, `twitter:card`
  (`summary_large_image`), favicon e `apple-touch-icon`. A imagem é
  `docs/assets/img/og-preview.png` (1200×630, fundo `#0b2b45`), gerada por
  `scripts/06b_generate_og_image.R` com `magick`. O título ocupa duas linhas
  (tamanho 58) porque em uma linha estourava a largura.
- Título da seção de acesso na página: "Acesse pelo portal, opere no app."

---

## 9. Scripts (`scripts/`)

Sempre rodar com o **diretório de trabalho na raiz do projeto** (Session > Set
Working Directory > To Project Directory) e via `source("scripts/NN_....R")`.
Todos leem `shiny_app/.Renviron` ou `.Renviron` se existir.

| Script | Função | Efeito colateral |
|---|---|---|
| `01_validate_database.R` | Valida abas, colunas, duplicidade de usuários/e-mails, níveis, status, IDs de computador, regras de prioridade e settings booleanas | só leitura |
| `02_test_google_sheets_connection.R` | Testa conexão com a planilha | só leitura |
| `03_test_google_sheets_service_account.R` | Testa a service account | só leitura |
| `04_prepare_shinyapps_files.R` | Copia logos `docs/…/img → shiny_app/www/img` e o JSON da service account (procura em `LAB_SCHEDULER_SERVICE_ACCOUNT_JSON`, `secrets/`, `shiny_app/secrets/`) para `shiny_app/secrets/`; confere os 9 módulos | cria/sobrescreve arquivos locais |
| `05_deploy_shinyapps.R` | Roda o 04 → confere arquivos → exige as env vars → preflight (01 + 07) → escreve `shiny_app/.Renviron` → `rsconnect::deployApp()` | **publica em produção** |
| `06_update_github_page.R` | Regenera `docs/index.html` (template em R, specs dos computadores hardcoded) | cria backup `index_backup_*.html` e sobrescreve `index.html` |
| `06b_generate_og_image.R` | Gera `docs/assets/img/og-preview.png` (requer `magick`) | sobrescreve a PNG |
| `07_test_shiny_app_logic.R` | Testes de lógica pura (sem credenciais, sem rede): extrai só as funções necessárias por `parse()` e testa em ambiente isolado | nenhum |
| `08_test_shiny_ui.R` | Jornada UI com `shinytest2`/`chromote`: solicitar → aprovar → iniciar/finalizar uso, login errado e certo; confere `reservations`, `audit_log`, `usage_log` no Sheets | **escreve no Sheets** (marcador `AUTOMATED_TEST_*`) |
| `09_cleanup_shiny_test_rows.R` | Remove linhas de teste por marcador (padrão `AUTOMATED_TEST`) | apaga linhas; exige `…CONFIRM=TRUE` |
| `10_run_ui_test_with_first_user.R` | Escolhe o 1º usuário ativo com e-mail, roda o 08 via `Rscript` (até 3 tentativas) e limpa com o 09 | escreve e limpa |
| `11_migrate_usage_log_schema.R` | Migra `usage_log` do schema antigo (`computer_assigned`, `actual_start_time`, `actual_end_time`, `actual_hours`) para o novo; cria aba de backup `usage_log_backup_<timestamp>` | dry-run por padrão; exige `…CONFIRM=TRUE` |
| `12_run_regression_suite.R` | 01 → 07 → 10 em sequência, com auto-limpeza | escreve e limpa |
| `13_reset_operational_sheets.R` | Zera `reservations`, `usage_log`, `audit_log` mantendo cabeçalhos | dry-run por padrão; exige `…CONFIRM=TRUE` |

### 9.1 Variáveis de ambiente

| Variável | Onde é usada | Observação |
|---|---|---|
| `LAB_SCHEDULER_SHEET_URL` | app e todos os scripts de banco | obrigatória |
| `LAB_SCHEDULER_ADMIN_PASSWORD` | app (login admin), 05, 08 | senha única compartilhada |
| `LAB_SCHEDULER_SERVICE_ACCOUNT_JSON` | app, 01–04, 08–11, 13 | caminho do JSON; se ausente, procura nos caminhos padrão; se não achar, cai em `gs4_auth(email = TRUE)` |
| `LAB_SCHEDULER_DEPLOY_SKIP_PREFLIGHT` | 05 | `TRUE` pula 01+07 (não recomendado) |
| `LAB_SCHEDULER_UI_TEST_USER_ID` / `_EMAIL` / `_WRITE` / `_MARKER` | 08 | preenchidas pelo 10 |
| `LAB_SCHEDULER_UI_TEST_AUTO_CLEANUP` | 10, 12 | padrão TRUE; `FALSE` desliga a limpeza |
| `LAB_SCHEDULER_UI_TEST_ATTEMPTS` | 10 | padrão 3 |
| `LAB_SCHEDULER_CHROMOTE_TIMEOUT` | 08 | padrão 60 s |
| `LAB_SCHEDULER_TEST_CLEANUP_MARKER` / `_CONFIRM` | 09 | |
| `LAB_SCHEDULER_MIGRATE_USAGE_LOG_CONFIRM` | 11 | |
| `LAB_SCHEDULER_RESET_OPERATIONAL_CONFIRM` | 13 | desligar após usar (`Sys.unsetenv`) |

Padrão de segurança: ações destrutivas são **dry-run por padrão** e só agem com
a variável `…_CONFIRM = "TRUE"`.

---

## 10. Como configurar do zero

1. Ter o repositório (RStudio, abrir `lab_processing_scheduler.Rproj`).
2. Criar `shiny_app/.Renviron` (nunca commitar):
   ```
   LAB_SCHEDULER_SHEET_URL=<url da planilha>
   LAB_SCHEDULER_ADMIN_PASSWORD=<senha administrativa>
   ```
3. Colocar a service account em `secrets/google_service_account.json` (raiz).
   A service account precisa de acesso **Editor** à planilha.
4. `source("scripts/01_validate_database.R")` para conferir a planilha.
5. Rodar local: `shiny::runApp("shiny_app")`.

---

## 11. Publicação (checklist)

```r
source("scripts/12_run_regression_suite.R")   # opcional, mas recomendado (escreve/limpa no Sheets)
source("scripts/05_deploy_shinyapps.R")       # publica o app (já roda o 04 sozinho)
source("scripts/06_update_github_page.R")     # só se a página institucional mudou
source("scripts/06b_generate_og_image.R")     # só se a imagem de preview mudou
```

Depois: revisar `docs/index.html` / `og-preview.png`, `git commit` e `git push`
(o push atualiza o GitHub Pages).

**Regra prática:** mexeu em `shiny_app/**` → precisa deploy no shinyapps.io.
Mexeu em `docs/**` → basta push. Mexeu só em `scripts/**` ou docs Markdown → nada
a publicar.

Detalhes do 05 que costumam surpreender:
- O 05 **sobrescreve `shiny_app/.Renviron`** com apenas 3 linhas
  (`SHEET_URL`, `ADMIN_PASSWORD`, `SERVICE_ACCOUNT_JSON=secrets/google_service_account.json`).
  Se você guardava outras variáveis nesse arquivo, elas somem.
- O bundle enviado ao shinyapps.io **inclui** o `.Renviron` e o JSON da service
  account (é assim que o app lê as credenciais em produção). O shinyapps.io é
  tratado como ambiente confiável; nada disso vai ao Git.
- O usuário costuma apagar `shiny_app/secrets/` depois do deploy; por isso o 05
  agora chama o 04, que recopia o JSON da raiz `secrets/`.
- O preflight (01 + 07) exige acesso ao Google Sheets; se a rede/credencial
  falhar, o deploy aborta antes de publicar.

---

## 12. Segurança

- Nunca versionados (`.gitignore`): `secrets/`, `shiny_app/secrets/`, `*.json`,
  `shiny_app/.Renviron`, `.Renviron`, `.r-lib/`, `shiny_app/rsconnect/`,
  `.Rproj.user`, `.Rhistory`, `docs/index_backup_*.html`.
- Auditado em 2026-09-18: **nenhum** `.json`, `.Renviron` ou `secrets/` jamais
  entrou no histórico do Git.
- O único arquivo de deploy que estava rastreado por engano
  (`shiny_app/rsconnect/.../lab_processing_scheduler.dcf`, só metadados:
  appId, bundleId, conta, URL — sem token) foi destracked em `a7a4c6c`.
- Login admin: comparação `identical(input$admin_password, senha_do_ambiente)`;
  estado de autenticação só na sessão do navegador. **Todas as ações admin são
  registradas com o literal `"admin"`** — não há identificação individual.
- Repositório e app são públicos; a planilha não é (acesso só via service
  account). Dados de usuários (nome, categoria) aparecem no painel público
  conforme as settings `public_show_*`; e-mails não são exibidos.

---

## 13. Testes

- **`07_test_shiny_app_logic.R`** (rápido, offline): ~20 casos — ordem de
  preferência incluindo Super 3 hipotético, conflitos (sobreposição, adjacência,
  status, máquinas), fallback determinístico, matriz de aprovação, status com
  auto-aprovação desligada, limites de prazo/duração, score composto, colunas de
  `create_reservation_row`/`create_usage_row`, transições de status e carimbos
  de ator, preservação de `admin_notes`, `finish_usage_row` (cálculo de
  horas = 2,5 e caso sem linha aberta). Para carregar funções, o script faz
  `parse()` de cada arquivo e só avalia atribuições de função listadas em
  `required_functions` — **função nova que precise de teste deve ser adicionada
  a essa lista**.
- **`08`/`10`** (jornada UI, exigem credenciais, escrevem no Sheets e limpam).
- **`12`** roda tudo em sequência. É o "comando principal de teste".
- Nota: o teste "finish usage row is no-op…" envolve a chamada em
  `suppressWarnings()` porque a função emite `warning()` nesse caminho por
  design.

---

## 14. Decisões de design tomadas (e por quê)

| Decisão | Motivo |
|---|---|
| Google Sheets como banco | o grupo já administra a planilha; edição manual de cadastros/listas/regras sem código |
| Service account | app roda sem interação humana no shinyapps.io |
| Separar tabelas estáticas e dinâmicas | reduzir chamadas à API e latência; só o dinâmico entra no timer de 60 s |
| Pedido de máquina específica é respeitado mesmo com conflito | conflito força aprovação manual; admin decide |
| Pendentes nunca bloqueiam horário | só reservas aprovadas/em uso ocupam a máquina |
| Prioridade é informativa | aprovação segue regras explícitas de `settings`, não um limiar de score |
| `finish_usage_row` relê o `usage_log` fresco | evita fechar linha com snapshot velho |
| Ações destrutivas em scripts = dry-run + env var de confirmação | evitar apagar dados por engano |
| Scripts 06/06b separados | 06 gera HTML; 06b gera só a imagem (`magick` é dependência pesada) |
| `08_generate_og_image.R` → `06b_…` | havia dois scripts com prefixo 08; agrupado com o gerador da página |
| Removido `app_local_excel.R` e `format_reservations_public` | versões antigas, sem chamadas |
| `time_choices` movida para `08_ui.R` | só a UI usa; removia dependência frágil de ordem de `source` |
| Tabela de pendentes com `include_all = TRUE` | pendência com data já passada precisa continuar visível |

---

## 15. Histórico resumido do desenvolvimento

- **2026-05-11/12**: primeiro protótipo com banco `.xlsx` local; formulário com
  prévia; painel público; conexão com Google Sheets.
- **Meados de mai–jun/2026**: refatoração de app monolítico (~2482 linhas) para
  modular (`app.R` + 9 módulos); área admin com auditoria; página institucional
  no GitHub Pages; unificação do tema (sharp-corporate); scripts 01–10.
- **Jun/2026**: `usage_log` com início/fim de uso; scripts 11–13; suíte de
  regressão; deploy com preflight.
- **Sessão de 2026-09** (esta linha de trabalho):
  - 5 correções de qualidade: IDs crus resolvidos para rótulos na revisão admin
    e nas tabelas; badge de status dinâmico (`preview-neutral`); tabela
    "Reservas" sem filtro de data (`include_all`); `order = list()` nas DT.
  - Favicon + Open Graph + Twitter Card + imagem de preview (corrigida após
    texto cortado/sobreposto).
  - README completo; ajuste de textos da página.
  - Renomeio 08→06b; script 13 commitado; documentação sincronizada.
  - **Correção de dupla codificação UTF-8** em 9–11 arquivos `.R`
    (`b675950`, `9a5f350`). Causa: texto acentuado salvo/lido com encoding errado
    (ex.: `ção` virou `Ã§Ã£o`; travessão virou `â€"`). Correção: ler como
    UTF-8, reinterpretar como Windows-1252 e decodificar como UTF-8 (não bastou
    Latin-1 porque o travessão usa bytes 0x80–0x9F). **Detecção rápida**:
    buscar por `Ã` nos `.R`.
  - `05_deploy` passou a chamar o `04` (erro "Missing required files" quando o
    JSON local em `shiny_app/secrets/` já tinha sido apagado).
  - **Auditoria geral** (`a7a4c6c`): ver seção 14; nada de credencial no
    histórico.

---

## 16. Convenções e armadilhas para quem for editar

**Convenções de código (preferência do Cassio):**
- `%>%` sempre; **nunca** `|>`. Violações atuais: `scripts/06b_generate_og_image.R`
  (linhas 55–56) e `scripts/08_test_shiny_ui.R` (várias) — **pendente corrigir**.
- Comentários de seção: linha única minúscula com traços; sem `====`.
- Documentar mudanças com o porquê (comentário no código; decisões descartadas
  também contam).
- Acentos só em strings e comentários (arquivos UTF-8); nomes de objetos sem
  acento.

**Armadilhas conhecidas:**
- **Encoding**: editar via ferramentas que assumam Latin-1/CP1252 corrompe
  acentos. Sempre UTF-8 sem BOM. O `.Rproj` já força `Encoding: UTF-8`.
- **Git no Windows**: avisos `LF will be replaced by CRLF` são normais aqui.
  O repositório está em sparse-checkout (`--sparse` em `git rm --cached`).
- **Tudo é texto**: comparar `== "TRUE"`, nunca lógico; números vêm como
  string (`as.numeric` explícito).
- **Diretório de trabalho**: os scripts assumem a raiz do projeto (o 01 aborta se
  o nome do diretório não terminar em `lab_processing_scheduler`).
- **Função nova no app**: se quiser testá-la no 07, adicione o nome em
  `required_functions`.
- **Schema novo**: alterar em `01_sheets.R`, `01_validate_database.R`, `13_…`,
  (e `11_…` se for `usage_log`) e na planilha real.
- **Não editar `docs/index.html` à mão**: será sobrescrito pelo script 06.
  Edite o template dentro do 06.
- **Testes de UI escrevem no Sheets de produção** (com marcador e limpeza).
  Não rodar `08`/`10`/`12` enquanto houver uso real sem necessidade.

---

## 17. Pendências e riscos conhecidos (priorizado)

**Médio**
1. **Escrita concorrente / last-writer-wins.** Cada escrita reescreve a aba
   inteira a partir de um snapshot que pode ter até 60 s. Dois envios
   simultâneos (ou usuário + admin) podem se sobrescrever. `submit_booking` e as
   ações admin não relêem a aba antes de gravar (só o "finalizar uso" relê o
   `usage_log`). Mitigação possível: reler a aba imediatamente antes de gravar
   ou migrar para `sheet_append()` nas inserções.
2. **`range_clear` + `range_write` não é atômico.** Falha de rede entre os dois
   passos deixa a aba vazia. Erro aparece como notificação, mas os dados
   perdidos não voltam. Mitigação: fazer backup periódico da planilha ou usar
   escrita que substitua sem limpar antes.
3. **"Uso finalizado" pode aparecer como sucesso sem fechar o `usage_log`.**
   Quando não há linha aberta para a reserva, `finish_usage_row()` só emite
   `warning()` (vai para o log do servidor) e devolve a tabela inalterada; a
   reserva vira `finished` e a notificação de sucesso é exibida. A auditoria
   de 2026-09 adicionou o warning, **mas a interface ainda mostra sucesso**.
   Correção completa: detectar o caso em `app.R` e avisar o admin (ou bloquear
   finalizar sem `start_use`), idealmente validando transições de status.
4. **Sem validação de transição de status** (ver 7.5).

**Baixo**
5. `admin_user` é sempre `"admin"` (sem rastreio individual); senha única.
6. Inconsistência de schema em `priority_rules`: `sheet_columns` (app) tem
   `user_level` e não tem `description`; `01_validate_database.R` exige
   `description` e não `user_level`. Hoje é inofensivo (o app nunca grava essa
   aba e só usa `rule_group`/`condition_value`/`points`/`active`), mas deve ser
   alinhado.
7. Settings validadas no 01 mas não consumidas pelo app
   (`public_show_email`, `maintenance_mode`, `allow_weekend_booking`,
   `business_hours_enabled`, `auto_finish_expired_reservations`…). Ou
   implementar ou remover da validação/planilha para não dar falsa impressão de
   controle.
8. Especificações dos computadores em dois lugares (aba `computers` e lista
   hardcoded no script 06).
9. Nomes legados `write_sheet_to_workbook`/`database_file` (vêm da fase `.xlsx`).
10. `|>` em `06b` e `08` (ver seção 16).
11. IDs com sufixo aleatório de 4 dígitos (colisão improvável, mas possível no
    mesmo segundo).
12. Sem responsividade mobile refinada e sem links diretos por aba (itens de
    baixa prioridade do backlog original).
13. Dois backups HTML antigos permanecem no histórico do Git (inofensivos).

---

## 18. Comandos úteis

```r
# validar a planilha
source("scripts/01_validate_database.R")

# testes rápidos, sem rede
source("scripts/07_test_shiny_app_logic.R")

# regressão completa (escreve e limpa no Sheets)
source("scripts/12_run_regression_suite.R")

# rodar o app local
shiny::runApp("shiny_app")

# zerar dados operacionais (dry-run primeiro; depois confirmar; depois desligar)
source("scripts/13_reset_operational_sheets.R")
Sys.setenv(LAB_SCHEDULER_RESET_OPERATIONAL_CONFIRM = "TRUE")
source("scripts/13_reset_operational_sheets.R")
Sys.unsetenv("LAB_SCHEDULER_RESET_OPERATIONAL_CONFIRM")

# publicar o app
source("scripts/05_deploy_shinyapps.R")
```

```bash
# detectar corrupção de acentos nos fontes
grep -rn "Ã" --include=*.R shiny_app scripts

# estado do repositório
git status
git log --oneline -10
```

---

## 19. Stack e dependências

R ≥ 4.0. Pacotes do app: `shiny`, `bslib`, `googlesheets4`, `gargle`, `dplyr`,
`stringr`, `purrr`, `DT`, `tibble`, `htmltools`, `lubridate`. Scripts:
`rsconnect` (deploy), `magick` (imagem OG), `shinytest2` + `chromote` (testes de
UI), `utf8` (testes de lógica). Biblioteca local em `.r-lib/` (gitignored):
scripts e `app.R` a colocam no início do `.libPaths()` e instalam o que faltar.

---

## 20. Contatos e links

- Responsável: Cassio (GeoCiS/ESALQ/USP) — GitHub `moquedace`.
- Repositório: https://github.com/moquedace/lab_processing_scheduler
- Portal: https://moquedace.github.io/lab_processing_scheduler/
- App: https://moquedace.shinyapps.io/lab_processing_scheduler/
