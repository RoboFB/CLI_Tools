#!/bin/bash

# Folder containing your script files
SCRIPTS_DIR="./scripts"   # change this to your path
BIN_DIR="./build"
PARAMETER_IS_VALID=0

# Collect all script and bin files
files=()
for file in "$SCRIPTS_DIR"/* "$BIN_DIR"/*; do
    [ -f "$file" ] && files+=("$file")
done

# Check if any files found
if [ ${#files[@]} -eq 0 ]; then
    echo "No scripts found in $SCRIPTS_DIR or $BIN_DIR"
    exit 1
fi

# If a number argument is given
if [ -n "$1" ]; then
    choice="$1"
    # Validate input
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#files[@]} ]; then
        PARAMETER_IS_VALID=1
    else
        echo "Invalid script number: $choice"
        PARAMETER_IS_VALID=0
    fi
fi

# If no valid parameter, show interactive selection
if [ "$PARAMETER_IS_VALID" -eq 0 ]; then
    echo "Available scripts in $SCRIPTS_DIR and $BIN_DIR:"
    i=1
    for f in "${files[@]}"; do
        echo "$i) $(basename "$f")"
        ((i++))
    done
    read -p "Select a script by number: " choice
    # Validate input
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#files[@]} ]; then
        echo "Invalid selection."
        exit 1
    fi
fi

# Run the selected script
SELECTED_FILE="${files[$((choice-1))]}"
echo "Running script: $(basename "$SELECTED_FILE")"
echo "----------------------------------------"
$SELECTED_FILE
