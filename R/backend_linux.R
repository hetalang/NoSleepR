# Check if systemd-inhibit is available in PATH.
have_systemd_inhibit <- function() {
  nzchar(Sys.which("systemd-inhibit"))
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

  # Start inhibitor in background and echo its PID:
  #  sh -c 'systemd-inhibit ... >/dev/null 2>&1 & echo $!'
  shell_cmd <- sprintf("%s >/dev/null 2>&1 & echo $!", base_cmd)

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
