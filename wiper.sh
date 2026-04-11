#!/bin/bash

secure_wipe() {
    local target="$1"

    if [[ -f "$target" ]]; then
        local file_size
        file_size=$(stat -f%z "$target" 2>/dev/null)

        if [[ "$file_size" -gt 0 ]]; then
            local key iv tmp_file
            key=$(openssl rand -hex 32)
            iv=$(openssl rand -hex 16)
            tmp_file="${target}.wipe_tmp"

            openssl enc -aes-256-cbc -K "$key" -iv "$iv" \
                -in "$target" -out "$tmp_file" 2>/dev/null

            if [[ -f "$tmp_file" ]]; then
                cat "$tmp_file" > "$target" 2>/dev/null
                rm -f "$tmp_file"
            fi

            unset key iv
        fi

        local random_name dir_path
        random_name=$(openssl rand -hex 8)
        dir_path=$(dirname "$target")
        mv "$target" "$dir_path/$random_name" 2>/dev/null
        rm -f "$dir_path/$random_name"
        echo "[✓] Wiped: $target"

    elif [[ -d "$target" ]]; then
        while IFS= read -r file; do
            secure_wipe "$file"
        done < <(find "$target" -type f 2>/dev/null)

        rm -rf "$target"
        echo "[✓] Removed dir: $target"
    fi
}

echo "================================================================="
echo "  INITIATING SECURE WIPE"
echo "================================================================="
echo ""

wipe_count=0
fail_count=0

while IFS= read -r item; do
    [[ -z "$item" ]] && continue
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
echo "  Wiped and fucked  : $wipe_count items"
echo "  Skipped: $fail_count items (already missing)"
echo "================================================================="
echo ""