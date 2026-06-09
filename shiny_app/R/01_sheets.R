sheet_columns <- list(
  users = c(
    "user_id",
    "full_name",
    "email",
    "user_level",
    "user_level_label",
    "advisor",
    "project_or_group",
    "status",
    "can_book",
    "priority_base",
    "notes",
    "created_at",
    "updated_at"
  ),
  computers = c(
    "computer_id",
    "computer_name",
    "computer_label",
    "processor",
    "cores",
    "threads",
    "ram_gb",
    "gpu",
    "gpu_memory_gb",
    "main_profile",
    "status",
    "can_be_booked",
    "public_description",
    "notes"
  ),
  reservations = c(
    "reservation_id",
    "created_at",
    "updated_at",
    "user_id",
    "computer_requested",
    "computer_assigned",
    "start_time",
    "end_time",
    "estimated_hours",
    "main_environment",
    "processing_type",
    "computing_demand",
    "uses_gpu",
    "requires_super_2",
    "can_be_reallocated",
    "deadline",
    "justification",
    "priority_score",
    "status",
    "approval_mode",
    "approved_by",
    "approved_at",
    "rejected_by",
    "rejected_at",
    "cancelled_by",
    "cancelled_at",
    "admin_notes",
    "public_notes"
  ),
  lists = c(
    "list_name",
    "value",
    "label",
    "sort_order",
    "active"
  ),
  priority_rules = c(
    "rule_id",
    "rule_group",
    "condition_value",
    "user_level",
    "points",
    "active"
  ),
  usage_log = c(
    "usage_id",
    "reservation_id",
    "user_id",
    "computer_id",
    "started_at",
    "finished_at",
    "duration_hours",
    "started_by",
    "finished_by",
    "finish_reason",
    "notes"
  ),
  audit_log = c(
    "log_id",
    "event_time",
    "event_type",
    "reservation_id",
    "user_id",
    "admin_user",
    "old_value",
    "new_value",
    "notes"
  ),
  settings = c(
    "setting_name",
    "setting_value",
    "description",
    "active"
  )
)

normalize_sheet_schema <- function(sheet_tbl, sheet_name) {
  expected_columns <- sheet_columns[[sheet_name]]

  if (is.null(expected_columns)) {
    return(sheet_tbl)
  }

  missing_columns <- setdiff(expected_columns, names(sheet_tbl))

  for (column_name in missing_columns) {
    sheet_tbl[[column_name]] <- character(nrow(sheet_tbl))
  }

  sheet_tbl %>%
    dplyr::select(dplyr::all_of(expected_columns)) %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
}

read_sheet_clean <- function(sheet_name) {
  sheet_tbl <- googlesheets4::read_sheet(
    ss = sheet_url,
    sheet = sheet_name,
    col_types = "c"
  ) %>%
    dplyr::rename_with(stringr::str_trim) %>%
    dplyr::select(
      !dplyr::matches("^\\.\\.\\.[0-9]+$")
    ) %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ ifelse(is.na(.x), NA_character_, stringr::str_trim(as.character(.x)))
      )
    )

  normalize_sheet_schema(sheet_tbl, sheet_name)
}

# Abas que mudam raramente (cadastros e configura��o).
# Relidas apenas quando o app for�a recarga (reload_key), n�o no timer.
static_sheet_names <- c(
  "users",
  "computers",
  "lists",
  "priority_rules",
  "settings"
)

# Abas que mudam com frequ�ncia (opera��o di�ria).
# Relidas pelo timer de atualiza��o autom�tica.
dynamic_sheet_names <- c(
  "reservations",
  "usage_log",
  "audit_log"
)

read_sheets <- function(sheet_names) {
  purrr::map(sheet_names, read_sheet_clean) %>%
    stats::setNames(sheet_names)
}

read_static_tables <- function() {
  read_sheets(static_sheet_names)
}

read_dynamic_tables <- function() {
  read_sheets(dynamic_sheet_names)
}

read_database <- function() {
  c(read_static_tables(), read_dynamic_tables())
}

write_sheet_to_workbook <- function(database_file, sheet_name, data_tbl) {
  sheet_url_value <- database_file
  
  data_tbl <- data_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
  available_sheets <- googlesheets4::sheet_names(sheet_url_value)
  
  if (!sheet_name %in% available_sheets) {
    googlesheets4::sheet_add(
      ss = sheet_url_value,
      sheet = sheet_name
    )
  }
  
  googlesheets4::range_clear(
    ss = sheet_url_value,
    sheet = sheet_name
  )
  
  googlesheets4::range_write(
    ss = sheet_url_value,
    data = data_tbl,
    sheet = sheet_name,
    range = "A1",
    col_names = TRUE,
    reformat = FALSE
  )
}

align_tables_as_character <- function(reference_tbl, new_tbl) {
  reference_tbl <- reference_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
  new_tbl <- new_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
  missing_in_reference <- setdiff(names(new_tbl), names(reference_tbl))
  
  if (length(missing_in_reference) > 0) {
    for (col_name in missing_in_reference) {
      reference_tbl[[col_name]] <- NA_character_
    }
  }
  
  missing_in_new <- setdiff(names(reference_tbl), names(new_tbl))
  
  if (length(missing_in_new) > 0) {
    for (col_name in missing_in_new) {
      new_tbl[[col_name]] <- NA_character_
    }
  }
  
  new_tbl <- new_tbl %>%
    dplyr::select(dplyr::all_of(names(reference_tbl)))
  
  list(
    reference_tbl = reference_tbl,
    new_tbl = new_tbl
  )
}
