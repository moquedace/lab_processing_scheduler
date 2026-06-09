pkg <- c(
  "rsconnect"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg)
}

invisible(lapply(pkg, library, character.only = TRUE))

rm(list = ls())
gc()

project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

app_dir <- file.path(project_root, "shiny_app")

renviron_file <- file.path(app_dir, ".Renviron")

renviron_candidates <- c(
  renviron_file,
  file.path(project_root, ".Renviron")
)

renviron_source <- renviron_candidates[file.exists(renviron_candidates)][1]

if (!is.na(renviron_source)) {
  readRenviron(renviron_source)
}

required_files <- c(
  file.path(app_dir, "app.R"),
  file.path(app_dir, "www", "img", "logo_geocis.png"),
  file.path(app_dir, "www", "img", "logo_solos.png"),
  file.path(app_dir, "www", "img", "logo_esalq.png"),
  file.path(app_dir, "www", "img", "logo_usp.png"),
  file.path(app_dir, "www", "img", "logo_fapesp.png"),
  file.path(app_dir, "secrets", "google_service_account.json")
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    paste(
      "Missing required files:",
      paste(missing_files, collapse = "\n")
    )
  )
}

sheet_url <- Sys.getenv("LAB_SCHEDULER_SHEET_URL")
admin_password <- Sys.getenv("LAB_SCHEDULER_ADMIN_PASSWORD")

if (sheet_url == "") {
  stop("Set LAB_SCHEDULER_SHEET_URL before deploying.")
}

if (admin_password == "") {
  stop("Set LAB_SCHEDULER_ADMIN_PASSWORD before deploying.")
}

skip_preflight <- identical(Sys.getenv("LAB_SCHEDULER_DEPLOY_SKIP_PREFLIGHT"), "TRUE")

if (!skip_preflight) {
  message("\nRunning deployment preflight checks...")

  source(
    file.path(project_root, "scripts", "01_validate_database.R"),
    local = new.env(parent = globalenv())
  )

  source(
    file.path(project_root, "scripts", "07_test_shiny_app_logic.R"),
    local = new.env(parent = globalenv())
  )

  message("\nDeployment preflight checks passed.")
} else {
  message("\nDeployment preflight checks skipped by LAB_SCHEDULER_DEPLOY_SKIP_PREFLIGHT=TRUE.")
}

write_env_line <- function(name, value) {
  paste0(name, "=", encodeString(value, quote = "\""))
}

renviron_lines <- c(
  write_env_line("LAB_SCHEDULER_SHEET_URL", sheet_url),
  write_env_line("LAB_SCHEDULER_ADMIN_PASSWORD", admin_password),
  write_env_line("LAB_SCHEDULER_SERVICE_ACCOUNT_JSON", "secrets/google_service_account.json")
)

writeLines(
  text = renviron_lines,
  con = renviron_file,
  useBytes = TRUE
)

message("\nTemporary .Renviron created at:")
message(renviron_file)
message("\nDo not commit this file.")

module_files <- list.files(
  file.path(app_dir, "R"),
  pattern = "\\.R$",
  full.names = FALSE
)

app_files <- c(
  "app.R",
  ".Renviron",
  paste0("R/", module_files),
  "www/img/logo_geocis.png",
  "www/img/logo_solos.png",
  "www/img/logo_esalq.png",
  "www/img/logo_usp.png",
  "www/img/logo_fapesp.png",
  "secrets/google_service_account.json"
)

rsconnect::deployApp(
  appDir = app_dir,
  appName = "lab-processing-scheduler",
  appTitle = "Reserva dos Computadores de Processamento",
  appFiles = app_files,
  forceUpdate = TRUE
)

message("\nDeployment command completed.")
message("Keep shiny_app/.Renviron out of Git.")
