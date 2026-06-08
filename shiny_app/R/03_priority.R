get_rule_points <- function(priority_rules_tbl, rule_group_value, condition_value_value) {
  points <- priority_rules_tbl %>%
    dplyr::filter(
      active == "TRUE",
      rule_group == !!rule_group_value,
      condition_value == !!condition_value_value
    ) %>%
    dplyr::pull(points)
  
  if (length(points) == 0) {
    return(0)
  }
  
  suppressWarnings(as.numeric(points[1]))
}

get_deadline_points <- function(priority_rules_tbl, deadline_date) {
  if (is.null(deadline_date) || length(deadline_date) == 0) {
    return(0)
  }
  
  deadline_date <- deadline_date[1]
  
  if (is.na(deadline_date) || identical(deadline_date, "") || identical(deadline_date, "NA")) {
    return(0)
  }
  
  deadline_date <- suppressWarnings(as.Date(deadline_date))
  
  if (is.na(deadline_date)) {
    return(0)
  }
  
  days_to_deadline <- as.numeric(deadline_date - Sys.Date())
  
  if (is.na(days_to_deadline) || !is.finite(days_to_deadline) || days_to_deadline < 0) {
    return(0)
  }
  
  rules <- priority_rules_tbl %>%
    dplyr::filter(active == "TRUE", rule_group == "deadline_within_days") %>%
    dplyr::mutate(
      threshold = suppressWarnings(as.numeric(condition_value)),
      points_num = suppressWarnings(as.numeric(points))
    ) %>%
    dplyr::filter(!is.na(threshold), days_to_deadline <= threshold) %>%
    dplyr::arrange(threshold)
  
  if (nrow(rules) == 0) {
    return(0)
  }
  
  rules$points_num[1]
}

get_duration_points <- function(priority_rules_tbl, estimated_hours) {
  rules <- priority_rules_tbl %>%
    dplyr::filter(active == "TRUE", rule_group == "duration_over_hours") %>%
    dplyr::mutate(
      threshold = suppressWarnings(as.numeric(condition_value)),
      points_num = suppressWarnings(as.numeric(points))
    ) %>%
    dplyr::filter(!is.na(threshold), estimated_hours > threshold) %>%
    dplyr::arrange(dplyr::desc(threshold))
  
  if (nrow(rules) == 0) {
    return(0)
  }
  
  rules$points_num[1]
}

calculate_priority_score <- function(
    user_level,
    deadline_date,
    computing_demand,
    requires_super_2,
    uses_gpu,
    estimated_hours,
    can_be_reallocated,
    main_environment,
    priority_rules_tbl
) {
  user_points <- get_rule_points(priority_rules_tbl, "user_level", user_level)
  deadline_points <- get_deadline_points(priority_rules_tbl, deadline_date)
  demand_points <- get_rule_points(priority_rules_tbl, "computing_demand", computing_demand)
  super_2_points <- get_rule_points(priority_rules_tbl, "requires_super_2", requires_super_2)
  gpu_points <- get_rule_points(priority_rules_tbl, "uses_gpu", uses_gpu)
  duration_points <- get_duration_points(priority_rules_tbl, estimated_hours)
  reallocation_points <- get_rule_points(priority_rules_tbl, "can_be_reallocated", can_be_reallocated)
  environment_points <- get_rule_points(priority_rules_tbl, "main_environment", main_environment)
  
  user_points +
    deadline_points +
    demand_points +
    super_2_points +
    gpu_points +
    duration_points +
    reallocation_points +
    environment_points
}
