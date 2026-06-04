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
   typeset -a formatter=(groff -man) pager=(less -R) offon=('off' 'on')
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
.TH SD 1 "May 09, 2026"
.nh
.SH NAME
sd \- switch between directories using a dynamic directory stack
.SH SYNOPSIS
.SY sd
.RI [ pattern | pathname | \- ]
.LP
.SY ds
.OP \-012Vcfhimnoprw
|
.OP \-d pat
|
.OP \-e p
|
.OP \-k K
|
.OP \-l N
|
.OP \-s
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
.IR pattern .
When multiple directories match, the highest scoring match is selected. This
enables reaching desired locations even with highly unspecific patterns.
.B sd
.I [pathname|\-]
behaves identical to the
.B cd
builtin (pathname interpretation takes precedence over pattern matching).
Directories become available for pattern matching once visited via the
.B sd
or
.B cd
command using a pathname argument.
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
Clean up logfile/history by removing stale entries. This will also affect
entries pointing to locations on temporarily unmounted file systems/drives.
If such entries need to be retained, do not use this option.
.TP
.BI \-d " pat"
Delete entries matching pattern
.I pat
from logfile/history.
.TP
.BI \-e " p"
Set the age-penalty parameter of the convolution kernel. Higher values decrease
relevance of older visits. Fractional values allowed. Current value:
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
This also ensures invariant rank order on the stack which sometimes might be
desirable. Current state:
.BR ${offon[SD_CFG[dynamic]]} .
.TP
.B \-p
Send PDF version of manpage to stdout.
.TP
.B \-r
Show score and rank info for present working directory.
.TP
.B \-s
.B "ds -s
.RI [ pattern ]
displays matches sorted alphabetically rather than by rank.
.TP
.B \-w
Write newly visited directories to logfile immediately.
.TP
.B \-y
Show recent directory visits (trailing segment of the recorded history).
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
.IR \- ,
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
.IR  =1 .
Note:
.B zsh
users must quote the equal sign.
.LP
The
.B ds
command serves two purposes. With an option, it acts as a configuration,
management, and inspection interface. As
.B ds
.IR pattern ,
it provides interactive selection from matching stack entries. If
.I pattern
is empty, the full stack is displayed.
.LP
By default,
if
.B fzf
is available and multiple matches exist,
.B ds
.I pattern
opens the
.B fzf
interface
(mode
.BR 2 ).
If
.B ds
.I pattern
yields a unique match, cd executes immediately.
.B fzf
is non-standard and may require separate installation. By default,
.B fzf
displays the stack bottom-up (highest ranking match at bottom), with
the entry initially selected being the one
.B sd
.I pattern
would have chosen. Selection is done at the fzf prompt or via mouse (see
.BR fzf (1)).
Selecting a stale entry in fzf will fail, whereas
.B sd
.I pattern
attempts to find another valid match (see next section).
.LP
Detailed behaviour of
.B fzf
is user-configurable via the associative array
.B SD_FZF
(see
.IR CUSTOMIZATION ).
.LP
If
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
.BR SD_CFG[period] ,
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
.LP
In concurrent multi-shell use, logfile ordering is not guaranteed to be strictly
chronological unless
.B SD_CFG[period]=0
is set. In practice this rarely affects ranking noticeably.
.LP
Note:
.B SD
uses a shell EXIT/HUP/TERM trap to trigger logfile updates on shell termination
(see
.IR INITIAL\ SETUP ).
During logfile updates, SD temporarily ignores INT and QUIT signals to protect
against interruption. After the update, the default signal handling for these
signals is restored.
.SS
Limitations
.LP
Due to the internal use of tab-separated fields for stack representation,
directory names containing tab characters are not supported. Such paths may
lead to incorrect matching or display behaviour and should be avoided.
.
.
.SH SHELL VARIABLES AND FUNCTIONS
.LP
User-visible internal functions follow the naming scheme
.BR _sd__funcname .
User-visible internal variables follow
.BR SD__VARNAME .
The associative arrays
.B SD_CFG
and
.B SD_FZF
hold configuration information. Default behaviour can be changed by modifying
these arrays in your shell rc file (see
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
.SS "SD behaviour
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
.RB ( ** )
take effect only during startup and are ignored if modified later:
.LP
.EX
typeset \-A SD_CFG=(
   [logdir]=${SD__LOGDIR}${pad[logdir]} # absolute path to logfile directory (\fB**\fP)
   [loglim]=${SD__LOGLIM}${pad[loglim]} # max. cd actions in logfile (\fB**\fP)

   [dynamic]=${SD_CFG[dynamic]}${pad[dynamic]} # auto-update stack after each cd?
   [freeze]=${SD_CFG[freeze]}${pad[freeze]} # freeze logfile? (usually: don't)
   [kernel]=${SD_CFG[kernel]}${pad[kernel]} # kernel type (0: power law, 1: exponential)
   [mode]=${SD_CFG[mode]}${pad[mode]} # controls behaviour of \fBds \fIpattern\fR
   [period]=${SD_CFG[period]}${pad[period]} # flush delay period in seconds
   [power]=${SD_CFG[power]}${pad[power]} # age-penalty parameter
   [prefix]='${SD_CFG[prefix]}'${pad[prefix]} # prefix char for \fBcd \fI=num\fR actions
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
.BR kernel ,
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
.SS "fzf behaviour
.LP
.B fzf
behaviour is customized via the associative array
.BR SD_FZF ,
using long option names (without the leading
.BR -- )
as keys. Options that do not take a value are specified in
.B SD_FZF
with an empty value, for example:
.LP
.EX
typeset -A SD_FZF=(
   [cycle]=''
   [tmux]='center,80%,border-native'
)
.EE
.LP
User-defined entries in
.B SD_FZF
may be set either before or after sourcing
.B sd.ksh
(in the latter case, use
.I SD_FZF+=(...)
instead of
.I SD_FZF=(...)
to add new keys to those already set by
.BR sd.ksh )
and generally override
internal defaults. The only exception is the default definition
.BR SD_FZF[exact]='' .
To disable the
.B --exact
option, unset the entry
.I after
sourcing
.BR sd.ksh :
.LP
.EX
unset SD_FZF[exact]
.EE
.LP
The options
.B --preview
and
.B --no-sort
are set internally by
.B SD
and cannot be overridden via
.BR SD_FZF .
No dedicated
.B ds
options exist for modifying
.BR SD_FZF ;
transient changes may be made by editing the array directly. The current
configuration can be inspected with
.BR "typeset -p SD_FZF.
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
"attention span". Example: ~40 cd/day with window width 1200 corresponds to ~30
days of history. Logfile size determines available "long-term memory".
.LP
A score F ("frecency") is computed for each distinct directory
.I i
encountered in the window:
.LP
.EX
   F[i] = sum_n{i} K[N \- n{i}]
.EE
.LP
where the sum runs over all event indices
.I n{i}
involving directory
.IR i ,
and K[j] is an aging kernel assigning a weight to events of age j=N\-n (j=0 for
the most recent event, j=N\-1 for the oldest). Formally, F[i] represents the
convolution (T{i} * K)[N] of a time series T{i}[n] (value 1 at positions
.IR n{i} ,
zero elsewhere) with the kernel K, evaluated at position N.
.LP
The default kernel is exponential:
.LP
.EX
   K[j] = exp(\-p*j/N)
.EE
.LP
The alternative (legacy) kernel (SD_CFG[kernel]=0) is a power law:
.LP
.EX
   K[j] = (1\-j/N)^p
.EE
.LP
In both cases p controls the rate of decay with age; larger p assigns less weight
to older events. Both kernels share K[0]=1, so each new visit contributes an
increment of 1 to the directory's score. The exponential kernel provides exact
preservation of relative stack order for non\-visited directories between
successive cd events, the only exception being score adjustments due to window
truncation which can occasionally affect lower-ranked entries where scores are
closest in magnitude. The legacy power\-law kernel only approximately preserves
order between events, making the exponential the preferred default for
deterministic cycling over repeated same\-pattern invocations.
.LP
Directories i=1,...,I are sorted by score F[i], yielding the dynamic directory
stack queried by
.B sd
and
.BR ds .
With each further event (changed directory except / and \$HOME), the window
advances one tick, computation repeats, and the stack updates.
.LP
Note: K[0]=1 independent of kernel choice and parameters. This provides an
intuitive way to appreciate the effect of p by examining stack scores with
.BR "ds \-0" :
adjusting p controls where a first\-time visit initially appears on the stack.
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
array definition to customize behaviour (see
.IR CUSTOMIZATION ).
.LP
.B SD
installs a shell EXIT/HUP/TERM trap to ensure logfile updates on shell
termination. This overrides any existing custom trap definitions for these
signals in the current shell: if you rely on custom trap handlers, ensure that
they are reinstalled after sourcing
.IR sd.ksh ,
and incorporate the SD trap command
.B ${SD__TRPCMD}
into your own handler.
.LP
At first use, the logfile is seeded with non-hidden toplevel directories in
\$HOME (emulating a single visit to each in alphabetical order) to provide a
starting point. Subsequently, the logfile reflects actual cd activities.
During early use, scores are uniformly low and ranking reflects little history.
The stack stabilises meaningfully \- both in size and in rank order \- after a few
days of normal cd activity.
.LP
To handle naming collisions with existing commands or aliases, redefine the
wrapper functions in your rc file after sourcing sd.ksh, using non-colliding
names:
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
The
.B GLOB_SUBST
option
.I must not
be enabled.
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

   # now set the prospective readonly variables. doing this in the following way allows repeated
   # sourcing (this issue is only relevant when setting SD__INTERN[debug] != 0 due to the added
   # initial SD__INTERN[loaded] check and early-return):

   # ATTENTION: this only works for ksh93 and bash but not for zsh where 2nd source _will_ fail (root
   # cause: zsh applies readonly check to ":=" assignment no matter what).
   : "${SD__LOGDIR:=${SD_CFG[logdir]}}"
   : "${SD__LOGLIM:=${SD_CFG[loglim]}}"
   : "${SD__LOGFILE:="${SD__LOGDIR}/dirv"}"
   : "${SD__LOCK:="${SD__LOGDIR}/_sd.lockdir"}"
   : "${SD__MAGIC:="## sd: log of visited directories (keep this line) ##"}"
   : "${SD__TRPCMD:="typeset -f _sd__logappend > /dev/null && _sd__logappend 1"}"

   # assign [logdir] and [loglim] keys to reflect the actually operational values (which might differ
   # if we are sourcing a 2nd time and user has modified these two CFG keys in the meantime). they
   # are subsequently ignored by sd. they are only updated to ensure that SD_CFG[@] is reflecting
   # the actually used settings.
   SD_CFG[logdir]=${SD__LOGDIR}
   SD_CFG[loglim]=${SD__LOGLIM}

   # now set the other SD_CFG keys (do this before the failure tests block since on first use user is
   # offered to view manpage immediately -- and the manpage reports the values).
   typeset -i mode
   typeset -i window=1280
   command -v fzf >/dev/null
   ((mode = $? == 0? 2:1))
   : "${SD_CFG[dynamic]:="1"}"
   : "${SD_CFG[freeze]:="0"}"
   : "${SD_CFG[kernel]:="1"}"
   : "${SD_CFG[mode]:="$mode"}"
   : "${SD_CFG[period]:="3600"}"
   : "${SD_CFG[power]:="10"}"
   : "${SD_CFG[prefix]:="="}"
   : "${SD_CFG[smartcase]:="1"}"
   : "${SD_CFG[stacklim]:="0"}"
   : "${SD_CFG[verbose]:="1"}"
   : "${SD_CFG[window]:="$window"}"

   # some selective config validity checks
   [[ ${SD_CFG[kernel]} == [01] ]] || SD_CFG[kernel]=1
   [[ ${SD_CFG[prefix]} == [=:,+?] ]] || SD_CFG[prefix]='='
   [[ ${SD_CFG[window]} != [1-9]*([0-9]) ]] && SD_CFG[window]="$window"

   : "${SD_FZF[bind]:="ctrl-j:accept"}"
   : "${SD_FZF[color]:="header:bright-red"}"
   : "${SD_FZF[exact]:=""}"
   : "${SD_FZF[header]:="selected name will be passed to cd"}"
   : "${SD_FZF[layout]:="default"}"
   : "${SD_FZF[preview-window]:="top,38%"}"

   : "${SD__STATE[dname]:="$PWD"}"
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
   : "${SD__INTERN[version]:="3.3.3"}"

   : "${SD__STACK:=""}"
   : "${SD__NEW:=""}"

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
         =============================================================
         This is a reminder that you are now using the SD utility
         (sd.ksh) which defines two new commands 'sd' and 'ds'
         (provided these names are not used already for other commands
         or aliases in your namespace) that act as replacement for the
         'cd' command. You can view the manpage with 'ds -m' (or
         '_sd__man', if the 'ds' name is not available).

                     This message will not be shown again.
         =============================================================

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

      unset SD_CFG SD_FZF SD__STATE SD__INTERN SD__STACK SD__NEW
      unset SD__LOGDIR SD__LOGLIM SD__LOGFILE SD__LOCK SD__MAGIC SD__TRPCMD
      return $failure
   else
      if [[ -d "${SD__LOCK}" ]]; then   # should be a stale lock
         find "${SD__LOCK}" -prune -mmin +1 -exec rmdir {} \; 2>/dev/null
      fi
      readonly SD__LOGDIR SD__LOGLIM SD__LOGFILE SD__LOCK SD__MAGIC SD__TRPCMD
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

   trap '' HUP TERM # deactivate these traps until we are done

   typeset tmpfile="${SD__LOGFILE}_tmp.$$"
   typeset -i stat=1

   if printf '%s\n' "${SD__MAGIC} ($(date))" "${SD__ALL[@]}" >| "$tmpfile"; then
      if [[ -s "$tmpfile" ]]; then
         if [[ -f "${SD__LOGFILE}" ]]; then
            cp -pf "${SD__LOGFILE}" "${SD__LOGFILE}.$ext" 2>/dev/null
         fi
         if mv -f "$tmpfile" "${SD__LOGFILE}"; then
            stat=0
            SD__NEW=''
            SD__STATE[stamp]=$SECONDS
         fi
      fi
   fi
   (( stat == 1 )) && rm -f "$tmpfile"
   rmdir "${SD__LOCK}" 2>/dev/null

   # Restore exit trap and return.
   # shellcheck disable=SC2064  # trap string intentionally fixed at definition time, not when signalled
   trap "${SD__TRPCMD}" EXIT HUP TERM
   return $stat
}

function _sd__logappend { ## 1/0 (1: called in exit trap)
   if [[ -z $SD__NEW ]] || (( SD_CFG[freeze] )); then
      return
   fi
   trap '' HUP INT QUIT TERM
   typeset -i flag=${1:-0}
   typeset -i retry maxretry=3
   for ((retry = 1; retry <= maxretry; retry++)); do
      if mkdir "${SD__LOCK}" 2>/dev/null; then
         # append-only write, absence of mv/cp should prevent logfile corruption
         # in case we get interrupted.
         printf '%s' "$SD__NEW" >> "${SD__LOGFILE}"
         rmdir "${SD__LOCK}" 2>/dev/null
         SD__NEW=''
         SD__STATE[stamp]=$SECONDS
         trap - HUP INT QUIT TERM
         # shellcheck disable=SC2064  # trap string intentionally fixed at definition time, not when signalled
         trap "${SD__TRPCMD}" EXIT HUP TERM
         (( flag )) && exit 0 || return 0
      fi
      (( retry < maxretry )) && sleep "${SD__INTERN[sleep]}"
   done
   # if we get here, we have failed to get lock and can't update db. if this happens in the exit
   # trap we loose the SD__NEW content but logfile will be unharmed. if it happens during ongoing
   # shell session it means we cannot update _now_. we thus do not clear SD__NEW but preserve it for
   # next update attempt.
   trap - HUP INT QUIT TERM
   # shellcheck disable=SC2064  # trap string intentionally fixed at definition time, not when signalled
   trap "${SD__TRPCMD}" EXIT HUP TERM
   (( flag )) && exit 1 || return 1
}

function _sd__logread {
   typeset IFS=$'\n'
   set -o noglob
   SD__ALL=( $(<"${SD__LOGFILE}") )
   set +o noglob
   SD__ALL=("${SD__ALL[@]: 1}")

   typeset -i lognum
   ((lognum = ${#SD__ALL[@]}))
   if (( lognum == 0 )); then
      function _sd__seed {
         typeset maxdepth=1
         typeset -a prunedirs=(-name '.*' ! -name '.')
         typeset IFS=$'\n'
         SD__NEW=$(find "$HOME" -maxdepth $maxdepth \( "${prunedirs[@]}" \) -prune -o -type d -print |
                 awk -v home="$HOME" 'NR > 1 {sub(home, "~"); print | "LC_ALL=C sort"}')
         [[ -n $SD__NEW ]] || SD__NEW=$'~'  # ensure at least _one_ entry
         SD__NEW+=$'\n'
         set -o noglob
         SD__ALL=($SD__NEW)
         set +o noglob
         _sd__logappend
      }
      _sd__seed
      unset -f _sd__seed  # we should never need it again
   fi

   if (( lognum > SD__LOGLIM )); then  # time to prune
      typeset -i prune scale=32
      ((prune = SD__LOGLIM/scale))
      ((lognum = SD__LOGLIM - prune))
      SD__ALL=("${SD__ALL[@]: -$lognum}")
      _sd__logwrite prune
   fi

   (( SD_CFG[stacklim] > 0 )) && _sd__wincalc "${SD_CFG[stacklim]}"
   _sd__stack 1
}

function _sd__remove {
   # need to sync SD__ALL with logfile before rewriting the logfile after tidy up
   # in order to avoid loss of entries possibly added by other shell instances in
   # the meantime. note that _sd__logread triggers '_sd__stack 1' internally and
   # thus resets same-pattern cycling.
   _sd__logappend
   _sd__logread

   typeset -i window
   typeset check
   typeset IFS=' '
   typeset pat="$*"

   ((window = SD_CFG[window]))
   ((SD_CFG[window] = ${#SD__ALL[@]})) && _sd__stack

   typeset IFS=$'\n'
   set -o noglob
   typeset -a dnames=($(_sd__match 1 "$pat"))
   typeset -a astack=($SD__STACK)
   set +o noglob

   if (( ${#dnames[@]} == 0 )); then
      printf '%s\n' "$pat: No match"
   elif (( ${#dnames[@]} == ${#astack[@]} )); then
      printf '%s\n' "The pattern '$pat' selects your complete history for deletion." \
                     "This looks like a mistake."
   else
      printf '%s\n' "${dnames[@]}" | LC_ALL=C sort | nl
      printf 'remove these directory names from history? [y/N] '
      read -r check
      : "${check:=N}"
      if [[ "$check" == y ]]; then
         # we want grep -F to avoid any regex interpretation of names in dnames. the -f
         # flag allows to pass a file of fixed patterns so we use that via the below construct.
         set -o noglob
         SD__ALL=( $(printf '%s\n' "${SD__ALL[@]}" | grep -F -v -f <(printf '%s\n' "${dnames[@]}")) )
         set +o noglob
         _sd__logwrite remove
      fi
   fi
   ((SD_CFG[window] = window)) && _sd__stack 1
}

function _sd__clean {
   # see comment in _sd__remove
   _sd__logappend
   _sd__logread

   typeset -a fresh=() stale=()
   typeset dname check

   for dname in "${SD__ALL[@]}"; do
      if [[ -d ${dname/#\~/$HOME} ]]; then
         fresh+=("$dname")
      else
         stale+=("$dname")
      fi
   done
   if (( ${#stale[@]} > 0 )); then
      printf '%s\n' "${stale[@]}" | LC_ALL=C sort -u | nl
      printf 'eliminate these stale entries from history? [y/N] '
      read -r check
      : "${check:=N}"
      if [[ "$check" == y ]]; then
         SD__ALL=("${fresh[@]}")
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
   typeset top report ttgtxt power
   typeset -i stacksize=0 lognum=0 newnum=0 ttg
   typeset -a ara=()

   power=$(printf '%.4g' "${SD_CFG[power]}")

   lognum=${#SD__ALL[@]}
   set -o noglob
   ara=($SD__NEW) && newnum=${#ara[@]}
   set +o noglob

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

   if (( lognum > 0 )); then
      set -o noglob
      ara=($SD__STACK) && stacksize=${#ara[@]}
      set +o noglob
      top=$(
         header=$(printf '%-8s\t%s\t%s\t%s' score count rank "name (top ten on stack)")
         printf '%s\n' "$(_sd__dye "$header" 1)"
         printf '%s\n' "$ruler1"
         printf '%s\n' "${ara[@]: 0:10}" |
            awk '{buf[NR] = $0} END {while (NR) print buf[NR--]}'
      )
   fi

   typeset -a seltxt=('tabular listing' 'index-based selection' 'fzf-based selection')
   typeset -a smrtxt=('Case-sensitive' 'Smartcase')
   typeset -a algtxt=('Power law' 'Exponential')
   typeset -i wd1=${#SD__LOGLIM} wl=${#lognum} wd2
   ((wd1 = wd1 > 5? wd1:5))  # for very small loglim (<100) we might get misalignment otherwise
   ((wd1 = wd1 > wl? wd1:wl)) && ((wd1+= 9)) # to account for the color escapes
   ((wd2 = wd1 - 1))  # csi no-color escapes (bold, underline..)

   (( SD_CFG[freeze] )) && immu=$(printf '%s' " $(_sd__dye "(immutable)" 7)")
   (( SD_CFG[dynamic] )) || static=$(printf '%s' "$(_sd__dye "(static)" 7)")
   ((ttg = SD__STATE[stamp] + SD_CFG[period] - SECONDS))
   if (( ttg >= 0 )); then
      ttgtxt="$(_sd__dye "$ttg" 34) seconds remaining"
   else
      ttgtxt="expired $(_sd__dye "$((-ttg))" 31) seconds ago"
   fi

   report+='%s\n'   # $ruler2
   report+="logfile   : %s%s\n"
   report+="loglim    : %*s     Logfile pruning threshold\n"
   report+="history   : %*s     Recorded events (%s not yet flushed to disk)\n"
   report+="period    : %*s     Flush delay (%s)\n"
   report+="window    : %*s     Trailing window for stack computation\n"
   report+="stacksize : %*s     Directories currently on stack %s\n"
   report+="power     : %*s     Age penalty parameter (0 = no penalty)\n"
   report+="kernel    : %*s     %s aging kernel\n"
   report+="mode      : %*s     'ds [pattern]' provides %s\n"
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
      "$wd1" "$(_sd__dye "${lognum}" 31)" "$(_sd__dye "$newnum" 31)" \
      "$wd1" "$(_sd__dye "${SD_CFG[period]}" 36)" "$ttgtxt" \
      "$wd1" "$(_sd__dye "${SD_CFG[window]}" 32)" \
      "$wd1" "$(_sd__dye "$stacksize" 33)" "$static"\
      "$wd1" "$(_sd__dye "$power" 34)" \
      "$wd1" "$(_sd__dye "${SD_CFG[kernel]}" 35)" "$(_sd__dye "${algtxt[${SD_CFG[kernel]}]}" 35)" \
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
   typeset -i window=${SD_CFG[window]} effwin
   # effwin: actual number of events used for scoring (min. of configured window and available
   # history). 'power' is scaled proportionally so that the per-event decay fraction remains equal
   # to 'p/window' regardless of how full the log is, ensuring consistent kernel behaviour during
   # early use.
   ((effwin = (window > lognum) ? lognum:window))
   SD__STACK=$(
      printf '%s\n' "${SD__ALL[@]: -$effwin}" |
      awk -F '\t' -v window=$window -v effwin=$effwin -v power="${SD_CFG[power]}" -v kernel="${SD_CFG[kernel]}" '
         BEGIN { OFS = "\t"; power = power * effwin/window }
         {
            score[$0] += (kernel == 0) ? (NR/effwin)^power : exp(-power*(1-NR/effwin))
            freq[$0]  += 1
         }
         END { for (name in score) print score[name], freq[name], name }
      ' 2> /dev/null | LC_ALL=C sort -k1,1gr -k2,2nr |
      awk -F '\t' '{ printf "%#-8.6g\t%d\t%d\t%s\n", $1, $2, NR, $3 }'
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
               if (( SD_CFG[verbose] > 0 )); then
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
      set -o noglob
      for match in $matches; do
         if [[ -d $match ]]; then
            dname=$match
            break
         else
            ((SD__STATE[pick]++))
         fi
      done
      set +o noglob

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
               set -o noglob
               typeset -a dnames=($(_sd__match 1 "$pat"))
               set +o noglob
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

   # Log the new directory if not equal to one of $HOME, $OLDPWD, /. Value of $HOME is replaced by
   # a tilde character in log entries. Achieving this portably across ksh/bash/zsh requires a bit
   # care. best solution: avoid double quoting rhs and use \~ (which would tolerate additional
   # double quoting) rather than single quoting '~' (which would lead to issues in zsh in the
   # presencee of double quoting the value).

   if [[ $PWD != @($HOME|$OLDPWD|/) ]]; then
      typeset entry=${PWD/#$HOME/\~}
      SD__NEW+="$entry"$'\n'
      SD__ALL+=("$entry")
      (( SD_CFG[dynamic] )) && _sd__stack
   fi
   if (( SECONDS > SD__STATE[stamp] + SD_CFG[period] )); then
      _sd__logappend
   fi
}

function _sd__choose { ## matches
   typeset matches="$1"
   typeset dname

   # bypass interactive selection if only one match
   if [[ $matches != *$'\n'* ]]; then
      dname=${matches##*$'\t'}

   elif (( SD_CFG[mode] == 1 )); then
      typeset -i idx nrow
      printf '%s\n' "$matches" |
         awk -F'\t' '{buf[NR] = NR "\t" $NF} END {while (NR) print buf[NR--]}'
      printf 'pick index (<CR> = 1; CTRL-D = abort): '
      read -r idx || { tput clear; return; }
      ((idx = idx == 0? 1:idx))
      nrow=$(printf '%s\n' "$matches" | wc -l)
      (( idx < 1 || idx > nrow )) && return

      dname=$(printf '%s\n' "$matches" | awk -F'\t' -v idx=$idx 'NR == idx {print $NF}')

   elif (( SD_CFG[mode] == 2 )); then
      if ! command -v fzf >/dev/null; then
         printf '%s\n' 'executable for "fzf" fuzzy finder not found -- do not use mode=2'
         return 1
      fi
      typeset -a keys=() opts=()
      typeset key
      # shellcheck disable=SC2296  # shellcheck does not handle zsh-specific syntax
      [[ -n ${ZSH_VERSION-} ]] && keys=("${(k)SD_FZF[@]}") || keys=("${!SD_FZF[@]}")
      for key in "${keys[@]}"; do
         opts+=("--$key")
         [[ -n ${SD_FZF[$key]} ]] && opts+=("${SD_FZF[$key]}")
      done
      opts+=(--no-sort)
      opts+=(--preview 'pathname={2..}; LC_ALL=C ls -Al --color=always "${pathname/#~/$HOME}"')

      dname=$(printf '%s\n' "$matches" | awk -F'\t' '{print $NF}' | nl | fzf "${opts[@]}" | cut -f2)
      [[ -z $dname ]] && return 2
   fi
   cd "${dname/#\~/$HOME}" || return
}

function _sd__wincalc { ## stacklim
   if (( $# == 0 )); then
      return
   elif [[ $1 == +(0) ]] || (( $1 < 0 )); then # verbatim 0 or numeric < 0: do nothing
      return
   fi
   typeset -i stacklim=$1     # non-digit value: cast to numeric 0
   typeset -i n dircount=0 lognum=${#SD__ALL[@]}
   typeset key
   typeset -A seen=()
   ((stacklim = stacklim > 0? stacklim:lognum))
   for ((n = lognum - 1; n >= 0; n--)); do
      # kept as memo: using "((++seen[$key] > 1)) && continue" to test for "key has been
      # seen" works but imposes a measurable arithmetic overhead (5% in ksh, 20% in bash). the
      # actual number of hits is not relevant here so we can avoid this overhead:
      key=${SD__ALL[n]}
      [[ -n ${seen[$key]+1} ]] && continue
      seen[$key]=1
      (( ++dircount == stacklim )) && break
   done
   ((SD_CFG[window] = n < 0? lognum:lognum - n))  #n=-1 happens if loop completes
   ((SD_CFG[stacklim] = dircount))
}

function _sd__dispatch {  ##  [-012Vcd:e:fhik:l:mnopsw] | [-s] [pattern]
   typeset optstring=012Vcd:e:fhik:l:mnoprswy
   typeset opt matches
   typeset -i showinfo=0
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
      opflag[$opt]=1
      case $opt in
         [012])
            SD_CFG[mode]=$opt
            ;;
         V)
            printf '%s\n' "SD v${SD__INTERN[version]}"
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
            ;;
         k)
            _sd__wincalc "$OPTARG"
            ;;
         l)
            typeset window=$OPTARG
            typeset -i lognum=${#SD__ALL[@]}
            ((lognum = lognum > 0 ? lognum:1))
            [[ $window == +([0-9]) ]] || window=0
            ((SD_CFG[window] = window > 0? window:lognum))
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
         r)
            if [[ $PWD == @($HOME|/) ]]; then
               printf '%s\n' "'$HOME' and '/' are not tracked by SD"
            else
               printf '%s\n' "$SD__STACK" |
                  pat=${PWD/#$HOME/\~} awk -F'\t' '
                     $4 == ENVIRON["pat"] {
                        gsub(/ *$/, "", $1)
                        printf("%s: score %s (rank %s)\n", ENVIRON["pat"], $1, $3)
                        exit
                     }
                  '
            fi
            ;;
         s)
            ;;
         w)
            _sd__logappend
            ;;
         y)
            typeset -i nrow=$(($(tput lines) - 2))
            typeset -i lognum=${#SD__ALL[@]}
            ((nrow = nrow > lognum? lognum:nrow))  # again: only bash needs this measure
            printf '%s\n' "${SD__ALL[@]: -$nrow}" | nl -v $((lognum - nrow + 1))
            ;;
         *)
            return 1
      esac
   done
   shift $((OPTIND - 1))

   # shellcheck disable=SC2296  # shellcheck does not handle zsh-specific syntax
   [[ -n ${ZSH_VERSION-} ]] && keys=("${(k)opflag[@]}") || keys=("${!opflag[@]}")

   [[ ${keys[*]} == *[ino]* ]] && showinfo=1
   if [[ ${keys[*]} == *[ekl]* ]]; then
      (( SD_CFG[verbose] > 0 )) && showinfo=1
      _sd__stack 1
   fi
   (( showinfo )) && _sd__info

   if (( ${#keys[@]} > 0 )) && (( !opflag[s] )); then
      return
   elif (( $# == 0 )); then
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
      printf '%s\n' "$matches" |
         awk '{buf[NR] = $0} END {while (NR) print buf[NR--]}'
      printf '%-8s\t%s\t%s\n' score count rank
   else
      _sd__choose "$matches"
   fi
}

# restore immediately after all functions are defined to ensure that it is done
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
typeset -A SD_CFG SD_FZF SD__STATE   # ensure assoc arrays are declared before use (don't init: they might already exist)
typeset -a SD__ALL
typeset SD__STACK SD__NEW
typeset SD__LOGDIR SD__LOGLIM SD__LOGFILE SD__LOCK SD__MAGIC SD__TRPCMD # to be made readonly soon

if ! _sd__setup; then
   unset -f _sd__setup
   return 1
fi
unset -f _sd__setup

# set the logfile-update trap to be executed when the shell is terminating.
# shellcheck disable=SC2064  # trap string intentionally fixed at definition time, not when signalled
trap "${SD__TRPCMD}" EXIT HUP TERM

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
