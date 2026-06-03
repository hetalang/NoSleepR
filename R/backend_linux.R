# Check if systemd-inhibit is available in PATH.
have_systemd_inhibit <- function() {
  nzchar(Sys.which("systemd-inhibit"))
}

linux_process_alive <- function(pid) {
  if (is.na(pid) || pid <= 0L || !nzchar(Sys.which("kill"))) {
    return(FALSE)
  }

  status <- suppressWarnings(
    try(
      system2(
        "kill",
        c("-0", as.character(pid)),
        stdout = FALSE,
        stderr = FALSE
      ),
      silent = TRUE
    )
  )

  identical(status, 0L)
}

linux_systemd_inhibit_list <- function() {
  out <- suppressWarnings(
    try(
      system2(
        "systemd-inhibit",
        args = c("--list"),
        stdout = TRUE,
        stderr = TRUE
      ),
      silent = TRUE
    )
  )

  if (inherits(out, "try-error")) {
    return(NA_character_)
  }

  status <- attr(out, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    return(NA_character_)
  }

  paste(out, collapse = "\n")
}

linux_inhibitor_listed <- function(list_output, pid) {
  if (length(list_output) != 1L || is.na(list_output) || !nzchar(list_output)) {
    return(NA)
  }

  grepl("NoSleepR", list_output, fixed = TRUE) &&
    grepl("Long computation", list_output, fixed = TRUE)
}

linux_read_error_file <- function(path) {
  if (!file.exists(path)) {
    return("")
  }

  lines <- suppressWarnings(try(readLines(path, warn = FALSE), silent = TRUE))
  if (inherits(lines, "try-error") || length(lines) == 0L) {
    return("")
  }

  paste(lines, collapse = "\n")
}

# Helper: terminate a process by PID with a short grace period.
# First sends SIGTERM, then (after a delay) SIGKILL.
terminate_process_linux <- function(pid, grace_ms = 500L) {
  if (is.na(pid) || pid <= 0L) {
    return(invisible(NULL))
  }

  # Try graceful SIGTERM
  try(
    suppressWarnings(
      system2(
        "kill",
        c("-TERM", as.character(pid)),
        stdout = FALSE,
        stderr = FALSE
      )
    ),
    silent = TRUE
  )

  # Wait for a short grace period
  steps <- max(1L, grace_ms %/% 50L)
  for (i in seq_len(steps)) {
    Sys.sleep(0.05)
  }

  # If still alive, send SIGKILL (ignore errors)
  try(
    suppressWarnings(
      system2(
        "kill",
        c("-KILL", as.character(pid)),
        stdout = FALSE,
        stderr = FALSE
      )
    ),
    silent = TRUE
  )

  invisible(NULL)
}

# Linux backend: turn nosleep on using systemd-inhibit.
# keep_display = TRUE -> use "sleep:idle", otherwise only "sleep".
# Returns: integer PID on success, or NULL if backend is not available / failed.
nosleep_on_linux <- function(keep_display = FALSE) {
  if (!have_systemd_inhibit()) {
    warning("NoSleepR: 'systemd-inhibit' not found in PATH; Linux backend is not available.")
    return(NULL)
  }

  what <- if (isTRUE(keep_display)) "sleep:idle" else "sleep"

  # Build base command similar to Julia version:
  # systemd-inhibit --what=... --who=NoSleepR --why=Long computation --mode=block sleep infinity
  base_cmd <- sprintf(
    "systemd-inhibit --what=%s --who=NoSleepR --why='Long computation' --mode=block sleep infinity",
    what
  )

  err_file <- tempfile("nosleepr-systemd-inhibit-", fileext = ".err")
  on.exit(unlink(err_file), add = TRUE)

  # Start inhibitor in background and echo its PID:
  #  sh -c 'systemd-inhibit ... >/dev/null 2>err_file & echo $!'
  shell_cmd <- sprintf("%s >/dev/null 2>%s & echo $!", base_cmd, shQuote(err_file))

  out <- suppressWarnings(
    try(
      system2(
        "sh",
        args   = c("-c", shell_cmd),
        stdout = TRUE,
        stderr = FALSE,
        wait   = TRUE  # wait only for the shell; inhibitor keeps running
      ),
      silent = TRUE
    )
  )

  if (inherits(out, "try-error") || length(out) == 0L) {
    warning("NoSleepR: failed to start 'systemd-inhibit' via shell.")
    return(NULL)
  }

  # PID should be the last non-empty line
  pid_str <- utils::tail(out[nzchar(out)], 1L)

  if (length(pid_str) != 1L) {
    stop("NoSleepR: could not read PID from systemd-inhibit shell output.")
  }

  pid_num <- suppressWarnings(as.integer(pid_str))

  if (is.na(pid_num) || pid_num <= 0L) {
    stop("NoSleepR: invalid PID parsed for 'systemd-inhibit' process.")
  }

  listed <- NA
  alive <- FALSE

  for (i in seq_len(10L)) {
    Sys.sleep(0.1)
    alive <- linux_process_alive(pid_num)
    if (!alive) {
      break
    }

    listed <- linux_inhibitor_listed(linux_systemd_inhibit_list(), pid_num)
    if (isTRUE(listed)) {
      break
    }
  }

  if (!alive) {
    details <- linux_read_error_file(err_file)
    warning(
      "NoSleepR: 'systemd-inhibit' started but exited immediately; sleep prevention was not enabled.",
      if (nzchar(details)) paste0(" Details: ", details) else ""
    )
    return(NULL)
  }

  if (identical(listed, FALSE)) {
    terminate_process_linux(pid_num, grace_ms = 200L)
    warning("NoSleepR: 'systemd-inhibit' is running, but NoSleepR could not confirm an active sleep inhibitor.")
    return(NULL)
  }

  if (is.na(listed)) {
    warning("NoSleepR: 'systemd-inhibit' is running, but NoSleepR could not verify it with 'systemd-inhibit --list'.")
  }

  pid_num
}

# Linux backend: turn nosleep off for a specific PID.
# This is called from the high-level interface with handle$data (PID).
nosleep_off_linux <- function(pid) {
  # Here we only handle a single PID; NULL or missing -> no-op.
  if (missing(pid) || is.null(pid)) {
    return(invisible(NULL))
  }

  if (is.na(pid) || pid <= 0L) {
    return(invisible(NULL))
  }

  if (!is.integer(pid) && !is.numeric(pid)) {
    stop("NoSleepR: 'pid' must be an integer PID returned by nosleep_on_linux().")
  }

  terminate_process_linux(pid, grace_ms = 800L)

  invisible(NULL)
}
