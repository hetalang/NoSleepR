# macos backend: caffeinate process management

# Check if caffeinate utility is available in PATH.
have_caffeinate <- function() {
  nzchar(Sys.which("caffeinate"))
}

# Helper: terminate a process by PID with a short grace period.
# First sends SIGTERM, then (after a delay) SIGKILL.
terminate_process_macos <- function(pid, grace_ms = 500L) {
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

# macOS backend: turn nosleep on using caffeinate.
# keep_display = TRUE -> use -d to keep display awake as well.
nosleep_on_macos <- function(keep_display = FALSE) {
  # Require caffeinate to be available, otherwise this backend is not functional.
  if (!have_caffeinate()) {
    warning("NoSleepR: 'caffeinate' not found in PATH; macOS backend is not available.")
    return(NULL)
  }

  # Use a long but finite timeout so we do not keep the system awake forever
  # if teardown fails. 7200 seconds = 2 hours.
  timeout_sec <- 7200L

  base_cmd <- sprintf(
    "caffeinate %s -i -t %d",
    if (isTRUE(keep_display)) "-d" else "",
    timeout_sec
  )

  # Start caffeinate in the background and echo its PID.
  shell_cmd <- sprintf("%s >/dev/null 2>&1 & echo $!", base_cmd)

  out <- suppressWarnings(
    try(
      system2(
        "sh",
        args   = c("-c", shell_cmd),
        stdout = TRUE,
        stderr = FALSE,
        wait   = TRUE  # wait only for the shell; caffeinate keeps running
      ),
      silent = TRUE
    )
  )

  if (inherits(out, "try-error") || length(out) == 0L) {
    warning("NoSleepR: failed to start 'caffeinate' via shell.")
    return(NULL)
  }

  # PID should be the last non-empty line
  pid_str <- utils::tail(out[nzchar(out)], 1L)

  if (length(pid_str) != 1L) {
    stop("NoSleepR: could not read PID from shell output.")
  }

  pid_num <- suppressWarnings(as.integer(pid_str))

  if (is.na(pid_num) || pid_num <= 0L) {
    stop("NoSleepR: invalid PID parsed for 'caffeinate' process.")
  }

  pid_num
}

# macOS backend: turn nosleep off for a specific PID returned by nosleep_on_macos()
nosleep_off_macos <- function(pid) {
  if (missing(pid) || is.null(pid)) {
    return(invisible(NULL))
  }

  if (is.na(pid) || pid <= 0L) {
    return(invisible(NULL))
  }

  if (!is.integer(pid) && !is.numeric(pid)) {
    stop("NoSleepR: 'pid' must be an integer PID returned by nosleep_on_macos().")
  }

  terminate_process_macos(pid, grace_ms = 800L)

  invisible(NULL)
}
