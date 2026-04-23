# SD — switch directory using a dynamic stack

SD is a directory navigation utility for ksh93u+, bash ≥ 4.2, and zsh ≥ 4.3, using
frequency–recency tracking over an explicit visit history. Ksh-compatibility
options are enabled: `extglob` in bash; `KSH_ARRAYS`, `KSH_GLOB`,
`POSIX_BUILTINS`, and `SH_WORD_SPLIT` in zsh.

> Note: This project is unrelated to the Rust-based `sd` text replacement tool.

> This repository is a **read-only snapshot mirror** containing tagged stable states.  
> Issues are monitored, and pull requests may be considered for manual integration.

## Overview

SD provides the `sd` command, designed to act as a drop-in replacement for `cd`
for pathname arguments. In addition, it supports pattern-based directory selection
from a dynamically ranked directory stack.

Directory ranking is computed over a trailing window of recorded directory visits.
For each directory, a score is obtained by summing weighted contributions of
its visits within that window. The weighting follows a configurable
power-law kernel over normalized event indices.

Repeated invocation with the same pattern cycles deterministically through
successive rank-ordered matches.

The companion command `ds` exposes the ranked directory stack and provides
inspection and management functions.

---

## What it does

* Records directory changes in a logfile.
* Maintains an in-memory history including events not yet flushed to disk.
* Recomputes a ranked stack from a trailing window of directory visit events after each directory change.
* Matches patterns (regular expressions) against full directory paths.
* Changes directory according to highest-ranked match.
* Allows deterministic cycling through further matches by repeating the same pattern.

---

## Commands

These shell functions provide the interface:

* **`sd ARG...`** — change directory (pathname or pattern)
* **`ds [options] [pattern]`** — inspect and optionally select directories interactively
  * If `fzf` is installed, matches are presented in an interactive fuzzy finder.
* **`cd ARG...`** — identical to `sd`

The `cd` command behaves identically to `sd`. It is provided for convenience so
existing muscle memory works without retraining; use whichever you prefer.


### `sd` semantics

`sd` accepts arguments but does **not** implement command-line options.

Behavior:

1. If the argument resolves to a valid pathname, standard `cd` semantics apply.
2. Otherwise, the argument is treated as a pattern and matched against the
   ranked stack.

Special case:

* `sd -` behaves like builtin `cd -`.

All other arguments beginning with `-` are treated as ordinary arguments
(pathname or pattern). Builtin `cd` options (e.g., `-P`, `-L`) are not parsed or
forwarded.

For valid pathnames, behavior matches the shell builtin `cd`, including:

* Absolute and relative paths
* `.`, `..`
* `~` expansion
* Permission handling

---

## Pattern matching

If no valid pathname is found, arguments are interpreted as a pattern:

* Multiple arguments are merged into a single pattern.
* Whitespace is normalized to single blanks.
* Matching uses regular expressions against full directory paths.
* Smart case: matching is case-insensitive unless the pattern contains
  uppercase characters.

Shell and/or Regex metacharacters may require quoting (e.g., `'a\.b'`).

---

## Cycling semantics

If `sd pattern` is invoked repeatedly with the exact same pattern:

* Matches are traversed in strictly rank-based order.
* Cycling is deterministic during the first traversal of the current stack.
* The stack is recomputed after each directory change.
* The selected directory's score increases, but the relative order of the
  remaining matches is preserved during the first traversal.
* Cycling resets as soon as a different argument is used.
* Intervening non-`sd` commands do not reset the cycle.

After a full traversal, a further cycle may reflect updated ranking due to score
changes.

---

## Ranking model

Scoring is computed over a trailing window of $N$ events. Let the last $N$
directory-change events be indexed $1, \dots, N,$ oldest to newest. Let
$n_i \subseteq {1,\dots,N}$ be the set of indices at which directory $i$ was
visited. Then the score of directory $i$ is

$$
F(i) = \sum_{n \in n_i} \left(\frac{n}{N}\right)^p
$$

where:

* $N$ is the window length (not the logfile size)
* $p$ is the power-law exponent
* $n_i$ are the event indices within the window at which directory $i$ was visited

Higher $p$ increases recency bias. Default: $p = 10$.

Properties:

* Full visit chronology is preserved within the window.
* Scores are computed from event indices.
* Ranking is deterministic given the recorded history.
* Recency is measured in number of directory-change events, not wall-clock time.
  Inactive periods do not affect scores or ranking.

A first-time visit receives score $F = 1$, which decreases as subsequent events
push it back in history.

---

## Memory and retention

Two independent limits exist:

* **`loglim`** — maximum number of stored directory-change events (hard cutoff)
* **`window`** — number of trailing events used for scoring

Events older than `window` do not influence ranking.
Events older than `loglim` are permanently discarded.

With default settings:

* `window = 1280` events. At ~50 directory changes per day, this spans roughly one month.
* `loglim = 8192` typically retains substantially longer history.

Changing `window` recomputes the stack immediately.

---

## Stale and missing directories

If a ranked match no longer exists:

1. Lower-ranked matches are attempted.
2. If all stack matches are stale (or none exist), matching is expanded to the
   full recorded history currently held in memory.

Permission errors are handled consistently with the builtin `cd`.

Logfile integrity is verified via a header marker when loading. No automatic
repair mechanism is implemented.

Logfile locking is used to coordinate concurrent shells.

---

## Performance

Performance depends on the scoring window size.

On typical hardware and for default settings:

* ~22 ms (ksh) to ~32 ms (bash) per `cd` action (real time)

Extending window size to the full event log reduces performance by about
a factor of two.

---

## Installation

**Requirements**

* ksh93, bash, or zsh
* Optional: `fzf` for interactive selection via `ds`

Add to your shell rc file:

```sh
. /path/to/sd.ksh
```

On first run, a logfile is created and initialized.

---

## Configuration

Configuration is held in associative array `SD_CFG`, initialized with defaults.
Define only the keys you want to override:

```sh
typeset -A SD_CFG=(
    [loglim]=8192
    [window]=1280
    [power]=10
    [stacklim]=0
    [smartcase]=1
    [verbose]=1
    [period]=3600
)
. /path/to/sd.ksh
```

Runtime adjustments (via `ds`):

* `ds -l N` — set scoring window
* `ds -k K` — cap stack size
* `ds -e pow` — adjust exponent
* `ds -c` — clean stale entries
* `ds -i` — show status
* `ds -m` — show full manual

`sd` itself takes no options.

---

## Related tools

Other directory-jumping tools include:

* [autojump](https://github.com/wting/autojump)
* [fasd](https://github.com/clvv/fasd)
* [jumper](https://github.com/homerours/jumper)
* [z](https://github.com/rupa/z)
* [zoxide](https://github.com/ajeetdsouza/zoxide)

These tools maintain per-directory aggregate state rather than a full sequence of
visits. SD retains the complete visit history up to a configurable limit and
derives scores from it, unaffected by elapsed wall-clock time.
