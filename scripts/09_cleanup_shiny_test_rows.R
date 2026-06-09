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
cleanup_marker <- Sys.getenv("LAB_SCHEDULER_TEST_CLEANUP_MARKER", unset = "AUTOMATED_TEST")
confirm_cleanup <- identical(Sys.getenv("LAB_SCHEDULER_TEST_CLEANUP_CONFIRM"), "TRUE")
service_account_json <- Sys.getenv("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON")

if (sheet_url == "") {
  stop("Set LAB_SCHEDULER_SHEET_URL before cleanup.")
}

if (cleanup_marker == "") {
  stop("LAB_SCHEDULER_TEST_CLEANUP_MARKER cannot be empty.")
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
  
  googlesheets4::gs4_auth(
    token = service_account_token
  )
} else {
  googlesheets4::gs4_auth(email = TRUE)
}

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

write_sheet <- function(sheet_name, data_tbl) {
  data_tbl <- data_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
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

row_has_marker <- function(tbl, columns, marker) {
  available_columns <- intersect(columns, names(tbl))
  
  if (length(available_columns) == 0 || nrow(tbl) == 0) {
    return(rep(FALSE, nrow(tbl)))
  }
  
  marker_matches <- lapply(
    available_columns,
    function(column_name) {
      values <- tbl[[column_name]]
      values <- ifelse(is.na(values), "", values)
      stringr::str_detect(values, stringr::fixed(marker))
    }
  )
  
  Reduce(`|`, marker_matches, init = rep(FALSE, nrow(tbl)))
}

cleanup_specs <- list(
  reservations = c(
    "reservation_id",
    "justification",
    "public_notes",
    "admin_notes"
  ),
  audit_log = c(
    "log_id",
    "reservation_id",
    "notes",
    "old_value",
    "new_value"
  ),
  usage_log = c(
    "usage_id",
    "reservation_id",
    "notes"
  )
)

available_sheets <- googlesheets4::sheet_names(sheet_url)

cleanup_summary <- tibble::tibble(
  sheet = character(),
  rows_before = integer(),
  rows_matching = integer(),
  rows_after = integer(),
  action = character()
)

message("\nCleanup marker: ", cleanup_marker)
message("Confirm cleanup: ", confirm_cleanup)

for (sheet_name in names(cleanup_specs)) {
  if (!sheet_name %in% available_sheets) {
    cleanup_summary <- dplyr::bind_rows(
      cleanup_summary,
      tibble::tibble(
        sheet = sheet_name,
        rows_before = 0L,
        rows_matching = 0L,
        rows_after = 0L,
        action = "sheet_missing"
      )
    )
    next
  }
  
  sheet_tbl <- read_sheet_clean(sheet_name)
  matching_rows <- row_has_marker(
    tbl = sheet_tbl,
    columns = cleanup_specs[[sheet_name]],
    marker = cleanup_marker
  )
  
  cleaned_tbl <- sheet_tbl[!matching_rows, , drop = FALSE]
  
  action <- if (sum(matching_rows) == 0) {
    "none"
  } else if (confirm_cleanup) {
    write_sheet(sheet_name, cleaned_tbl)
    "deleted"
  } else {
    "preview_only"
  }
  
  cleanup_summary <- dplyr::bind_rows(
    cleanup_summary,
    tibble::tibble(
      sheet = sheet_name,
      rows_before = nrow(sheet_tbl),
      rows_matching = sum(matching_rows),
      rows_after = nrow(cleaned_tbl),
      action = action
    )
  )
  
  if (sum(matching_rows) > 0) {
    message("\nMatching rows in ", sheet_name, ":")
    print(sheet_tbl[matching_rows, , drop = FALSE])
  }
}

message("\nCleanup summary:")
print(cleanup_summary, n = Inf)

if (!confirm_cleanup && any(cleanup_summary$rows_matching > 0)) {
  message(
    "\nPreview only. To delete matching rows, run again with: ",
    "Sys.setenv(LAB_SCHEDULER_TEST_CLEANUP_CONFIRM = 'TRUE')"
  )
}

if (confirm_cleanup) {
  message("\nCleanup completed.")
}
