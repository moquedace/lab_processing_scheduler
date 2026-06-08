register_public_server_outputs <- function(
    output,
    database,
    computers,
    reservations,
    settings,
    lists
) {
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
        "Solicitações recebidas e ainda não aprovadas pela administração."
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
