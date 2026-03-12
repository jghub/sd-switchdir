# SD — Changelog

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
