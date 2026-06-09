format_reservations_public <- function(reservations_tbl, users_tbl, lists_tbl) {
  if (nrow(reservations_tbl) == 0) {
    return(
      tibble::tibble(
        "Usu�rio" = character(),
        "Computador" = character(),
        "In�cio" = character(),
        "Fim previsto" = character(),
        "Dura��o h" = character(),
        "Tipo de processamento" = character(),
        "Status" = character()
      )
    )
  }

  reservations_tbl %>%
    dplyr::left_join(
      users_tbl %>% dplyr::select(user_id, full_name),
      by = "user_id"
    ) %>%
    dplyr::mutate(
      computer_assigned_label = purrr::map_chr(
        computer_assigned,
        ~ get_label_from_value(lists_tbl, "computer_assigned", .x)
      ),
      processing_type_label = purrr::map_chr(
        processing_type,
        ~ get_label_from_value(lists_tbl, "processing_type", .x)
      ),
      status_label = purrr::map_chr(
        status,
        ~ get_label_from_value(lists_tbl, "reservation_status", .x)
      )
    ) %>%
    dplyr::select(
      full_name,
      computer_assigned_label,
      start_time,
      end_time,
      estimated_hours,
      processing_type_label,
      status_label
    ) %>%
    dplyr::rename(
      "Usu�rio" = full_name,
      "Computador" = computer_assigned_label,
      "In�cio" = start_time,
      "Fim previsto" = end_time,
      "Dura��o h" = estimated_hours,
      "Tipo de processamento" = processing_type_label,
      "Status" = status_label
    )
}

format_audit_public <- function(audit_tbl, users_tbl) {
  if (nrow(audit_tbl) == 0) {
    return(
      tibble::tibble(
        "Log" = character(),
        "Data" = character(),
        "Evento" = character(),
        "Reserva" = character(),
        "Usu�rio" = character(),
        "Admin" = character(),
        "Antes" = character(),
        "Depois" = character(),
        "Observa��o" = character()
      )
    )
  }
  
  audit_tbl %>%
    dplyr::left_join(
      users_tbl %>% dplyr::select(user_id, full_name),
      by = "user_id"
    ) %>%
    dplyr::select(
      log_id,
      event_time,
      event_type,
      reservation_id,
      full_name,
      admin_user,
      old_value,
      new_value,
      notes
    ) %>%
    dplyr::rename(
      "Log" = log_id,
      "Data" = event_time,
      "Evento" = event_type,
      "Reserva" = reservation_id,
      "Usu�rio" = full_name,
      "Admin" = admin_user,
      "Antes" = old_value,
      "Depois" = new_value,
      "Observa��o" = notes
    )
}

format_datetime_label_vector <- function(datetime_value, timezone_value = "America/Sao_Paulo") {
  if (length(datetime_value) == 0) {
    return(character(0))
  }
  
  datetime_value <- lubridate::with_tz(datetime_value, timezone_value)
  
  out <- format(datetime_value, "%d/%m/%Y %H:%M")
  out[is.na(datetime_value)] <- ""
  out
}

empty_public_reservation_table <- function(settings_tbl) {
  show_user_level <- get_setting_logical(settings_tbl, "public_show_user_level", FALSE)
  show_processing_type <- get_setting_logical(settings_tbl, "public_show_processing_type", TRUE)
  show_computing_demand <- get_setting_logical(settings_tbl, "public_show_computing_demand", FALSE)
  
  column_names <- c("Computador", "Usu�rio")
  
  if (show_user_level) {
    column_names <- c(column_names, "Categoria")
  }
  
  column_names <- c(column_names, "In�cio", "Fim previsto")
  
  if (show_processing_type) {
    column_names <- c(column_names, "Tipo de processamento")
  }
  
  if (show_computing_demand) {
    column_names <- c(column_names, "Demanda computacional")
  }
  
  column_names <- c(column_names, "Status")
  
  tibble::as_tibble(
    stats::setNames(
      rep(list(character()), length(column_names)),
      column_names
    )
  )
}

format_public_reservations <- function(
    reservations_tbl,
    users_tbl,
    lists_tbl,
    settings_tbl,
    status_values,
    include_current = TRUE,
    include_all = FALSE
) {
  timezone_value <- get_setting_value(settings_tbl, "timezone", "America/Sao_Paulo")
  now_value <- lubridate::now(tzone = timezone_value)
  
  show_user_level <- get_setting_logical(settings_tbl, "public_show_user_level", FALSE)
  show_processing_type <- get_setting_logical(settings_tbl, "public_show_processing_type", TRUE)
  show_computing_demand <- get_setting_logical(settings_tbl, "public_show_computing_demand", FALSE)
  
  if (nrow(reservations_tbl) == 0) {
    return(empty_public_reservation_table(settings_tbl))
  }
  
  out <- reservations_tbl %>%
    dplyr::mutate(
      start_dt = lubridate::ymd_hms(start_time, tz = timezone_value, quiet = TRUE),
      end_dt = lubridate::ymd_hms(end_time, tz = timezone_value, quiet = TRUE)
    ) %>%
    dplyr::filter(
      status %in% status_values,
      !is.na(start_dt),
      !is.na(end_dt)
    )
  
  if (!include_all) {
    if (include_current) {
      out <- out %>%
        dplyr::filter(end_dt >= now_value)
    } else {
      out <- out %>%
        dplyr::filter(start_dt >= now_value)
    }
  }
  
  if (nrow(out) == 0) {
    return(empty_public_reservation_table(settings_tbl))
  }
  
  out <- out %>%
    dplyr::left_join(
      users_tbl %>% dplyr::select(user_id, full_name, user_level_label),
      by = "user_id"
    ) %>%
    dplyr::mutate(
      computer_label = purrr::map_chr(
        computer_assigned,
        ~ get_label_from_value(lists_tbl, "computer_assigned", .x)
      ),
      processing_type_label = purrr::map_chr(
        processing_type,
        ~ get_label_from_value(lists_tbl, "processing_type", .x)
      ),
      computing_demand_label = purrr::map_chr(
        computing_demand,
        ~ get_label_from_value(lists_tbl, "computing_demand", .x)
      ),
      status_label = purrr::map_chr(
        status,
        ~ get_label_from_value(lists_tbl, "reservation_status", .x)
      ),
      start_label = format_datetime_label_vector(start_dt, timezone_value),
      end_label = format_datetime_label_vector(end_dt, timezone_value),
      full_name = dplyr::if_else(
        is.na(full_name) | full_name == "",
        "Usu�rio n�o informado",
        full_name
      )
    ) %>%
    dplyr::arrange(start_dt)
  
  public_tbl <- tibble::tibble(
    "Computador" = out$computer_label,
    "Usu�rio" = out$full_name
  )
  
  if (show_user_level) {
    public_tbl <- public_tbl %>%
      tibble::add_column("Categoria" = out$user_level_label, .after = "Usu�rio")
  }
  
  public_tbl <- public_tbl %>%
    tibble::add_column(
      "In�cio" = out$start_label,
      "Fim previsto" = out$end_label
    )
  
  if (show_processing_type) {
    public_tbl <- public_tbl %>%
      tibble::add_column("Tipo de processamento" = out$processing_type_label)
  }
  
  if (show_computing_demand) {
    public_tbl <- public_tbl %>%
      tibble::add_column("Demanda computacional" = out$computing_demand_label)
  }
  
  public_tbl %>%
    tibble::add_column("Status" = out$status_label)
}

public_computer_status_cards_ui <- function(
    computers_tbl,
    reservations_tbl,
    users_tbl,
    lists_tbl,
    settings_tbl
) {
  timezone_value <- get_setting_value(settings_tbl, "timezone", "America/Sao_Paulo")
  now_value <- lubridate::now(tzone = timezone_value)
  
  show_processing_type <- get_setting_logical(settings_tbl, "public_show_processing_type", TRUE)
  
  reservations_aug <- reservations_tbl %>%
    dplyr::mutate(
      start_dt = lubridate::ymd_hms(start_time, tz = timezone_value, quiet = TRUE),
      end_dt = lubridate::ymd_hms(end_time, tz = timezone_value, quiet = TRUE)
    ) %>%
    dplyr::left_join(
      users_tbl %>% dplyr::select(user_id, full_name),
      by = "user_id"
    ) %>%
    dplyr::mutate(
      processing_type_label = purrr::map_chr(
        processing_type,
        ~ get_label_from_value(lists_tbl, "processing_type", .x)
      ),
      full_name = dplyr::if_else(
        is.na(full_name) | full_name == "",
        "Usu�rio n�o informado",
        full_name
      )
    )
  
  card_list <- purrr::pmap(
    computers_tbl,
    function(
    computer_id,
    computer_name,
    computer_label,
    processor,
    cores,
    threads,
    ram_gb,
    gpu,
    gpu_memory_gb,
    main_profile,
    status,
    can_be_booked,
    public_description,
    notes,
    ...
    ) {
      current_use <- reservations_aug %>%
        dplyr::filter(
          computer_assigned == computer_id,
          status %in% c("approved", "in_use"),
          !is.na(start_dt),
          !is.na(end_dt),
          start_dt <= now_value,
          end_dt >= now_value
        ) %>%
        dplyr::arrange(end_dt) %>%
        dplyr::slice(1)
      
      next_use <- reservations_aug %>%
        dplyr::filter(
          computer_assigned == computer_id,
          status %in% c("approved"),
          !is.na(start_dt),
          start_dt > now_value
        ) %>%
        dplyr::arrange(start_dt) %>%
        dplyr::slice(1)
      
      if (nrow(current_use) == 1) {
        badge_class <- "machine-badge machine-busy"
        badge_label <- "Em uso agora"
        
        status_body <- tagList(
          tags$p(
            tags$strong("Usu�rio: "),
            current_use$full_name
          ),
          tags$p(
            tags$strong("At�: "),
            format_datetime_label_vector(current_use$end_dt, timezone_value)
          )
        )
        
        if (show_processing_type) {
          status_body <- tagList(
            status_body,
            tags$p(
              tags$strong("Tipo: "),
              current_use$processing_type_label
            )
          )
        }
      } else {
        badge_class <- "machine-badge machine-free"
        badge_label <- "Dispon�vel agora"
        
        if (nrow(next_use) == 1) {
          status_body <- tagList(
            tags$p(
              tags$strong("Pr�xima reserva: "),
              next_use$full_name
            ),
            tags$p(
              tags$strong("In�cio: "),
              format_datetime_label_vector(next_use$start_dt, timezone_value)
            )
          )
        } else {
          status_body <- tagList(
            tags$p("Nenhuma reserva aprovada futura para este computador.")
          )
        }
      }
      
      tags$article(
        class = "public-machine-card",
        tags$div(
          class = "public-machine-header",
          tags$div(
            tags$h3(computer_name),
            tags$span(computer_label)
          ),
          tags$div(
            class = badge_class,
            badge_label
          )
        ),
        tags$div(
          class = "public-machine-body",
          status_body
        ),
        tags$div(
          class = "public-machine-specs",
          tags$span(paste0(cores, " n�cleos | ", threads, " threads")),
          tags$span(paste0(ram_gb, " GB RAM")),
          tags$span(paste0(gpu_memory_gb, " GB GPU"))
        )
      )
    }
  )
  
  tags$div(
    class = "public-status-grid",
    card_list
  )
}

time_choices <- sprintf(
  "%02d:%02d",
  rep(0:23, each = 2),
  rep(c(0, 30), times = 24)
)
