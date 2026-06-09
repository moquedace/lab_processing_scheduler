dt_language_pt <- list(
  search = "Buscar:",
  lengthMenu = "Mostrar _MENU_ registros",
  info = "Mostrando _START_ a _END_ de _TOTAL_ registros",
  infoEmpty = "Mostrando 0 a 0 de 0 registros",
  infoFiltered = "(filtrado de _MAX_ registros)",
  zeroRecords = "Nenhum registro encontrado",
  emptyTable = "Nenhum dado dispon�vel",
  paginate = list(
    first = "Primeiro",
    previous = "Anterior",
    `next` = "Pr�ximo",
    last = "�ltimo"
  )
)

institutional_header_ui <- function() {
  tags$section(
    class = "institutional-header",
    tags$div(
      class = "institutional-main",
      tags$img(
        src = "site-assets/logo_geocis.png",
        alt = "GeoCIS",
        class = "logo-geocis"
      ),
      tags$div(
        class = "institutional-text",
        tags$span("Grupo de Geotecnologias em Ci�ncia do Solo"),
        tags$strong("Departamento de Ci�ncia do Solo | ESALQ | USP")
      )
    ),
    tags$div(
      class = "institutional-logo-row",
      tags$img(
        src = "site-assets/logo_solos.png",
        alt = "Departamento de Ci�ncia do Solo",
        class = "logo-institution logo-solos"
      ),
      tags$img(
        src = "site-assets/logo_esalq.png",
        alt = "ESALQ",
        class = "logo-institution logo-esalq"
      ),
      tags$img(
        src = "site-assets/logo_usp.png",
        alt = "USP",
        class = "logo-institution logo-usp"
      ),
      tags$div(
        class = "support-logo-box",
        tags$span("Apoio"),
        tags$img(
          src = "site-assets/logo_fapesp.png",
          alt = "FAPESP",
          class = "logo-institution logo-fapesp"
        )
      )
    )
  )
}

hero_ui <- function() {
  tags$section(
    class = "app-hero-grid",
    tags$div(
      class = "app-hero",
      tags$div(class = "hero-badge", "Painel p�blico"),
      tags$h1("Reserva dos Computadores de Processamento"),
      tags$p(
        "Consulte a disponibilidade das esta��es de processamento do GeoCiS, ",
        "solicite reservas e acompanhe as aprova��es em um s� lugar."
      )
    ),
    tags$aside(
      class = "hero-summary-card",
      tags$span(class = "summary-label", "Atualiza��o autom�tica"),
      tags$div(class = "summary-main", "60s"),
      tags$p("A disponibilidade dos computadores � atualizada automaticamente."),
      tags$div(
        class = "summary-list",
        tags$div(
          tags$span("Consultar"),
          tags$strong("Painel p�blico")
        ),
        tags$div(
          tags$span("Solicitar"),
          tags$strong("Solicitar reserva")
        )
      )
    )
  )
}

footer_ui <- function() {
  tags$footer(
    class = "app-footer",
    tags$div(
      class = "footer-main",
      tags$img(
        src = "site-assets/logo_geocis.png",
        alt = "GeoCIS",
        class = "footer-logo"
      ),
      tags$div(
        tags$p("Grupo de Geotecnologias em Ci�ncia do Solo"),
        tags$span("Departamento de Ci�ncia do Solo | Escola Superior de Agricultura Luiz de Queiroz | Universidade de S�o Paulo")
      )
    ),
    tags$div(
      class = "footer-support",
      tags$span("Apoio"),
      tags$img(
        src = "site-assets/logo_fapesp.png",
        alt = "FAPESP",
        class = "footer-fapesp"
      )
    )
  )
}

reservation_preview_ui <- function(preview) {
  if (is.null(preview)) {
    return(
      tags$div(
        class = "empty-preview",
        tags$h3("Pr�via da solicita��o"),
        tags$p("Preencha o formul�rio e clique em Gerar pr�via da reserva.")
      )
    )
  }
  
  status_class <- ifelse(preview$status == "approved", "preview-approved", "preview-pending")
  status_label <- ifelse(preview$status == "approved", "Aprovada automaticamente", "Pendente de aprova��o")
  
  tags$div(
    class = "preview-card",
    tags$div(
      class = "preview-header",
      tags$div(
        tags$span(class = "section-kicker", "Pr�via da solicita��o"),
        tags$h3(preview$user_name)
      ),
      tags$div(class = paste("preview-status", status_class), status_label)
    ),
    tags$div(
      class = "preview-grid",
      tags$div(tags$span("Computador solicitado"), tags$strong(preview$computer_requested_label)),
      tags$div(tags$span("Computador sugerido"), tags$strong(preview$computer_assigned_label)),
      tags$div(tags$span("In�cio"), tags$strong(preview$start_time_label)),
      tags$div(tags$span("Fim previsto"), tags$strong(preview$end_time_label)),
      tags$div(tags$span("Dura��o estimada"), tags$strong(paste0(preview$estimated_hours, " h"))),
      tags$div(tags$span("Ambiente"), tags$strong(preview$main_environment_label)),
      tags$div(tags$span("Tipo de processamento"), tags$strong(preview$processing_type_label)),
      tags$div(tags$span("Demanda computacional"), tags$strong(preview$computing_demand_label)),
      tags$div(tags$span("Usa GPU"), tags$strong(preview$uses_gpu_label)),
      tags$div(tags$span("Exige Super 2"), tags$strong(preview$requires_super_2_label)),
      tags$div(tags$span("Pode ser realocada"), tags$strong(preview$can_be_reallocated_label)),
      tags$div(tags$span("Prioridade calculada"), tags$strong(preview$priority_score))
    ),
    tags$div(
      class = "preview-reasons",
      tags$span("Decis�o preliminar"),
      tags$p(preview$approval_reason)
    ),
    tags$p(
      class = "preview-note",
      "Confira os dados antes de enviar. A solicita��o ser� gravada no Google Sheets."
    ),
    tags$div(
      class = "submit-area",
      actionButton(
        inputId = "submit_booking",
        label = "Enviar solicita��o",
        class = "btn-success"
      )
    )
  )
}
