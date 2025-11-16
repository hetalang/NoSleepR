test_that("NoSleepR basic API works", {
  # nosleep_on/nosleep_off should run without error
  expect_silent(nosleep_on())
  expect_silent(nosleep_off())

  # with_nosleep should execute block and return result
  result <- with_nosleep({
    2 + 2
  })
  expect_identical(result, 4)

  # with_nosleep must restore state even if an error is thrown
  expect_error(
    with_nosleep({
      stop("fail inside block")
    }),
    "fail inside block"
  )

  # after exception nosleep_off should still be callable
  expect_silent(nosleep_off())
})

test_that("NoSleepR keep_display option works", {
  # nosleep_on with keep_display = TRUE should run without error
  expect_silent(nosleep_on(keep_display = TRUE))
  expect_silent(nosleep_off())
})
