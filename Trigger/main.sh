#!/bin/bash

# Argümanları Python'dan al
mode="$1"
prompt="$2"
confirm="$3"

# --- Input Control ---
if [[ -z "$mode" || -z "$prompt" ]]; then
    echo "Usage: bash alexander.sh <mode> <query> <confirm>"
    exit 1
fi

# --- Normalizasyon ---
query="$(
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "$prompt" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -s ' '
)"

norm_it() {
    echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]//g'
}

piece="$(norm_it "$query")"

echo ""
echo "[✓] Searching for: '$query'"
echo ""

found_items=()

# =================================================================
# MOD 1 — APPLICATION MODE
# =================================================================
if [[ "$mode" == "1" ]]; then

    search_dirs=(
        "/Applications"
        "/Applications/Utilities"
        "/System/Applications"
        "/System/Applications/Utilities"
        "$HOME/Applications"
        "$HOME/Library/Application Support"
        "$HOME/Library/Preferences"
        "$HOME/Library/Caches"
        "$HOME/Library/Logs"
        "$HOME/Library/Containers"
        "$HOME/Library/Group Containers"
        "$HOME/Library/Saved Application State"
        "$HOME/Library/LaunchAgents"
        "/Library/Application Support"
        "/Library/Preferences"
        "/Library/Caches"
        "/Library/Logs"
        "/Library/Extensions"
        "/Library/LaunchAgents"
        "/Library/LaunchDaemons"
    )

    echo "[*] Scanning directories..."
    echo ""

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r path; do
            norm_name="$(norm_it "$(basename "$path")")"
            if [[ "$norm_name" == *"$piece"* ]]; then
                found_items+=("$path")
            fi
        done < <(find "$dir" -maxdepth 3 2>/dev/null)
    done

    # --- Bundle ID Tespiti ---
    bundle_ids=()

    for path in "${found_items[@]}"; do
        if [[ "$path" == *.app ]]; then
            info_plist="$path/Contents/Info.plist"
            if bundle_id=$(defaults read "$info_plist" CFBundleIdentifier 2>/dev/null); then
                bundle_ids+=("$bundle_id")
                echo "[✓] Found app: $path"
                echo "[✓] Bundle ID: $bundle_id"
                echo ""
            fi
        fi
    done

    # --- mdfind ile Derin Tarama ---
    echo "[*] Running deep scan with mdfind..."
    echo ""

    for bundle_id in "${bundle_ids[@]}"; do
        while IFS= read -r path; do
            found_items+=("$path")
        done < <(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null)

        while IFS= read -r path; do
            found_items+=("$path")
        done < <(mdfind "$bundle_id" 2>/dev/null)
    done

    while IFS= read -r path; do
        found_items+=("$path")
    done < <(mdfind "$query" -onlyin "$HOME/Library" 2>/dev/null)

# =================================================================
# MOD 2 — FILE/FOLDER MODE
# =================================================================
elif [[ "$mode" == "2" ]]; then

    file_search_dirs=(
        "$HOME/Desktop"
        "$HOME/Documents"
        "$HOME/Downloads"
        "$HOME/Movies"
        "$HOME/Music"
        "$HOME/Pictures"
        "$HOME"
    )

    echo "[*] Scanning for file/folder..."
    echo ""

    for dir in "${file_search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r path; do
            norm_name="$(norm_it "$(basename "$path")")"
            if [[ "$norm_name" == *"$piece"* ]]; then
                found_items+=("$path")
                echo "[✓] Found target: $path"
            fi
        done < <(find "$dir" -maxdepth 5 2>/dev/null)
    done

    echo ""
    echo "[*] Scanning for related cache and log traces..."
    echo ""

    cache_dirs=(
        "$HOME/Library/Caches"
        "$HOME/Library/Logs"
        "$HOME/Library/Application Support"
        "$HOME/Library/Saved Application State"
        "$HOME/Library/Containers"
        "$HOME/Library/Group Containers"
        "/Library/Caches"
        "/Library/Logs"
    )

    for dir in "${cache_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r path; do
            norm_name="$(norm_it "$(basename "$path")")"
            if [[ "$norm_name" == *"$piece"* ]]; then
                found_items+=("$path")
                echo "[✓] Found trace: $path"
            fi
        done < <(find "$dir" -maxdepth 4 2>/dev/null)
    done

    echo ""
    echo "[*] Running deep scan with mdfind..."
    echo ""

    while IFS= read -r path; do
        found_items+=("$path")
    done < <(mdfind "$query" -onlyin "$HOME" 2>/dev/null)

fi

# =================================================================
# ORTAK — Deduplicate + Safety Filter + Preview
# =================================================================

# --- Deduplicate ---
unique_items=()

while IFS= read -r item; do
    unique_items+=("$item")
done < <(printf '%s\n' "${found_items[@]}" | sort -u)

echo "[✓] Discovery complete. Found ${#unique_items[@]} items."
echo ""

echo "[*] Found items:"
echo ""
for item in "${unique_items[@]}"; do
    echo "  $item"
done
echo ""

# --- Safety Filter ---
safe_items=()
rejected_items=()

protected_paths=(
    "/System"
    "/usr"
    "/bin"
    "/sbin"
    "/etc"
    "/var"
    "/private/var"
    "/private/etc"
    "/cores"
    "/dev"
    "/opt"
)

for item in "${unique_items[@]}"; do
    is_protected=0
    for protected in "${protected_paths[@]}"; do
        if [[ "$item" == "$protected" || "$item" == "$protected/"* ]]; then
            is_protected=1
            rejected_items+=("$item")
            break
        fi
    done
    if [[ $is_protected -eq 0 ]]; then
        safe_items+=("$item")
    fi
done

echo "[✓] Safety filter complete."
echo ""

if [[ ${#rejected_items[@]} -gt 0 ]]; then
    echo "[!] Protected paths skipped (${#rejected_items[@]} items):"
    for item in "${rejected_items[@]}"; do
        echo "    SKIPPED: $item"
    done
    echo ""
fi

echo "[✓] Items cleared for deletion (${#safe_items[@]} items):"
echo ""
for item in "${safe_items[@]}"; do
    echo "    $item"
done
echo ""

# --- Preview ---
echo "================================================================="
echo "  ITEMS SCHEDULED FOR PERMANENT DELETION"
echo "================================================================="
echo ""

total_size=0

for item in "${safe_items[@]}"; do
    if [[ -e "$item" ]]; then
        size=$(du -sk "$item" 2>/dev/null | awk '{print $1}')
        total_size=$((total_size + size))
        printf "  [%.1f MB] %s\n" "$(echo "scale=1; $size/1024" | bc)" "$item"
    fi
done

echo ""
echo "================================================================="
printf "  TOTAL SIZE: %.2f MB\n" "$(echo "scale=2; $total_size/1024" | bc)"
echo "================================================================="
echo ""

# --- DRYRUN kontrolü ---
if [[ "$confirm" != "CONFIRM" ]]; then
    exit 0
fi

echo "[✓] Confirmed. Initiating secure wipe..."
echo ""

# --- Secure Wipe Function ---
secure_wipe() {
    local target="$1"

    if [[ -f "$target" ]]; then
        file_size=$(stat -f%z "$target" 2>/dev/null)

        if [[ "$file_size" -gt 0 ]]; then
            key=$(openssl rand -hex 32)
            iv=$(openssl rand -hex 16)
            tmp_file="${target}.wipe_tmp"

            openssl enc -aes-256-cbc -K "$key" -iv "$iv" \
                -in "$target" -out "$tmp_file" 2>/dev/null

            if [[ -f "$tmp_file" ]]; then
                cat "$tmp_file" > "$target" 2>/dev/null
                rm -f "$tmp_file"
            fi

            unset key
            unset iv
        fi

        random_name=$(openssl rand -hex 8)
        dir_path=$(dirname "$target")
        mv "$target" "$dir_path/$random_name" 2>/dev/null
        rm -f "$dir_path/$random_name"
        echo "  [✓] Wiped: $target"

    elif [[ -d "$target" ]]; then
        while IFS= read -r file; do
            secure_wipe "$file"
        done < <(find "$target" -type f 2>/dev/null)

        rm -rf "$target"
        echo "  [✓] Removed dir: $target"
    fi
}

# --- Wipe Başlat ---
echo "================================================================="
echo "  INITIATING SECURE WIPE"
echo "================================================================="
echo ""

wipe_count=0
fail_count=0

for item in "${safe_items[@]}"; do
    if [[ -e "$item" ]]; then
        secure_wipe "$item"
        ((wipe_count++))
    else
        echo "  [!] Already gone: $item"
        ((fail_count++))
    fi
done

echo ""
echo "================================================================="
echo "  WIPE COMPLETE"
echo "  Wiped  : $wipe_count items"
echo "  Skipped: $fail_count items (already missing)"
echo "================================================================="
echo ""

