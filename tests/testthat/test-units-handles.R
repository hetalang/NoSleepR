test_that("nosleep_on returns either handle or NULL", {
  h <- suppressWarnings(nosleep_on())

  # On any platform available backend should return either:
  # 1) NULL  (backend not available)
  # 2) OBject of type NoSleepR_handle
  expect_true(
    is.null(h) ||
      (inherits(h, "NoSleepR_handle") && is.list(h))
  )

  # nosleep_off(NULL) should be no-op and not affect "all"
  expect_silent(nosleep_off(NULL))

  if (!is.null(h)) {
    # If handle is present, it can be safely turned off
    expect_silent(nosleep_off(h))
  } else {
    # If backend is not available, just ensure global off does not error
    expect_silent(nosleep_off())
  }
})

test_that("nosleep_off() handles missing, NULL and wrong types correctly", {
  # No argument: global off
  expect_silent(nosleep_off())

  # NULL — no-op
  expect_silent(nosleep_off(NULL))

  # Wrong type -> error
  expect_error(
    nosleep_off(123),
    "NoSleepR_handle"
  )
})

test_that("multiple handles and nosleep_off semantics", {
  h1 <- suppressWarnings(nosleep_on())
  h2 <- suppressWarnings(nosleep_on())

  # If backend is not available (both NULL), multi-handle test is meaningless
  if (is.null(h1) || is.null(h2)) {
    expect_silent(nosleep_off())
    skip("Backend not available; skipping multi-handle behavior checks.")
  }

  expect_true(inherits(h1, "NoSleepR_handle"))
  expect_true(inherits(h2, "NoSleepR_handle"))

  # Turn off one handle — should not error
  expect_silent(nosleep_off(h1))

  # Turn off the other one
  expect_silent(nosleep_off(h2))

  # Repeated off on already turned-off handle should not error (idempotent)
  expect_silent(nosleep_off(h2))

  # Create one more handle
  h3 <- suppressWarnings(nosleep_on())
  if (!is.null(h3)) {
    expect_silent(nosleep_off())  # Must turn off all active
  } else {
    expect_silent(nosleep_off())
  }
})

test_that("with_nosleep works even when backend returns NULL", {

  # Simulate a situation where nosleep_on always returns NULL
  testthat::with_mocked_bindings(
    nosleep_on = function(keep_display = FALSE) NULL,
    {
      result <- with_nosleep({ 10 })
      expect_identical(result, 10)

      # nosleep_off() after such scenario should not fail
      expect_silent(nosleep_off())
    }
  )
})
