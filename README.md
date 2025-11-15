# NoSleepR

Prevent your computer from entering sleep mode while long-running R tasks are running — and automatically restore normal system behavior when they finish or fail.

- **Cross-platform backend**  
  - Windows: `PowerRequest`
  - macOS: `caffeinate`
  - Linux: `systemd-inhibit`
- **Simple API**: block-style or manual on/off.
- **Safe by design**: resets on exit; optional timeout.

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

Prevents the display from turning off (default is `TRUE`):

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
    - **OR use** `keep_display=true` to keep the screen awake.

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
