# SD — Changelog

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
