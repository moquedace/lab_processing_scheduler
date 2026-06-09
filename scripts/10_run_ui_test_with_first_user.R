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
  "stringr"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg, lib = local_library)
}

invisible(lapply(pkg, library, character.only = TRUE))

sheet_url <- Sys.getenv("LAB_SCHEDULER_SHEET_URL")

if (sheet_url == "") {
  stop(
    "LAB_SCHEDULER_SHEET_URL is not set. ",
    "Set it in shiny_app/.Renviron or with Sys.setenv()."
  )
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

users <- googlesheets4::read_sheet(
  ss = sheet_url,
  sheet = "users",
  col_types = "c"
) %>%
  dplyr::rename_with(stringr::str_trim) %>%
  dplyr::mutate(
    dplyr::across(
      dplyr::everything(),
      ~ ifelse(is.na(.x), NA_character_, stringr::str_trim(as.character(.x)))
    )
  )

test_user <- users %>%
  dplyr::filter(
    status == "active",
    !is.na(user_id),
    user_id != "",
    !is.na(email),
    email != ""
  ) %>%
  dplyr::arrange(full_name) %>%
  dplyr::slice(1)

if (nrow(test_user) != 1) {
  stop("No active user with user_id and email was found in the users sheet.")
}

auto_cleanup <- !identical(Sys.getenv("LAB_SCHEDULER_UI_TEST_AUTO_CLEANUP"), "FALSE")
max_attempts <- suppressWarnings(
  as.integer(Sys.getenv("LAB_SCHEDULER_UI_TEST_ATTEMPTS", unset = "3"))
)

if (is.na(max_attempts) || max_attempts < 1) {
  max_attempts <- 3L
}

cleanup_test_marker <- function(marker_value) {
  if (!auto_cleanup || is.na(marker_value) || marker_value == "") {
    return(invisible(NULL))
  }

  Sys.setenv(
    LAB_SCHEDULER_TEST_CLEANUP_MARKER = marker_value,
    LAB_SCHEDULER_TEST_CLEANUP_CONFIRM = "TRUE"
  )

  try(
    source(file.path(project_root, "scripts", "09_cleanup_shiny_test_rows.R")),
    silent = FALSE
  )

  invisible(NULL)
}

if (auto_cleanup) {
  on.exit(
    {
      cleanup_test_marker(Sys.getenv("LAB_SCHEDULER_UI_TEST_MARKER"))
    },
    add = TRUE
  )
}

message("\nSelected UI test user:")
message("Name: ", test_user$full_name[1])
message("User ID: ", test_user$user_id[1])
message("Auto cleanup: ", auto_cleanup)
message("UI test attempts: ", max_attempts)

rscript <- file.path(R.home("bin"), "Rscript.exe")

if (!file.exists(rscript)) {
  rscript <- file.path(R.home("bin"), "Rscript")
}

test_script <- file.path(project_root, "scripts", "08_test_shiny_ui.R")
status <- 1L

for (attempt in seq_len(max_attempts)) {
  test_marker <- paste0(
    "AUTOMATED_TEST_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_try",
    attempt
  )

  Sys.setenv(
    LAB_SCHEDULER_UI_TEST_USER_ID = test_user$user_id[1],
    LAB_SCHEDULER_UI_TEST_EMAIL = test_user$email[1],
    LAB_SCHEDULER_UI_TEST_WRITE = "TRUE",
    LAB_SCHEDULER_UI_TEST_MARKER = test_marker
  )

  message("\nUI test attempt ", attempt, " of ", max_attempts)
  message("Marker: ", test_marker)

  status <- system2(rscript, test_script)

  if (identical(status, 0L)) {
    break
  }

  message("\nUI test attempt failed with status: ", status)
  cleanup_test_marker(test_marker)

  if (attempt < max_attempts) {
    Sys.sleep(5)
  }
}

if (!identical(status, 0L)) {
  stop("Shiny UI test failed after ", max_attempts, " attempt(s). Last status: ", status)
}

cleanup_test_marker(Sys.getenv("LAB_SCHEDULER_UI_TEST_MARKER"))
