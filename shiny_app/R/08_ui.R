ui <- bslib::page_navbar(
  title = "Reserva dos Computadores de Processamento",
  theme = theme_app,
  id = "main_nav",
  
  header = tagList(
    tags$head(tags$style(HTML(app_css))),
    institutional_header_ui()
  ),
  
  bslib::nav_panel(
    title = "Painel público",
    hero_ui(),
    tags$div(
      class = "section-card",
      tags$h2("Status atual dos computadores"),
      tags$p(
        "Consulte a disponibilidade atual do Super 1 e Super 2 e acompanhe as próximas reservas aprovadas."
      ),
      uiOutput("public_status_cards")
    ),
    tags$div(
      class = "section-card",
      tags$h2("Próximas reservas aprovadas"),
      tags$p(
        "Agenda pública com as reservas aprovadas em andamento ou futuras."
      ),
      DT::DTOutput("public_upcoming_table")
    ),
    uiOutput("public_pending_block"),
    footer_ui()
  ),
  
  bslib::nav_panel(
    title = "Solicitar reserva",
    tags$div(
      class = "section-card",
      tags$h2("Solicitar reserva"),
      tags$p(
        "Gere a prévia, confira os dados e envie a solicitação. A reserva será gravada no Google Sheets."
      ),
      tags$div(
        class = "form-layout",
        tags$div(
          selectInput(
            inputId = "booking_user_id",
            label = "Selecione seu nome",
            choices = NULL
          ),
          textInput(
            inputId = "booking_email",
            label = "Confirme seu e-mail cadastrado",
            placeholder = "Digite o e-mail cadastrado na base"
          ),
          uiOutput("selected_user_info"),
          tags$h4(class = "form-section-title", "Reserva"),
          selectInput(
            inputId = "booking_computer_requested",
            label = "Computador desejado",
            choices = NULL
          ),
          fluidRow(
            column(
              width = 6,
              dateInput(
                inputId = "booking_start_date",
                label = "Data de início",
                value = Sys.Date(),
                min = Sys.Date(),
                language = "pt-BR",
                weekstart = 0
              )
            ),
            column(
              width = 6,
              selectInput(
                inputId = "booking_start_time",
                label = "Horário de início",
                choices = time_choices,
                selected = "08:00"
              )
            )
          ),
          numericInput(
            inputId = "booking_estimated_hours",
            label = "Duração estimada em horas",
            value = 4,
            min = 0.5,
            max = 168,
            step = 0.5
          ),
          tags$h4(class = "form-section-title", "Processamento"),
          selectInput(
            inputId = "booking_main_environment",
            label = "Ambiente principal",
            choices = NULL
          ),
          selectInput(
            inputId = "booking_processing_type",
            label = "Tipo de processamento",
            choices = NULL
          ),
          selectInput(
            inputId = "booking_computing_demand",
            label = "Demanda computacional principal",
            choices = NULL
          ),
          fluidRow(
            column(
              width = 4,
              selectInput(
                inputId = "booking_uses_gpu",
                label = "Usa GPU?",
                choices = NULL
              )
            ),
            column(
              width = 4,
              selectInput(
                inputId = "booking_requires_super_2",
                label = "Exige Super 2?",
                choices = NULL
              )
            ),
            column(
              width = 4,
              selectInput(
                inputId = "booking_can_be_reallocated",
                label = "Pode ser realocada?",
                choices = NULL
              )
            )
          ),
          dateInput(
            inputId = "booking_deadline",
            label = "Data limite do processamento, se houver",
            value = NULL,
            language = "pt-BR",
            weekstart = 0
          ),
          helpText(
            "Informe apenas se houver uma entrega, reunião, relatório, qualificação, submissão ou outro prazo formal relacionado ao processamento."
          ),
          textAreaInput(
            inputId = "booking_justification",
            label = "Justificativa da solicitação",
            placeholder = "Descreva brevemente o objetivo do processamento, o motivo da escolha do computador e, se houver, o prazo relacionado.",
            rows = 4
          ),
          textAreaInput(
            inputId = "booking_public_notes",
            label = "Observação pública, opcional",
            placeholder = "Exemplo: processamento raster, modelagem espectral, predição em larga escala. Evite informações sensíveis.",
            rows = 2
          ),
          actionButton(
            inputId = "generate_booking_preview",
            label = "Gerar prévia da reserva",
            class = "btn-primary"
          )
        ),
        tags$div(
          uiOutput("booking_preview")
        )
      )
    )
  ),
  
  bslib::nav_panel(
    title = "Reservas",
    tags$div(
      class = "section-card",
      tags$h2("Reservas registradas"),
      tags$p("Tabela com as solicitações gravadas no Google Sheets."),
      DT::DTOutput("reservations_table")
    )
  ),
  
  bslib::nav_panel(
    title = "Administração",
    tags$div(
      class = "section-card",
      tags$h2("Administração"),
      tags$p(
        "Área para aprovar, rejeitar ou cancelar reservas. O acesso exige senha administrativa."
      ),
      uiOutput("admin_panel")
    )
  )
)
