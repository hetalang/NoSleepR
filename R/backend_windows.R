# Windows backend: thin wrappers around the C implementation.

nosleep_on_windows <- function(keep_display = FALSE) {
  # Ensure logical scalar
  keep_display <- isTRUE(keep_display)

  # C side: SEXP NoSleepR_request_create(SEXP keep_display)
  ptr <- .Call("NoSleepR_request_create", keep_display, PACKAGE = "NoSleepR")

  if (is.null(ptr)) {
    return(NULL)
  }
  
  if (!inherits(ptr, "externalptr")) {
    stop("NoSleepR: Windows backend returned invalid handle (expected externalptr).")
  }

  ptr
}

nosleep_off_windows <- function(ptr) {
  if (is.null(ptr)) {
    return(invisible(NULL))
  }

  if (!inherits(ptr, "externalptr")) {
    stop("NoSleepR: 'ptr' must be an externalptr returned by nosleep_on_windows().")
  }

  # C side: SEXP NoSleepR_request_clear(SEXP ext)
  .Call("NoSleepR_request_clear", ptr, PACKAGE = "NoSleepR")

  invisible(NULL)
}
