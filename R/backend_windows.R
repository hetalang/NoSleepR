# Windows backend: thin wrappers around the C implementation.

nosleep_on_windows <- function(keep_display = TRUE) {
  # Ensure logical scalar
  keep_display <- isTRUE(keep_display)
  .Call("NoSleepR_nosleep_on", keep_display, PACKAGE = "NoSleepR")
}

nosleep_off_windows <- function() {
  .Call("NoSleepR_nosleep_off", PACKAGE = "NoSleepR")
}
