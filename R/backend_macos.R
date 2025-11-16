# Internal state for macOS backend stored in an environment.
# We mutate the environment contents instead of rebinding package globals.
.nosleep_macos_state <- new.env(parent = emptyenv())
.nosleep_macos_state$pid <- NA_integer_

# Check if caffeinate utility is available in PATH.
have_caffeinate <- function() {
  nzchar(Sys.which("caffeinate"))
}

# Helper: terminate a process by PID with a short grace period.
# First sends SIGTERM, then (after a delay) SIGKILL.
terminate_process <- function(pid, grace_ms = 500L) {
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
    stop("NoSleepR: 'caffeinate' binary not found in PATH.")
  }

  pid <- .nosleep_macos_state$pid

  # If there is already a tracked process, do not start a second one.
  if (!is.na(pid) && pid > 0L) {
    return(invisible(NULL))
  }

  # Use a long but finite timeout so we do not keep the system awake forever
  # if teardown fails. 7200 seconds = 2 hours.
  timeout_sec <- 7200L

  base_cmd <- sprintf(
    "caffeinate %s -i -t %d",
    if (isTRUE(keep_display)) "-d" else "",
    timeout_sec
  )

  # Important: redirect caffeinate stdout/stderr to /dev/null, otherwise
  # the pipe never gets EOF and system2() will block forever.
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
    stop("NoSleepR: failed to start 'caffeinate' via shell.")
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

  .nosleep_macos_state$pid <- pid_num

  invisible(NULL)
}

# macOS backend: turn nosleep off by terminating the caffeinate process.
nosleep_off_macos <- function() {
  pid <- .nosleep_macos_state$pid
  if (is.na(pid) || pid <= 0L) {
    return(invisible(NULL))
  }

  terminate_process(pid, grace_ms = 800L)
  .nosleep_macos_state$pid <- NA_integer_

  invisible(NULL)
}
