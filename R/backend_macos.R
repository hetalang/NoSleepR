# macOS backend for NoSleepR: uses the 'caffeinate' utility to prevent system sleep.

# Global state: PID of the caffeinate process, or NA_integer_ if inactive.
.nosleep_macos_pid <- NA_integer_

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
nosleep_on_macos <- function(keep_display = TRUE) {
  if (!have_caffeinate()) {
    warning("NoSleepR: 'caffeinate' not found; no-sleep is not available on this system.")
    return(invisible(NULL))
  }

  # If there is already a tracked process, do not start a second one.
  if (!is.na(.nosleep_macos_pid) && .nosleep_macos_pid > 0L) {
    return(invisible(NULL))
  }

  # Use a long but finite timeout so we do not keep the system awake forever
  # if teardown fails. 7200 seconds = 2 hours.
  timeout_sec <- 7200L

  args <- c("-i", "-t", as.character(timeout_sec))
  if (isTRUE(keep_display)) {
    args <- c("-d", args)
  }

  # Start caffeinate in the background; do not wait for completion.
  pid <- suppressWarnings(
    system2(
      "caffeinate",
      args = args,
      stdout = FALSE,
      stderr = FALSE,
      wait   = FALSE
    )
  )

  # system2(wait = FALSE) should return the PID on Unix-like systems.
  if (is.null(pid) || !is.numeric(pid) || length(pid) != 1L || is.na(pid) || pid <= 0) {
    warning("NoSleepR: failed to start 'caffeinate' process.")
    .nosleep_macos_pid <<- NA_integer_
  } else {
    .nosleep_macos_pid <<- as.integer(pid)
  }

  invisible(NULL)
}

# macOS backend: turn nosleep off by terminating the caffeinate process.
nosleep_off_macos <- function() {
  pid <- .nosleep_macos_pid
  if (is.na(pid) || pid <= 0L) {
    return(invisible(NULL))
  }

  terminate_process(pid, grace_ms = 800L)
  .nosleep_macos_pid <<- NA_integer_

  invisible(NULL)
}
