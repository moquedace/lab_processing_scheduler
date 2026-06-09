project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

renviron_candidates <- c(
  file.path(project_root, "shiny_app", ".Renviron"),
  file.path(project_root, ".Renviron")
)

renviron_file <- renviron_candidates[file.exists(renviron_candidates)][1]

if (!is.na(renviron_file)) {
  readRenviron(renviron_file)
}

local_library <- file.path(project_root, ".r-lib")
dir.create(local_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(local_library, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

pkg <- c(
  "googlesheets4",
  "gargle",
  "dplyr",
  "stringr",
  "tibble"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg, lib = local_library)
}

invisible(lapply(pkg, library, character.only = TRUE))

sheet_url <- Sys.getenv("LAB_SCHEDULER_SHEET_URL")
confirm_migration <- identical(Sys.getenv("LAB_SCHEDULER_MIGRATE_USAGE_LOG_CONFIRM"), "TRUE")
service_account_json <- Sys.getenv("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON")

if (sheet_url == "") {
  stop("Set LAB_SCHEDULER_SHEET_URL before migration.")
}

service_account_candidates <- c(
  service_account_json,
  file.path(project_root, "secrets", "google_service_account.json"),
  file.path(project_root, "shiny_app", "secrets", "google_service_account.json")
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

  googlesheets4::gs4_auth(token = service_account_token)
} else {
  googlesheets4::gs4_auth(email = TRUE)
}

required_usage_columns <- c(
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
)

read_sheet_clean <- function(sheet_name) {
  googlesheets4::read_sheet(
    ss = sheet_url,
    sheet = sheet_name,
    col_types = "c"
  ) %>%
    dplyr::rename_with(stringr::str_trim) %>%
    dplyr::select(!dplyr::matches("^\\.\\.\\.[0-9]+$")) %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ ifelse(is.na(.x), NA_character_, stringr::str_trim(as.character(.x)))
      )
    )
}

first_available <- function(tbl, column_names) {
  for (column_name in column_names) {
    if (column_name %in% names(tbl)) {
      return(tbl[[column_name]])
    }
  }

  rep(NA_character_, nrow(tbl))
}

write_sheet <- function(sheet_name, data_tbl) {
  data_tbl <- data_tbl %>%
    dplyr::mutate(dplyr::across(dplyr::everything(), as.character))

  googlesheets4::range_clear(
    ss = sheet_url,
    sheet = sheet_name
  )

  googlesheets4::range_write(
    ss = sheet_url,
    data = data_tbl,
    sheet = sheet_name,
    range = "A1",
    col_names = TRUE,
    reformat = FALSE
  )
}

available_sheets <- googlesheets4::sheet_names(sheet_url)

if (!"usage_log" %in% available_sheets) {
  stop("Sheet usage_log was not found.")
}

usage_log <- read_sheet_clean("usage_log")
current_columns <- names(usage_log)
missing_columns <- setdiff(required_usage_columns, current_columns)
extra_columns <- setdiff(current_columns, required_usage_columns)

migrated_usage_log <- tibble::tibble(
  usage_id = first_available(usage_log, "usage_id"),
  reservation_id = first_available(usage_log, "reservation_id"),
  user_id = first_available(usage_log, "user_id"),
  computer_id = first_available(usage_log, c("computer_id", "computer_assigned")),
  started_at = first_available(usage_log, c("started_at", "actual_start_time")),
  finished_at = first_available(usage_log, c("finished_at", "actual_end_time")),
  duration_hours = first_available(usage_log, c("duration_hours", "actual_hours")),
  started_by = first_available(usage_log, "started_by"),
  finished_by = first_available(usage_log, "finished_by"),
  finish_reason = first_available(usage_log, "finish_reason"),
  notes = first_available(usage_log, "notes")
)

backup_sheet_name <- paste0(
  "usage_log_backup_",
  format(Sys.time(), "%Y%m%d_%H%M%S")
)

message("Usage log schema migration")
message("Rows: ", nrow(usage_log))
message("Current columns: ", paste(current_columns, collapse = ", "))
message("Missing required columns: ", paste(missing_columns, collapse = ", "))
message("Extra columns to remove from active sheet: ", paste(extra_columns, collapse = ", "))
message("Backup sheet to create: ", backup_sheet_name)

if (!confirm_migration) {
  message("\nDry run only. To apply, run:")
  message('Sys.setenv(LAB_SCHEDULER_MIGRATE_USAGE_LOG_CONFIRM = "TRUE")')
  message('source("scripts/11_migrate_usage_log_schema.R")')
} else {
  googlesheets4::sheet_add(
    ss = sheet_url,
    sheet = backup_sheet_name
  )

  googlesheets4::range_write(
    ss = sheet_url,
    data = usage_log,
    sheet = backup_sheet_name,
    range = "A1",
    col_names = TRUE,
    reformat = FALSE
  )

  write_sheet("usage_log", migrated_usage_log)

  message("\nMigration completed.")
  message("Backup sheet: ", backup_sheet_name)
  message("New usage_log columns: ", paste(names(migrated_usage_log), collapse = ", "))
}
