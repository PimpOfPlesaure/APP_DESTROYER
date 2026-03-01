#!/bin/bash

mode="$1"
prompt="$2"

# --- Normalizasyon ---
query="$(sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "$prompt" | tr '[:upper:]' '[:lower:]' | tr -s ' ')"

norm_it() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g'
}

piece="$(norm_it "$query")"

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

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r path; do
            norm_name="$(norm_it "$(basename "$path")")"
            [[ "$norm_name" == *"$piece"* ]] && found_items+=("$path")
        done < <(find "$dir" -maxdepth 3 2>/dev/null)
    done

    bundle_ids=()
    for path in "${found_items[@]}"; do
        if [[ "$path" == *.app ]]; then
            info_plist="$path/Contents/Info.plist"
            if bundle_id=$(defaults read "$info_plist" CFBundleIdentifier 2>/dev/null); then
                bundle_ids+=("$bundle_id")
                echo "[LOG] Found app: $path" >&2
                echo "[LOG] Bundle ID: $bundle_id" >&2
            fi
        fi
    done

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

    for dir in "${file_search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r path; do
            norm_name="$(norm_it "$(basename "$path")")"
            [[ "$norm_name" == *"$piece"* ]] && found_items+=("$path")
        done < <(find "$dir" -maxdepth 5 2>/dev/null)
    done

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
            [[ "$norm_name" == *"$piece"* ]] && found_items+=("$path")
        done < <(find "$dir" -maxdepth 4 2>/dev/null)
    done

    while IFS= read -r path; do
        found_items+=("$path")
    done < <(mdfind "$query" -onlyin "$HOME" 2>/dev/null)

fi

# =================================================================
# Deduplicate + Safety Filter → stdout'a yaz
# =================================================================

protected_paths=(
    "/System" "/usr" "/bin" "/sbin" "/etc" "/var"
    "/private/var" "/private/etc" "/cores" "/dev" "/opt"
)

is_protected() {
    local item="$1"
    for protected in "${protected_paths[@]}"; do
        if [[ "$item" == "$protected" || "$item" == "$protected/"* ]]; then
            return 0
        fi
    done
    return 1
}

printf '%s\n' "${found_items[@]}" | sort -u | while IFS= read -r item; do
    if ! is_protected "$item"; then
        echo "$item"
    fi
done