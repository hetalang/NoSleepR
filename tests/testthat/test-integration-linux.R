# Enable these integration checks only when explicitly requested
RUN_TEST <- Sys.getenv("INTEGRATION_TESTS", "0") == "1"

# tests/testthat/test-integration-linux.R

test_that("Linux: systemd-inhibit is listed (opt-in)", {
  # Run only on Linux
  skip_if_not(Sys.info()[["sysname"]] == "Linux", "Test is Linux-specific.")

  # Opt-in via environment variable (same convention as for Windows/macOS)
  if (!RUN_TEST) {
    skip("CLI integration tests are disabled (set INTEGRATION_TESTS=1 to enable).")
  }

  # Requires systemd and loginctl
  if (!nzchar(Sys.which("systemd-inhibit")) || !nzchar(Sys.which("loginctl"))) {
    testthat::fail("Linux CLI check requires 'systemd-inhibit' and 'loginctl' in PATH, but one or both were not found.")
    return(invisible(NULL))
  }

  # Helper: run `systemd-inhibit --list` and return full text
  systemd_inhibit_list <- function() {
    out <- suppressWarnings(
      system2(
        "systemd-inhibit",
        args   = c("--list"),
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

  # Before
  pre <- systemd_inhibit_list()

  NoSleepR::nosleep_on()
  short_wait()
  mid <- systemd_inhibit_list()
  NoSleepR::nosleep_off()
  post <- systemd_inhibit_list()

  # Our backend uses --who=NoSleepR --why=Long computation
  # Check that the inhibitor appears while active...
  testthat::expect_match(
    mid,
    "NoSleepR",
    label = "systemd-inhibit --list while nosleep_on() is active should mention NoSleepR"
  )

  # ...and disappears after nosleep_off()
  testthat::expect_false(
    grepl("NoSleepR", post, fixed = TRUE),
    info = "systemd-inhibit --list after nosleep_off() should not mention NoSleepR"
  )

  # State should actually change between pre and mid
  testthat::expect_false(
    identical(pre, mid),
    info = "systemd-inhibit --list output should change when inhibitor is active"
  )
})
