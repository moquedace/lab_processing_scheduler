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
  "shinytest2",
  "testthat",
  "googlesheets4",
  "gargle",
  "dplyr",
  "stringr"
)
missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg, lib = local_library)
}

app_dir <- file.path(project_root, "shiny_app")
Sys.setenv(NOT_CRAN = "true")

sheet_url <- Sys.getenv("LAB_SCHEDULER_SHEET_URL")
admin_password <- Sys.getenv("LAB_SCHEDULER_ADMIN_PASSWORD")
test_user_id <- Sys.getenv("LAB_SCHEDULER_UI_TEST_USER_ID")
test_user_email <- Sys.getenv("LAB_SCHEDULER_UI_TEST_EMAIL")
allow_write <- identical(Sys.getenv("LAB_SCHEDULER_UI_TEST_WRITE"), "TRUE")
test_marker <- Sys.getenv(
  "LAB_SCHEDULER_UI_TEST_MARKER",
  unset = paste0("AUTOMATED_TEST_", format(Sys.time(), "%Y%m%d_%H%M%S"))
)

if (sheet_url == "") {
  stop(
    "Set LAB_SCHEDULER_SHEET_URL before running UI tests. ",
    "Use a test Google Sheet when possible."
  )
}

if (test_user_id == "" || test_user_email == "") {
  stop(
    "Set LAB_SCHEDULER_UI_TEST_USER_ID and LAB_SCHEDULER_UI_TEST_EMAIL ",
    "before running the full UI test."
  )
}

if (!allow_write) {
  stop("Set LAB_SCHEDULER_UI_TEST_WRITE=TRUE to run the full UI write test.")
}

if (admin_password == "") {
  stop("Set LAB_SCHEDULER_ADMIN_PASSWORD to run the admin UI test.")
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

  googlesheets4::gs4_auth(token = service_account_token)
} else {
  googlesheets4::gs4_auth(email = TRUE)
}

message("\nStarting Shiny UI journey test.")
message("App directory: ", app_dir)
message("Write actions enabled: ", allow_write)
message("Test marker: ", test_marker)

chromote_timeout <- suppressWarnings(
  as.numeric(Sys.getenv("LAB_SCHEDULER_CHROMOTE_TIMEOUT", unset = "60"))
)

if (is.na(chromote_timeout) || chromote_timeout < 10) {
  chromote_timeout <- 60
}

options(chromote.timeout = chromote_timeout)
message("Chromote startup timeout: ", chromote_timeout, "s")

app <- shinytest2::AppDriver$new(
  app_dir = app_dir,
  name = paste0("lab-processing-scheduler-ui-", test_marker),
  seed = 123,
  height = 900,
  width = 1360,
  load_timeout = 90000,
  timeout = 90000
)

on.exit(
  {
    try(app$stop(), silent = TRUE)
  },
  add = TRUE
)

wait_for_app <- function(seconds = 1) {
  if (seconds > 0) {
    Sys.sleep(seconds)
  }

  invisible(TRUE)
}

dump_app_logs <- function(stage) {
  logs <- tryCatch(
    app$get_logs(),
    error = function(e) {
      list(list(type = "log_error", message = conditionMessage(e)))
    }
  )

  if (length(logs) == 0) {
    message("\nNo app logs available during ", stage, ".")
    return(invisible(NULL))
  }

  message("\nApp logs during ", stage, ":")

  if (is.data.frame(logs)) {
    for (row_id in seq_len(nrow(logs))) {
      log_type <- if ("level" %in% names(logs)) logs$level[row_id] else "unknown"
      log_source <- if ("source" %in% names(logs)) logs$source[row_id] else "unknown"
      log_message <- if ("message" %in% names(logs)) {
        logs$message[row_id]
      } else {
        paste(logs[row_id, ], collapse = " ")
      }

      message("[", log_source, "/", log_type, "] ", log_message)
    }

    return(invisible(NULL))
  }

  for (log_item in logs) {
    if (is.list(log_item)) {
      log_type <- ifelse(is.null(log_item$type), "unknown", log_item$type)
      log_message <- ifelse(is.null(log_item$message), "", log_item$message)
    } else {
      log_type <- "unknown"
      log_message <- paste(as.character(log_item), collapse = " ")
    }

    message("[", log_type, "] ", log_message)
  }

  invisible(NULL)
}

expect_snapshot <- function(values, output_id, stage, require_html = FALSE) {
  snapshot <- values$output[[output_id]]

  if (is.null(snapshot)) {
    dump_app_logs(stage)
    testthat::expect_true(FALSE, info = paste("Output not available during", stage, ":", output_id))
  }

  if (require_html) {
    has_html <- is.list(snapshot) && !is.null(snapshot$html) && nzchar(snapshot$html)

    if (!has_html) {
      dump_app_logs(stage)
      testthat::expect_true(FALSE, info = paste("HTML output not available during", stage, ":", output_id))
    }
  }

  invisible(TRUE)
}

get_values_checked <- function(stage) {
  tryCatch(
    app$get_values(),
    error = function(error) {
      dump_app_logs(stage)
      stop(error)
    }
  )
}

read_sheet_clean <- function(sheet_name) {
  googlesheets4::read_sheet(
    ss = sheet_url,
    sheet = sheet_name,
    col_types = "c"
  ) |>
    dplyr::rename_with(stringr::str_trim) |>
    dplyr::select(!dplyr::matches("^\\.\\.\\.[0-9]+$")) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ ifelse(is.na(.x), NA_character_, stringr::str_trim(as.character(.x)))
      )
    )
}

get_first_list_value <- function(list_name) {
  list_tbl <- read_sheet_clean("lists")

  values <- list_tbl |>
    dplyr::filter(
      .data$list_name == !!list_name,
      active == "TRUE",
      !is.na(value),
      value != ""
    ) |>
    dplyr::arrange(suppressWarnings(as.numeric(sort_order))) |>
    dplyr::pull(value)

  if (length(values) == 0) {
    stop("No active value found in lists for: ", list_name)
  }

  values[1]
}

find_reservation_by_marker <- function(marker_value) {
  reservations_tbl <- read_sheet_clean("reservations")

  marker_columns <- intersect(
    c("reservation_id", "justification", "public_notes", "admin_notes"),
    names(reservations_tbl)
  )

  if (length(marker_columns) == 0 || nrow(reservations_tbl) == 0) {
    return(reservations_tbl[0, , drop = FALSE])
  }

  matching_rows <- Reduce(
    `|`,
    lapply(
      marker_columns,
      function(column_name) {
        values <- reservations_tbl[[column_name]]
        values <- ifelse(is.na(values), "", values)
        stringr::str_detect(values, stringr::fixed(marker_value))
      }
    )
  )

  reservations_tbl[matching_rows, , drop = FALSE]
}

wait_for_reservation <- function(marker_value, stage, timeout_seconds = 45) {
  deadline <- Sys.time() + timeout_seconds

  repeat {
    found <- find_reservation_by_marker(marker_value)

    if (nrow(found) > 0) {
      return(found[nrow(found), , drop = FALSE])
    }

    if (Sys.time() > deadline) {
      stop("Reservation not found during ", stage, ": ", marker_value)
    }

    Sys.sleep(2)
  }
}

wait_for_reservation_status <- function(reservation_id, expected_status, stage, timeout_seconds = 45) {
  deadline <- Sys.time() + timeout_seconds

  repeat {
    reservations_tbl <- read_sheet_clean("reservations")
    found <- reservations_tbl |>
      dplyr::filter(reservation_id == !!reservation_id)

    if (nrow(found) == 1 && identical(found$status[1], expected_status)) {
      return(found)
    }

    if (Sys.time() > deadline) {
      actual_status <- if (nrow(found) == 1) found$status[1] else "<missing>"
      stop(
        "Reservation did not reach status during ", stage,
        ". Expected: ", expected_status,
        ". Actual: ", actual_status,
        ". Reservation: ", reservation_id
      )
    }

    Sys.sleep(2)
  }
}

expect_audit_event <- function(reservation_id, event_type, note_marker) {
  audit_tbl <- read_sheet_clean("audit_log")

  found <- audit_tbl |>
    dplyr::filter(
      reservation_id == !!reservation_id,
      event_type == !!event_type,
      stringr::str_detect(ifelse(is.na(notes), "", notes), stringr::fixed(note_marker))
    )

  testthat::expect_true(
    nrow(found) >= 1,
    info = paste("Expected audit event not found:", reservation_id, event_type)
  )
}

wait_for_usage_row <- function(reservation_id, expected_state, note_marker, stage, timeout_seconds = 45) {
  deadline <- Sys.time() + timeout_seconds

  repeat {
    usage_tbl <- read_sheet_clean("usage_log")

    found <- usage_tbl |>
      dplyr::filter(
        reservation_id == !!reservation_id,
        stringr::str_detect(ifelse(is.na(notes), "", notes), stringr::fixed(note_marker))
      )

    if (nrow(found) >= 1) {
      latest <- found[nrow(found), , drop = FALSE]
      finished_value <- if ("finished_at" %in% names(latest)) latest$finished_at[1] else NA_character_
      is_open <- is.na(finished_value) || identical(finished_value, "")
      is_finished <- !is_open

      if (identical(expected_state, "started") && is_open) {
        return(latest)
      }

      if (identical(expected_state, "finished") && is_finished) {
        return(latest)
      }
    }

    if (Sys.time() > deadline) {
      stop(
        "Usage row did not reach expected state during ", stage,
        ". Expected: ", expected_state,
        ". Reservation: ", reservation_id
      )
    }

    Sys.sleep(2)
  }
}

submit_booking <- function(case_id, start_date, start_time, estimated_hours, requires_super_2) {
  marker_value <- paste(test_marker, case_id, sep = "_")

  app$set_inputs(main_nav = "Solicitar reserva")
  wait_for_app(1)

  app$set_inputs(
    booking_user_id = test_user_id,
    booking_email = test_user_email,
    booking_computer_requested = "any",
    booking_start_date = as.character(start_date),
    booking_start_time = start_time,
    booking_estimated_hours = estimated_hours,
    booking_main_environment = "r",
    booking_processing_type = "raster_processing",
    booking_computing_demand = "raster_processing",
    booking_uses_gpu = "no",
    booking_requires_super_2 = requires_super_2,
    booking_can_be_reallocated = "yes",
    booking_deadline = "",
    booking_justification = paste("Teste automatizado de interface.", marker_value),
    booking_public_notes = paste("Teste automatizado.", marker_value)
  )

  wait_for_app(1)
  app$set_inputs(generate_booking_preview = "click")
  wait_for_app(4)

  booking_values <- get_values_checked(paste("booking preview", case_id))

  testthat::expect_true(
    booking_values$input$generate_booking_preview > 0,
    info = paste("Booking preview button did not increment:", case_id)
  )
  testthat::expect_true(
    !is.null(booking_values$input$booking_user_id) && booking_values$input$booking_user_id != "",
    info = paste("Booking user id was not set:", case_id)
  )
  testthat::expect_true(
    !is.null(booking_values$input$booking_email) && booking_values$input$booking_email != "",
    info = paste("Booking email was not set:", case_id)
  )
  expect_snapshot(booking_values, "booking_preview", paste("booking preview", case_id), require_html = TRUE)

  app$set_inputs(submit_booking = "click")
  wait_for_app(8)

  wait_for_reservation(marker_value, paste("booking submit", case_id))
}

run_admin_action <- function(
    reservation_id,
    note_marker,
    button_input,
    expected_status,
    event_type,
    finish_reason = NULL
) {
  app$set_inputs(main_nav = "Administração")
  wait_for_app(2)

  app$set_inputs(
    admin_reservation_id = reservation_id,
    admin_notes = note_marker
  )

  if (!is.null(finish_reason)) {
    app$set_inputs(admin_finish_reason = finish_reason)
  }

  wait_for_app(1)

  button_args <- stats::setNames(list("click"), button_input)
  do.call(app$set_inputs, button_args)
  wait_for_app(8)

  tryCatch(
    wait_for_reservation_status(
      reservation_id = reservation_id,
      expected_status = expected_status,
      stage = paste("admin action", event_type)
    ),
    error = function(error) {
      values <- get_values_checked(paste("admin action failure", event_type))
      input_names <- names(values$input)
      matching_inputs <- input_names[
        input_names %in% c(
          "admin_reservation_id",
          "admin_notes",
          "admin_finish_reason",
          button_input
        )
      ]

      message("\nAdmin input state during failed action:")
      print(values$input[matching_inputs])
      dump_app_logs(paste("admin action failure", event_type))
      stop(error)
    }
  )
  expect_audit_event(
    reservation_id = reservation_id,
    event_type = event_type,
    note_marker = note_marker
  )
}

wait_for_app(0)

message("Checking public panel outputs...")
public_values <- get_values_checked("public panel")
expect_snapshot(public_values, "public_status_cards", "public panel", require_html = TRUE)
expect_snapshot(public_values, "public_upcoming_table", "public panel")
expect_snapshot(public_values, "public_pending_block", "public panel", require_html = TRUE)

message("Creating disposable reservations through the public booking form...")
base_date <- Sys.Date() + 7
cancel_row <- submit_booking(
  case_id = "ADMIN_CANCEL",
  start_date = base_date,
  start_time = "08:00",
  estimated_hours = 2.5,
  requires_super_2 = "yes"
)
approve_row <- submit_booking(
  case_id = "ADMIN_APPROVE",
  start_date = base_date + 1,
  start_time = "09:00",
  estimated_hours = 3,
  requires_super_2 = "yes"
)
reject_row <- submit_booking(
  case_id = "ADMIN_REJECT",
  start_date = base_date + 2,
  start_time = "10:00",
  estimated_hours = 3,
  requires_super_2 = "yes"
)

testthat::expect_identical(cancel_row$status[1], "pending")
testthat::expect_identical(approve_row$status[1], "pending")
testthat::expect_identical(reject_row$status[1], "pending")

message("Checking reservations output...")
reservation_values <- get_values_checked("reservations output")
expect_snapshot(reservation_values, "reservations_table", "reservations output")

message("Logging into administration and exercising admin actions...")
app$set_inputs(main_nav = "Administração")
wait_for_app(1)

admin_values <- get_values_checked("admin output")
expect_snapshot(admin_values, "admin_panel", "admin output", require_html = TRUE)

app$set_inputs(admin_password = "wrong-password-for-ui-test")
app$set_inputs(admin_login = "click")
wait_for_app(2)

app$set_inputs(admin_password = admin_password)
app$set_inputs(admin_login = "click")
wait_for_app(3)

admin_values <- get_values_checked("admin login")
expect_snapshot(admin_values, "admin_panel", "admin login", require_html = TRUE)

approve_note <- paste(test_marker, "ADMIN_APPROVE_NOTE", sep = "_")
reject_note <- paste(test_marker, "ADMIN_REJECT_NOTE", sep = "_")
cancel_note <- paste(test_marker, "ADMIN_CANCEL_NOTE", sep = "_")
start_note <- paste(test_marker, "ADMIN_START_NOTE", sep = "_")
finish_note <- paste(test_marker, "ADMIN_FINISH_NOTE", sep = "_")
finish_reason_value <- get_first_list_value("finish_reason")

run_admin_action(
  reservation_id = approve_row$reservation_id[1],
  note_marker = approve_note,
  button_input = "admin_approve",
  expected_status = "approved",
  event_type = "reservation_approved"
)

run_admin_action(
  reservation_id = approve_row$reservation_id[1],
  note_marker = start_note,
  button_input = "admin_start_use",
  expected_status = "in_use",
  event_type = "reservation_start_use"
)

started_usage <- wait_for_usage_row(
  reservation_id = approve_row$reservation_id[1],
  expected_state = "started",
  note_marker = start_note,
  stage = "admin start usage"
)

testthat::expect_identical(started_usage$started_by[1], "admin")
testthat::expect_true(
  !is.na(started_usage$started_at[1]) && started_usage$started_at[1] != "",
  info = "Usage start time was not recorded."
)

run_admin_action(
  reservation_id = approve_row$reservation_id[1],
  note_marker = finish_note,
  button_input = "admin_finish_use",
  expected_status = "finished",
  event_type = "reservation_finish_use",
  finish_reason = finish_reason_value
)

finished_usage <- wait_for_usage_row(
  reservation_id = approve_row$reservation_id[1],
  expected_state = "finished",
  note_marker = finish_note,
  stage = "admin finish usage"
)

testthat::expect_identical(finished_usage$finished_by[1], "admin")
testthat::expect_identical(finished_usage$finish_reason[1], finish_reason_value)
testthat::expect_true(
  !is.na(finished_usage$duration_hours[1]) && finished_usage$duration_hours[1] != "",
  info = "Usage duration was not recorded."
)

run_admin_action(
  reservation_id = reject_row$reservation_id[1],
  note_marker = reject_note,
  button_input = "admin_reject",
  expected_status = "rejected",
  event_type = "reservation_rejected"
)

run_admin_action(
  reservation_id = cancel_row$reservation_id[1],
  note_marker = cancel_note,
  button_input = "admin_cancel",
  expected_status = "cancelled",
  event_type = "reservation_cancelled"
)

message("\nAll Shiny UI journey tests passed.")
