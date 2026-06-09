pkg <- c(
  "googlesheets4",
  "gargle",
  "dplyr",
  "purrr",
  "stringr",
  "tibble"
)

project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

if (!grepl("lab-processing-scheduler$", project_root)) {
  stop(
    "The working directory does not appear to be the project root. ",
    "In RStudio, go to: Session > Set Working Directory > To Project Directory"
  )
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

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg, lib = local_library)
}

invisible(lapply(pkg, library, character.only = TRUE))

sheet_url <- Sys.getenv("LAB_SCHEDULER_SHEET_URL")
service_account_json <- Sys.getenv("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON")

if (sheet_url == "") {
  stop("Set LAB_SCHEDULER_SHEET_URL before validation.")
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

required_sheets <- c(
  "users",
  "computers",
  "reservations",
  "lists",
  "priority_rules",
  "usage_log",
  "audit_log",
  "settings"
)

available_sheets <- googlesheets4::sheet_names(sheet_url)

missing_sheets <- setdiff(required_sheets, available_sheets)

if (length(missing_sheets) > 0) {
  stop(
    "Missing sheets: ",
    paste(missing_sheets, collapse = ", ")
  )
}

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

database <- purrr::map(
  required_sheets,
  read_sheet_clean
) %>%
  stats::setNames(required_sheets)

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

check_required_columns <- function(sheet_name) {
  expected_columns <- required_columns[[sheet_name]]
  available_columns <- names(database[[sheet_name]])
  
  missing_cols <- setdiff(expected_columns, available_columns)
  extra_cols <- setdiff(available_columns, expected_columns)
  validation_status <- ifelse(length(missing_cols) == 0, "ok", "error")
  
  tibble::tibble(
    sheet = sheet_name,
    missing_columns = paste(missing_cols, collapse = ", "),
    extra_columns = paste(extra_cols, collapse = ", "),
    status = validation_status
  )
}

column_check <- purrr::map_dfr(
  names(required_columns),
  check_required_columns
)

if (any(column_check$status == "error")) {
  print(column_check)
  stop("Column validation failed.")
}

users <- database$users
computers <- database$computers
lists <- database$lists
priority_rules <- database$priority_rules
settings <- database$settings
reservations <- database$reservations

active_list_values <- lists %>%
  dplyr::filter(active == "TRUE")

valid_user_levels <- active_list_values %>%
  dplyr::filter(list_name == "user_level") %>%
  dplyr::pull(value)

valid_computers_requested <- active_list_values %>%
  dplyr::filter(list_name == "computer_requested") %>%
  dplyr::pull(value)

valid_computers_assigned <- active_list_values %>%
  dplyr::filter(list_name == "computer_assigned") %>%
  dplyr::pull(value)

valid_settings <- settings %>%
  dplyr::filter(active == "TRUE")

duplicate_users <- users %>%
  dplyr::filter(!is.na(user_id), user_id != "") %>%
  dplyr::count(user_id) %>%
  dplyr::filter(n > 1)

duplicate_emails <- users %>%
  dplyr::filter(!is.na(email), email != "") %>%
  dplyr::count(email) %>%
  dplyr::filter(n > 1)

invalid_user_levels <- users %>%
  dplyr::filter(!user_level %in% valid_user_levels) %>%
  dplyr::select(user_id, full_name, user_level)

invalid_can_book <- users %>%
  dplyr::filter(!can_book %in% c("TRUE", "FALSE")) %>%
  dplyr::select(user_id, full_name, can_book)

invalid_user_status <- users %>%
  dplyr::filter(!status %in% c("active", "inactive")) %>%
  dplyr::select(user_id, full_name, status)

invalid_computer_ids <- computers %>%
  dplyr::filter(!computer_id %in% valid_computers_assigned) %>%
  dplyr::select(computer_id, computer_name)

invalid_computer_status <- computers %>%
  dplyr::filter(!status %in% c("active", "inactive", "maintenance")) %>%
  dplyr::select(computer_id, computer_name, status)

invalid_can_be_booked <- computers %>%
  dplyr::filter(!can_be_booked %in% c("TRUE", "FALSE")) %>%
  dplyr::select(computer_id, computer_name, can_be_booked)

invalid_priority_user_levels <- priority_rules %>%
  dplyr::filter(rule_group == "user_level") %>%
  dplyr::filter(!condition_value %in% valid_user_levels) %>%
  dplyr::select(rule_id, rule_group, condition_value)

invalid_settings_boolean <- valid_settings %>%
  dplyr::filter(
    setting_name %in% c(
      "allow_auto_approval",
      "public_show_pending",
      "public_show_user_level",
      "public_show_processing_type",
      "public_show_computing_demand",
      "public_show_email",
      "public_show_advisor",
      "public_show_justification",
      "public_show_admin_notes",
      "admin_password_enabled",
      "require_registered_user",
      "require_active_user",
      "require_can_book",
      "require_email_confirmation",
      "allow_super_1_booking",
      "allow_super_2_booking",
      "allow_any_computer_request",
      "allow_same_day_booking",
      "allow_weekend_booking",
      "business_hours_enabled",
      "maintenance_mode",
      "auto_finish_expired_reservations",
      "show_lab_about_block",
      "show_technical_specs",
      "show_quick_recommendation",
      "manual_approval_if_requires_super_2",
      "manual_approval_if_conflict",
      "manual_approval_if_unknown_demand"
    )
  ) %>%
  dplyr::filter(!setting_value %in% c("TRUE", "FALSE")) %>%
  dplyr::select(setting_name, setting_value)

validation_summary <- tibble::tibble(
  check = c(
    "required_sheets",
    "required_columns",
    "duplicate_users",
    "duplicate_emails",
    "invalid_user_levels",
    "invalid_can_book",
    "invalid_user_status",
    "invalid_computer_ids",
    "invalid_computer_status",
    "invalid_can_be_booked",
    "invalid_priority_user_levels",
    "invalid_settings_boolean"
  ),
  issues = c(
    length(missing_sheets),
    sum(column_check$status == "error"),
    nrow(duplicate_users),
    nrow(duplicate_emails),
    nrow(invalid_user_levels),
    nrow(invalid_can_book),
    nrow(invalid_user_status),
    nrow(invalid_computer_ids),
    nrow(invalid_computer_status),
    nrow(invalid_can_be_booked),
    nrow(invalid_priority_user_levels),
    nrow(invalid_settings_boolean)
  )
)

print(validation_summary)

if (sum(validation_summary$issues) > 0) {
  message("\nDetailed issues:")
  
  issue_objects <- list(
    duplicate_users = duplicate_users,
    duplicate_emails = duplicate_emails,
    invalid_user_levels = invalid_user_levels,
    invalid_can_book = invalid_can_book,
    invalid_user_status = invalid_user_status,
    invalid_computer_ids = invalid_computer_ids,
    invalid_computer_status = invalid_computer_status,
    invalid_can_be_booked = invalid_can_be_booked,
    invalid_priority_user_levels = invalid_priority_user_levels,
    invalid_settings_boolean = invalid_settings_boolean
  )
  
  purrr::iwalk(
    issue_objects,
    function(tbl, nm) {
      if (nrow(tbl) > 0) {
        message("\n", nm, ":")
        print(tbl)
      }
    }
  )
  
  stop("Database validation found issues.")
}

message("\nDatabase validation completed successfully.")
message("Users: ", nrow(users))
message("Computers: ", nrow(computers))
message("List items: ", nrow(lists))
message("Priority rules: ", nrow(priority_rules))
message("Settings: ", nrow(settings))
