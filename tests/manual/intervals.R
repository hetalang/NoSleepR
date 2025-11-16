# inst/manual/sleep_monitor.R

#devtools::load_all()

# Manual sleep drift monitor for ~1 hour.
# Prints every minute and measures wall-clock delta between iterations.
# If the system sleeps, you'll see delta >> interval seconds.

time_interval_monitor <- function(minutes = 60L, interval = 60) {
  if (!is.numeric(minutes) || minutes <= 0) {
    stop("minutes must be a positive number.")
  }
  if (!is.numeric(interval) || interval <= 0) {
    stop("interval must be a positive number (seconds).")
  }

  t_prev <- Sys.time()

  message("Sleep monitor started: minutes = ", minutes,
          ", interval = ", interval, " s")

  tryCatch(
    {
      for (i in seq_len(minutes)) {
        Sys.sleep(interval)  # will stall during system sleep

        t_now  <- Sys.time()
        delta  <- as.numeric(difftime(t_now, t_prev, units = "secs"))
        t_prev <- t_now

        ts <- format(t_now, "%H:%M:%S")
        cat(sprintf("[%s] iter=%d  delta=%ds\n", ts, i, round(delta)))
        flush.console()
      }
    },
    interrupt = function(e) {
      cat("\n^C Stopped by user.\n")
    },
    finally = {
      message("Sleep monitor finished.")
    }
  )

  invisible(NULL)
}

# Run under NoSleepR protection:
# (assumes library(NoSleepR) is already loaded)
NoSleepR::with_nosleep({
  time_interval_monitor()
})
