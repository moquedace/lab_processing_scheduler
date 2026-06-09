project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

local_library <- file.path(project_root, ".r-lib")
dir.create(local_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(local_library, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

pkg <- c(
  "utf8",
  "dplyr",
  "lubridate",
  "stringr",
  "tibble"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg, lib = local_library)
}

invisible(lapply(pkg, library, character.only = TRUE))

rm(list = setdiff(ls(), c("pkg", "project_root", "local_library")))
gc()

app_file <- file.path(project_root, "shiny_app", "app.R")
module_files <- list.files(
  file.path(project_root, "shiny_app", "R"),
  pattern = "\\.R$",
  full.names = TRUE
)

required_functions <- c(
  "get_setting_value",
  "get_setting_logical",
  "get_setting_numeric",
  "get_setting_vector",
  "get_rule_points",
  "get_deadline_points",
  "get_duration_points",
  "calculate_priority_score",
  "format_datetime_pt",
  "format_datetime_label_pt",
  "check_reservation_conflict",
  "get_computer_preference_order",
  "suggest_computer_assignment",
  "decide_approval_mode",
  "decide_reservation_status",
  "generate_reservation_id",
  "generate_log_id",
  "create_reservation_row",
  "create_audit_row",
  "update_reservation_status",
  "generate_usage_id",
  "create_usage_row",
  "finish_usage_row"
)

test_env <- new.env(parent = globalenv())

is_required_function_assignment <- function(expr) {
  if (!is.call(expr) || !identical(expr[[1]], as.name("<-"))) {
    return(FALSE)
  }
  
  target <- expr[[2]]
  value <- expr[[3]]
  
  is.name(target) &&
    as.character(target) %in% required_functions &&
    is.call(value) &&
    identical(value[[1]], as.name("function"))
}

for (source_file in c(module_files, app_file)) {
  source_exprs <- parse(source_file, encoding = "UTF-8")
  
  for (expr in source_exprs) {
    if (is_required_function_assignment(expr)) {
      eval(expr, envir = test_env)
    }
  }
}

loaded_functions <- ls(test_env)
missing_functions <- setdiff(required_functions, loaded_functions)

if (length(missing_functions) > 0) {
  stop(
    "Could not load required functions from app.R: ",
    paste(missing_functions, collapse = ", ")
  )
}

test_results <- tibble::tibble(
  test = character(),
  status = character(),
  details = character()
)

record_test <- function(test_name, expr) {
  result <- tryCatch(
    {
      force(expr)
      list(status = "ok", details = "")
    },
    error = function(e) {
      list(status = "error", details = conditionMessage(e))
    }
  )
  
  test_results <<- dplyr::bind_rows(
    test_results,
    tibble::tibble(
      test = test_name,
      status = result$status,
      details = result$details
    )
  )
}

expect_true <- function(value, message) {
  if (!isTRUE(value)) {
    stop(message, call. = FALSE)
  }
}

expect_equal <- function(actual, expected, message) {
  if (!identical(actual, expected)) {
    stop(
      paste0(
        message,
        " Expected: ",
        paste(expected, collapse = ", "),
        ". Actual: ",
        paste(actual, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }
}

timezone_value <- "America/Sao_Paulo"

computers_fixture <- tibble::tibble(
  computer_id = c("super_1", "super_2", "super_3", "maintenance_box"),
  computer_name = c("Super 1", "Super 2", "Super 3", "Maintenance"),
  computer_label = c("Geral", "Intensivo", "Muito intensivo", "Fora de uso"),
  processor = c("Xeon", "Threadripper", "Future CPU", "Old CPU"),
  cores = c("28", "64", "96", "8"),
  threads = c("56", "128", "192", "16"),
  ram_gb = c("128", "512", "768", "32"),
  gpu = c("Quadro", "RTX Ada", "Future GPU", "None"),
  gpu_memory_gb = c("8", "20", "48", "0"),
  main_profile = c("general", "intensive", "very_intensive", "maintenance"),
  status = c("active", "active", "active", "maintenance"),
  can_be_booked = c("TRUE", "TRUE", "TRUE", "FALSE"),
  public_description = c("A", "B", "C", "D"),
  notes = c("", "", "", "")
)

reservations_fixture <- tibble::tibble(
  reservation_id = c("res_a", "res_b", "res_c"),
  user_id = c("user_1", "user_2", "user_3"),
  computer_assigned = c("super_1", "super_3", "super_2"),
  start_time = c(
    "2026-06-10 08:00:00",
    "2026-06-10 08:00:00",
    "2026-06-10 20:00:00"
  ),
  end_time = c(
    "2026-06-10 12:00:00",
    "2026-06-10 12:00:00",
    "2026-06-11 08:00:00"
  ),
  status = c("approved", "approved", "pending")
)

empty_reservations <- reservations_fixture[0, ]

settings_fixture <- tibble::tibble(
  setting_name = c(
    "manual_approval_user_levels",
    "manual_approval_above_hours",
    "manual_approval_if_requires_super_2",
    "manual_approval_if_conflict",
    "manual_approval_if_unknown_demand",
    "allow_auto_approval",
    "default_auto_approved_status",
    "default_manual_approval_status"
  ),
  setting_value = c(
    "undergraduate, master",
    "24",
    "TRUE",
    "TRUE",
    "TRUE",
    "TRUE",
    "approved",
    "pending"
  ),
  description = "",
  active = "TRUE"
)

priority_rules_fixture <- tibble::tibble(
  rule_id = c(
    "r_user_phd",
    "r_deadline_7",
    "r_deadline_14",
    "r_demand",
    "r_super2",
    "r_gpu",
    "r_duration",
    "r_realloc",
    "r_env"
  ),
  rule_group = c(
    "user_level",
    "deadline_within_days",
    "deadline_within_days",
    "computing_demand",
    "requires_super_2",
    "uses_gpu",
    "duration_over_hours",
    "can_be_reallocated",
    "main_environment"
  ),
  condition_value = c(
    "phd",
    "7",
    "14",
    "raster_processing",
    "yes",
    "yes",
    "24",
    "no",
    "r"
  ),
  points = c("10", "8", "4", "6", "5", "3", "-4", "2", "1"),
  description = "",
  active = "TRUE"
)

settings_relaxed_fixture <- settings_fixture %>%
  dplyr::mutate(
    setting_value = dplyr::case_when(
      setting_name == "manual_approval_user_levels" ~ "",
      setting_name == "manual_approval_above_hours" ~ "999",
      setting_name == "manual_approval_if_requires_super_2" ~ "FALSE",
      setting_name == "manual_approval_if_conflict" ~ "FALSE",
      setting_name == "manual_approval_if_unknown_demand" ~ "FALSE",
      TRUE ~ setting_value
    )
  )

settings_auto_disabled_fixture <- settings_fixture %>%
  dplyr::mutate(
    setting_value = dplyr::if_else(
      setting_name == "allow_auto_approval",
      "FALSE",
      setting_value
    )
  )

expect_contains <- function(values, expected_value, message) {
  if (!expected_value %in% values) {
    stop(
      paste0(
        message,
        " Expected to find: ",
        expected_value,
        ". Actual: ",
        paste(values, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }
}

expect_reason_matching <- function(values, pattern, message) {
  if (!any(stringr::str_detect(values, stringr::regex(pattern, ignore_case = TRUE)))) {
    stop(
      paste0(
        message,
        " Expected pattern: ",
        pattern,
        ". Actual: ",
        paste(values, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }
}

record_test("computer preference supports future Super 3", {
  common_order <- test_env$get_computer_preference_order(
    computers_tbl = computers_fixture,
    computing_demand = "light"
  )
  
  intensive_order <- test_env$get_computer_preference_order(
    computers_tbl = computers_fixture,
    computing_demand = "raster_processing"
  )
  
  expect_equal(
    common_order,
    c("super_1", "super_2", "super_3"),
    "Common demand should start with the lighter available computer."
  )
  
  expect_equal(
    intensive_order,
    c("super_3", "super_2", "super_1"),
    "Intensive demand should start with the strongest available computer."
  )
})

record_test("requested computer is preserved when available", {
  selected <- test_env$suggest_computer_assignment(
    computer_requested = "super_3",
    computing_demand = "light",
    reservations_tbl = empty_reservations,
    start_time_value = lubridate::ymd_hms("2026-06-10 13:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-10 15:00:00", tz = timezone_value),
    timezone_value = timezone_value,
    computers_tbl = computers_fixture
  )
  
  expect_equal(selected, "super_3", "Specific available computer should be preserved.")
})

record_test("computer availability ignores unavailable requested machines", {
  selected <- test_env$suggest_computer_assignment(
    computer_requested = "maintenance_box",
    computing_demand = "light",
    reservations_tbl = empty_reservations,
    start_time_value = lubridate::ymd_hms("2026-06-10 13:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-10 15:00:00", tz = timezone_value),
    timezone_value = timezone_value,
    computers_tbl = computers_fixture
  )
  
  expect_equal(
    selected,
    "super_1",
    "Unavailable requested computer should fall back to the normal preference order."
  )
})

record_test("conflict detection handles overlaps and adjacent slots", {
  overlap <- test_env$check_reservation_conflict(
    reservations_tbl = reservations_fixture,
    computer_id_value = "super_1",
    start_time_value = lubridate::ymd_hms("2026-06-10 11:30:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-10 13:00:00", tz = timezone_value),
    timezone_value = timezone_value
  )
  
  adjacent <- test_env$check_reservation_conflict(
    reservations_tbl = reservations_fixture,
    computer_id_value = "super_1",
    start_time_value = lubridate::ymd_hms("2026-06-10 12:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-10 14:00:00", tz = timezone_value),
    timezone_value = timezone_value
  )
  
  pending_overlap <- test_env$check_reservation_conflict(
    reservations_tbl = reservations_fixture,
    computer_id_value = "super_2",
    start_time_value = lubridate::ymd_hms("2026-06-10 21:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-10 22:00:00", tz = timezone_value),
    timezone_value = timezone_value
  )
  
  expect_true(overlap, "Approved overlap should conflict.")
  expect_true(!adjacent, "Adjacent reservations should not conflict.")
  expect_true(!pending_overlap, "Pending reservations should not block conflicts yet.")
})

record_test("conflict detection follows status and computer boundaries", {
  status_reservations <- tibble::tibble(
    reservation_id = c("res_in_use", "res_rejected", "res_cancelled", "res_other_machine"),
    user_id = c("user_1", "user_2", "user_3", "user_4"),
    computer_assigned = c("super_1", "super_1", "super_1", "super_2"),
    start_time = c(
      "2026-06-12 08:00:00",
      "2026-06-12 08:00:00",
      "2026-06-12 08:00:00",
      "2026-06-12 08:00:00"
    ),
    end_time = c(
      "2026-06-12 12:00:00",
      "2026-06-12 12:00:00",
      "2026-06-12 12:00:00",
      "2026-06-12 12:00:00"
    ),
    status = c("in_use", "rejected", "cancelled", "approved")
  )
  
  in_use_conflict <- test_env$check_reservation_conflict(
    reservations_tbl = status_reservations,
    computer_id_value = "super_1",
    start_time_value = lubridate::ymd_hms("2026-06-12 09:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-12 10:00:00", tz = timezone_value),
    timezone_value = timezone_value
  )
  
  other_machine_only <- test_env$check_reservation_conflict(
    reservations_tbl = status_reservations %>% dplyr::filter(reservation_id != "res_in_use"),
    computer_id_value = "super_1",
    start_time_value = lubridate::ymd_hms("2026-06-12 09:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-12 10:00:00", tz = timezone_value),
    timezone_value = timezone_value
  )
  
  expect_true(in_use_conflict, "In-use reservations should conflict.")
  expect_true(!other_machine_only, "Rejected, cancelled and other-computer rows should not conflict.")
})

record_test("assignment skips conflicted preferred computer", {
  selected <- test_env$suggest_computer_assignment(
    computer_requested = "any",
    computing_demand = "raster_processing",
    reservations_tbl = reservations_fixture,
    start_time_value = lubridate::ymd_hms("2026-06-10 09:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-10 10:00:00", tz = timezone_value),
    timezone_value = timezone_value,
    computers_tbl = computers_fixture
  )
  
  expect_equal(selected, "super_2", "Should skip conflicted Super 3 and assign next intensive option.")
})

record_test("assignment fallback remains deterministic when every preferred machine conflicts", {
  all_busy <- tibble::tibble(
    reservation_id = c("busy_1", "busy_2", "busy_3"),
    user_id = c("user_1", "user_2", "user_3"),
    computer_assigned = c("super_3", "super_2", "super_1"),
    start_time = "2026-06-13 08:00:00",
    end_time = "2026-06-13 12:00:00",
    status = "approved"
  )
  
  selected <- test_env$suggest_computer_assignment(
    computer_requested = "any",
    computing_demand = "raster_processing",
    reservations_tbl = all_busy,
    start_time_value = lubridate::ymd_hms("2026-06-13 09:00:00", tz = timezone_value),
    end_time_value = lubridate::ymd_hms("2026-06-13 10:00:00", tz = timezone_value),
    timezone_value = timezone_value,
    computers_tbl = computers_fixture
  )
  
  expect_equal(
    selected,
    "super_3",
    "When every preferred machine conflicts, assignment should fall back to the top preference."
  )
})

record_test("approval mode reacts to duration, conflict and Super 2 requirement", {
  auto_mode <- test_env$decide_approval_mode(
    user_level = "phd",
    estimated_hours = 4,
    requires_super_2 = "no",
    computing_demand = "raster_processing",
    has_conflict = FALSE,
    settings_tbl = settings_fixture
  )
  
  manual_mode <- test_env$decide_approval_mode(
    user_level = "phd",
    estimated_hours = 25,
    requires_super_2 = "yes",
    computing_demand = "unknown",
    has_conflict = TRUE,
    settings_tbl = settings_fixture
  )
  
  expect_equal(auto_mode$mode, "automatic", "Low-risk reservation should be automatic.")
  expect_equal(manual_mode$mode, "manual", "High-risk reservation should be manual.")
  expect_true(length(manual_mode$reasons) >= 4, "Manual mode should explain every triggered reason.")
})

record_test("approval mode matrix covers user levels and individual rule switches", {
  undergraduate_mode <- test_env$decide_approval_mode(
    user_level = "undergraduate",
    estimated_hours = 4,
    requires_super_2 = "no",
    computing_demand = "raster_processing",
    has_conflict = FALSE,
    settings_tbl = settings_fixture
  )
  
  master_mode <- test_env$decide_approval_mode(
    user_level = "master",
    estimated_hours = 4,
    requires_super_2 = "no",
    computing_demand = "raster_processing",
    has_conflict = FALSE,
    settings_tbl = settings_fixture
  )
  
  duration_mode <- test_env$decide_approval_mode(
    user_level = "phd",
    estimated_hours = 24.01,
    requires_super_2 = "no",
    computing_demand = "raster_processing",
    has_conflict = FALSE,
    settings_tbl = settings_fixture
  )
  
  super_2_mode <- test_env$decide_approval_mode(
    user_level = "phd",
    estimated_hours = 4,
    requires_super_2 = "yes",
    computing_demand = "raster_processing",
    has_conflict = FALSE,
    settings_tbl = settings_fixture
  )
  
  conflict_mode <- test_env$decide_approval_mode(
    user_level = "phd",
    estimated_hours = 4,
    requires_super_2 = "no",
    computing_demand = "raster_processing",
    has_conflict = TRUE,
    settings_tbl = settings_fixture
  )
  
  unknown_mode <- test_env$decide_approval_mode(
    user_level = "phd",
    estimated_hours = 4,
    requires_super_2 = "no",
    computing_demand = "unknown",
    has_conflict = FALSE,
    settings_tbl = settings_fixture
  )
  
  relaxed_mode <- test_env$decide_approval_mode(
    user_level = "undergraduate",
    estimated_hours = 72,
    requires_super_2 = "yes",
    computing_demand = "unknown",
    has_conflict = TRUE,
    settings_tbl = settings_relaxed_fixture
  )
  
  expect_equal(undergraduate_mode$mode, "manual", "Undergraduate reservations should be manual.")
  expect_equal(master_mode$mode, "manual", "Master reservations should be manual.")
  expect_equal(duration_mode$mode, "manual", "Duration above threshold should be manual.")
  expect_equal(super_2_mode$mode, "manual", "Required Super 2 should be manual.")
  expect_equal(conflict_mode$mode, "manual", "Conflict should be manual.")
  expect_equal(unknown_mode$mode, "manual", "Unknown demand should be manual.")
  expect_equal(relaxed_mode$mode, "automatic", "Relaxed settings should disable manual triggers.")
  
  expect_reason_matching(duration_mode$reasons, "limite", "Duration reason missing.")
  expect_reason_matching(super_2_mode$reasons, "Super 2", "Super 2 reason missing.")
  expect_reason_matching(conflict_mode$reasons, "conflito", "Conflict reason missing.")
  expect_reason_matching(unknown_mode$reasons, "desconhecida", "Unknown demand reason missing.")
})

record_test("reservation status follows auto-approval settings", {
  automatic_status <- test_env$decide_reservation_status(
    approval_mode = "automatic",
    settings_tbl = settings_fixture
  )
  
  manual_status <- test_env$decide_reservation_status(
    approval_mode = "manual",
    settings_tbl = settings_fixture
  )
  
  expect_equal(automatic_status, "approved", "Automatic approval should use configured approved status.")
  expect_equal(manual_status, "pending", "Manual approval should use configured pending status.")
})

record_test("reservation status respects disabled auto approval", {
  automatic_disabled_status <- test_env$decide_reservation_status(
    approval_mode = "automatic",
    settings_tbl = settings_auto_disabled_fixture
  )
  
  expect_equal(
    automatic_disabled_status,
    "pending",
    "Automatic approval mode should still become pending when auto approval is disabled."
  )
})

record_test("priority deadline and duration boundaries are deterministic", {
  deadline_7 <- test_env$get_deadline_points(priority_rules_fixture, Sys.Date() + 7)
  deadline_14 <- test_env$get_deadline_points(priority_rules_fixture, Sys.Date() + 14)
  deadline_none <- test_env$get_deadline_points(priority_rules_fixture, Sys.Date() + 15)
  deadline_past <- test_env$get_deadline_points(priority_rules_fixture, Sys.Date() - 1)
  
  duration_exact <- test_env$get_duration_points(priority_rules_fixture, 24)
  duration_over <- test_env$get_duration_points(priority_rules_fixture, 24.01)
  
  expect_equal(deadline_7, 8, "Deadline within 7 days should use the tighter rule.")
  expect_equal(deadline_14, 4, "Deadline within 14 days should use the broader rule.")
  expect_equal(deadline_none, 0, "Deadline outside configured windows should not add points.")
  expect_equal(deadline_past, 0, "Past deadlines should not add points.")
  expect_equal(duration_exact, 0, "Duration exactly on the threshold should not trigger over-threshold points.")
  expect_equal(duration_over, -4, "Duration above threshold should trigger configured points.")
})

record_test("priority score combines rules and decimal duration", {
  score <- test_env$calculate_priority_score(
    user_level = "phd",
    deadline_date = Sys.Date() + 5,
    computing_demand = "raster_processing",
    requires_super_2 = "yes",
    uses_gpu = "yes",
    estimated_hours = 25.5,
    can_be_reallocated = "no",
    main_environment = "r",
    priority_rules_tbl = priority_rules_fixture
  )
  
  expect_equal(score, 31, "Priority score should combine all matching rule points.")
})

record_test("priority score matrix covers absent rules and optional flags", {
  minimal_score <- test_env$calculate_priority_score(
    user_level = "technician",
    deadline_date = Sys.Date() + 30,
    computing_demand = "light",
    requires_super_2 = "no",
    uses_gpu = "no",
    estimated_hours = 2,
    can_be_reallocated = "yes",
    main_environment = "python",
    priority_rules_tbl = priority_rules_fixture
  )
  
  deadline_only_score <- test_env$calculate_priority_score(
    user_level = "technician",
    deadline_date = Sys.Date() + 10,
    computing_demand = "light",
    requires_super_2 = "no",
    uses_gpu = "no",
    estimated_hours = 2,
    can_be_reallocated = "yes",
    main_environment = "python",
    priority_rules_tbl = priority_rules_fixture
  )
  
  gpu_without_super_score <- test_env$calculate_priority_score(
    user_level = "technician",
    deadline_date = NA,
    computing_demand = "light",
    requires_super_2 = "no",
    uses_gpu = "yes",
    estimated_hours = 2,
    can_be_reallocated = "yes",
    main_environment = "python",
    priority_rules_tbl = priority_rules_fixture
  )
  
  expect_equal(minimal_score, 0, "Absent rules and optional no-flags should score zero.")
  expect_equal(deadline_only_score, 4, "Deadline-only score should use the 14-day rule.")
  expect_equal(gpu_without_super_score, 3, "GPU flag should add points independently from Super 2.")
})

record_test("reservation row preserves all booking fields", {
  preview <- list(
    user_id = "user_1",
    computer_requested = "any",
    computer_assigned = "super_3",
    start_time = lubridate::ymd_hms("2026-06-10 13:00:00", tz = timezone_value),
    end_time = lubridate::ymd_hms("2026-06-10 15:30:00", tz = timezone_value),
    estimated_hours = 2.5,
    main_environment = "r",
    processing_type = "raster_processing",
    computing_demand = "raster_processing",
    uses_gpu = "yes",
    requires_super_2 = "no",
    can_be_reallocated = "yes",
    deadline = NA,
    justification = "Teste automatizado",
    priority_score = 20,
    status = "approved",
    approval_mode = "automatic",
    public_notes = "Processamento raster"
  )
  
  row <- test_env$create_reservation_row(preview, timezone_value)
  
  expected_columns <- c(
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
  )
  
  expect_equal(names(row), expected_columns, "Reservation row columns changed.")
  expect_equal(row$computer_assigned, "super_3", "Assigned computer should be preserved.")
  expect_equal(row$estimated_hours, "2.5", "Decimal duration should be preserved as text.")
  expect_equal(row$deadline, NA_character_, "Empty deadline should stay NA.")
})

record_test("admin actions update reservation and audit rows", {
  reservations_tbl <- tibble::tibble(
    reservation_id = "res_admin",
    created_at = "2026-06-10 08:00:00",
    updated_at = "2026-06-10 08:00:00",
    user_id = "user_1",
    status = "pending",
    approved_by = NA_character_,
    approved_at = NA_character_,
    rejected_by = NA_character_,
    rejected_at = NA_character_,
    cancelled_by = NA_character_,
    cancelled_at = NA_character_,
    admin_notes = NA_character_
  )
  
  updated <- test_env$update_reservation_status(
    reservations_tbl = reservations_tbl,
    reservation_id_value = "res_admin",
    new_status = "approved",
    admin_user = "admin_test",
    admin_notes_value = "ok",
    timezone_value = timezone_value
  )
  
  audit_row <- test_env$create_audit_row(
    event_type = "reservation_approved",
    reservation_id = "res_admin",
    user_id = updated$user_id,
    admin_user = "admin_test",
    old_value = updated$old_status,
    new_value = "approved",
    notes = "ok",
    timezone_value = timezone_value
  )
  
  expect_equal(updated$old_status, "pending", "Old status should be returned.")
  expect_equal(updated$reservations_tbl$status[1], "approved", "Reservation should be approved.")
  expect_equal(updated$reservations_tbl$approved_by[1], "admin_test", "Approver should be recorded.")
  expect_equal(audit_row$event_type, "reservation_approved", "Audit event type should be preserved.")
  expect_equal(audit_row$old_value, "pending", "Audit row should preserve old status.")
})

record_test("admin status transitions stamp the correct actor columns", {
  base_tbl <- tibble::tibble(
    reservation_id = c("res_reject", "res_cancel"),
    created_at = c("2026-06-10 08:00:00", "2026-06-10 08:00:00"),
    updated_at = c("2026-06-10 08:00:00", "2026-06-10 08:00:00"),
    user_id = c("user_1", "user_2"),
    status = c("pending", "approved"),
    approved_by = c(NA_character_, "admin_previous"),
    approved_at = c(NA_character_, "2026-06-10 09:00:00"),
    rejected_by = c(NA_character_, NA_character_),
    rejected_at = c(NA_character_, NA_character_),
    cancelled_by = c(NA_character_, NA_character_),
    cancelled_at = c(NA_character_, NA_character_),
    admin_notes = c(NA_character_, NA_character_)
  )
  
  rejected <- test_env$update_reservation_status(
    reservations_tbl = base_tbl,
    reservation_id_value = "res_reject",
    new_status = "rejected",
    admin_user = "admin_test",
    admin_notes_value = "reject note",
    timezone_value = timezone_value
  )
  
  cancelled <- test_env$update_reservation_status(
    reservations_tbl = rejected$reservations_tbl,
    reservation_id_value = "res_cancel",
    new_status = "cancelled",
    admin_user = "admin_test",
    admin_notes_value = "cancel note",
    timezone_value = timezone_value
  )
  
  rejected_row <- cancelled$reservations_tbl %>%
    dplyr::filter(reservation_id == "res_reject")
  cancelled_row <- cancelled$reservations_tbl %>%
    dplyr::filter(reservation_id == "res_cancel")
  
  expect_equal(rejected$old_status, "pending", "Reject action should report old pending status.")
  expect_equal(cancelled$old_status, "approved", "Cancel action should report old approved status.")
  expect_equal(rejected_row$status[1], "rejected", "Reject action should update status.")
  expect_equal(cancelled_row$status[1], "cancelled", "Cancel action should update status.")
  expect_equal(rejected_row$rejected_by[1], "admin_test", "Reject action should stamp rejected_by.")
  expect_equal(cancelled_row$cancelled_by[1], "admin_test", "Cancel action should stamp cancelled_by.")
  expect_equal(rejected_row$admin_notes[1], "reject note", "Reject note should be preserved.")
  expect_equal(cancelled_row$admin_notes[1], "cancel note", "Cancel note should be preserved.")
})

record_test("status update preserves existing admin notes when none is provided", {
  base_tbl <- tibble::tibble(
    reservation_id = "res_keep_note",
    created_at = "2026-06-10 08:00:00",
    updated_at = "2026-06-10 08:00:00",
    user_id = "user_1",
    status = "approved",
    approved_by = "admin_prev",
    approved_at = "2026-06-10 09:00:00",
    rejected_by = NA_character_,
    rejected_at = NA_character_,
    cancelled_by = NA_character_,
    cancelled_at = NA_character_,
    admin_notes = "nota anterior importante"
  )

  started <- test_env$update_reservation_status(
    reservations_tbl = base_tbl,
    reservation_id_value = "res_keep_note",
    new_status = "in_use",
    admin_user = "admin_test",
    admin_notes_value = NA_character_,
    timezone_value = timezone_value
  )

  expect_equal(
    started$reservations_tbl$admin_notes[1],
    "nota anterior importante",
    "Existing admin note should be preserved when no new note is provided."
  )
  expect_equal(
    started$reservations_tbl$status[1],
    "in_use",
    "Status should still update to in_use."
  )
})

record_test("usage row is created with start time and empty end fields", {
  usage_row <- test_env$create_usage_row(
    reservation_id = "res_test",
    user_id = "user_1",
    computer_assigned = "super_1",
    actual_start_time = lubridate::ymd_hms("2026-06-15 09:00:00", tz = timezone_value),
    timezone_value = timezone_value,
    started_by = "admin_test",
    notes = "start note"
  )

  expected_columns <- c(
    "usage_id", "reservation_id", "user_id", "computer_id",
    "started_at", "finished_at", "duration_hours",
    "started_by", "finished_by", "finish_reason", "notes"
  )

  expect_equal(names(usage_row), expected_columns, "Usage row columns changed.")
  expect_equal(usage_row$reservation_id, "res_test", "Reservation ID preserved.")
  expect_equal(usage_row$computer_id, "super_1", "Computer preserved.")
  expect_equal(usage_row$started_by, "admin_test", "Starter should be recorded.")
  expect_equal(usage_row$notes, "start note", "Start note should be recorded.")
  expect_true(is.na(usage_row$finished_at), "End time should be NA on creation.")
  expect_true(is.na(usage_row$duration_hours), "Actual hours should be NA on creation.")
  expect_true(nzchar(usage_row$usage_id), "Usage ID should be non-empty.")
})

record_test("finish usage row updates end time and computes actual hours", {
  usage_tbl <- tibble::tibble(
    usage_id = "use_001",
    reservation_id = "res_test",
    user_id = "user_1",
    computer_id = "super_1",
    started_at = "2026-06-15 09:00:00",
    finished_at = NA_character_,
    duration_hours = NA_character_,
    started_by = "admin_start",
    finished_by = NA_character_,
    finish_reason = NA_character_,
    notes = "start note"
  )

  updated <- test_env$finish_usage_row(
    usage_log_tbl = usage_tbl,
    reservation_id_value = "res_test",
    actual_end_time = lubridate::ymd_hms("2026-06-15 11:30:00", tz = timezone_value),
    finish_reason = "normal",
    timezone_value = timezone_value,
    finished_by = "admin_finish",
    notes = "finish note"
  )

  expect_true(!is.na(updated$finished_at[1]), "End time should be set after finish.")
  expect_equal(updated$duration_hours[1], "2.5", "Actual hours should be 2.5h.")
  expect_equal(updated$finished_by[1], "admin_finish", "Finisher should be recorded.")
  expect_equal(updated$finish_reason[1], "normal", "Finish reason should be set.")
  expect_equal(updated$notes[1], "finish note", "Finish note should be set.")
})

record_test("finish usage row is no-op when no open usage row exists", {
  empty_usage <- tibble::tibble(
    usage_id = character(),
    reservation_id = character(),
    user_id = character(),
    computer_id = character(),
    started_at = character(),
    finished_at = character(),
    duration_hours = character(),
    started_by = character(),
    finished_by = character(),
    finish_reason = character(),
    notes = character()
  )

  # suppressWarnings: este caminho emite warning por design (linha aberta não encontrada).
  result <- suppressWarnings(
    test_env$finish_usage_row(
      usage_log_tbl = empty_usage,
      reservation_id_value = "res_missing",
      actual_end_time = lubridate::ymd_hms("2026-06-15 11:00:00", tz = timezone_value),
      finish_reason = "normal",
      timezone_value = timezone_value
    )
  )

  expect_equal(nrow(result), 0L, "Empty table should be returned unchanged.")
})

print(test_results, n = Inf)

failed_tests <- test_results %>%
  dplyr::filter(status != "ok")

if (nrow(failed_tests) > 0) {
  stop(
    "\nShiny app logic tests failed: ",
    nrow(failed_tests),
    " failure(s)."
  )
}

message("\nAll Shiny app logic tests passed.")
