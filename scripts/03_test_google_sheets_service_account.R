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
  "dplyr",
  "purrr",
  "stringr",
  "tibble",
  "lubridate",
  "jsonlite"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg, lib = local_library)
}

invisible(lapply(pkg, library, character.only = TRUE))

sheet_url <- Sys.getenv("LAB_SCHEDULER_SHEET_URL")

if (sheet_url == "") {
  stop("Set LAB_SCHEDULER_SHEET_URL with your Google Sheets URL before running this script.")
}

service_account_json <- Sys.getenv("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON")

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

if (is.na(service_account_json) || !file.exists(service_account_json)) {
  stop(
    paste(
      "Service account JSON file not found in:",
      paste(service_account_candidates, collapse = "\n")
    )
  )
}

expected_sheets <- c(
  "users",
  "computers",
  "reservations",
  "lists",
  "priority_rules",
  "usage_log",
  "audit_log",
  "settings"
)

required_columns <- list(
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
    "points",
    "description",
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

check_required_columns <- function(sheet_name, sheet_tbl, required_columns) {
  required <- required_columns[[sheet_name]]
  current <- names(sheet_tbl)
  
  required <- required %>%
    as.character() %>%
    stringr::str_trim()
  
  current <- current %>%
    as.character() %>%
    stringr::str_trim()
  
  required <- required[!is.na(required) & required != ""]
  current <- current[!is.na(current) & current != ""]
  
  missing_columns <- setdiff(required, current)
  extra_columns <- setdiff(current, required)
  
  missing_columns <- missing_columns[!is.na(missing_columns) & missing_columns != ""]
  extra_columns <- extra_columns[!is.na(extra_columns) & extra_columns != ""]
  
  missing_text <- paste(missing_columns, collapse = ", ")
  extra_text <- paste(extra_columns, collapse = ", ")
  
  status_value <- if (length(missing_columns) == 0) {
    "ok"
  } else {
    "error"
  }
  
  tibble::tibble(
    sheet = sheet_name,
    missing_columns = missing_text,
    extra_columns = extra_text,
    status = status_value
  )
}

append_service_account_test <- function(sheet_url) {
  test_row <- tibble::tibble(
    test_id = paste0(
      "service_test_",
      format(Sys.time(), "%Y%m%d_%H%M%S")
    ),
    test_time = format(
      lubridate::now(tzone = "America/Sao_Paulo"),
      "%Y-%m-%d %H:%M:%S"
    ),
    test_user = Sys.info()[["user"]],
    test_note = "Google Sheets service account test from R"
  )
  
  available_sheets <- googlesheets4::sheet_names(sheet_url)
  
  if (!"service_account_test" %in% available_sheets) {
    googlesheets4::sheet_add(
      ss = sheet_url,
      sheet = "service_account_test"
    )
    
    googlesheets4::range_write(
      ss = sheet_url,
      data = test_row,
      sheet = "service_account_test",
      range = "A1",
      col_names = TRUE,
      reformat = FALSE
    )
  } else {
    googlesheets4::sheet_append(
      ss = sheet_url,
      data = test_row,
      sheet = "service_account_test"
    )
  }
  
  test_row
}

service_account_info <- jsonlite::fromJSON(service_account_json)

message("\nService account file:")
message(service_account_json)

message("\nService account email:")
message(service_account_info$client_email)

message("\nAuthenticating with Google Sheets using service account...")
googlesheets4::gs4_auth(
  path = service_account_json,
  scopes = "https://www.googleapis.com/auth/spreadsheets"
)

message("\nChecking sheet names...")
available_sheets <- googlesheets4::sheet_names(sheet_url)

missing_sheets <- setdiff(expected_sheets, available_sheets)
extra_sheets <- setdiff(
  available_sheets,
  c(expected_sheets, "connection_test", "service_account_test")
)

if (length(missing_sheets) > 0) {
  message("\nMissing sheets:")
  print(missing_sheets)
  stop("Sheet validation failed.")
}

message("\nAll expected sheets were found.")

if (length(extra_sheets) > 0) {
  message("\nExtra sheets found, not a problem:")
  print(extra_sheets)
}

message("\nReading database sheets...")
database <- purrr::map(
  expected_sheets,
  read_sheet_clean
) %>%
  stats::setNames(expected_sheets)

message("\nChecking required columns...")
column_check <- purrr::map_dfr(
  expected_sheets,
  ~ check_required_columns(
    sheet_name = .x,
    sheet_tbl = database[[.x]],
    required_columns = required_columns
  )
)

print(column_check)

if (any(column_check$status == "error")) {
  message("\nColumn validation errors found:")
  print(column_check %>% dplyr::filter(status == "error"))
  stop("Column validation failed.")
}

message("\nCounting records...")
record_count <- tibble::tibble(
  sheet = names(database),
  rows = purrr::map_int(database, nrow),
  columns = purrr::map_int(database, ncol)
)

print(record_count)

message("\nWriting service account test...")
test_row <- append_service_account_test(sheet_url)

message("\nService account test row written:")
print(test_row)

message("\nGoogle Sheets service account test completed successfully.")
