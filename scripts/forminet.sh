#!/bin/bash

PROG="norminette"

COLOR_OK="\033[32m"
COLOR_ERR="\033[31m"
COLOR_RESET="\033[0m"

if ! command -v "$PROG" >/dev/null 2>&1; then
	echo "Error: $PROG not found in PATH" >&2
	exit 127
fi



"$PROG" -R CheckForbiddenSourceHeader "$@" | \
awk -v okC="$COLOR_OK" -v errC="$COLOR_ERR" -v rstC="$COLOR_RESET" '
BEGIN {
    max_len_path = 0
}

# Capture filename when we see ": Error!"
/: Error!/ {
    file_name = $1
    sub(/:$/, "", file_name)
    next
}

# Capture detailed error lines
/^Error:/ {
    line_num = $4; sub(/,/, "", line_num)
    col_num  = $6; sub(/\):/, "", col_num)
    msg = ""
    for (i = 7; i <= NF; i++) msg = msg $i " "
    sub(/[ \t]+$/, "", msg)

    path = file_name ":" line_num ":" col_num

    if (length(path) > max_len_path)
        max_len_path = length(path)

    errors[path] = msg
    next
}

# Capture OK lines
/: OK!/ {
    oks[NR] = $0
    next
}

END {
    # Print OK messages in green
    for (i in oks)
        printf("%s%s%s\n", okC, oks[i], rstC)

    # Print errors in red, nicely aligned
    for (p in errors)
        printf("%s%-*s %s%s\n", errC, max_len_path, p, errors[p], rstC)
}
'

