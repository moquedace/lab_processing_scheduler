register_public_server_outputs <- function(
    output,
    database,
    users,
    computers,
    reservations,
    audit_log,
    priority_rules,
    settings,
    lists,
    sheet_url
) {
  output$n_users <- renderText({
    nrow(users())
  })
  
  output$n_computers <- renderText({
    nrow(computers())
  })
  
  output$n_reservations <- renderText({
    nrow(reservations())
  })
  
  output$n_rules <- renderText({
    nrow(priority_rules())
  })
  
  output$system_summary <- renderUI({
    reservations_n <- nrow(reservations())
    usage_n <- nrow(database()$usage_log)
    audit_n <- nrow(audit_log())
    
    source_label <- ifelse(
      sheet_url != "",
      "Google Sheets",
      "Fonte nÃ£o encontrada"
    )
    
    auto_approval <- get_setting_value(settings(), "allow_auto_approval", "FALSE")
    require_email <- get_setting_value(settings(), "require_email_confirmation", "FALSE")
    
    tagList(
      tags$p(
        tags$span(class = "status-ok", "ConexÃ£o online funcionando")
      ),
      tags$p(
        "A base foi lida com sucesso. Existem ",
        tags$strong(nrow(users())),
        " usuÃ¡rios ativos, ",
        tags$strong(nrow(computers())),
        " computadores ativos, ",
        tags$strong(nrow(database()$lists)),
        " itens de lista, ",
        tags$strong(nrow(priority_rules())),
        " regras de prioridade e ",
        tags$strong(nrow(settings())),
        " configuraÃ§Ãµes ativas."
      ),
      tags$p(
        "Reservas registradas: ",
        tags$strong(reservations_n),
        ". Registros de uso: ",
        tags$strong(usage_n),
        ". Eventos administrativos: ",
        tags$strong(audit_n),
        "."
      ),
      tags$p(
        "Fonte atual: ",
        tags$strong(source_label),
        ". AtualizaÃ§Ã£o automÃ¡tica: ",
        tags$strong("a cada 60 segundos"),
        ". AprovaÃ§Ã£o automÃ¡tica: ",
        tags$strong(ifelse(auto_approval == "TRUE", "habilitada", "desabilitada")),
        ". ConfirmaÃ§Ã£o de e-mail: ",
        tags$strong(ifelse(require_email == "TRUE", "obrigatÃ³ria", "desabilitada")),
        "."
      )
    )
  })
  
  output$computer_cards <- renderUI({
    computer_cards_ui(computers())
  })
  
  output$public_status_cards <- renderUI({
    public_computer_status_cards_ui(
      computers_tbl = computers(),
      reservations_tbl = reservations(),
      users_tbl = database()$users,
      lists_tbl = lists(),
      settings_tbl = settings()
    )
  })
  
  output$public_upcoming_table <- DT::renderDT({
    DT::datatable(
      format_public_reservations(
        reservations_tbl = reservations(),
        users_tbl = database()$users,
        lists_tbl = lists(),
        settings_tbl = settings(),
        status_values = c("approved", "in_use"),
        include_current = TRUE
      ),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        language = dt_language_pt
      )
    )
  })
  
  output$public_pending_block <- renderUI({
    show_pending <- get_setting_logical(settings(), "public_show_pending", TRUE)
    
    if (!show_pending) {
      return(NULL)
    }
    
    tags$div(
      class = "section-card",
      tags$h2("Reservas pendentes"),
      tags$p(
        "SolicitaÃ§Ãµes recebidas e ainda nÃ£o aprovadas pela administraÃ§Ã£o."
      ),
      DT::DTOutput("public_pending_table")
    )
  })
  
  output$public_pending_table <- DT::renderDT({
    DT::datatable(
      format_public_reservations(
        reservations_tbl = reservations(),
        users_tbl = database()$users,
        lists_tbl = lists(),
        settings_tbl = settings(),
        status_values = c("pending"),
        include_current = TRUE
      ),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        language = dt_language_pt
      )
    )
  })
}
