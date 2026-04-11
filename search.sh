#!/bin/bash

# =================================================================
# THE GREAT ALEXANDER - ADVANCED SEARCH ENGINE (V2)
# =================================================================

mode="$1"
query_raw="$2"

# --- Helper: Normalize String ---
# Sadece küçük harfe çevirir ve gereksiz boşlukları temizler. 
# Eskisi gibi tüm karakterleri silmiyoruz ki nokta ve tireler (bundle id'ler) korunsun.
normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | xargs
}

query="$(normalize "$query_raw")"

# --- Global Found List ---
declare -a found_items

# --- Safety: Protected Paths ---
is_protected() {
    local item="$1"
    local protected_roots=(
        "/System" "/usr" "/bin" "/sbin" "/etc" "/var" "/private"
        "/Library/Apple" "/Library/System" "/Library/Audio"
        "/Applications/Safari.app" "/Applications/Utilities"
        "/Applications/App Store.app" "/Applications/Finder.app"
    )
    
    for root in "${protected_roots[@]}"; do
        if [[ "$item" == "$root" || "$item" == "$root/"* ]]; then
            return 0
        fi
    done
    return 1
}

# =================================================================
# MODE 1: APPLICATION MODE (High Precision)
# =================================================================
if [[ "$mode" == "1" ]]; then
    echo "[LOG] Identifying main application bundles..." >&2
    
    # 1. Önce ana .app paketlerini bulalım
    app_bundles=()
    search_locations=(
        "/Applications"
        "/System/Applications"
        "$HOME/Applications"
    )

    for loc in "${search_locations[@]}"; do
        [[ -d "$loc" ]] || continue
        # Tam eşleşme veya başlangıç eşleşmesi arıyoruz
        while IFS= read -r app_path; do
            app_name="$(basename "$app_path" .app)"
            norm_app_name="$(normalize "$app_name")"
            
            # Sadece uygulama ismi sorguyu içeriyorsa alıyoruz (daha güvenli)
            if [[ "$norm_app_name" == *"$query"* ]]; then
                app_bundles+=("$app_path")
                found_items+=("$app_path")
            fi
        done < <(find "$loc" -maxdepth 2 -name "*.app" 2>/dev/null)
    done

    # 2. Bulunan bundle'ların ID'lerini çıkarıp sistem genelinde iz sürelim
    for bundle in "${app_bundles[@]}"; do
        info_plist="$bundle/Contents/Info.plist"
        if [[ -f "$info_plist" ]]; then
            bundle_id=$(defaults read "$info_plist" CFBundleIdentifier 2>/dev/null)
            if [[ -n "$bundle_id" ]]; then
                echo "[LOG] Deep scanning for Bundle ID: $bundle_id" >&2
                
                # Metadata araması (en hızlı ve kesin yol)
                while IFS= read -r path; do
                    found_items+=("$path")
                done < <(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null)
                
                # Klasik kütüphane yolları (Bundle ID ile)
                lib_paths=(
                    "$HOME/Library/Application Support/$bundle_id"
                    "$HOME/Library/Caches/$bundle_id"
                    "$HOME/Library/Caches/$(echo "$bundle_id" | tr '[:upper:]' '[:lower:]')"
                    "$HOME/Library/Preferences/$bundle_id.plist"
                    "$HOME/Library/Containers/$bundle_id"
                    "$HOME/Library/Group Containers/$bundle_id"
                    "$HOME/Library/Saved Application State/$bundle_id.savedState"
                    "$HOME/Library/Logs/$bundle_id"
                    "$HOME/Library/WebKit/$bundle_id"
                    "/Library/Application Support/$bundle_id"
                    "/Library/Caches/$bundle_id"
                    "/Library/Preferences/$bundle_id.plist"
                )
                for lp in "${lib_paths[@]}"; do
                    [[ -e "$lp" ]] && found_items+=("$lp")
                done
            fi
        fi
    done

    # 3. İsim bazlı kütüphane taraması (Sadece spesifik yerlerde)
    # Bu aşamada "Spot" ararsak "Hotspot" bulmaması için regex kullanıyoruz.
    echo "[LOG] Scanning library for named traces..." >&2
    lib_search_dirs=(
        "$HOME/Library/Application Support"
        "$HOME/Library/Caches"
        "$HOME/Library/Logs"
        "/Library/Application Support"
    )
    for lsd in "${lib_search_dirs[@]}"; do
        [[ -d "$lsd" ]] || continue
        # Kelime sınırları içinde aramayı simüle ediyoruz (grep -i)
        while IFS= read -r path; do
            found_items+=("$path")
        done < <(find "$lsd" -maxdepth 2 -iname "*$query*" 2>/dev/null)
    done

# =================================================================
# MODE 2: FILE/FOLDER MODE (Path Based)
# =================================================================
elif [[ "$mode" == "2" ]]; then
    echo "[LOG] Searching for files/folders matching: $query" >&2
    
    # Doğrudan kullanıcı alanlarında mdfind kullanımı (hızlı)
    while IFS= read -r path; do
        found_items+=("$path")
    done < <(mdfind -name "$query" 2>/dev/null)

    # Eğer query bir path ise doğrudan ekle
    if [[ -e "$query_raw" ]]; then
        found_items+=("$query_raw")
    fi
fi

# =================================================================
# CLEANUP & OUTPUT
# =================================================================

# Duplicate'leri temizle, korunan yolları filtrele ve exist kontrolü yap
printf '%s\n' "${found_items[@]}" | sort -u | while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    if [[ -e "$item" ]] && ! is_protected "$item"; then
        # Son bir güvenlik: Sadece dosya veya klasörse (device vs değilse) yazdır
        if [[ -f "$item" || -d "$item" ]]; then
            echo "$item"
        fi
    fi
done
