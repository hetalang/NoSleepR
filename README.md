# NoSleepR

[![Continuous Integration](https://github.com/hetalang/NoSleepR/actions/workflows/ci.yml/badge.svg)](https://github.com/hetalang/NoSleepR/actions/workflows/ci.yml)
[![GitHub issues](https://img.shields.io/github/issues/hetalang/NoSleepR.svg)](https://GitHub.com/hetalang/NoSleepR/issues/)
[![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](https://github.com/hetalang/NoSleepR/blob/master/LICENSE.md)
[![CodeQL](https://github.com/hetalang/NoSleepR/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/hetalang/NoSleepR/actions/workflows/github-code-scanning/codeql)
<!--[![CRAN status](https://www.r-pkg.org/badges/version/NoSleepR)](https://cran.r-project.org/package=NoSleepR)
[![Downloads](https://cranlogs.r-pkg.org/badges/NoSleepR)](https://cran.r-project.org/package=NoSleepR)-->

Prevent your computer from entering sleep mode while long-running R tasks are running — and automatically restore normal system behavior when they finish or fail.

- **Cross-platform backend**  
  - Windows: `PowerRequest`
  - macOS: `caffeinate`
  - Linux: `systemd-inhibit`
- **Simple API**: block-style or manual on/off.
- **Safe by design**: resets on exit or error.
- Optional **keep_display** mode to prevent screen from turning off.

## Installation

Install the development version directly from GitHub:

```r
# install.packages("devtools")
devtools::install_github("hetalang/NoSleepR")
library(NoSleepR)
```

## Usage

### Basic usage

```r
nosleep_on()
# long-running R code here
nosleep_off()
```

### Block-style usage

You can wrap a code block using `with_nosleep()` to ensure sleep-prevention is enabled only for the duration of the block:

```r
with_nosleep({
  # long-running R code here
})
```

## Options

### keep_display

Prevents the display from turning off (default is `FALSE`):

```r
nosleep_on(keep_display = TRUE)
```

Or in block mode:

```r
with_nosleep(keep_display = TRUE, {
  # long-running code
})
```

## Known limitations and recommendations

*Some sleep behaviors are enforced by the operating system and cannot be overridden by NoSleepR or any similar tools.*

1. **Closing the laptop lid or pressing the power button** will force the system into sleep regardless of active sleep-prevent requests of `NoSleepR`.

1. On Windows devices with **Modern Standby (S0ix) running on battery power (DC mode)** the OS may ignore sleep prevention signals after a 5 minutes of inactivity if the screen is turned off.
    - **Connect charger (AC mode)** to avoid this.
    - **OR use** `keep_display=TRUE` to keep the screen awake.

## Remote sessions (SSH, Posit/RStudio Server)

`NoSleepR` only affects the machine where R actually runs.
If your code runs on a remote server, the package has no effect on your local computer — and it won't prevent disconnects in remote IDEs.

Most "remote sleep" problems are actually connection timeouts, not the server going to sleep. This is normal: `NoSleepR` is designed for local laptops/desktops, not for managing network sessions.

For reliable long runs on a remote server, use tools like `tmux`, `screen`, or built-in session-recovery mechanisms of your IDE. There's usually no need to keep your local machine awake.

## Related packages

- **lares** — <https://github.com/laresbernardo/lares>  
  Provides a `dont_sleep()` helper with similar purpose, but relies on simulating mouse activity and depends on external tools.  
  *It does not use system-level sleep-inhibit mechanisms*

- **NoSleep.jl** — <https://github.com/hetalang/NoSleep.jl>  
  Julia implementation of the same concept, using native OS sleep-inhibition backends (Windows/macOS/Linux).  
  *For Julia developers*

## Author

- [Evgeny Metelkin](https://metelkin.me)

## License

MIT (see `LICENSE.md`).
