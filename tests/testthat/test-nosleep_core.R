test_that("nosleep_on/off work on any platform (no crash)", {
  expect_silent(nosleep_on())
  expect_silent(nosleep_off())
})
