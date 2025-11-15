# Enable these integration checks only when explicitly requested
RUN_CLI_CHECKS <- Sys.getenv("NOSLEEP_CLI_TESTS", "0") == "1"

test_that("Windows: CLI integration checks (opt-in)", {
  # Only for Windows backend
  skip_if_not(.Platform$OS.type == "windows", "Test is Windows-specific.")

  # Allow opting in via environment variable
  if (!RUN_CLI_CHECKS) {
    skip("CLI checks are disabled (set NOSLEEP_CLI_TESTS=1 to enable).")
  }

  # Require powercfg to be available
  if (!nzchar(Sys.which("powercfg"))) {
    testthat::fail("Windows CLI check requires 'powercfg' in PATH, but it was not found.")
    return(invisible(NULL))
  }

  # Small pause to let system update power requests
  short_wait <- function() {
    try(Sys.sleep(0.2), silent = TRUE)
    invisible(NULL)
  }

  # Helper to run `powercfg /requests` via PowerShell and capture output
  powercfg_requests <- function() {
    out <- try(
      system2(
        "powershell",
        c("-NoProfile", "-Command", "powercfg /requests"),
        stdout = TRUE,
        stderr = FALSE
      ),
      silent = TRUE
    )

    if (inherits(out, "try-error")) {
        testthat::fail("Failed to run 'powercfg /requests' via PowerShell.")
        return(character(0))
    }

    paste(out, collapse = "\n")
  }

  pre  <- powercfg_requests()

  nosleep_on()
  short_wait()
  mid  <- powercfg_requests()
  nosleep_off()
  short_wait()
  post <- powercfg_requests()

  # Heuristics: look for common markers that may appear under SYSTEM/DISPLAY sections.
  has_signal <- function(s) {
    grepl("EXECUTION|System Required|Display Required|Legacy Kernel Caller",
          s,
          ignore.case = TRUE)
  }

  # Expect to see signal after enabling, and not before or after
  if (has_signal(mid) && (!has_signal(post) || identical(post, pre))) {
    expect_true(TRUE)  # signal observed and cleared as expected
  } else {
    testthat::fail("Windows CLI integration check failed: unexpected power request state.")
    return(invisible(NULL))
  }
})
