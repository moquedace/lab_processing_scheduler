project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

run_step <- function(label, script_name) {
  message("\n== ", label, " ==")
  source(file.path(project_root, "scripts", script_name), local = new.env(parent = globalenv()))
  message("OK: ", label)
}

previous_auto_cleanup <- Sys.getenv("LAB_SCHEDULER_UI_TEST_AUTO_CLEANUP", unset = NA_character_)

if (is.na(previous_auto_cleanup) || previous_auto_cleanup == "") {
  Sys.setenv(LAB_SCHEDULER_UI_TEST_AUTO_CLEANUP = "TRUE")
}

on.exit(
  {
    if (is.na(previous_auto_cleanup)) {
      Sys.unsetenv("LAB_SCHEDULER_UI_TEST_AUTO_CLEANUP")
    } else {
      Sys.setenv(LAB_SCHEDULER_UI_TEST_AUTO_CLEANUP = previous_auto_cleanup)
    }
  },
  add = TRUE
)

message("Starting Lab Processing Scheduler regression suite.")
message("Project root: ", project_root)
message("UI auto cleanup: ", Sys.getenv("LAB_SCHEDULER_UI_TEST_AUTO_CLEANUP"))

run_step(
  label = "Google Sheets database validation",
  script_name = "01_validate_database.R"
)

run_step(
  label = "Shiny app logic tests",
  script_name = "07_test_shiny_app_logic.R"
)

run_step(
  label = "Shiny UI journey test",
  script_name = "10_run_ui_test_with_first_user.R"
)

message("\nAll regression checks passed.")
