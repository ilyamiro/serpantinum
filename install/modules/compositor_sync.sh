#!/usr/bin/env bash
# Prune and refresh logic for deployed compositor configs.
# Functions only (plus the COMPOSITOR_EDITED_FILES list), safe to source.

COMPOSITOR_EDITED_FILES=()

# 0 when neither <base>/<rel> nor any folder between <base> and it is a symlink.
config_path_is_real() {
    local base="$1" rel="$2"
    local cur="$base" part
    local IFS='/'
    local -a parts
    read -r -a parts <<< "$rel"
    for part in "${parts[@]}"; do
        [ -z "$part" ] && continue
        cur="$cur/$part"
        [ -L "$cur" ] && return 1
    done
    return 0
}

# First line of compositors/hyprland/config/custom.lua; it marks the helper as ours.
HYPR_CUSTOM_HELPER_MARKER="-- serpantinum: custom overrides helper"

# hypr_custom_helper_is_ours <hypr config dir>: 0 when <dir>/config/custom.lua is a
# regular file reached without symlinks whose first line is the helper marker.
hypr_custom_helper_is_ours() {
    local f="$1/config/custom.lua" first=""
    config_path_is_real "$1" config/custom.lua || return 1
    [ -f "$f" ] && [ -r "$f" ] || return 1
    IFS= read -r first < "$f" || [ -n "$first" ] || return 1
    first="${first%$'\r'}"
    [ "$first" = "$HYPR_CUSTOM_HELPER_MARKER" ]
}

# Remove files in target_dir that are not in src_dir, then empty folders.
# Never descends into <target_dir>/custom.
prune_compositor_dir() {
    local target_dir="${1%/}" src_dir="${2%/}"
    [ -d "$target_dir" ] || return 0

    local dest_file rel_path
    while IFS= read -r dest_file; do
        rel_path="${dest_file#"$target_dir"/}"
        if [ ! -e "$src_dir/$rel_path" ] && [ ! -L "$src_dir/$rel_path" ]; then
            rm -f "$dest_file"
        fi
    done < <(find "$target_dir" \( -path "$target_dir/custom" -prune \) -o \( -type f -o -type l \) -print)

    find "$target_dir" -depth -type d -empty ! -path "$target_dir" \
        ! -path "$target_dir/custom" ! -path "$target_dir/custom/*" -delete 2>/dev/null || true
}

# Update ~/.config/<dir> from compositors/<comp>/ of new_commit on an update.
# Unedited files (byte-identical to the old commit's version) are replaced,
# missing ones are added, edited ones are kept and appended to
# COMPOSITOR_EDITED_FILES. A symlinked or missing ~/.config/<dir> is never
# written to (symlinked: differing files are listed as edited). A file that
# can't be written is kept and listed; the function never fails. Hyprland's
# hyprland.lua is only written when config/custom.lua is our helper
# (hypr_custom_helper_is_ours), since the new one requires it.
refresh_compositor_defaults() {
    local repo_root="$1" old_commit="$2" new_commit="$3" comp="$4"
    local src_dir="$repo_root/compositors/$comp"

    local dir_name
    dir_name=$(get_compositor_config_dir_name "$comp")
    local cfg="$HOME/.config/$dir_name"
    local prefix="compositors/$comp/"

    if [ ! -d "$cfg" ] && [ ! -L "$cfg" ]; then
        return 0
    fi
    local base_is_link=false
    [ -L "$cfg" ] && base_is_link=true

    local is_git=false
    [ -d "$repo_root/.git" ] && is_git=true

    local old_usable=false
    if [ "$is_git" = true ] && [ -n "$old_commit" ] && [ "$old_commit" != "unknown" ] \
        && git -C "$repo_root" cat-file -e "$old_commit^{commit}" 2>/dev/null; then
        old_usable=true
    fi
    local new_from_git=false
    if [ "$is_git" = true ] && [ -n "$new_commit" ] && [ "$new_commit" != "unknown" ] \
        && git -C "$repo_root" cat-file -e "$new_commit^{commit}" 2>/dev/null; then
        new_from_git=true
    fi

    local -a new_files=() old_files=()
    local -A is_exec=()
    local f meta
    if [ "$new_from_git" = true ]; then
        while IFS= read -r -d '' f; do
            meta="${f%%$'\t'*}"
            f="${f#*$'\t'}"
            new_files+=("${f#"$prefix"}")
            [ "${meta%% *}" = "100755" ] && is_exec["${f#"$prefix"}"]=1
        done < <(git -C "$repo_root" ls-tree -r -z "$new_commit" -- "$prefix")
    elif [ -d "$src_dir" ]; then
        while IFS= read -r -d '' f; do
            new_files+=("${f#"$src_dir"/}")
        done < <(find "$src_dir" -type f -print0)
    fi
    if [ "$old_usable" = true ]; then
        while IFS= read -r -d '' f; do
            old_files+=("${f#"$prefix"}")
        done < <(git -C "$repo_root" ls-tree -r -z --name-only "$old_commit" -- "$prefix")
    fi

    # Prints the shipped content of a file; fails if it is unavailable.
    _new_content() {
        if [ "$new_from_git" = true ]; then
            git -C "$repo_root" show "$new_commit:$prefix$1"
        else
            cat "$src_dir/$1"
        fi
    }

    # _write_new <rel> <dest>: write the shipped content of <rel> to <dest> through
    # a temp file in the same folder. On any failure <dest> is left as it was,
    # listed as edited, and the function still returns 0 (the installer runs
    # with set -e).
    _write_new() {
        local wrel="$1" wdest="$2" wtmp mode
        if [ -e "$wdest" ] && [ ! -w "$wdest" ]; then
            COMPOSITOR_EDITED_FILES+=("$wdest")
            return 0
        fi
        mkdir -p "$(dirname "$wdest")" 2>/dev/null \
            && wtmp="$(mktemp "$(dirname "$wdest")/.serpantinum.XXXXXX" 2>/dev/null)" \
            || { COMPOSITOR_EDITED_FILES+=("$wdest"); return 0; }
        if [ -e "$wdest" ]; then
            chmod --reference="$wdest" "$wtmp" 2>/dev/null || true
        else
            mode="$(printf '%o' $(( 0666 & ~0$(umask) )))"
            chmod "$mode" "$wtmp" 2>/dev/null || true
            if [ -n "${is_exec[$wrel]:-}" ]; then chmod +x "$wtmp" 2>/dev/null || true; fi
        fi
        if _new_content "$wrel" > "$wtmp" 2>/dev/null && mv -f "$wtmp" "$wdest" 2>/dev/null; then
            return 0
        fi
        rm -f "$wtmp" 2>/dev/null || true
        COMPOSITOR_EDITED_FILES+=("$wdest")
        return 0
    }

    # _refresh_one <rel>: replace, add or keep (and list) one shipped file.
    # With HOLD_WRITES=1 the file is kept and listed instead of being written.
    _refresh_one() {
        local rel="$1" dest="$cfg/$1"
        if [ "$new_from_git" != true ] && [ ! -f "$src_dir/$rel" ]; then
            return 0
        fi

        if [ "$base_is_link" = true ]; then
            if [ -e "$dest" ] || [ -L "$dest" ]; then
                cmp -s <(_new_content "$rel") "$dest" || COMPOSITOR_EDITED_FILES+=("$dest")
            fi
            return 0
        fi
        if ! config_path_is_real "$cfg" "$rel"; then
            COMPOSITOR_EDITED_FILES+=("$dest")
            return 0
        fi
        if [ ! -e "$dest" ]; then
            if [ "${HOLD_WRITES:-0}" = 1 ]; then
                COMPOSITOR_EDITED_FILES+=("$dest")
            else
                _write_new "$rel" "$dest"
            fi
            return 0
        fi
        cmp -s <(_new_content "$rel") "$dest" && return 0
        if [ "${HOLD_WRITES:-0}" != 1 ] && [ "$old_usable" = true ] \
            && git -C "$repo_root" cat-file -e "$old_commit:$prefix$rel" 2>/dev/null \
            && cmp -s <(git -C "$repo_root" show "$old_commit:$prefix$rel") "$dest"; then
            _write_new "$rel" "$dest"
        else
            COMPOSITOR_EDITED_FILES+=("$dest")
        fi
        return 0
    }

    local rel dest hypr_main=""
    local -A in_new=()
    for rel in "${new_files[@]}"; do
        in_new["$rel"]=1
        [[ "$rel" == custom/* ]] && continue
        # hyprland.lua requires config/custom.lua, so it is handled last, once
        # we know whether that helper is ours.
        if [ "$comp" = hyprland ] && [ "$rel" = hyprland.lua ]; then
            hypr_main="$rel"
            continue
        fi
        _refresh_one "$rel"
    done
    if [ -n "$hypr_main" ]; then
        if hypr_custom_helper_is_ours "$cfg"; then
            _refresh_one "$hypr_main"
        else
            HOLD_WRITES=1 _refresh_one "$hypr_main"
        fi
    fi

    # Files that upstream deleted
    local parent
    for rel in "${old_files[@]}"; do
        [[ "$rel" == custom/* ]] && continue
        [ -n "${in_new[$rel]:-}" ] && continue
        dest="$cfg/$rel"
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        if [ "$base_is_link" = false ] && config_path_is_real "$cfg" "$rel" \
            && cmp -s <(git -C "$repo_root" show "$old_commit:$prefix$rel") "$dest"; then
            if ! rm -f "$dest" 2>/dev/null || [ -e "$dest" ] || [ -L "$dest" ]; then
                COMPOSITOR_EDITED_FILES+=("$dest")
                continue
            fi
            parent="$(dirname "$dest")"
            while [ "$parent" != "$cfg" ] && rmdir "$parent" 2>/dev/null; do
                parent="$(dirname "$parent")"
            done
        else
            COMPOSITOR_EDITED_FILES+=("$dest")
        fi
    done
    unset -f _new_content _write_new _refresh_one
    return 0
}
