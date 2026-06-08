get_active_users <- function(database) {
  database$users %>%
    dplyr::filter(status == "active") %>%
    dplyr::arrange(full_name)
}

get_active_computers <- function(database) {
  database$computers %>%
    dplyr::filter(status == "active", can_be_booked == "TRUE") %>%
    dplyr::arrange(computer_id)
}

get_active_lists <- function(database) {
  database$lists %>%
    dplyr::filter(active == "TRUE") %>%
    dplyr::arrange(list_name, as.numeric(sort_order))
}

get_active_settings <- function(database) {
  database$settings %>%
    dplyr::filter(active == "TRUE") %>%
    dplyr::arrange(setting_name)
}

get_setting_value <- function(settings_tbl, setting_name, default_value = NA_character_) {
  value <- settings_tbl %>%
    dplyr::filter(.data$setting_name == !!setting_name, active == "TRUE") %>%
    dplyr::pull(setting_value)
  
  if (length(value) == 0 || is.na(value[1])) {
    return(default_value)
  }
  
  value[1]
}

get_setting_logical <- function(settings_tbl, setting_name, default_value = FALSE) {
  value <- get_setting_value(settings_tbl, setting_name, as.character(default_value))
  identical(value, "TRUE")
}

get_setting_numeric <- function(settings_tbl, setting_name, default_value = NA_real_) {
  value <- get_setting_value(settings_tbl, setting_name, as.character(default_value))
  suppressWarnings(as.numeric(value))
}

get_setting_vector <- function(settings_tbl, setting_name) {
  value <- get_setting_value(settings_tbl, setting_name, "")
  
  if (is.na(value) || value == "") {
    return(character(0))
  }
  
  stringr::str_split(value, ",")[[1]] %>%
    stringr::str_trim()
}

get_choices <- function(lists_tbl, list_name) {
  selected <- lists_tbl %>%
    dplyr::filter(.data$list_name == !!list_name, active == "TRUE") %>%
    dplyr::arrange(as.numeric(sort_order))
  
  stats::setNames(selected$value, selected$label)
}

get_label_from_value <- function(lists_tbl, list_name, value) {
  out <- lists_tbl %>%
    dplyr::filter(
      .data$list_name == !!list_name,
      .data$value == !!value,
      active == "TRUE"
    ) %>%
    dplyr::pull(label)
  
  if (length(out) == 0 || is.na(out[1])) {
    return(value)
  }
  
  out[1]
}
