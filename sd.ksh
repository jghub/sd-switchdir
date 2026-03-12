#!/usr/bin/env ksh
# ---------------------------------------------------------------------
# Copyright (c) 2011-26, Joerg van den Hoff
#
# Permission to use, copy, modify, and/or distribute this software for
# any purpose with or without fee is hereby granted, provided that the
# above copyright notice and this permission notice appear in all
# copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
# PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
# -------------------------------------------------------------------------------
# shellcheck disable=SC2016  # awk/fzf scripts in single quotes must not expand
# shellcheck disable=SC2206  # intentional IFS-controlled array splits throughout
# shellcheck disable=SC2207  # intentional IFS-controlled array splits throughout
# -------------------------------------------------------------------------------
typeset -A SD__INTERN
[[ ${SD__INTERN[debug]:-0} == 0 ]] && [[ -n ${SD__INTERN[loaded]+1} ]] && return

function _sd__checkshell {
   if [[ ${KSH_VERSION-} == 'Version AJM'* ]]; then
      SD__ALIAS_DEFS=$(alias -p)
      unalias -a 2>/dev/null
   elif [[ -n ${BASH_VERSION+x} ]]; then
      shopt -q expand_aliases && SD__ALIASES_ON=1 || SD__ALIASES_ON=0
      shopt -u expand_aliases
      shopt -s extglob
   elif [[ -n ${ZSH_VERSION+x} ]]; then
      [[ -o aliases ]] && SD__ALIASES_ON=1 || SD__ALIASES_ON=0
      [[ -o aliasfuncdef ]] && SD__ALIASFD_ON=1 || SD__ALIASFD_ON=0
      setopt no_aliases
      setopt aliasfuncdef
      set -o KSH_ARRAYS
      set -o KSH_GLOB
      set -o POSIX_BUILTINS
      set -o SH_WORD_SPLIT
   else
      unset SD__INTERN
      printf '%s\n' 'sd.ksh requires ksh93, bash, or zsh.'
      return 1
   fi
}
_sd__checkshell || { unset -f _sd__checkshell; return 1; }

function _sd__man {  ## pdf?
   typeset -a formatter=(groff -man) pager=(less -R)  offon=('off' 'on')
   if [[ ${1:-tty} == pdf ]]; then
      formatter+=(-Tpdf)
      pager=(cat)
   else
      # we do not really make use of utf8 capabilities in the manpage so far and
      # could just use the latin1 device no matter what. but it still is better
      # to maintain the capability to make use of those possibly in the manpage.
      case "${LC_ALL:-${LC_CTYPE:-${LANG}}}" in
         *UTF-8*|*utf8*|*UTF8*|*utf-8*)
            formatter+=(-Tutf8)
            ;;
         *)
            formatter+=(-Tlatin1)
            ;;
      esac
      formatter+=(-rLL=$(($(tput cols) - 3))n)
      (( SD__INTERN[debug] )) && formatter+=(-P -cbou)
   fi

   # ensure correct alignment in the dynamic SD_CFG[key]=value listing in manpage.
   typeset -A pad=() len=()
   typeset -i maxlen=0
   typeset key
   typeset -a keys=()
   # shellcheck disable=SC2296  # shellcheck does not handle zsh-specific syntax
   [[ -n ${ZSH_VERSION-} ]] && keys=("${(k)SD_CFG[@]}") || keys=("${!SD_CFG[@]}")
   for key in "${keys[@]}"; do
      ((len[$key] = ${#key} + ${#SD_CFG[$key]} ))
      [[ $key == prefix ]] && ((len[$key] += 2))   # account for hardcoded '..' quoting of this special key/value
      ((maxlen = len[$key] > maxlen? len[$key]:maxlen))
   done
   for key in "${keys[@]}"; do
      pad[$key]=$(printf '%*s' $((maxlen - len[$key])) '')
   done

   cat <<-HERE | "${formatter[@]}" | "${pager[@]}"
.\"----------------------------------------------------------
.TH SD 1 "January 25, 2026"
.nh
.SH NAME
sd \- switch between directories using a dynamic directory stack
.SH SYNOPSIS
.SY sd
.RI [ pattern | pathname | \- ]
.LP
.SY ds
.OP \-012Vcfhimnopsw
|
.OP \-d pat
|
.OP \-e pow
|
.OP \-k K
|
.OP \-l N
|
.RI [ pattern ]
.YS
.SH DESCRIPTION
.LP
The
.B SD
utility enables rapid navigation between previously visited directories via
two commands:
.B ds
("directory stack") and
.B sd
("switch directory").
.B SD
also shadows the builtin
.B cd
command with a shell function so that
.B cd
and
.B sd
can be used interchangeably.
.LP
.B SD
tracks
.B cd
activities using a logfile, which is analyzed to generate a directory stack
sorted by a "frecency" metric (see
.IR "DIRECTORY STACK ALGORITHM" ).
The stack is queried with
.B sd
.IR pattern ;
when multiple directories match, the highest scoring match is selected. This
enables reaching desired locations even with highly unspecific patterns.
.B sd
.I [pathname|\-]
behaves identical to the
.B cd
builtin (pathname interpretation takes precedence over pattern matching).
.LP
.B SD
is written in
.I KornShell
and runs under
.BR ksh93 ,
.B bash
(4.2+), and
.B zsh
(4.3+).
.
.
.SH OPTIONS
.LP
The
.B sd
command does not accept options. Patterns starting with a hyphen are treated
literally (e.g.,
.B sd
.IR \-git ).
Exception:
.B sd
.I [\-h|\-\-help]
provides a usage hint. To use the literal pattern
.IR \-h ,
escape the hyphen:
.IR \e\e\-h .
.LP
The
.B ds
command options are processed in order of appearance (specifying more than one
is rarely useful). Note that options apply only to
.BR ds ,
not
.BR sd .
For hyphen-prefixed patterns with
.BR ds ,
use:
.B ds
.B \-\-
.IR \-pattern .
.TP
.B \-[012]
Selection mode for
.B ds
.IR pattern :
0 (tabular view), 1 (indexed selection), 2 (fzf finder, default).
Current value:
.BR ${SD_CFG[mode]} .
.TP
.B \-V
Version info.
.TP
.B \-c
Clean logfile/history: remove stale entries.
.TP
.BI \-d " pat"
Delete all entries matching pattern
.I pat
from logfile/history.
.TP
.BI \-e " pow"
Set power law exponent for age-scoring. Fractional values allowed.
Current value:
.BR ${SD_CFG[power]} .
.TP
.B \-f
Force immediate update and reload of logfile.
.TP
.B \-h
Short usage note.
.TP
.B \-i
Status and configuration info.
.TP
.BI \-k " K"
Cap stack size at
.I K
directories (set K=0 to disable).
Current value:
.BR ${SD_CFG[stacklim]} .
.TP
.BI \-l " N"
Limit analysis window to
.I N
events. Use
.B ds
.B \-l
.I 0
or
.B ds
.B \-l
.I l
to maximize (use full history).
Current value:
.BR ${SD_CFG[window]} .
.TP
.B \-m
Display manpage.
.TP
.B \-n
On/off toggle: whether to freeze logfile (default: off). If switched on, cd actions
in the present shell will not be stored in the logfile. Current state:
.BR ${offon[SD_CFG[freeze]]} .
.TP
.B \-o
On/off toggle: whether to update stack (default: on). If switched off, cd actions
do no longer trigger directory stack updates, making the stack content
"static" (stack recomputation is still triggered by any of
.B ds
.BR "\-[cdefkl]" ).
This also ensures invariant rank order on the stack which sometimes might be desirable.
Current state:
.BR ${offon[SD_CFG[dynamic]]} .
.TP
.B \-p
Send PDF version of manpage to stdout.
.TP
.B \-s
Display
.B ds
.I pattern
matches alphabetically (default: by relevance).
.TP
.B \-w
Write newly visited directories to logfile immediately.
.
.
.SH USAGE
.LP
.B SD
uses smart case matching (case-insensitive unless pattern contains an
uppercase letter).
.LP
The
.B sd
command merges multiple arguments into a single regex pattern, converting
multiple white space characters separating arguments to single blanks (this
allows specifying patterns or pathnames containing single blanks without
quotes). Arguments are first tried as literal pathnames. Special cases
.B sd
(no args),
.B sd
.I \- ,
and
.B sd
.I .
work as expected. If pathname interpretation fails, the input is treated as a
regular expression. Characters special to the shell or regex may need quoting.
Example: verbatim lookup of
.I a.b
requires
.IR 'a\e.b' .
.LP
Search is performed top-down by relevance. The working directory changes to
the first match. If this is not the desired directory, repeating the
.B sd
command with the
.I same
pattern (easily recalled from shell history) cycles through all matches.
Example:
.B sd
.I '.*'
visits every directory on the stack in relevance order (note:
.B sd
.I .
differs, as pathname interpretation takes precedence). By default, cycle
completion triggers an informational message. These messages can be adjusted
with the
.B verbose
setting (see
.IR CUSTOMIZATION ).
.LP
Alternatively, make patterns more specific using trailing pathname components
or use
.BI 'sd\ = rank'
to jump directly to a specific stack position (e.g.,
.B sd
.IR =3 ).
.BI "sd " =
is equivalent to
.B sd
.IR  = .
Note:
.B zsh
users must quote the equal sign.
.LP
The
.B ds
command serves two purposes. With an option, it acts as a configuration
interface. As
.B ds
.IR pattern ,
it provides interactive selection from matching stack entries. If
.I pattern
is empty, the full stack is displayed.
.LP
By default (mode
.BR 2 ),
if
.B fzf
is available and multiple matches exist,
.B ds
.I pattern
opens the
.B fzf
interface. Note that
.B fzf
is non-standard and may require separate installation.
.B fzf
displays the stack bottom-up (highest ranking match at bottom), with the
entry initially selected being the one
.B sd
.I pattern
would have chosen. Selection is done at the fzf prompt or via mouse (see
.BR fzf (1)).
If
.B ds
.I pattern
has a unique match, cd executes immediately without opening fzf.
.LP
Selecting a stale entry in fzf will fail, whereas
.B sd
.I pattern
attempts to find another valid match (see next section). If
.B fzf
is unavailable or after
.BR "ds \-1" ,
.B ds
.I pattern
uses index-based selection. After
.BR "ds \-0" ,
.B ds
.I pattern
provides a tabular view
.RI ( "score count rank name" ).
Switch back to fzf mode with
.BR "ds \-2" .
.
.
.SH HANDLING OF STALE ENTRIES AND NON-MATCHING PATTERNS
.LP
An
.B sd
.I pattern
command can fail for two reasons:
.IP 1.
The pattern matches but the entry is "stale" (directory no longer accessible).
.IP 2.
The pattern does not match anything on the current stack.
.LP
.B SD
implements the following fallback strategy:
.IP 1.
If pattern matches but cd fails (directory inaccessible or permission denied),
skip to the next matching entry down the stack.
.IP 2.
If all matches are stale or no matches exist in the current window,
temporarily expand the search to the entire logfile, recreate the stack, and
retry.
.IP 3.
If cd still fails, give up.
.
.
.SH FURTHER NOTES
.LP
In standard operation,
.B SD
reads its logfile only once when
.I sd.ksh
is sourced.
.B SD
may update the logfile intermittently during the shell session
and always updates on shell termination. Intermittent updates are controlled
by
.BR \${SD_CFG[period]} ,
which sets a threshold in seconds after which the next cd triggers a logfile
update (current:
.BR ${SD_CFG[period]} ).
Otherwise,
.B SD
manages all data in memory including new cd logging and stack recomputation.
.LP
Minimizing disk I/O keeps
.B SD
fast but implies that concurrent shell incarnations can slowly diverge regarding
stack content and ranking. Except in very early use (insufficient logfile
history), this is rarely noticeable. If it becomes relevant, synchronize
shells by issuing
.B ds
.B \-f
in one or both, which forces a logfile update and reload. Generally, this is
rarely necessary.
.
.
.SH SHELL VARIABLES AND FUNCTIONS
.LP
User-visible internal functions follow the naming scheme
.BR _sd__funcname .
User-visible internal variables follow
.BR SD__VARNAME .
The associative array
.B SD_CFG
holds configuration information. Default behavior can be changed by modifying
this array in your shell rc file (see
.IR CUSTOMIZATION ).
Some
.B SD
variables can be large and intrusive when inspecting your namespace with
.BR set .
Use
.B set
.B |
.B less
.B \-S
to suppress line wrapping, or use the dedicated alias
.B sdset
which removes disruptive variables from
.B set
output.
.
.
.SH CUSTOMIZATION
.LP
Defaults should usually be adequate but can be adjusted by defining the
associative array
.B SD_CFG
in your shell resource file
.I prior
to sourcing
.BR sd.ksh .
Only key/value pairs you want to change need specification (others use
defaults). Keys marked
.B **
take effect only during startup and are ignored if modified later:
.LP
.EX
typeset \-A SD_CFG=(
   [logdir]=${SD__LOGDIR}${pad[logdir]} # absolute path to logfile directory **
   [loglim]=${SD__LOGLIM}${pad[loglim]} # max. cd actions in logfile **
   [dynamic]=${SD_CFG[dynamic]}${pad[dynamic]} # auto-update stack after each cd?
   [freeze]=${SD_CFG[freeze]}${pad[freeze]} # freeze logfile? (usually: don't)
   [mode]=${SD_CFG[mode]}${pad[mode]} # controls behavior of \fBds \fIpattern\fR
   [period]=${SD_CFG[period]}${pad[period]} # auto-save period in seconds
   [power]=${SD_CFG[power]}${pad[power]} # power exponent for score computation
   [prefix]="${SD_CFG[prefix]}"${pad[prefix]} # prefix char for \fBcd \fI=num\fR actions
   [smartcase]=${SD_CFG[smartcase]}${pad[smartcase]} # smartcase matching yes/no
   [stacklim]=${SD_CFG[stacklim]}${pad[stacklim]} # prescribe directory stack size
   [verbose]=${SD_CFG[verbose]}${pad[verbose]} # verbosity level [012]
   [window]=${SD_CFG[window]}${pad[window]} # window size
)
.EE
.LP
After sourcing
.IR sd.ksh ,
the keys
.BR period ,
.BR prefix ,
.BR smartcase ,
and
.B verbose
usually need not be modified (though possible). The keys
.BR dynamic ,
.BR freeze ,
.BR mode ,
.BR power ,
.BR stacklim ,
.B window
might be changed transiently with
.B ds
options
.BR \-o ,
.BR \-n ,
.BR \-[012] ,
.BR \-e ,
.BR \-k ,
.BR \-l ,
respectively.
.
.
.SH DIRECTORY STACK ALGORITHM
.LP
The logfile holds a chronological list of cd actions ("events"). The ordinal
index into this list is the implicit clock tick. Event age equals distance to
the last event (which has age zero).
.LP
Analysis is restricted to a trailing segment ("window") covering N events,
enumerated n=1 (oldest) to n=N (newest). Window width determines
.BR SD 's
"attention span". Example: 50 cd/day with window width 500 corresponds to ~10
days of history. Logfile size determines available "long-term memory".
.LP
A score F ("frecency") is computed for each distinct directory
.I i
encountered in the window:
.LP
.EX
   F[i] = sum_n{i} (n{i}/N)^p
.EE
.LP
where the sum runs over all event indices
.I n{i}
involving directory
.IR i .
Conceptually, this represents the convolution (T {*} K)[N] of
a time series T{i}[n] (value 1 at positions
.IR n{i} ,
zero elsewhere) with an aging kernel:
.LP
.EX
   K[j] = (1-j/N)^p
.EE
.LP
where j=0,...,N-1 is sample age in clock ticks relative to the most recent
sample. This score accounts for the full visit chronology, assigning
age-dependent weights controlled by parameters N and p.
.LP
Directories i=1,...,I are sorted by score F[i], yielding the dynamic directory
stack queried by
.B sd
and
.BR ds .
With each further event (changed directory except / and \$HOME), the window
advances one tick, computation repeats, and the stack updates.
.LP
Note: Since K[0]=1 independent of N and p, a first-time visit always gets
initial score F=1. This provides an intuitive way to appreciate the effect of
exponent p by examining stack scores with
.BR "ds \-0" :
adjusting p controls where a first-time visit initially appears on the stack.
.
.
.SH INITIAL SETUP
.LP
.SS Setup for all shells (ksh, bash, zsh)
.LP
Source the script in your shell resource file:
.LP
.B .
.B /path/to/sd.ksh
.LP
This line may be preceded by
.B SD_CFG
array definition to customize behavior (see
.IR CUSTOMIZATION ).
.LP
At first use, the logfile is seeded with non-hidden toplevel directories in
\$HOME (emulating a single visit to each in alphabetical order) to provide a
starting point. Subsequently, the logfile reflects actual cd activities.
.LP
To handle naming collisions with existing commands or aliases, redefine the
wrapper functions using non-colliding names:
.LP
.EX
   function myds { _sd__dispatch "\$@"; }
   function mysd { _sd__switch "\$@"; }
.EE
.LP
If you have a custom
.B cd
function, replace
.B "command cd
with
.B _sd__switch
in that function to make it
.BR SD -aware.
.LP
.B SD
provides a convenience alias
.B sdset
that removes bulky
.B SD
variables from
.B set
output.
.
.
.SS Bash users
.LP
.B SD
expects bash version 4.2 or later.
.B SD
sets
.B shopt
.B \-s
.B extglob
(extended globbing). This option is required for correct operation.
.
.
.SS Zsh users
.LP
.B SD
expects zsh version 4.3 or later.
.B SD
sets
.BR KSH_ARRAYS ,
.BR KSH_GLOB ,
.BR POSIX_BUILTINS ,
and
.BR SH_WORD_SPLIT .
These options are required for correct operation.
HERE
}

function _sd__logcheck {
   typeset firstline
   [[ -f "${SD__LOGFILE}" ]] && read -r firstline < "${SD__LOGFILE}"
   if [[ $firstline == ${SD__MAGIC}* ]]; then
      return
   else
      printf '%s\n' "
      \`sd' problem: '${SD__LOGFILE}' not identified as valid log of visited
      dirs. The file needs to contain a first line starting with string

      ${SD__MAGIC}" >&2
      return 1
   fi
}

function _sd__setup {
   typeset    defdir="$HOME/.sd"
   typeset -i deflim=8192
   # note that the syntax ': "${x:=$y}"' is not completely equivalent to [[ -z $x ]] && x=$y: if
   # running under 'set -u', and 'x' is unset/undefined, an error would occur with the latter:
   : "${SD_CFG[logdir]:="$defdir"}"
   : "${SD_CFG[loglim]:="$deflim"}"

   if [[ ! -v SD__LOGLIM ]]; then  # i.e. only when we are sourced for the first time
      # sanity check for this sensitive setting (typos can happen in user's .shrc).
      if [[ ${SD_CFG[loglim]} != [1-9]*([0-9]) ]]; then
         ((SD_CFG[loglim] = deflim))
      else
         typeset -i imax=999999   # this would correspond to about a lifetime of cd's..
         (( ${#SD_CFG[loglim]} > ${#imax} )) && ((SD_CFG[loglim] = imax))
      fi
   fi

   # this issue is no longer relevant due to new SD__INTERN[loaded] check and early-return:
   # now set the prospective readonly variables. doing it this way allows repeated sourcing.
   # ATTENTION: this is only correct for ksh93 and bash but not for zsh where 2nd source _will_
   # fail (root cause: zsh applies readonly check to ":=" assignment no matter what).
   : "${SD__LOGDIR:=${SD_CFG[logdir]}}"
   : "${SD__LOGLIM:=${SD_CFG[loglim]}}"
   : "${SD__LOGFILE:="${SD__LOGDIR}/dirv"}"
   : "${SD__LOCK:="${SD__LOGDIR}/_sd.lockdir"}"
   : "${SD__MAGIC:="## sd: log of visited directories (keep this line) ##"}"
   : "${SD__TRPCMD:="typeset -f _sd__logappend > /dev/null && _sd__logappend 1"}"
   : "${SD__TRPSIG:="1 2 3 15"}"

   # assign [logdir] and [loglim] keys to reflect the actually operational values (which might differ
   # if we are sourcing a 2nd time and user has modified these two CFG keys in the meantime). they
   # are subsequently ignored by sd. they are only updated to ensure that SD_CFG[@] is reflecting
   # the actually used settings.
   SD_CFG[logdir]=${SD__LOGDIR}
   SD_CFG[loglim]=${SD__LOGLIM}

   # now set the other SD_CFG keys (do this before the failure tests block since on first use user is
   # offered to view manpage immediately -- and the manpage reports the values).
   typeset -i mode
   command -v fzf >/dev/null
   ((mode = $? == 0? 2:1))
   : "${SD_CFG[dynamic]:="1"}"
   : "${SD_CFG[freeze]:="0"}"
   : "${SD_CFG[mode]:="$mode"}"
   : "${SD_CFG[period]:="3600"}"
   : "${SD_CFG[power]:="9.97"}"
   : "${SD_CFG[prefix]:="="}"; [[ ${SD_CFG[prefix]} == [=:,+?] ]] || SD_CFG[prefix]='='
   : "${SD_CFG[smartcase]:="1"}"
   : "${SD_CFG[stacklim]:="0"}"
   : "${SD_CFG[verbose]:="1"}"
   : "${SD_CFG[window]:="1280"}"

   : "${SD__STATE[dname]:=""}"
   : "${SD__STATE[fail]:="0"}"
   : "${SD__STATE[lastpat]:=""}"
   : "${SD__STATE[pick]:="0"}"
   : "${SD__STATE[stamp]:="$SECONDS"}"
   : "${SD__STATE[tries]:="0"}"

   : "${SD__INTERN[debug]:="0"}"
   : "${SD__INTERN[loaded]:="1"}"
   : "${SD__INTERN[mycd]:="0"}"
   : "${SD__INTERN[myds]:="0"}"
   : "${SD__INTERN[mysd]:="0"}"
   : "${SD__INTERN[mysdset]:="0"}"
   : "${SD__INTERN[sleep]:="0.01"}"
   : "${SD__INTERN[version]:="SD v3.1-acd48404"}"

   typeset -i failure=0
   if [[ ${SD__LOGDIR} != /* ]]; then
      printf '%s\n' "
      Startup failure of the SD utility (sd.ksh):
      the 'sd' logfile directory is specified as the relative path '${SD__LOGDIR}'
      but it needs to be an absolute path. Adjust or remove SD_CFG[logdir] in
      your shell resource file."
      failure=1
   elif [[ ! -e "${SD__LOGDIR}" ]]; then
      if mkdir -p "${SD__LOGDIR}"; then
         typeset msg="
         This directory contains the file '${SD__LOGFILE##*/}' used by the SD utility
         (sd.ksh). In this file, recent 'cd' actions are logged for further
         analysis by the utility. Don't remove it. For further details see
         'ds -m' (or '_sd__man', if the 'ds' name is not available)."

         printf '%s\n' "$msg" > "${SD__LOGDIR}/README"
         printf '%s' "
         =========================================================================
         This is a reminder that you are now using the SD utility (sd.ksh) which
         defines two new commands 'sd' and 'ds' (provided these names are not used
         already for other commands or aliases in your namespace) that act as
         replacement for the 'cd' command. You can view the manpage with 'ds -m'
         (or '_sd__man', if the 'ds' name is not available).

                           This message will not be shown again.
         =========================================================================

         View manpage now? (Y/n) "; read -r
         : "${REPLY:=Y}"
         [[ $REPLY == [yY] ]] && _sd__man || printf '%s\n' ''
      else
         failure=1
      fi
   elif [[ ! -d "${SD__LOGDIR}" ]]; then
      printf '%s\n' "
      Startup failure of the SD utility (sd.ksh): configured to use
      '${SD__LOGDIR}' as SD logfile directory but this path denotes a
      non-directory file. Either move the file out of the way or configure a
      different name for the logfile directory by defining SD_CFG[logdir]
      accordingly in your shell resource file."
      failure=1
   fi
   if (( !failure )); then
      if [[ ! -f "${SD__LOGFILE}" ]]; then
         printf '%s\n' "${SD__MAGIC} ($(date))" > "${SD__LOGFILE}" || failure=1
      fi
   fi
   if (( !failure )); then
      _sd__logcheck || failure=1
   fi
   if (( failure )); then
      unset -f _sd__switch _sd__dispatch _sd__choose _sd__clean _sd__info \
         _sd__logappend _sd__logcheck _sd__logread _sd__logwrite _sd__man _sd__match \
         _sd__name _sd__remove _sd__seed _sd__checkshell _sd__stack _sd__wincalc

      unset SD_CFG SD__STATE SD__INTERN
      unset SD__LOGDIR SD__LOGLIM SD__LOGFILE SD__LOCK SD__MAGIC SD__TRPCMD SD__TRPSIG
      return $failure
   else
      if [[ -d "${SD__LOCK}" ]]; then   # should be a stale lock
         find "${SD__LOCK}" -prune -mmin +1 -exec rmdir {} \; 2>/dev/null
      fi
      readonly SD__LOGDIR SD__LOGLIM SD__LOGFILE SD__LOCK SD__MAGIC SD__TRPCMD SD__TRPSIG
      unset -f _sd__checkshell _sd__logcheck
   fi
}

function _sd__logwrite { # ext
   if (( SD_CFG[freeze] )); then
      printf '%s\n' "Logfile not modified -- SD_CFG[freeze]=${SD_CFG[freeze]}.";
      return
   fi
   typeset ext=$1
   : "${ext:=prune}"
   ext+=.bak

   # atomic logfile update to prevent corruption.
   if ! mkdir "${SD__LOCK}" 2>/dev/null; then
      find "${SD__LOCK}" -prune -mmin +1 -exec rmdir {} \; 2>/dev/null
      mkdir "${SD__LOCK}" 2>/dev/null || return
   fi

   typeset IFS=' '   # we need to ensure correct field splitting of SD__TRPSIG into separate signals
   # shellcheck disable=SC2086  # word splitting intended
   set -- ${SD__TRPSIG}
   trap '' "$@"      # deactivate all (non-zero) traps until we are done

   typeset tmpfile="${SD__LOGFILE}_tmp.$$"
   typeset -i stat=1

   if printf '%s\n' "${SD__MAGIC} ($(date))" "${SD__ALL[@]}" >| "$tmpfile"; then
      if [[ -s "$tmpfile" ]]; then
         if [[ -f "${SD__LOGFILE}" ]]; then
            cp -pf "${SD__LOGFILE}" "${SD__LOGFILE}.$ext" 2>/dev/null
         fi
         mv -f "$tmpfile" "${SD__LOGFILE}" && stat=0
      fi
   fi
   (( stat == 1 )) && rm -f "$tmpfile"
   rmdir "${SD__LOCK}" 2>/dev/null

   # Restore exit trap and return.
   # shellcheck disable=SC2064  # trap string intentionally fixed at definition time, not when signalled
   trap "${SD__TRPCMD}" 0 "$@"
   return $stat
}

function _sd__logappend { ## 1/0 (1: called in exit trap)
   if [[ -z $SD__NEW ]] || (( SD_CFG[freeze] )); then
      return
   fi
   typeset -i flag=${1:-0}
   typeset -i retry
   for ((retry = 0; retry < 3; retry++)); do
      if mkdir "${SD__LOCK}" 2>/dev/null; then
         # append-only write, absence of mv/cp should prevent logfile corruption
         # in case we get interrupted.
         printf '%s' "$SD__NEW" >> "${SD__LOGFILE}"
         rmdir "${SD__LOCK}" 2>/dev/null
         SD__NEW=''
         SD__STATE[stamp]=$SECONDS
         (( flag )) && exit 0 || return 0
      fi
      (( retry < 2 )) && sleep "${SD__INTERN[sleep]}"
   done
   # if we get here, we have failed to get lock and can't update db. if this happens in the exit
   # trap we loose the SD__NEW content but logfile will be unharmed. if it happens during ongoing
   # shell session it means we cannot update _now_. we thus do not clear SD__NEW but preserve it for
   # next update attempt.
   (( flag )) && exit 1 || return 1
}

function _sd__logread {
   typeset IFS=$'\n'
   set -f
   SD__ALL=( $(<"${SD__LOGFILE}") )
   set +f
   SD__ALL=("${SD__ALL[@]: 1}")

   typeset -i logsize
   ((logsize = ${#SD__ALL[@]}))
   if (( logsize == 0 )); then
      function _sd__seed {
         typeset maxdepth=1
         typeset -a prunedirs=(-name '.*' ! -name '.')
         set -f
         typeset IFS=$'\n'
         SD__NEW=$(find "$HOME" -maxdepth $maxdepth \( "${prunedirs[@]}" \) -prune -o -type d -print |
                 awk -v home="$HOME" 'NR > 1 {sub(home, "~"); print | "LC_ALL=C sort"}')
         [[ -n $SD__NEW ]] || SD__NEW=$'~'  # ensure at least _one_ entry
         SD__NEW+=$'\n'
         SD__ALL=($SD__NEW)
         set +f
         _sd__logappend
      }
      _sd__seed
      unset -f _sd__seed  # we should never need it again
   fi

   if (( logsize > SD__LOGLIM )); then  # time to prune
      typeset -i prune scale=32
      ((prune = SD__LOGLIM/scale))
      ((logsize = SD__LOGLIM - prune))
      SD__ALL=("${SD__ALL[@]: -$logsize}")
      _sd__logwrite prune
   fi

   (( SD_CFG[stacklim] > 0 )) && _sd__wincalc "${SD_CFG[stacklim]}"
   _sd__stack 1
   SD__NEW=''
}

function _sd__remove {
   typeset check window=${SD_CFG[window]}
   typeset IFS=' '
   typeset pat="$*"

   ((SD_CFG[window] = ${#SD__ALL[@]})) && _sd__stack # expand...
   typeset IFS=$'\n'
   typeset -a dnames=($(_sd__match 1 "$pat"))
   typeset -a astack=($SD__STACK)

   if (( ${#dnames[@]} == 0 )); then
      printf '%s\n' "$pat: No match"
      return
   elif (( ${#dnames[@]} == ${#astack[@]} )); then
      printf '%s\n' "The pattern '$pat' selects your complete history for deletion." \
                     "This looks like a mistake."
      return
   fi

   printf '%s\n' "${dnames[@]}" | nl
   printf 'remove these directory names from history? [y/N] '
   read -r check
   : "${check:=N}"
   if [[ "$check" == y ]]; then
      # we want grep -F to avoid any regex interpretation of names in dnames. the -f
      # flag allows to pass a file of fixed patterns so we use that via the below construct.
      SD__ALL=( $(printf '%s\n' "${SD__ALL[@]}" | grep -F -v -f <(printf '%s\n' "${dnames[@]}")) )
      SD__NEW=''
      _sd__logwrite remove
   fi
   ((SD_CFG[window] = window)) && _sd__stack 1  # ...recompute stack (and reset retry counter)
}

function _sd__clean {
   typeset -a fresh=() stale=()
   typeset dname check

   for dname in "${SD__ALL[@]}"; do
      if [[ -d ${dname/#'~'/$HOME} ]]; then
         fresh+=("$dname")
      else
         stale+=("$dname")
      fi
   done
   if (( ${#stale[@]} > 0 )); then
      # enforcing newline as IFS is mandatory due to the array assignment of unquoted content (the
      # result of the printf|sort pipe). note that "IFS=$'\n' stale=(...)" would _not_ make IFS
      # change transient. this only works for simple commands/assignments, not for a process
      # substitution like here.
      typeset IFS=$'\n'
      stale=( $(printf "%s\n" "${stale[@]}" | LC_ALL=C sort -u) )
      printf '%s\n' "${stale[@]}" | nl
      printf 'eliminate these stale entries from history? [y/N] '
      read -r check
      : "${check:=N}"
      if [[ "$check" == y ]]; then
         SD__ALL=("${fresh[@]}")
         SD__NEW=''
         _sd__stack 1
         _sd__logwrite clean
      fi
   else
      printf '%s\n' 'No stale entries (clean history).'
   fi
}

function _sd__match { ## what(0/1) pat
   typeset IFS=' '
   typeset -i what=$1 downcase=0 nf
   shift
   typeset pat="$*"
   if [[ $pat == ${SD_CFG[prefix]}*([0-9]) ]]; then
      pat=${pat#"${SD_CFG[prefix]}"}
      : "pat${pat:=1}"
      awkpat='NR == ENVIRON["pat"]'
   else
      (( SD_CFG[smartcase] )) && [[ $pat != *[A-Z]* ]] && downcase=1
      (( downcase )) && awkpat='tolower($NF) ~ ENVIRON["pat"]' || awkpat='$NF ~ ENVIRON["pat"]'
   fi
   ((nf = what == 0? 0:4))  # 0: complete line, 4: name only
   printf '%s\n' "$SD__STACK" | pat="$pat" awk -F'\t' -v nf=$nf "$awkpat"' {print $(nf)}'
}

function _sd__info {
   typeset IFS=$'\n'
   typeset top report
   typeset -i stacksize=0 entries=0 newnum=0
   typeset -a ara=()

   entries=${#SD__ALL[@]}
   ara=($SD__NEW) && newnum=${#ara[@]}

   function _sd__dye { ## text (0,1,3-7,30-37)
      typeset text=$1
      typeset -i num=${2:-1}
      typeset off=$'\E[0m'
      typeset on=$'\E['${num}m
      printf '%s' "$on$text$off"
   }

   typeset static='' immu='' space rule1 rule2 ruler1 ruler2
   case "${LC_ALL:-${LC_CTYPE:-${LANG}}}" in
      *UTF-8*|*utf8*|*UTF8*|*utf-8*)
         rule1=$'\u2500'
         rule2=$'\u2550'
         ;;
      *) rule1="-"
         rule2="="
         ;;
   esac
   space=$(printf '%*s' 71 '')
   ruler1=${space// /$rule1}
   ruler2=${space// /$rule2}

   if (( entries > 0 )); then
      ara=($SD__STACK) && stacksize=${#ara[@]}
      top=$(
         header=$(printf '%-8s\t%s\t%s\t%s' score count rank "name (top ten on stack)")
         printf '%s\n' "$(_sd__dye "$header" 1)"
         printf '%s\n' "$ruler1"
         printf '%s\n' "${ara[@]: 0:10}"
      )
   fi

   typeset -a seltxt=('tabular listing' 'index-based selection' 'fzf-based selection')
   typeset -a smrtxt=('Case-sensitive' 'Smartcase')
   typeset -i wd1=${#SD__LOGLIM} wl=${#entries} wd2
   ((wd1 = wd1 > 5? wd1:5))  # for very small loglim (<100) we might get misalignment otherwise
   ((wd1 = wd1 > wl? wd1:wl)) && ((wd1+= 9)) # to account for the color escapes
   ((wd2 = wd1 - 1))  # csi no-color escapes (bold, underline..)

   (( SD_CFG[freeze] )) && immu=$(printf '%s' " $(_sd__dye "(immutable)" 7)")
   (( SD_CFG[dynamic] )) || static=$(printf '%s' "$(_sd__dye "(static)" 7)")

   report+='%s\n'   # $ruler2
   report+="logfile   : %s%s\n"
   report+="loglim    : %*s     Logfile pruning threshold\n"
   report+="history   : %*s     Logged cd actions (%s not yet saved)\n"
   report+="window    : %*s     Trailing window for stack computation\n"
   report+="stacksize : %*s     Directories currently on stack %s\n"
   report+="power     : %*s     Age penalty parameter (0 = no penalty)\n"
   report+="mode      : %*s     'ds [pattern]' uses %s\n"
   report+="verbose   : %*s     Verbosity level [012]\n"
   report+="prefix    : %*s     Prefix for rank-based cd\n"
   report+="smartcase : %*s     %s matching\n"
   report+='%s\n'   # $ruler2
   report+="%s\n\n" # $top

   # shellcheck disable=SC2059  # spurious: report expands to a static format string
   printf "$report" \
      "$ruler2" \
      "$(_sd__dye "${SD__LOGFILE}" 4)" "$immu" \
      "$wd2" "$(_sd__dye "${SD__LOGLIM}" 1)" \
      "$wd1" "$(_sd__dye "${entries}" 31)" "$(_sd__dye "$newnum" 31)" \
      "$wd1" "$(_sd__dye "${SD_CFG[window]}" 32)" \
      "$wd1" "$(_sd__dye "$stacksize" 33)" "$static"\
      "$wd1" "$(_sd__dye "${SD_CFG[power]}" 34)" \
      "$wd1" "$(_sd__dye "${SD_CFG[mode]}" 35)" "$(_sd__dye "${seltxt[${SD_CFG[mode]}]}" 35)" \
      "$wd1" "$(_sd__dye "${SD_CFG[verbose]}" 36)" \
      "$wd2" "$(_sd__dye "${SD_CFG[prefix]}" 1)" \
      "$wd2" "$(_sd__dye "${SD_CFG[smartcase]}" 1)" "$(_sd__dye "${smrtxt[${SD_CFG[smartcase]}]}" 1)" \
      "$ruler2" \
      "$top"

   unset -f _sd__dye
}

function _sd__stack { ## 0/1
   (( ${1:-0} )) && SD__STATE[tries]=1

   typeset -i lognum=${#SD__ALL[@]}
   typeset -i window=${SD_CFG[window]}
   # bash deviates from ksh/zsh regarding ${x[@]: -$num}: if num > len(x), bash
   # returns empty string rather than full array so we have to catch this here:
   ((window = window > lognum? lognum:window))
   SD__STACK=$(
      printf '%s\n' "${SD__ALL[@]: -$window}" |
      awk -F '\t' -v window=$window -v power="${SD_CFG[power]}" '
         BEGIN { OFS = "\t" }
         {
            score[$0] += (NR/window)^power
            freq[$0]  += 1
         }
         END { for (name in score) print score[name], freq[name], name }
      ' | LC_ALL=C sort -k1,1gr -k2,2nr |
      awk -F '\t' '{ printf "%#-8.4g\t%d\t%d\t%s\n", $1, $2, NR, $3 }'
   )
}

function _sd__name {  ## regex
   # zsh separates words in "$@" by first char in global IFS, so we must enforce single blank
   # separation explicitly (in bash/ksh pat="$@" would suffice (for default IFS in zsh, too))
   typeset IFS=' '
   typeset pat="$*"
   typeset lastpat=${SD__STATE[lastpat]}
   typeset tries=${SD__STATE[tries]}
   typeset dname=''

   # --- direct resolution cases ---
   if [[ -z "$pat" ]]; then
      dname="$HOME"
   elif [[ "$pat" == "-" ]]; then
      dname="-"
   elif [[ -d "$pat" ]]; then
      dname="$pat"
   fi

   if [[ -n "$dname" ]]; then
      SD__STATE[fail]=0
      SD__STATE[pick]=0
      lastpat=''
      tries=1

   else
      typeset -i keepgoing=0
      typeset rank awkpat match matches

      # --- numeric prefix selection ---
      if [[ $pat == ${SD_CFG[prefix]}*([0-9]) ]]; then
         # look up by numeric index
         pat=${pat#"${SD_CFG[prefix]}"}
         : "pat${pat:=1}"
         awkpat='NR == ENVIRON["pat"]'
         tries=1
      else
         # look up by regex pattern matching. the dir names are in the last field/column in `SD__STACK'.
         # we use a hybrid aproach for construction of awk script, notably passing $pat via environment
         # since this prevents (shell _and_ awk related) parsing and quoting hell.
         typeset -i downcase=0
         (( SD_CFG[smartcase] )) && [[ $pat != *[A-Z]* ]] && downcase=1

         if (( downcase )); then
            awkpat='tolower($NF) ~ ENVIRON["pat"]'
         else
            awkpat='$NF ~ ENVIRON["pat"]'
         fi

         if [[ $pat == "$lastpat" ]]; then
            # this implements the logic that consecutive `cd' actions with the same regex pattern cycle
            # through the available matches. this necessitates keeping state (in vars `tries' and
            # `lastpat').
            ((tries++))

            rank=$(printf '%s\n' "$SD__STACK" |
               pat="$pat" awk -F'\t' -v tries=$tries "$awkpat"' {
                  if (++count == tries) {
                     print $(NF-1)
                     exit
                  }
               }'
            )

            if [[ -n $rank ]]; then
               typeset patbak="$pat"
               pat=$rank
               awkpat='NR == ENVIRON["pat"]'
               (( SD_CFG[verbose] == 2 )) &&
                  printf '%s\n' "trying match no. $tries" >&2
               ((keepgoing = 1))
            else
               if (( SD_CFG[verbose] >= 1 )); then
                  if (( tries > 2 )); then
                     printf '%s\n' '*** starting over *** ' >&2
                  else
                     printf '%s\n' 'no other match' >&2
                  fi
               fi
               tries=1
            fi
         else
            lastpat=$pat
            tries=1
         fi
      fi

      # --- collect matches ---
      matches=$(printf '%s\n' "$SD__STACK" |
         pat="$pat" awk -F'\t' -v home="$HOME" "$awkpat"' {
            sub(/^~/, home, $NF)
            print $NF
         }')

      SD__STATE[pick]=1

      typeset IFS=$'\n'
      for match in $matches; do
         if [[ -d $match ]]; then
            dname=$match
            break
         else
            ((SD__STATE[pick]++))
         fi
      done

      if [[ -z $dname ]]; then
         ((SD__STATE[fail]++))
         if (( keepgoing == 1 )); then
            dname="$patbak"
         else
            dname="$pat"
            lastpat=''
         fi
      else
         SD__STATE[fail]=0
      fi
   fi
   SD__STATE[dname]="$dname"
   SD__STATE[tries]=$tries
   SD__STATE[lastpat]="$lastpat"
}

function _sd__switch {  ## regex
   typeset IFS=' '
   typeset pat="$*"
   case $pat in
      -h|--help)
         typeset -a msg=()
         msg+=("Usage: [cd|sd] [pattern|pathname|-]. Full documentation: ds -m.")
         msg+=("If you actually meant pattern $pat: cd \\\\$pat.")
         printf '%s\n' "${msg[@]}"
         return;;
   esac
   SD__STATE[fail]=0
   while true; do
      _sd__name "$pat"

      # ------------------------------------------------------------
      # 1. Successful cd on windowed stack
      # ------------------------------------------------------------
      if command cd -- "${SD__STATE[dname]}" 2>/dev/null; then
         break

      # ------------------------------------------------------------
      # 2. cd failed, repeat to surface the error message and return
      # ------------------------------------------------------------
      elif [[ -d "${SD__STATE[dname]}" ]]; then
         command cd -- "${SD__STATE[dname]}" || return

      # ------------------------------------------------------------
      # 3. Handle stale matches during same-pattern cycling
      # ------------------------------------------------------------
      elif (( SD__STATE[pick] > 1 && SD__STATE[fail] > 0 )); then
         if (( SD__STATE[fail] < SD__STATE[pick] - 1 || SD__STATE[tries] > 1 )); then
            (( SD_CFG[verbose] == 2 )) && printf '%s\n' 'stale match' >&2
            continue  # try next matching stack entry
         else
            # only stale matches left
            if (( SD_CFG[verbose] < 2 )); then
               printf '%s\n' 'All matches are stale.' >&2
            elif (( SD_CFG[verbose] == 2 )); then
               typeset IFS=$'\n'
               typeset -a dnames=($(_sd__match 1 "$pat"))
               printf 'Input %s\n' "'$pat' is matched by" >&2
               printf '   "%s"\n' "${dnames[@]}" >&2
               printf '%s\n' 'but no such directory does exist (use ds -c or ds -d if you want to clean up).' >&2
            fi
            return 1
         fi

      # ------------------------------------------------------------
      # 4. Try full stack since windowed stack gave no usable match
      # ------------------------------------------------------------
      elif (( ${#SD__ALL[@]} > SD_CFG[window] )); then
         (( SD_CFG[verbose] == 2 )) && printf '%s' 'No match on windowed stack' >&2
         typeset wstack=$SD__STACK
         typeset -i window=${SD_CFG[window]}
          # expand to full stack
         ((SD_CFG[window] = ${#SD__ALL[@]}))
         _sd__stack
         _sd__name "$pat"
         # restore windowed stack (no need to actually recompute)
         SD__STACK=$wstack
         ((SD_CFG[window] = window))

         # --------------------------------------------------------------------------------
         # A. Successful cd on full stack
         # --------------------------------------------------------------------------------
         if command cd -- "${SD__STATE[dname]}" 2>/dev/null; then
            (( SD_CFG[verbose] == 2 )) && printf '%s\n' ', considering full stack.' >&2
            break

         # --------------------------------------------------------------------------------
         # B. cd failed, repeat to surface the error message and return
         # --------------------------------------------------------------------------------
         elif [[ -d "${SD__STATE[dname]}" ]]; then
            # Repeat cd to surface the error message and return
            (( SD_CFG[verbose] == 2 )) && printf '%s\n' ', considering full stack.' >&2
            command cd -- "${SD__STATE[dname]}" || return

         # --------------------------------------------------------------------------------
         # C. cd to non-existing dir failed, repeat to surface the error message and return
         #    (this is the usual way this failure point is reached).
         # --------------------------------------------------------------------------------
         else
            (( SD_CFG[verbose] == 2 )) && printf '%s\n' ' nor on full stack (or match is stale).' >&2
            command cd -- "${SD__STATE[dname]}" || return
         fi

      # --------------------------------------------------------------------------------
      # 5. cd to non-existing dir failed, repeat to surface the error message and return
      #    (can only be reached if SD_CFG[window] covers full buffered(!) history).
      # --------------------------------------------------------------------------------
      else
         (( SD_CFG[verbose] == 2 )) && printf '%s\n' 'No match on full stack.' >&2
         command cd -- "${SD__STATE[dname]}" || return
      fi
   done

   # Log the new directory if not equal to one of $HOME, $OLDPWD, /. Value of $HOME is replaced
   # by '~' in log entries. Achieving this portably across ksh/bash/zsh requires tilde in a
   # variable: direct use of literal '~' as replacement string works in ksh/bash but not zsh
   # (zsh treats replacement string verbatim including quotes).

   if [[ $PWD != @($HOME|$OLDPWD|/) ]]; then
      typeset entry tilde='~'
      entry="${PWD/#$HOME/$tilde}"
      SD__NEW+="$entry"$'\n'
      SD__ALL+=("$entry")
      (( SD_CFG[dynamic] )) && _sd__stack
   fi
   if (( SECONDS > SD__STATE[stamp] + SD_CFG[period] )); then
      (( SD__INTERN[debug] )) && printf '%s' "$SD__NEW"
      _sd__logappend
   fi
}

function _sd__choose { ## matches
   typeset matches="$1"
   typeset dname
   if (( SD_CFG[mode] == 1 )); then
      typeset -i hits num
      printf '%s\n' "$matches" | awk -F'\t' '
         BEGIN {
            print "rank\tindex\tname"
         }
         {
            print $(NF-1) "\t" NR "\t" $NF
         }' | less -FRX
      printf 'pick index (<CR> = 1; CTRL-D = abort): '
      read -r num || { tput clear; return; }
      tput clear
      hits=$(printf '%s\n' "$matches" | wc -l)
      (( num == 0 )) && ((num = 1))
      if (( num > 0 && num <= hits )); then
         dname=$(printf '%s\n' "$matches" | awk -F'\t' -v num=$num -v home="$HOME" 'NR == num {sub(/^~/, home, $NF); print $NF}')
      fi
   elif (( SD_CFG[mode] == 2 )); then
      # THINK: make fzf options user-settable via further SD_CFG[] entries?
      command -v fzf >/dev/null || { printf '%s\n' 'executable for "fzf" fuzzy finder not found -- do not use mode=2'; return 1; }
      typeset -a opts=()
      opts+=(--preview 'pathname={2..}; LC_ALL=C ls -Al --color=always "${pathname/#~/$HOME}"')
      opts+=(--color 'header:bright-red')
      opts+=(--header 'selected name will be passed to cd')
      opts+=(+s -e -1 --bind 'ctrl-j:accept')
      dname=$(printf '%s\n' "$matches" | awk -F'\t' '{print $NF}' | nl | fzf "${opts[@]}")
      [[ -z $dname ]] && return 2
      dname=$(printf '%s\n' "$dname" | cut -f2)
      dname=${dname/#'~'/$HOME}
   fi
   cd "$dname" || return
}

function _sd__wincalc { ## stacklim
   if (( $# == 0 )); then
      return
   elif [[ $1 == +(0) ]] || (( $1 < 0 )); then # verbatim 0 or numeric < 0: do nothing
      return
   fi
   typeset -i stacklim=$1     # non-digit value: cast to numeric 0
   typeset -i n dircount=0 bufsize=${#SD__ALL[@]}
   typeset key
   typeset -A seen=()
   ((stacklim = stacklim > 0? stacklim:bufsize))
   for ((n = bufsize - 1; n >= 0; n--)); do
      # kept as memo: using "((++seen[$key] > 1)) && continue" to test for "key has been
      # seen" works but imposes a measurable arithmetic overhead (5% in ksh, 20% in bash). the
      # actual number of hits is not relevant here so we can avoid this overhead:
      key=${SD__ALL[n]}
      [[ -n ${seen[$key]+1} ]] && continue
      seen[$key]=1
      (( ++dircount == stacklim )) && break
   done
   ((SD_CFG[window] = n < 0? bufsize:bufsize - n))  #n=-1 happens if loop completes
   ((SD_CFG[stacklim] = dircount))
}

function _sd__dispatch {  ##  [-012Vcd:e:fhik:l:mnopsw] | [-s] [pattern]
   typeset optstring=012Vcd:e:fhik:l:mnopsw
   typeset opt key matches
   typeset -a keys=()
   typeset -A opflag=()
   # NOTE TO SELF: ksh does make OPTIND local automatically but the other shells (bash, zsh) do not.
   # so we explicitly declare OPTIND local. for zsh, it is relevant to also reset to 1 it seems.
   # but zsh getopts exhibits really deviant behaviour if getopts while loop is left via "break" as
   # we have done so far for '-s'. result than even can oscillate between two different states on
   # successive calls: zsh keeps state for getopts internally somehow and we apparently cannot fix it
   # via some "off-by-one" logic. the only solution it seems is to _not_ use "break". in fact early
   # exit from loop via "return" does trigger related issues, notably, the return might be de
   # facto ignored if multiple options are specified and only happens for last specified option.
   # consequence: for zsh's sake the loop now does avoid any early exit, handling of decicion whether
   # to leave the function is postponed now until after the getopts loop.
   typeset OPTIND=1
   while getopts $optstring opt; do
      case $opt in
         [012])
            SD_CFG[mode]=$opt
            ;;
         V)
            printf '%s\n' "${SD__INTERN[version]}"
            ;;
         c)
            _sd__clean
            ;;
         d)
            _sd__remove "$OPTARG"
            ;;
         e)
            if [[ $OPTARG == +([0-9])?(.*([0-9])) ]]; then
               typeset -i maxpow=9999
               (( ${OPTARG%.*} >= maxpow )) && ((OPTARG = maxpow))
               SD_CFG[power]=$OPTARG  # relevant to _not_ use arithmetic context because: bash (OPTARG might equal 2.5, e.g.)
            fi
            ;;
         f)
            _sd__logappend
            _sd__logread
            ;;
         h)
            printf '%s\n' "Usage: ds -[$optstring] [pattern]"
            printf '%s\n' "For full documentation: ds -m"
            ;;
         i)
            :
            ;;
         k)
            _sd__wincalc "$OPTARG"
            ;;
         l)
            typeset window=$OPTARG
            typeset -i lines=${#SD__ALL[@]}
            ((lines = lines > 0 ? lines:1))
            [[ $window == +([0-9]) ]] || window=0
            ((SD_CFG[window] = window > 0? window:lines))
            SD_CFG[stacklim]=0
            ;;
         m)
            _sd__man
            ;;
         n)
            ((SD_CFG[freeze] = 1 - SD_CFG[freeze]))
            ;;
         o)
            ((SD_CFG[dynamic] = 1 - SD_CFG[dynamic]))
            ;;
         p)
            _sd__man pdf
            ;;
         s)
            :
            ;;
         w)
            _sd__logappend
            ;;
         *)
            return 1
      esac
      opflag[$opt]=1
   done
   shift $((OPTIND - 1))

   # shellcheck disable=SC2296  # shellcheck does not handle zsh-specific syntax
   [[ -n ${ZSH_VERSION-} ]] && keys=("${(k)opflag[@]}") || keys=("${!opflag[@]}")
   for key in "${keys[@]}"; do
      [[ $key == [ekl] ]]  && { _sd__stack 1; }
      [[ $key == [eiklno] ]] && { _sd__info; break; }
   done

   if (( $# == 0 )); then
      (( ${#keys[@]} == 0 )) || (( opflag[s] )) || return 0   # a bit opaque: a non-'ds -s' call w/ option but w/o argument must return now
      (( ${#SD__ALL[@]} > 0 )) && matches=$SD__STACK || return 1
   else
      matches=$(_sd__match 0 "$@")
      if [[ -z $matches ]]; then
         printf '%s\n' 'No match' >&2
         return 1
      fi
   fi

   (( opflag[s] )) && matches=$(printf '%s\n' "$matches" | LC_ALL=C sort -k4)
   if (( SD_CFG[mode] == 0 )); then
      {
         printf '%-8s\t%s\t%s\t%s\n' score count rank name
         printf '%s\n' "$matches"
      } | less -FR
   else
      _sd__choose "$matches"
   fi
}

# do this immediately after all functions are defined to ensure that it is done
# even if _sd__setup fails.
if [[ ${KSH_VERSION-} == 'Version AJM'* ]]; then
   eval "$SD__ALIAS_DEFS"
   unset SD__ALIAS_DEFS
elif [[ -n ${BASH_VERSION+x} ]]; then
   (( SD__ALIASES_ON )) && shopt -s expand_aliases
   unset SD__ALIASES_ON
elif [[ -n ${ZSH_VERSION+x} ]]; then
   (( SD__ALIASES_ON )) && setopt aliases
   (( SD__ALIASFD_ON )) && setopt aliasfuncdef
   unset SD__ALIASES_ON SD__ALIASFD_ON
fi
# ===========================================================================================================
typeset -A SD_CFG SD__STATE   # ensure assoc arrays are declared before use (do not init: they might already exist)
typeset -a SD__ALL
typeset SD__STACK SD__NEW
typeset SD__LOGDIR SD__LOGLIM SD__LOGFILE SD__LOCK SD__MAGIC SD__TRPCMD SD__TRPSIG   # to be made readonly soon

if ! _sd__setup; then
   unset -f _sd__setup
   return 1
fi
unset -f _sd__setup

# account for possibility of non-standard user IFS. do not rely on implicit field splitting of
# trpsig when setting the trap.
typeset sd_oldIFS=$IFS
IFS=' '
# shellcheck disable=SC2086  # word splitting intended
# shellcheck disable=SC2064  # trap string intentionally fixed at definition time, not when signalled
trap "${SD__TRPCMD}" 0 ${SD__TRPSIG}
IFS=$sd_oldIFS && unset sd_oldIFS

if ! command -v ds > /dev/null; then
   SD__INTERN[myds]=1 && function ds { _sd__dispatch "$@"; }
fi
if ! command -v sd > /dev/null; then
   SD__INTERN[mysd]=1 && function sd { _sd__switch "$@"; }
fi
if ! typeset -f cd > /dev/null; then   # need typeset -f: bash always returns 0 with +f
   SD__INTERN[mycd]=1 && function cd { _sd__switch "$@"; }
fi
if ! command -v sdset > /dev/null; then
   SD__INTERN[mysdset]=1 && alias sdset='set | grep -Ev "^(declare -[-a] )?SD__(ALL|NEW|STACK)"'
fi

_sd__logread
