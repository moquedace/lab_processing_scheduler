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
service_account_json <- Sys.getenv("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON")
confirm_reset <- identical(Sys.getenv("LAB_SCHEDULER_RESET_OPERATIONAL_CONFIRM"), "TRUE")

if (sheet_url == "") {
  stop("Set LAB_SCHEDULER_SHEET_URL before resetting operational sheets.")
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

required_columns <- list(
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
  )
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

empty_sheet_tbl <- function(sheet_name) {
  tibble::as_tibble(
    stats::setNames(
      replicate(length(required_columns[[sheet_name]]), character(), simplify = FALSE),
      required_columns[[sheet_name]]
    )
  )
}

write_empty_sheet <- function(sheet_name) {
  googlesheets4::range_clear(
    ss = sheet_url,
    sheet = sheet_name
  )

  googlesheets4::range_write(
    ss = sheet_url,
    data = empty_sheet_tbl(sheet_name),
    sheet = sheet_name,
    range = "A1",
    col_names = TRUE,
    reformat = FALSE
  )
}

available_sheets <- googlesheets4::sheet_names(sheet_url)
missing_sheets <- setdiff(names(required_columns), available_sheets)

if (length(missing_sheets) > 0) {
  stop("Missing operational sheets: ", paste(missing_sheets, collapse = ", "))
}

reset_summary <- tibble::tibble(
  sheet = character(),
  rows_before = integer(),
  rows_after = integer(),
  action = character()
)

message("\nOperational sheet reset")
message("Confirm reset: ", confirm_reset)
message("Sheets: ", paste(names(required_columns), collapse = ", "))

for (sheet_name in names(required_columns)) {
  sheet_tbl <- read_sheet_clean(sheet_name)
  available_columns <- names(sheet_tbl)
  missing_columns <- setdiff(required_columns[[sheet_name]], available_columns)
  extra_columns <- setdiff(available_columns, required_columns[[sheet_name]])

  if (length(missing_columns) > 0 || length(extra_columns) > 0) {
    stop(
      "Column mismatch in ",
      sheet_name,
      ". Missing: ",
      paste(missing_columns, collapse = ", "),
      ". Extra: ",
      paste(extra_columns, collapse = ", ")
    )
  }

  action <- if (confirm_reset) {
    write_empty_sheet(sheet_name)
    "reset"
  } else {
    "preview_only"
  }

  reset_summary <- dplyr::bind_rows(
    reset_summary,
    tibble::tibble(
      sheet = sheet_name,
      rows_before = nrow(sheet_tbl),
      rows_after = if (confirm_reset) 0L else nrow(sheet_tbl),
      action = action
    )
  )
}

message("\nReset summary:")
print(reset_summary, n = Inf)

if (!confirm_reset) {
  message(
    "\nPreview only. To reset operational sheets, run again with: ",
    "Sys.setenv(LAB_SCHEDULER_RESET_OPERATIONAL_CONFIRM = 'TRUE')"
  )
} else {
  message("\nOperational sheets reset completed.")
}
