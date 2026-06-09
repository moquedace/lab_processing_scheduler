project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

source_logo_dir <- file.path(
  project_root,
  "docs",
  "assets",
  "img"
)

target_logo_dir <- file.path(
  project_root,
  "shiny_app",
  "www",
  "img"
)

source_secret_candidates <- c(
  Sys.getenv("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON"),
  file.path(project_root, "secrets", "google_service_account.json"),
  file.path(project_root, "shiny_app", "secrets", "google_service_account.json")
)

target_secret_dir <- file.path(
  project_root,
  "shiny_app",
  "secrets"
)

target_secret_file <- file.path(
  target_secret_dir,
  "google_service_account.json"
)

source_secret_candidates <- source_secret_candidates[
  !is.na(source_secret_candidates) &
    source_secret_candidates != ""
]

source_secret_candidates <- normalizePath(
  source_secret_candidates,
  winslash = "/",
  mustWork = FALSE
)

source_secret_file <- source_secret_candidates[
  file.exists(source_secret_candidates)
][1]

required_logos <- c(
  "logo_geocis.png",
  "logo_solos.png",
  "logo_esalq.png",
  "logo_usp.png",
  "logo_fapesp.png"
)

required_modules <- c(
  "01_sheets.R",
  "02_settings_lists.R",
  "03_priority.R",
  "04_public_formatting.R",
  "05_reservations.R",
  "06_ui_components.R",
  "07_theme.R",
  "08_ui.R",
  "09_server_public.R"
)

dir.create(target_logo_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(target_secret_dir, recursive = TRUE, showWarnings = FALSE)

missing_logos <- required_logos[
  !file.exists(file.path(source_logo_dir, required_logos))
]

if (length(missing_logos) > 0) {
  stop(
    paste(
      "Missing logo files:",
      paste(missing_logos, collapse = ", ")
    )
  )
}

missing_modules <- required_modules[
  !file.exists(file.path(project_root, "shiny_app", "R", required_modules))
]

if (length(missing_modules) > 0) {
  stop(
    paste(
      "Missing Shiny module files:",
      paste(missing_modules, collapse = ", ")
    )
  )
}

for (logo_file in required_logos) {
  file.copy(
    from = file.path(source_logo_dir, logo_file),
    to = file.path(target_logo_dir, logo_file),
    overwrite = TRUE
  )
}

if (is.na(source_secret_file) || !file.exists(source_secret_file)) {
  stop(
    paste(
      "Service account file not found in:",
      paste(source_secret_candidates, collapse = "\n")
    )
  )
}

secret_already_in_place <- identical(
  normalizePath(source_secret_file, winslash = "/", mustWork = TRUE),
  normalizePath(target_secret_file, winslash = "/", mustWork = FALSE)
)

if (!secret_already_in_place) {
  file.copy(
    from = source_secret_file,
    to = target_secret_file,
    overwrite = TRUE
  )
}

message("\nFiles prepared for shinyapps.io.")
message("Logos copied to: ", target_logo_dir)
message("Service account available at: ", target_secret_file)
message("\nDo not commit shiny_app/secrets or any JSON file.")
