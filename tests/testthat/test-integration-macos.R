# Enable these integration checks only when explicitly requested
RUN_TEST <- Sys.getenv("INTEGRATION_TESTS", "0") == "1"

test_that("macOS: pmset shows caffeinate assertion (opt-in)", {
  # Run only on macOS
  skip_if_not(Sys.info()[["sysname"]] == "Darwin", "Test is macOS-specific.")

  # Opt-in via environment variable
  if (!RUN_TEST) {
    skip("CLI integration tests are disabled (set INTEGRATION_TESTS=1 to enable).")
  }

  # Require pmset and caffeinate to be available
  if (!nzchar(Sys.which("pmset")) || !nzchar(Sys.which("caffeinate"))) {
    testthat::fail("macOS CLI check requires 'pmset' and 'caffeinate' in PATH, but one or both were not found.")
    return(invisible(NULL))
  }

  # Helper: run pmset -g assertions and return full text
  pmset_assertions <- function() {
    out <- suppressWarnings(
      system2(
        "pmset",
        args   = c("-g", "assertions"),
        stdout = TRUE,
        stderr = FALSE
      )
    )
    paste(out, collapse = "\n")
  }

  # Small delay helper (like short_wait() in Julia)
  short_wait <- function() {
    try(Sys.sleep(0.2), silent = TRUE)
  }

  pre  <- pmset_assertions()

  NoSleepR::nosleep_on(keep_display = FALSE)
  short_wait()
  mid  <- pmset_assertions()
  NoSleepR::nosleep_off()
  post <- pmset_assertions()

  # Look for caffeinate process being asserted
  testthat::expect_match(
    mid,
    "caffeinate",
    ignore.case = TRUE,
    label = "pmset output while nosleep_on() is active should mention caffeinate"
  )

  # After nosleep_off(), caffeinate assertion should be gone,
  # or pmset may still show the same snapshot briefly (like in Julia test).
  has_caff_post <- grepl("caffeinate", post, ignore.case = TRUE)
  has_caff_mid  <- grepl("caffeinate", mid,  ignore.case = TRUE)

  testthat::expect_true(
    !has_caff_post || identical(post, mid),
    info = "pmset output after nosleep_off() should not show caffeinate, or be identical to mid due to caching."
  )
})
