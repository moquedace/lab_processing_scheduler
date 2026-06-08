initial_app_dir <- getwd()
initial_project_root <- if (basename(initial_app_dir) == "shiny_app") {
  dirname(initial_app_dir)
} else {
  initial_app_dir
}
initial_local_library <- file.path(initial_project_root, ".r-lib")
dir.create(initial_local_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(initial_local_library, .libPaths()))

pkg <- c(
  "shiny",
  "bslib",
  "googlesheets4",
  "dplyr",
  "stringr",
  "purrr",
  "DT",
  "tibble",
  "htmltools",
  "lubridate",
  "gargle"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg)
}

invisible(lapply(pkg, library, character.only = TRUE))

rm(list = ls())
gc()

app_dir <- getwd()

project_root <- if (basename(app_dir) == "shiny_app") {
  dirname(app_dir)
} else {
  app_dir
}

sheet_url <- Sys.getenv("LAB_SCHEDULER_SHEET_URL")

if (sheet_url == "") {
  stop("Set LAB_SCHEDULER_SHEET_URL before running the app.")
}

service_account_json <- Sys.getenv("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON")

service_account_candidates <- c(
  service_account_json,
  file.path(app_dir, "secrets", "google_service_account.json"),
  file.path(project_root, "shiny_app", "secrets", "google_service_account.json"),
  file.path(project_root, "secrets", "google_service_account.json")
)

service_account_candidates <- service_account_candidates[
  !is.na(service_account_candidates) &
    service_account_candidates != ""
]

service_account_candidates <- normalizePath(
  service_account_candidates,
  winslash = "/",
  mustWork = FALSE
)

service_account_json <- service_account_candidates[
  file.exists(service_account_candidates)
][1]

if (!is.na(service_account_json) && file.exists(service_account_json)) {
  service_account_token <- gargle::credentials_service_account(
    path = service_account_json,
    scopes = "https://www.googleapis.com/auth/spreadsheets"
  )
  
  googlesheets4::gs4_auth(
    token = service_account_token
  )
} else {
  googlesheets4::gs4_auth(email = TRUE)
}

database_file <- sheet_url

logo_dir_candidates <- c(
  file.path(app_dir, "www", "img"),
  file.path(project_root, "shiny_app", "www", "img"),
  file.path(project_root, "docs", "assets", "img")
)

logo_dir <- logo_dir_candidates[
  dir.exists(logo_dir_candidates)
][1]

if (!is.na(logo_dir) && dir.exists(logo_dir)) {
  shiny::addResourcePath("site-assets", logo_dir)
}

module_files <- c(
  "01_sheets.R",
  "02_settings_lists.R",
  "03_priority.R",
  "04_public_formatting.R",
  "05_reservations.R",
  "06_ui_components.R",
  "07_theme.R",
  "08_ui.R",
  "09_server_public.R"
)

module_dir_candidates <- c(
  file.path(app_dir, "R"),
  file.path(project_root, "shiny_app", "R")
)

module_dir <- module_dir_candidates[
  dir.exists(module_dir_candidates)
][1]

if (is.na(module_dir) || !dir.exists(module_dir)) {
  stop("Could not find shiny_app/R module directory.")
}

for (module_file in module_files) {
  source(file.path(module_dir, module_file), local = TRUE)
}

server <- function(input, output, session) {
  reload_key <- reactiveVal(0)
  last_submitted_id <- reactiveVal(NULL)
  admin_authenticated <- reactiveVal(FALSE)
  auto_refresh <- reactiveTimer(60000, session = session)
  
  # Cadastros e configuração: relidos apenas em recarga explícita (envio,
  # ação administrativa). Não dependem do timer, poupando chamadas à API.
  static_tables <- reactive({
    reload_key()

    validate(
      need(sheet_url != "", "Google Sheets URL not configured.")
    )

    read_static_tables()
  })

  # Reservas, uso e auditoria: relidos no timer e em cada recarga explícita.
  dynamic_tables <- reactive({
    auto_refresh()
    reload_key()

    validate(
      need(sheet_url != "", "Google Sheets URL not configured.")
    )

    read_dynamic_tables()
  })

  # Interface única: database()$users, database()$reservations, etc.
  database <- reactive({
    c(static_tables(), dynamic_tables())
  })
  
  users <- reactive({
    get_active_users(database())
  })
  
  computers <- reactive({
    get_active_computers(database())
  })
  
  lists <- reactive({
    get_active_lists(database())
  })
  
  reservations <- reactive({
    database()$reservations
  })
  
  audit_log <- reactive({
    database()$audit_log
  })
  
  priority_rules <- reactive({
    database()$priority_rules %>%
      dplyr::filter(active == "TRUE") %>%
      dplyr::arrange(rule_id)
  })
  
  settings <- reactive({
    get_active_settings(database())
  })
  
  observe({
    user_choices <- users() %>%
      dplyr::mutate(label = paste0(full_name, " | ", user_level_label)) %>%
      dplyr::arrange(full_name)
    
    updateSelectInput(
      session,
      inputId = "booking_user_id",
      choices = stats::setNames(user_choices$user_id, user_choices$label),
      selected = user_choices$user_id[1]
    )
    
    updateSelectInput(
      session,
      inputId = "booking_computer_requested",
      choices = get_choices(lists(), "computer_requested"),
      selected = "any"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_main_environment",
      choices = get_choices(lists(), "main_environment"),
      selected = "r"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_processing_type",
      choices = get_choices(lists(), "processing_type"),
      selected = "raster_processing"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_computing_demand",
      choices = get_choices(lists(), "computing_demand"),
      selected = "raster_processing"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_uses_gpu",
      choices = get_choices(lists(), "yes_no"),
      selected = "unknown"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_requires_super_2",
      choices = get_choices(lists(), "yes_no"),
      selected = "unknown"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_can_be_reallocated",
      choices = get_choices(lists(), "yes_no"),
      selected = "yes"
    )
  })
  
  selected_user <- reactive({
    users() %>%
      dplyr::filter(user_id == input$booking_user_id) %>%
      dplyr::slice(1)
  })
  
  output$selected_user_info <- renderUI({
    user_tbl <- selected_user()
    
    if (nrow(user_tbl) == 0) {
      return(NULL)
    }
    
    tags$div(
      class = "user-info-box",
      tags$span("Cadastro selecionado"),
      tags$strong(user_tbl$full_name),
      tags$span("Categoria"),
      tags$strong(user_tbl$user_level_label),
      tags$span("Orientador"),
      tags$strong(user_tbl$advisor)
    )
  })
  
  register_public_server_outputs(
    output = output,
    database = database,
    computers = computers,
    reservations = reservations,
    settings = settings,
    lists = lists
  )
  
  booking_preview_data <- eventReactive(input$generate_booking_preview, {
    user_tbl <- selected_user()
    
    estimated_hours_value <- suppressWarnings(
      as.numeric(input$booking_estimated_hours)
    )
    
    deadline_value <- input$booking_deadline
    
    if (is.null(deadline_value) || length(deadline_value) == 0 || is.na(deadline_value)) {
      deadline_value <- NA
    }
    
    validate(
      need(nrow(user_tbl) == 1, "Selecione um usuário válido."),
      need(input$booking_email != "", "Confirme o e-mail cadastrado."),
      need(
        stringr::str_to_lower(input$booking_email) == stringr::str_to_lower(user_tbl$email),
        "O e-mail informado não confere com o e-mail cadastrado."
      ),
      need(
        !is.na(estimated_hours_value) &&
          is.finite(estimated_hours_value) &&
          estimated_hours_value > 0,
        "Informe uma duração válida."
      )
    )
    
    timezone_value <- get_setting_value(
      settings(),
      "timezone",
      "America/Sao_Paulo"
    )
    
    start_time_value <- parse_datetime(
      input$booking_start_date,
      input$booking_start_time,
      timezone_value
    )
    
    end_time_value <- start_time_value + lubridate::dhours(estimated_hours_value)
    
    assigned_computer <- suggest_computer_assignment(
      computer_requested = input$booking_computer_requested,
      computing_demand = input$booking_computing_demand,
      reservations_tbl = reservations(),
      start_time_value = start_time_value,
      end_time_value = end_time_value,
      timezone_value = timezone_value,
      computers_tbl = computers()
    )
    
    has_conflict <- check_reservation_conflict(
      reservations_tbl = reservations(),
      computer_id_value = assigned_computer,
      start_time_value = start_time_value,
      end_time_value = end_time_value,
      timezone_value = timezone_value
    )
    
    priority_score <- calculate_priority_score(
      user_level = user_tbl$user_level,
      deadline_date = deadline_value,
      computing_demand = input$booking_computing_demand,
      requires_super_2 = input$booking_requires_super_2,
      uses_gpu = input$booking_uses_gpu,
      estimated_hours = estimated_hours_value,
      can_be_reallocated = input$booking_can_be_reallocated,
      main_environment = input$booking_main_environment,
      priority_rules_tbl = priority_rules()
    )
    
    approval_decision <- decide_approval_mode(
      user_level = user_tbl$user_level,
      estimated_hours = estimated_hours_value,
      requires_super_2 = input$booking_requires_super_2,
      computing_demand = input$booking_computing_demand,
      has_conflict = has_conflict,
      settings_tbl = settings()
    )
    
    reservation_status <- decide_reservation_status(
      approval_mode = approval_decision$mode,
      settings_tbl = settings()
    )
    
    choices_computer_requested <- get_choices(lists(), "computer_requested")
    choices_computer_assigned <- get_choices(lists(), "computer_assigned")
    choices_environment <- get_choices(lists(), "main_environment")
    choices_processing <- get_choices(lists(), "processing_type")
    choices_demand <- get_choices(lists(), "computing_demand")
    choices_yes_no <- get_choices(lists(), "yes_no")
    
    list(
      user_id = user_tbl$user_id,
      user_name = user_tbl$full_name,
      user_level = user_tbl$user_level,
      user_level_label = user_tbl$user_level_label,
      computer_requested = input$booking_computer_requested,
      computer_requested_label = names(choices_computer_requested)[
        match(input$booking_computer_requested, choices_computer_requested)
      ],
      computer_assigned = assigned_computer,
      computer_assigned_label = names(choices_computer_assigned)[
        match(assigned_computer, choices_computer_assigned)
      ],
      start_time = start_time_value,
      start_time_label = format_datetime_label_pt(
        start_time_value,
        timezone_value
      ),
      end_time = end_time_value,
      end_time_label = format_datetime_label_pt(
        end_time_value,
        timezone_value
      ),
      estimated_hours = estimated_hours_value,
      main_environment = input$booking_main_environment,
      main_environment_label = names(choices_environment)[
        match(input$booking_main_environment, choices_environment)
      ],
      processing_type = input$booking_processing_type,
      processing_type_label = names(choices_processing)[
        match(input$booking_processing_type, choices_processing)
      ],
      computing_demand = input$booking_computing_demand,
      computing_demand_label = names(choices_demand)[
        match(input$booking_computing_demand, choices_demand)
      ],
      uses_gpu = input$booking_uses_gpu,
      uses_gpu_label = names(choices_yes_no)[
        match(input$booking_uses_gpu, choices_yes_no)
      ],
      requires_super_2 = input$booking_requires_super_2,
      requires_super_2_label = names(choices_yes_no)[
        match(input$booking_requires_super_2, choices_yes_no)
      ],
      can_be_reallocated = input$booking_can_be_reallocated,
      can_be_reallocated_label = names(choices_yes_no)[
        match(input$booking_can_be_reallocated, choices_yes_no)
      ],
      deadline = deadline_value,
      justification = input$booking_justification,
      public_notes = input$booking_public_notes,
      priority_score = priority_score,
      has_conflict = has_conflict,
      approval_mode = approval_decision$mode,
      approval_reason = paste(approval_decision$reasons, collapse = "; "),
      status = reservation_status
    )
  })
  
  output$booking_preview <- renderUI({
    preview <- booking_preview_data()
    reservation_preview_ui(preview)
  })
  outputOptions(output, "booking_preview", suspendWhenHidden = FALSE)
  
  observeEvent(input$submit_booking, {
    preview <- booking_preview_data()
    req(preview)
    
    timezone_value <- get_setting_value(settings(), "timezone", "America/Sao_Paulo")
    new_reservation <- create_reservation_row(preview, timezone_value)
    
    aligned_reservations <- align_tables_as_character(
      reference_tbl = reservations(),
      new_tbl = new_reservation
    )
    
    reservations_updated <- dplyr::bind_rows(
      aligned_reservations$reference_tbl,
      aligned_reservations$new_tbl
    )
    
    tryCatch(
      {
        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "reservations",
          data_tbl = reservations_updated
        )
        
        last_submitted_id(new_reservation$reservation_id[1])
        reload_key(reload_key() + 1)
        
        showNotification(
          paste0(
            "Solicitação enviada com sucesso: ",
            new_reservation$reservation_id[1]
          ),
          type = "message",
          duration = 6
        )
        
        updateTabsetPanel(session, "main_nav", selected = "Reservas")
      },
      error = function(e) {
        showNotification(
          paste(
            "Não foi possível gravar a solicitação no Google Sheets.",
            e$message
          ),
          type = "error",
          duration = 10
        )
      }
    )
  })
  
  output$admin_panel <- renderUI({
    if (!admin_authenticated()) {
      return(
        tags$div(
          class = "form-layout",
          tags$div(
            passwordInput(
              inputId = "admin_password",
              label = "Senha administrativa",
              placeholder = "Digite a senha administrativa"
            ),
            actionButton(
              inputId = "admin_login",
              label = "Entrar",
              class = "btn-primary"
            )
          ),
          tags$div(
            class = "empty-preview",
            tags$h3("Acesso restrito"),
            tags$p(
              "Use esta área apenas para revisar solicitações e alterar status de reservas."
            )
          )
        )
      )
    }
    
    admin_reservations <- reservations() %>%
      dplyr::filter(status %in% c("pending", "approved", "in_use")) %>%
      dplyr::left_join(
        database()$users %>% dplyr::select(user_id, full_name),
        by = "user_id"
      ) %>%
      dplyr::arrange(
        dplyr::case_when(
          status == "pending"  ~ 1L,
          status == "approved" ~ 2L,
          status == "in_use"   ~ 3L,
          TRUE                 ~ 4L
        ),
        start_time
      )

    reservation_choices <- if (nrow(admin_reservations) == 0) {
      character(0)
    } else {
      stats::setNames(
        admin_reservations$reservation_id,
        paste0(
          admin_reservations$reservation_id,
          " | ",
          admin_reservations$full_name,
          " | ",
          admin_reservations$status
        )
      )
    }

    tags$div(
      class = "form-layout",
      tags$div(
        tags$div(
          style = "display: flex; justify-content: space-between; gap: 12px; align-items: center; margin-bottom: 16px;",
          tags$h4(class = "form-section-title", "Reserva"),
          actionButton(
            inputId = "admin_logout",
            label = "Sair da administração",
            class = "btn-outline-secondary"
          )
        ),
        selectInput(
          inputId = "admin_reservation_id",
          label = "Selecione uma reserva",
          choices = reservation_choices
        ),
        textAreaInput(
          inputId = "admin_notes",
          label = "Observação administrativa",
          placeholder = "Informe o motivo da decisão ou alguma orientação para o usuário.",
          rows = 3
        ),
        selectInput(
          inputId = "admin_finish_reason",
          label = "Motivo da finalização",
          choices = get_choices(lists(), "finish_reason"),
          selected = "normal"
        ),
        fluidRow(
          column(
            width = 4,
            actionButton(inputId = "admin_approve", label = "Aprovar", class = "btn-success")
          ),
          column(
            width = 4,
            actionButton(inputId = "admin_reject", label = "Rejeitar", class = "btn-warning")
          ),
          column(
            width = 4,
            actionButton(inputId = "admin_cancel", label = "Cancelar", class = "btn-danger")
          )
        ),
        tags$div(
          style = "margin-top: 8px;",
          fluidRow(
            column(
              width = 6,
              actionButton(inputId = "admin_start_use", label = "Iniciar uso", class = "btn-info")
            ),
            column(
              width = 6,
              actionButton(inputId = "admin_finish_use", label = "Finalizar uso", class = "btn-secondary")
            )
          )
        )
      ),
      tags$div(
        uiOutput("admin_selected_reservation")
      )
    )
  })
  outputOptions(output, "admin_panel", suspendWhenHidden = FALSE)

  output$admin_sub_tabs <- renderUI({
    if (!admin_authenticated()) {
      return(NULL)
    }

    tags$div(
      style = "margin-top: 24px;",
      tabsetPanel(
        tabPanel(
          "Aprovadas e em uso",
          tags$div(style = "margin-top: 12px;", DT::DTOutput("admin_approved_table"))
        ),
        tabPanel(
          "Histórico",
          tags$div(style = "margin-top: 12px;", DT::DTOutput("admin_history_table"))
        ),
        tabPanel(
          "Auditoria",
          tags$div(style = "margin-top: 12px;", DT::DTOutput("admin_audit_table"))
        )
      )
    )
  })
  outputOptions(output, "admin_sub_tabs", suspendWhenHidden = FALSE)

  observeEvent(input$admin_login, {
    expected_password <- Sys.getenv("LAB_SCHEDULER_ADMIN_PASSWORD")
    
    if (expected_password == "") {
      showNotification(
        "Senha administrativa não configurada no ambiente R.",
        type = "error",
        duration = 8
      )
      return(NULL)
    }
    
    if (identical(input$admin_password, expected_password)) {
      admin_authenticated(TRUE)
      showNotification(
        "Acesso administrativo liberado.",
        type = "message",
        duration = 5
      )
    } else {
      admin_authenticated(FALSE)
      showNotification(
        "Senha administrativa incorreta.",
        type = "error",
        duration = 6
      )
    }
  })
  
  observeEvent(input$admin_logout, {
    admin_authenticated(FALSE)
    
    updateTextInput(
      session,
      inputId = "admin_password",
      value = ""
    )
    
    showNotification(
      "Sessão administrativa encerrada.",
      type = "message",
      duration = 5
    )
  })
  
  output$admin_selected_reservation <- renderUI({
    req(admin_authenticated())
    
    selected_id <- input$admin_reservation_id
    
    if (is.null(selected_id) || selected_id == "") {
      return(
        tags$div(
          class = "empty-preview",
          tags$h3("Nenhuma reserva selecionada"),
          tags$p("Selecione uma reserva para revisar os detalhes.")
        )
      )
    }
    
    reservation_tbl <- reservations() %>%
      dplyr::filter(reservation_id == selected_id) %>%
      dplyr::left_join(
        database()$users %>% dplyr::select(user_id, full_name, user_level_label, email),
        by = "user_id"
      ) %>%
      dplyr::slice(1)
    
    if (nrow(reservation_tbl) == 0) {
      return(
        tags$div(
          class = "empty-preview",
          tags$h3("Reserva não encontrada"),
          tags$p("A reserva selecionada não foi encontrada na base.")
        )
      )
    }
    
    tags$div(
      class = "preview-card",
      tags$div(
        class = "preview-header",
        tags$div(
          tags$span(class = "section-kicker", "Revisão administrativa"),
          tags$h3(reservation_tbl$full_name)
        ),
        tags$div(
          class = "preview-status preview-pending",
          reservation_tbl$status
        )
      ),
      tags$div(
        class = "preview-grid",
        tags$div(tags$span("Reserva"), tags$strong(reservation_tbl$reservation_id)),
        tags$div(tags$span("Categoria"), tags$strong(reservation_tbl$user_level_label)),
        tags$div(tags$span("Computador solicitado"), tags$strong(reservation_tbl$computer_requested)),
        tags$div(tags$span("Computador atribuído"), tags$strong(reservation_tbl$computer_assigned)),
        tags$div(tags$span("Início"), tags$strong(reservation_tbl$start_time)),
        tags$div(tags$span("Fim previsto"), tags$strong(reservation_tbl$end_time)),
        tags$div(tags$span("Duração h"), tags$strong(reservation_tbl$estimated_hours)),
        tags$div(tags$span("Prioridade"), tags$strong(reservation_tbl$priority_score)),
        tags$div(tags$span("Tipo"), tags$strong(reservation_tbl$processing_type)),
        tags$div(tags$span("Demanda"), tags$strong(reservation_tbl$computing_demand)),
        tags$div(tags$span("Usa GPU"), tags$strong(reservation_tbl$uses_gpu)),
        tags$div(tags$span("Exige Super 2"), tags$strong(reservation_tbl$requires_super_2))
      ),
      tags$div(
        class = "preview-reasons",
        tags$span("Justificativa"),
        tags$p(reservation_tbl$justification)
      )
    )
  })
  outputOptions(output, "admin_selected_reservation", suspendWhenHidden = FALSE)
  
  process_admin_action <- function(new_status, event_type) {
    req(admin_authenticated())
    req(input$admin_reservation_id)
    
    selected_id <- input$admin_reservation_id
    timezone_value <- get_setting_value(settings(), "timezone", "America/Sao_Paulo")
    admin_user <- "admin"
    admin_notes_value <- ifelse(
      is.null(input$admin_notes) || input$admin_notes == "",
      NA_character_,
      input$admin_notes
    )
    
    tryCatch(
      {
        updated_result <- update_reservation_status(
          reservations_tbl = reservations(),
          reservation_id_value = selected_id,
          new_status = new_status,
          admin_user = admin_user,
          admin_notes_value = admin_notes_value,
          timezone_value = timezone_value
        )
        
        audit_row <- create_audit_row(
          event_type = event_type,
          reservation_id = selected_id,
          user_id = updated_result$user_id,
          admin_user = admin_user,
          old_value = updated_result$old_status,
          new_value = new_status,
          notes = admin_notes_value,
          timezone_value = timezone_value
        )
        
        aligned_audit <- align_tables_as_character(
          reference_tbl = audit_log(),
          new_tbl = audit_row
        )
        
        audit_updated <- dplyr::bind_rows(
          aligned_audit$reference_tbl,
          aligned_audit$new_tbl
        )
        
        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "reservations",
          data_tbl = updated_result$reservations_tbl
        )
        
        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "audit_log",
          data_tbl = audit_updated
        )
        
        reload_key(reload_key() + 1)
        
        showNotification(
          paste0("Reserva atualizada para: ", new_status),
          type = "message",
          duration = 6
        )
        
        updateTabsetPanel(session, "main_nav", selected = "Reservas")
      },
      error = function(e) {
        showNotification(
          paste(
            "Não foi possível atualizar a reserva no Google Sheets.",
            e$message
          ),
          type = "error",
          duration = 10
        )
      }
    )
  }
  
  observeEvent(input$admin_approve, {
    process_admin_action(
      new_status = "approved",
      event_type = "reservation_approved"
    )
  })
  
  observeEvent(input$admin_reject, {
    process_admin_action(
      new_status = "rejected",
      event_type = "reservation_rejected"
    )
  })
  
  observeEvent(input$admin_cancel, {
    process_admin_action(
      new_status = "cancelled",
      event_type = "reservation_cancelled"
    )
  })

  observeEvent(input$admin_start_use, {
    req(admin_authenticated())
    req(input$admin_reservation_id)

    selected_id <- input$admin_reservation_id
    timezone_value <- get_setting_value(settings(), "timezone", "America/Sao_Paulo")
    admin_user <- "admin"
    admin_notes_value <- ifelse(
      is.null(input$admin_notes) || input$admin_notes == "",
      NA_character_,
      input$admin_notes
    )

    tryCatch(
      {
        updated_result <- update_reservation_status(
          reservations_tbl = reservations(),
          reservation_id_value = selected_id,
          new_status = "in_use",
          admin_user = admin_user,
          admin_notes_value = admin_notes_value,
          timezone_value = timezone_value
        )

        res_row <- reservations() %>%
          dplyr::filter(reservation_id == selected_id) %>%
          dplyr::slice(1)

        usage_row <- create_usage_row(
          reservation_id = selected_id,
          user_id = updated_result$user_id,
          computer_assigned = res_row$computer_assigned,
          actual_start_time = lubridate::now(tzone = timezone_value),
          timezone_value = timezone_value
        )

        aligned_usage <- align_tables_as_character(
          reference_tbl = database()$usage_log,
          new_tbl = usage_row
        )

        usage_updated <- dplyr::bind_rows(
          aligned_usage$reference_tbl,
          aligned_usage$new_tbl
        )

        audit_row <- create_audit_row(
          event_type = "reservation_start_use",
          reservation_id = selected_id,
          user_id = updated_result$user_id,
          admin_user = admin_user,
          old_value = updated_result$old_status,
          new_value = "in_use",
          notes = admin_notes_value,
          timezone_value = timezone_value
        )

        aligned_audit <- align_tables_as_character(
          reference_tbl = audit_log(),
          new_tbl = audit_row
        )

        audit_updated <- dplyr::bind_rows(
          aligned_audit$reference_tbl,
          aligned_audit$new_tbl
        )

        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "reservations",
          data_tbl = updated_result$reservations_tbl
        )

        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "usage_log",
          data_tbl = usage_updated
        )

        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "audit_log",
          data_tbl = audit_updated
        )

        reload_key(reload_key() + 1)

        showNotification(
          "Uso iniciado. Status atualizado para em uso.",
          type = "message",
          duration = 6
        )
      },
      error = function(e) {
        showNotification(
          paste("Não foi possível iniciar o uso.", e$message),
          type = "error",
          duration = 10
        )
      }
    )
  })

  observeEvent(input$admin_finish_use, {
    req(admin_authenticated())
    req(input$admin_reservation_id)

    selected_id <- input$admin_reservation_id
    timezone_value <- get_setting_value(settings(), "timezone", "America/Sao_Paulo")
    admin_user <- "admin"
    admin_notes_value <- ifelse(
      is.null(input$admin_notes) || input$admin_notes == "",
      NA_character_,
      input$admin_notes
    )

    finish_reason_value <- if (
      is.null(input$admin_finish_reason) || input$admin_finish_reason == ""
    ) {
      "normal"
    } else {
      input$admin_finish_reason
    }

    tryCatch(
      {
        updated_result <- update_reservation_status(
          reservations_tbl = reservations(),
          reservation_id_value = selected_id,
          new_status = "finished",
          admin_user = admin_user,
          admin_notes_value = admin_notes_value,
          timezone_value = timezone_value
        )

        now_value <- lubridate::now(tzone = timezone_value)

        usage_updated <- finish_usage_row(
          usage_log_tbl = database()$usage_log,
          reservation_id_value = selected_id,
          actual_end_time = now_value,
          finish_reason = finish_reason_value,
          timezone_value = timezone_value
        )

        audit_row <- create_audit_row(
          event_type = "reservation_finish_use",
          reservation_id = selected_id,
          user_id = updated_result$user_id,
          admin_user = admin_user,
          old_value = updated_result$old_status,
          new_value = "finished",
          notes = admin_notes_value,
          timezone_value = timezone_value
        )

        aligned_audit <- align_tables_as_character(
          reference_tbl = audit_log(),
          new_tbl = audit_row
        )

        audit_updated <- dplyr::bind_rows(
          aligned_audit$reference_tbl,
          aligned_audit$new_tbl
        )

        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "reservations",
          data_tbl = updated_result$reservations_tbl
        )

        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "usage_log",
          data_tbl = usage_updated
        )

        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "audit_log",
          data_tbl = audit_updated
        )

        reload_key(reload_key() + 1)

        showNotification(
          "Uso finalizado. Status atualizado para finalizado.",
          type = "message",
          duration = 6
        )
      },
      error = function(e) {
        showNotification(
          paste("Não foi possível finalizar o uso.", e$message),
          type = "error",
          duration = 10
        )
      }
    )
  })

  output$admin_approved_table <- DT::renderDT({
    tbl <- reservations() %>%
      dplyr::filter(status %in% c("approved", "in_use")) %>%
      dplyr::left_join(
        database()$users %>% dplyr::select(user_id, full_name),
        by = "user_id"
      ) %>%
      dplyr::arrange(start_time) %>%
      dplyr::select(
        reservation_id,
        full_name,
        computer_assigned,
        start_time,
        end_time,
        estimated_hours,
        status
      ) %>%
      dplyr::rename(
        "Reserva"     = reservation_id,
        "Usuário"     = full_name,
        "Computador"  = computer_assigned,
        "Início"      = start_time,
        "Fim previsto" = end_time,
        "Duração h"   = estimated_hours,
        "Status"      = status
      )

    DT::datatable(
      tbl,
      rownames = FALSE,
      options = list(pageLength = 10, scrollX = TRUE, language = dt_language_pt)
    )
  })
  outputOptions(output, "admin_approved_table", suspendWhenHidden = FALSE)

  output$admin_history_table <- DT::renderDT({
    tbl <- reservations() %>%
      dplyr::filter(status %in% c("rejected", "cancelled", "finished")) %>%
      dplyr::left_join(
        database()$users %>% dplyr::select(user_id, full_name),
        by = "user_id"
      ) %>%
      dplyr::arrange(dplyr::desc(updated_at)) %>%
      dplyr::select(
        reservation_id,
        full_name,
        computer_assigned,
        start_time,
        status,
        admin_notes
      ) %>%
      dplyr::rename(
        "Reserva"    = reservation_id,
        "Usuário"    = full_name,
        "Computador" = computer_assigned,
        "Início"     = start_time,
        "Status"     = status,
        "Observação" = admin_notes
      )

    DT::datatable(
      tbl,
      rownames = FALSE,
      options = list(pageLength = 10, scrollX = TRUE, language = dt_language_pt)
    )
  })
  outputOptions(output, "admin_history_table", suspendWhenHidden = FALSE)

  output$admin_audit_table <- DT::renderDT({
    DT::datatable(
      format_audit_public(audit_log(), database()$users),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        order = list(list(1, "desc")),
        language = dt_language_pt
      )
    )
  })
  outputOptions(output, "admin_audit_table", suspendWhenHidden = FALSE)

  output$reservations_table <- DT::renderDT({
    # Visão pública: oculta reservas rejeitadas e canceladas.
    public_reservations <- reservations() %>%
      dplyr::filter(!status %in% c("rejected", "cancelled"))

    DT::datatable(
      format_reservations_public(public_reservations, database()$users, lists()),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        order = list(list(2, "desc")),
        language = dt_language_pt
      )
    )
  })
  outputOptions(output, "reservations_table", suspendWhenHidden = FALSE)
}

shinyApp(ui = ui, server = server)
