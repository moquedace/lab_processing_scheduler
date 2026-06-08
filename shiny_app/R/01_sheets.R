read_sheet_clean <- function(sheet_name) {
  googlesheets4::read_sheet(
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
}

# Abas que mudam raramente (cadastros e configuração).
# Relidas apenas quando o app força recarga (reload_key), não no timer.
static_sheet_names <- c(
  "users",
  "computers",
  "lists",
  "priority_rules",
  "settings"
)

# Abas que mudam com frequência (operação diária).
# Relidas pelo timer de atualização automática.
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
