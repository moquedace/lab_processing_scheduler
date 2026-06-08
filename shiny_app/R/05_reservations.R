parse_datetime <- function(date_value, time_value, timezone_value) {
  lubridate::ymd_hm(
    paste(as.Date(date_value), time_value),
    tz = timezone_value
  )
}

format_datetime_pt <- function(datetime_value, timezone_value = "America/Sao_Paulo") {
  if (is.null(datetime_value) || is.na(datetime_value)) {
    return("")
  }
  
  format(
    lubridate::with_tz(datetime_value, timezone_value),
    "%Y-%m-%d %H:%M:%S"
  )
}

format_datetime_label_pt <- function(datetime_value, timezone_value = "America/Sao_Paulo") {
  if (is.null(datetime_value) || is.na(datetime_value)) {
    return("")
  }
  
  format(
    lubridate::with_tz(datetime_value, timezone_value),
    "%d/%m/%Y %H:%M"
  )
}

check_reservation_conflict <- function(
    reservations_tbl,
    computer_id_value,
    start_time_value,
    end_time_value,
    timezone_value
) {
  if (nrow(reservations_tbl) == 0) {
    return(FALSE)
  }
  
  reservations_clean <- reservations_tbl %>%
    dplyr::filter(
      status %in% c("approved", "in_use"),
      computer_assigned == !!computer_id_value,
      !is.na(start_time),
      !is.na(end_time),
      start_time != "",
      end_time != ""
    ) %>%
    dplyr::mutate(
      start_time_parsed = lubridate::ymd_hms(start_time, tz = timezone_value, quiet = TRUE),
      end_time_parsed = lubridate::ymd_hms(end_time, tz = timezone_value, quiet = TRUE)
    )
  
  if (nrow(reservations_clean) == 0) {
    return(FALSE)
  }
  
  any(
    reservations_clean$start_time_parsed < end_time_value &
      reservations_clean$end_time_parsed > start_time_value,
    na.rm = TRUE
  )
}

get_computer_preference_order <- function(computers_tbl = NULL, computing_demand) {
  if (is.null(computers_tbl) || nrow(computers_tbl) == 0) {
    intensive_demands <- c(
      "cpu_intensive",
      "ram_intensive",
      "raster_processing",
      "large_data",
      "deep_learning"
    )
    
    if (computing_demand %in% intensive_demands) {
      return(c("super_2", "super_1"))
    }
    
    return(c("super_1", "super_2"))
  }
  
  available_computers <- computers_tbl %>%
    dplyr::filter(status == "active", can_be_booked == "TRUE") %>%
    dplyr::mutate(
      cores_num = suppressWarnings(as.numeric(cores)),
      threads_num = suppressWarnings(as.numeric(threads)),
      ram_gb_num = suppressWarnings(as.numeric(ram_gb)),
      gpu_memory_gb_num = suppressWarnings(as.numeric(gpu_memory_gb)),
      resource_score = dplyr::coalesce(cores_num, 0) +
        dplyr::coalesce(threads_num, 0) * 0.25 +
        dplyr::coalesce(ram_gb_num, 0) * 0.5 +
        dplyr::coalesce(gpu_memory_gb_num, 0) * 2
    )
  
  if (nrow(available_computers) == 0) {
    return(character(0))
  }
  
  intensive_demands <- c(
    "cpu_intensive",
    "ram_intensive",
    "raster_processing",
    "large_data",
    "deep_learning"
  )
  
  if (computing_demand %in% intensive_demands) {
    available_computers <- available_computers %>%
      dplyr::arrange(dplyr::desc(resource_score), computer_id)
  } else {
    available_computers <- available_computers %>%
      dplyr::arrange(resource_score, computer_id)
  }
  
  available_computers$computer_id
}

suggest_computer_assignment <- function(
    computer_requested,
    computing_demand,
    reservations_tbl,
    start_time_value,
    end_time_value,
    timezone_value,
    computers_tbl = NULL
) {
  computer_order <- get_computer_preference_order(
    computers_tbl = computers_tbl,
    computing_demand = computing_demand
  )
  
  if (length(computer_order) == 0) {
    stop("Nenhum computador ativo e reservável foi encontrado.")
  }
  
  if (computer_requested %in% computer_order) {
    return(computer_requested)
  }

  for (computer_id_value in computer_order) {
    has_conflict <- check_reservation_conflict(
      reservations_tbl = reservations_tbl,
      computer_id_value = computer_id_value,
      start_time_value = start_time_value,
      end_time_value = end_time_value,
      timezone_value = timezone_value
    )
    
    if (!has_conflict) {
      return(computer_id_value)
    }
  }
  
  computer_order[1]
}

decide_approval_mode <- function(
    user_level,
    estimated_hours,
    requires_super_2,
    computing_demand,
    has_conflict,
    settings_tbl
) {
  manual_user_levels <- get_setting_vector(settings_tbl, "manual_approval_user_levels")
  manual_above_hours <- get_setting_numeric(settings_tbl, "manual_approval_above_hours", 24)
  
  manual_if_requires_super_2 <- get_setting_logical(
    settings_tbl,
    "manual_approval_if_requires_super_2",
    TRUE
  )
  
  manual_if_conflict <- get_setting_logical(
    settings_tbl,
    "manual_approval_if_conflict",
    TRUE
  )
  
  manual_if_unknown_demand <- get_setting_logical(
    settings_tbl,
    "manual_approval_if_unknown_demand",
    TRUE
  )
  
  reasons <- character(0)
  
  if (user_level %in% manual_user_levels) {
    reasons <- c(reasons, "categoria exige aprovação manual")
  }
  
  if (!is.na(manual_above_hours) && estimated_hours > manual_above_hours) {
    reasons <- c(reasons, "duração acima do limite de aprovação automática")
  }
  
  if (manual_if_requires_super_2 && requires_super_2 == "yes") {
    reasons <- c(reasons, "uso obrigatório do Super 2")
  }
  
  if (manual_if_conflict && has_conflict) {
    reasons <- c(reasons, "conflito de horário")
  }
  
  if (manual_if_unknown_demand && computing_demand == "unknown") {
    reasons <- c(reasons, "demanda computacional desconhecida")
  }
  
  if (length(reasons) > 0) {
    return(list(mode = "manual", reasons = reasons))
  }
  
  list(mode = "automatic", reasons = "atende aos critérios de aprovação automática")
}

decide_reservation_status <- function(approval_mode, settings_tbl) {
  allow_auto_approval <- get_setting_logical(settings_tbl, "allow_auto_approval", TRUE)
  
  if (approval_mode == "automatic" && allow_auto_approval) {
    return(get_setting_value(settings_tbl, "default_auto_approved_status", "approved"))
  }
  
  get_setting_value(settings_tbl, "default_manual_approval_status", "pending")
}

generate_reservation_id <- function() {
  paste0(
    "res_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_",
    sample(1000:9999, 1)
  )
}

generate_log_id <- function() {
  paste0(
    "log_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_",
    sample(1000:9999, 1)
  )
}

create_reservation_row <- function(preview, timezone_value) {
  now_value <- lubridate::now(tzone = timezone_value)
  
  tibble::tibble(
    reservation_id = generate_reservation_id(),
    created_at = format_datetime_pt(now_value, timezone_value),
    updated_at = format_datetime_pt(now_value, timezone_value),
    user_id = preview$user_id,
    computer_requested = preview$computer_requested,
    computer_assigned = preview$computer_assigned,
    start_time = format_datetime_pt(preview$start_time, timezone_value),
    end_time = format_datetime_pt(preview$end_time, timezone_value),
    estimated_hours = as.character(preview$estimated_hours),
    main_environment = preview$main_environment,
    processing_type = preview$processing_type,
    computing_demand = preview$computing_demand,
    uses_gpu = preview$uses_gpu,
    requires_super_2 = preview$requires_super_2,
    can_be_reallocated = preview$can_be_reallocated,
    deadline = ifelse(
      is.null(preview$deadline) || is.na(preview$deadline),
      NA_character_,
      as.character(as.Date(preview$deadline))
    ),
    justification = preview$justification,
    priority_score = as.character(preview$priority_score),
    status = preview$status,
    approval_mode = preview$approval_mode,
    approved_by = NA_character_,
    approved_at = NA_character_,
    rejected_by = NA_character_,
    rejected_at = NA_character_,
    cancelled_by = NA_character_,
    cancelled_at = NA_character_,
    admin_notes = NA_character_,
    public_notes = preview$public_notes
  )
}

create_audit_row <- function(
    event_type,
    reservation_id,
    user_id,
    admin_user,
    old_value,
    new_value,
    notes,
    timezone_value
) {
  now_value <- lubridate::now(tzone = timezone_value)
  
  tibble::tibble(
    log_id = generate_log_id(),
    event_time = format_datetime_pt(now_value, timezone_value),
    event_type = event_type,
    reservation_id = reservation_id,
    user_id = user_id,
    admin_user = admin_user,
    old_value = old_value,
    new_value = new_value,
    notes = notes
  )
}

generate_usage_id <- function() {
  paste0(
    "use_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_",
    sample(1000:9999, 1)
  )
}

create_usage_row <- function(
    reservation_id,
    user_id,
    computer_assigned,
    actual_start_time,
    timezone_value
) {
  tibble::tibble(
    usage_id = generate_usage_id(),
    reservation_id = reservation_id,
    user_id = user_id,
    computer_assigned = computer_assigned,
    actual_start_time = format_datetime_pt(actual_start_time, timezone_value),
    actual_end_time = NA_character_,
    actual_hours = NA_character_,
    finish_reason = NA_character_,
    notes = NA_character_
  )
}

finish_usage_row <- function(
    usage_log_tbl,
    reservation_id_value,
    actual_end_time,
    finish_reason,
    timezone_value
) {
  usage_log_tbl <- usage_log_tbl %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ as.character(.x)))

  row_id <- which(
    usage_log_tbl$reservation_id == reservation_id_value &
      (is.na(usage_log_tbl$actual_end_time) | usage_log_tbl$actual_end_time == "")
  )

  if (length(row_id) == 0) {
    return(usage_log_tbl)
  }

  start_parsed <- lubridate::ymd_hms(
    usage_log_tbl$actual_start_time[row_id[1]],
    tz = timezone_value,
    quiet = TRUE
  )

  actual_h <- if (!is.na(start_parsed)) {
    as.character(
      round(
        as.numeric(difftime(actual_end_time, start_parsed, units = "hours")),
        2
      )
    )
  } else {
    NA_character_
  }

  usage_log_tbl$actual_end_time[row_id[1]] <- format_datetime_pt(actual_end_time, timezone_value)
  usage_log_tbl$actual_hours[row_id[1]] <- actual_h
  usage_log_tbl$finish_reason[row_id[1]] <- finish_reason

  usage_log_tbl
}

update_reservation_status <- function(
    reservations_tbl,
    reservation_id_value,
    new_status,
    admin_user,
    admin_notes_value,
    timezone_value
) {
  now_text <- format_datetime_pt(
    lubridate::now(tzone = timezone_value),
    timezone_value
  )
  
  reservations_tbl <- reservations_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
  row_id <- which(reservations_tbl$reservation_id == reservation_id_value)
  
  if (length(row_id) != 1) {
    stop("Reserva não encontrada ou identificador duplicado.")
  }
  
  old_status <- reservations_tbl$status[row_id]
  
  reservations_tbl$status[row_id] <- new_status
  reservations_tbl$updated_at[row_id] <- now_text
  reservations_tbl$admin_notes[row_id] <- admin_notes_value
  
  if (new_status == "approved") {
    reservations_tbl$approved_by[row_id] <- admin_user
    reservations_tbl$approved_at[row_id] <- now_text
  }
  
  if (new_status == "rejected") {
    reservations_tbl$rejected_by[row_id] <- admin_user
    reservations_tbl$rejected_at[row_id] <- now_text
  }
  
  if (new_status == "cancelled") {
    reservations_tbl$cancelled_by[row_id] <- admin_user
    reservations_tbl$cancelled_at[row_id] <- now_text
  }
  
  list(
    reservations_tbl = reservations_tbl,
    old_status = old_status,
    user_id = reservations_tbl$user_id[row_id]
  )
}
