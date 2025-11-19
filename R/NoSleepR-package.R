#' NoSleepR: Prevent system sleep during long R tasks
#'
#' @description
#' NoSleepR exposes a tiny, cross-platform API that temporarily disables system
#' sleep while your R script performs a long-running operation. The package
#' delegates to the native inhibition mechanisms shipped with each platform
#' (Win32 power requests, `caffeinate`, or `systemd-inhibit`) and automatically
#' tears them down once you are done.
#'
#' @details
#' \strong{Core helpers}
#' \itemize{
#'   \item [`nosleep_on()`] — establish a sleep-prevention request and keep the
#'     handle alive for as long as the work runs.
#'   \item [`nosleep_off()`] — release a specific handle or clear all active
#'     ones when called without arguments.
#'   \item [`with_nosleep()`] — wrap a code block so that NoSleepR turns itself
#'     on before the block executes and reliably shuts down after it completes
#'     or errors.
#' }
#'
#' All helpers accept the optional `keep_display` flag, allowing you to request
#' that the monitor stays on (when supported by the OS) in addition to the
#' system-wide sleep prevention.
#'
#' @section Typical workflow:
#' \enumerate{
#'   \item Call `nosleep_on()` (optionally with `keep_display = TRUE`) right
#'     before a long computation or data transfer.
#'   \item Run the expensive task.
#'   \item Explicitly stop the request with `nosleep_off()` as soon as the work
#'     finishes, or rely on `with_nosleep()` to bracket the code block.
#' }
#'
#' NoSleepR automatically cleans up pending requests when the R session ends,
#' but it is still best practice to explicitly call `nosleep_off()` so that the
#' operating system can resume managing power immediately after the protected
#' job completes.
#'
#' @seealso <https://github.com/hetalang/NoSleepR>
#'
#' @name NoSleepR
#' @useDynLib NoSleepR, .registration = TRUE
"_PACKAGE"
