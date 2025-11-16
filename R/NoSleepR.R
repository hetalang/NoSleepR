#' Turn nosleep on
#'
#' Prevent the system from going to sleep while R code is running.
#'
#' @param keep_display logical. If TRUE, also prevent the display from sleeping.
#'   Default is FALSE.
#'
#' @export
nosleep_on <- function(keep_display = FALSE) {
  sysname <- Sys.info()[["sysname"]]

  if (.Platform$OS.type == "windows") {
    nosleep_on_windows(keep_display)

  } else if (identical(sysname, "Darwin")) {
    nosleep_on_macos(keep_display)

  } else if (identical(sysname, "Linux")) {
    nosleep_on_linux(keep_display)

  } else {
    stop("NoSleepR: unsupported OS: ", sysname %||% "unknown")
  }
}

#' Turn nosleep off
#'
#' @export
nosleep_off <- function() {
  sysname <- Sys.info()[["sysname"]]

  if (.Platform$OS.type == "windows") {
    nosleep_off_windows()

  } else if (identical(sysname, "Darwin")) {
    nosleep_off_macos()

  } else if (identical(sysname, "Linux")) {
    nosleep_off_linux()

  } else {
    stop("NoSleepR: unsupported OS: ", sysname %||% "unknown")
  }
}

#' Execute an expression while preventing the system from sleeping
#'
#' @param expr Expression to execute while nosleep is on.
#' @param keep_display logical. If TRUE, also prevent the display from sleeping.
#' @return The result of evaluating `expr`.
#'
#' @export
with_nosleep <- function(expr, keep_display = FALSE) {
  nosleep_on(keep_display = keep_display)
  on.exit(nosleep_off(), add = TRUE)
  force(expr)
}