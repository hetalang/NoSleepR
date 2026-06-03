test_that("Linux inhibitor list parser recognizes NoSleepR entries", {
  output <- paste(
    "WHO      UID USER PID  COMM  WHAT  WHY              MODE",
    "NoSleepR 1000 user 1234 sleep sleep Long computation block",
    sep = "\n"
  )

  expect_true(linux_inhibitor_listed(output, 1234L))
  expect_false(linux_inhibitor_listed("No inhibitors.", 1234L))
  expect_true(is.na(linux_inhibitor_listed(NA_character_, 1234L)))
})
