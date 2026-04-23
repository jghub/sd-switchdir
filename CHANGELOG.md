# SD — Changelog

## v3.2.1 (2026-04-24)
* **manpage**: better explanation of `fzf` configurability via `SD_FZF`.

* **fix `set -u` edge case**: running `ds -i` before the first `cd` with
    `set -u` enabled previously raised an "unbound variable" error.

* **fix housekeeping edge case**: if initial setup failed, some variables were
    not properly unset.

* **default value adjustment**: the power law exponent now defaults to 10 rather
  than 9.97. The old value was chosen to make the weight at the midpoint of the
  attention window drop to exactly 1/1000; the round value 10 is numerically
  equivalent for practical purposes.

## v3.2.0 (2026-04-14)
* **improved handling of globbing during array construction**: all string-to-array
  conversions are now executed with globbing temporarily disabled
  (`set -o noglob` / `set +o noglob`) to prevent pathname expansion from affecting
  unquoted word-splitting of input data. Globbing is then re-enabled unconditionally,
  under the assumption that it is normally active in interactive shells and not
  deliberately disabled by the user.

* **bypass interactive selection for unique matches**: previously, `ds pattern`
  yielding a unique match bypassed the interactive selection interface only for
  `mode=2` (fzf-based selection) by letting `fzf` handle this case. It now also
  works for `mode=1` (index-based selection) and for `mode=2` avoids calling
  `fzf` at all.

* **make fzf behaviour user configurable**: SD now provides a new associative
  array `SD_FZF` which holds `fzf` option/value pairs (see `ds -m` for details).
  Definitions in `SD_FZF` take precedence over any conflicting settings in
  `FZF_DEFAULT_OPTS`.

* **minor fix**: ensure that buffer holding new `cd` events is only reset as a side
  effect of cleaning/deleting/pruning entries from history if logfile recreation
  actually succeeded; in this case the auto-update timestamp is now reset, too.
  Behaviour is now consistent with append-only update logic.

* **adjustments to `ds -i` report**: include flush delay information.

* **changed tag naming scheme**: tag names no longer include the checkout hash
  from the master repository and now use semantic version identifiers in the form
  `v1.2.3`.

## v3.1-626cb6e6 (2026-04-05)
* **better signal interception handling**: previously, even INT and QUIT signals
  were springing the logfile update trap but this never made much sense (and even
  could get into the user's way in ksh and zsh -- bash is nicer here). The trap now
  only springs on shell terminating signals (EXIT HUP TERM). Logfile update/rewrite
  functions handle signal interception and trap management a bit clearer than
  before.

* **fixed minor regression**: `ds -d` needs always to reset the stack, even if no
  entries are actually deleted from the logfile. The recently introduced early
  return cases erroneously bypassed this reset.

* **formatting**: `ds -d` now reports the to-be-deleted entries in alphabetical
  order to facilitate scrutiny of the list.

* **New `ds` options**:
    * `-r`: Report score and rank info for present working directory.
    * `-y`: Report chronological list of most recent cd events.

* **reporting**: improve logic of when to implicitly trigger `ds -i` output after
   interactive configuration change via any option from `[eklno]`.

* **manpage**: several small adjustments.

## v3.1-acd48404 (2026-03-12)
* **New `ds` options `-n` and `-o`**: Toggle `SD_CFG[freeze]` and
    `SD_CFG[dynamic]` states.

    * `-n` (Freeze): Prevents new directories from being added to the history.
        Useful for private sessions or testing.

    * `-o` (Static Stack): Disables stack updates. New `cd` actions are still
        logged, but the current stack order remains fixed.

    * **Note**: Deviations from defaults are now prominently highlighted in `ds
        -i` to prevent accidental persistence of these modes.

* **zsh-specific fix**: Corrected `~` expansion logic in `ds -c` to account for
    zsh-specific behavior (differing from ksh/bash).

* **bash-specific fix**: Explicitly initialized arrays to prevent errors under
    `set -u` (Bash treats uninitialized arrays as unset variables).

## v3.1-98157353 (2026-03-03)
* **Minor fix**: Isolated internal logic from the calling shell's positional
    parameters (`$1`, `$2`, etc.) to prevent side effects.

## v3.1-78285cd6 (2026-02-24)
* **Baseline**: First published version.
