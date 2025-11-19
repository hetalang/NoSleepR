# Internal state to track active nosleep handles
.nosleep_state <- new.env(parent = emptyenv())
.nosleep_state$handles <- list()

# Push a handle to the internal list
.nosleep_register <- function(handle) {
  handles <- .nosleep_state$handles
  handles <- c(handles, list(handle))
  .nosleep_state$handles <- handles
  invisible(handle)
}

# Remove a handle from the internal list
.nosleep_unregister <- function(handle) {
  handles <- .nosleep_state$handles
  .nosleep_state$handles <- Filter(function(x) !identical(x, handle), handles)
  invisible(NULL)
}



#' Turn nosleep on
#'
#' Prevent the operating system from suspending or putting the display to sleep
#' while long-running R work is executing.
#'
#' @param keep_display logical. If \code{TRUE}, also prevent the display from
#'   powering off (when supported by the underlying OS). Default is \code{FALSE}.
#'
#' @details
#' The returned handle must stay alive for as long as you want the nosleep
#' request to remain in effect. Call \code{nosleep_off()} with the handle to
#' release the underlying system resource as soon as the protected work is
#' complete.
#' 
#' If no backend is available for the current platform (e.g., missing
#' dependencies), a warning is issued and invisible \code{NULL} is returned.
#'
#' @return An object of class \code{"NoSleepR_handle"} that stores the active
#'   nosleep request for the current platform. Invisible \code{NULL} is
#'   returned when the request could not be established.
#'
#' @examples
#' 
#' # Simple usage
#' \dontrun{
#' nosleep_on()
#' long_running_job()
#' nosleep_off()
#' 
#' # Handle-based usage
#' h <- nosleep_on()
#' long_running_job()
#' nosleep_off(h)
#'
#' # Keep the display awake as well (when supported)
#' h <- nosleep_on(keep_display = TRUE)
#' Sys.sleep(100)  # simulate long job
#' nosleep_off(h)
#' }
#'
#' @export
nosleep_on <- function(keep_display = FALSE) {
  sysname <- Sys.info()[["sysname"]]

  # Function-level variables
  backend <- NULL
  data    <- NULL

  if (.Platform$OS.type == "windows") {
    backend <- "windows"
    data    <- nosleep_on_windows(keep_display = keep_display)
  } else if (identical(sysname, "Darwin")) {
    backend <- "macos"
    data    <- nosleep_on_macos(keep_display = keep_display)
  } else if (identical(sysname, "Linux")) {
    backend <- "linux"
    data    <- nosleep_on_linux(keep_display = keep_display)
  } else {
    stop("NoSleepR: unsupported OS: ", sysname %||% "unknown")
  }

  # If backend failed to start (e.g. missing systemd-inhibit), it should
  # already emit a warning and return NULL/NA. In that case we skip
  # handle creation and return NULL invisibly.
  if (is.null(data) || (is.atomic(data) && length(data) == 1L && is.na(data))) {
    return(invisible(NULL))
  }

  handle <- list(
    backend = backend,
    data    = data
  )
  class(handle) <- "NoSleepR_handle"

  .nosleep_register(handle)

  invisible(handle)
}

#' Turn nosleep off
#'
#' Turn off a specific nosleep request or, if no handle is supplied, every
#' active request opened by the current R session.
#'
#' @param handle Optional \code{"NoSleepR_handle"} object returned by
#'   \code{nosleep_on()}. If omitted, all active nosleep handles created
#'   in this session are turned off. Passing \code{NULL} is treated as a
#'   no-op.
#'
#' @return Invisibly returns \code{NULL}.
#'
#' @examples
#' \dontrun{
#' h <- nosleep_on()
#' # ... do work ...
#' nosleep_off(h)
#'
#' # Equivalent shortcut to clear everything
#' nosleep_on()
#' nosleep_on()
#' nosleep_off()
#' }
#'
#' @export
nosleep_off <- function(handle) {
  # Case 1: no argument passed at all -> turn off ALL
  if (missing(handle)) {
    return(nosleep_off_all())
  }

  # Case 2: handle explicitly NULL -> do nothing
  if (is.null(handle)) {
    return(invisible(NULL))
  }

  # Case 3: invalid handle type -> error
  if (!inherits(handle, "NoSleepR_handle")) {
    stop("NoSleepR: 'handle' must be a NoSleepR_handle object or NULL.")
  }

  # Case 4: normal handle

  # Function-level variables
  backend <- handle$backend
  data    <- handle$data

  sysname <- Sys.info()[["sysname"]]
  if (.Platform$OS.type == "windows" && identical(backend, "windows")) {
    # data is expected to be an externalptr from the Windows backend
    nosleep_off_windows(data)
  } else if (identical(sysname, "Darwin") && identical(backend, "macos")) {
    nosleep_off_macos(data)
  } else if (identical(sysname, "Linux") && identical(backend, "linux")) {
    nosleep_off_linux(data)
  } else {
    # handle from another platform or incompatible backend
    stop("NoSleepR: handle backend '", backend, "' is not compatible with current OS: ", sysname %||% "unknown")
  }

  .nosleep_unregister(handle)
  invisible(NULL)
}

# Turn off all active nosleep requests
nosleep_off_all <- function() {
  handles <- .nosleep_state$handles
  for (h in handles) {
    if (inherits(h, "NoSleepR_handle")) {
      nosleep_off(h)
    }
  }
  .nosleep_state$handles <- list()

  invisible(NULL)
}

#' Execute an expression while preventing the system from sleeping
#'
#' Helper that automatically brackets an expression with \code{nosleep_on()}
#' and \code{nosleep_off()}.
#'
#' @param expr Expression to execute while nosleep is on.
#' @param keep_display logical. If TRUE, also prevent the display from sleeping.
#'
#' @return The result of evaluating \code{expr}.
#'
#' @examples
#' \dontrun{
#' with_nosleep({
#'   message("Downloading a large file…")
#'   download_large_file()
#' })
#' }
#'
#' @export
with_nosleep <- function(expr, keep_display = FALSE) {
  handle <- nosleep_on(keep_display = keep_display)
 
  if (inherits(handle, "NoSleepR_handle")) {
    on.exit(nosleep_off(handle), add = TRUE)
  }

  force(expr)
}