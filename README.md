# SD — switch directory using a dynamic stack

SD is a directory navigation utility for ksh93u+, bash $\ge$ 4.2, and zsh $\ge$ 4.3, using
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
exponential kernel (or alternatively the legacy power-law kernel) over normalized
event indices.

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

Shell and/or regex metacharacters may require quoting (e.g., `'a\.b'`).

---

## Cycling semantics

If `sd pattern` is invoked repeatedly with the exact same pattern:

* Matches are traversed in strictly rank-based order.
* The stack is recomputed after each directory change.
* The selected directory's score increases, but the relative order of the
  remaining matches is preserved.
* Cycling resets as soon as a different argument is used.
* Intervening non-`sd` commands do not reset the cycle.

After a full traversal, a further cycle may reflect updated ranking due to score
changes. The exponential kernel provides exact preservation of relative stack
order for non-visited directories across successive cd events, the only exception
being score adjustments due to window truncation which can occasionally affect
lower-ranked entries where scores are closest in magnitude. Apart from this
effect, order of match traversal during further cycles will remain unaltered.

---

## Ranking model

Scoring is computed over a trailing window of $N$ events. Let the last $N$
directory-change events be indexed $1, \ldots, N$, oldest to newest. Let
$n_i \subseteq \{1,\ldots,N\}$ be the set of indices at which directory $i$ was
visited. The score of directory $i$ is:

$$
F(i) = \sum_{n \in n_i} K[N - n]
$$

where $j = N-n$ denotes event age in ticks ($j=0$ for the most recent event,
$j=N-1$ for the oldest), and $K[j]$ is an aging kernel assigning a weight to
events of age $j$. The default kernel is exponential:

$$
K[j] = \exp \left( -p \cdot \frac{j}{N} \right)
$$

The legacy power-law kernel (`SD_CFG[kernel]=0`) is:

$$
K[j] = \left( 1 - \frac{j}{N} \right)^p
$$

In both cases $p$ controls the rate of decay with age; larger $p$ assigns
less weight to older events. Both kernels share $K[0]=1$, so a first-time visit
always gets initial score $F=1$.

The exponential kernel provides exact preservation of relative stack order for
non-visited directories across successive cd events, making it the preferred
default for deterministic cycling over repeated same-pattern invocations. At
window boundaries a small score perturbation can affect lower-ranked entries (see
Cycling semantics above).

The legacy power-law kernel only approximately preserves order across events
while penalizing older events more heavily than the exponential kernel for the
same value of $p$.

Properties common to both kernels:

* Full visit chronology is preserved within the window.
* Scores are computed from event indices, not wall-clock time.
* Ranking is deterministic given the recorded history.
* Inactive periods do not affect scores or ranking.

A first-time visit receives score $F=1$, which decreases as subsequent events
push it back in history. Default: $p=10$.

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

**Naming conflicts:** If a command named `sd` already exists in your environment
(e.g. the Rust-based [sd](https://github.com/chmln/sd) text replacement tool),
SD will detect this and not define its own `sd` shell function. The existing
command remains unaffected. In this case, use `cd` to access SD's functionality,
or define a wrapper under a name of your choice:

```sh
function mysd { _sd__switch "$@"; }
```

The `ds` command can be renamed similarly if needed:

```sh
function myds { _sd__dispatch "$@"; }
``` 

---

## Configuration

Configuration is held in associative array `SD_CFG`, initialized with defaults.
Define only the keys you want to override, prior to sourcing `sd.ksh`:

```sh
typeset -A SD_CFG=(
    [loglim]=8192
    [kernel]=1
    [power]=10
    [window]=1280
    [stacklim]=0
    [smartcase]=1
    [verbose]=1
    [period]=3600
)
```

Key settings:

* `loglim` — maximum stored events (hard cutoff)
* `kernel` — scoring kernel: 1 (exponential, default), 0 (legacy power law)
* `power` — age-penalty parameter; higher values reduce weight of older visits
* `window` — number of trailing events used for scoring
* `period` — logfile flush interval in seconds (0 = flush on every cd)

Runtime adjustments via `ds`:

* `ds -l N` — set scoring window
* `ds -k K` — cap stack size
* `ds -e p` — adjust age-penalty parameter
* `ds -c` — clean stale entries
* `ds -i` — show status
* `ds -m` — show full manual

`sd` itself takes no options.

### fzf configuration

If `fzf` is available, `ds pattern` opens an interactive fuzzy finder for
multiple matches. `fzf` behaviour is configured via the associative array
`SD_FZF`, using fzf long option names (without the `--` prefix) as keys.
Options that take no value are specified with an empty string:

```sh
typeset -A SD_FZF=(
    [cycle]=''
    [tmux]='center,80%,border-native'
)
```

`SD_FZF` entries may be defined before or after sourcing `sd.ksh`. The options
`--preview` and `--no-sort` are set internally by SD and cannot be overridden.
The current configuration can be inspected with `typeset -p SD_FZF`.

---

## Related tools

Other directory-jumping tools include:

* [autojump](https://github.com/wting/autojump)
* [fasd](https://github.com/clvv/fasd)
* [fre](https://github.com/camdencheek/fre) (exponential frecency tracker; no built-in jumping)
* [jumper](https://github.com/homerours/jumper)
* [z](https://github.com/rupa/z)
* [zoxide](https://github.com/ajeetdsouza/zoxide)

These tools maintain per-directory aggregate state rather than a full sequence of
visits. SD retains the complete visit history up to a configurable limit and
derives scores from it, unaffected by elapsed wall-clock time.
