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

# Update ~/.config/<dir> from <repo_root>/compositors/<comp>/ on an update.
# Unedited files (byte-identical to the old commit's version) are replaced,
# missing ones are added, edited ones are kept and appended to
# COMPOSITOR_EDITED_FILES.
refresh_compositor_defaults() {
    local repo_root="$1" old_commit="$2" comp="$3"
    local src_dir="$repo_root/compositors/$comp"
    [ -d "$src_dir" ] || return 0

    local dir_name
    dir_name=$(get_compositor_config_dir_name "$comp")
    local cfg="$HOME/.config/$dir_name"
    local prefix="compositors/$comp/"

    local old_usable=false
    if [ -n "$old_commit" ] && [ "$old_commit" != "unknown" ] && [ -d "$repo_root/.git" ] \
        && git -C "$repo_root" cat-file -e "$old_commit^{commit}" 2>/dev/null; then
        old_usable=true
    fi

    local -a new_files=() old_files=()
    local f
    if [ -d "$repo_root/.git" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && new_files+=("${f#"$prefix"}")
        done < <(git -C "$repo_root" ls-files "$prefix")
    fi
    if [ ${#new_files[@]} -eq 0 ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && new_files+=("${f#"$src_dir"/}")
        done < <(find "$src_dir" -type f)
    fi
    if [ "$old_usable" = true ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && old_files+=("${f#"$prefix"}")
        done < <(git -C "$repo_root" ls-tree -r --name-only "$old_commit" -- "$prefix")
    fi

    local rel dest
    declare -A is_new=()
    for rel in "${new_files[@]}"; do
        is_new["$rel"]=1
        [[ "$rel" == custom/* ]] && continue
        dest="$cfg/$rel"

        if ! config_path_is_real "$cfg" "$rel"; then
            COMPOSITOR_EDITED_FILES+=("$dest")
            continue
        fi
        if [ ! -e "$dest" ]; then
            mkdir -p "$(dirname "$dest")"
            cp -p "$src_dir/$rel" "$dest"
            continue
        fi
        cmp -s "$src_dir/$rel" "$dest" && continue
        if [ "$old_usable" = true ] && git -C "$repo_root" cat-file -e "$old_commit:$prefix$rel" 2>/dev/null \
            && cmp -s <(git -C "$repo_root" show "$old_commit:$prefix$rel") "$dest"; then
            cp -p "$src_dir/$rel" "$dest"
        else
            COMPOSITOR_EDITED_FILES+=("$dest")
        fi
    done

    # Files that upstream deleted
    local parent
    for rel in "${old_files[@]}"; do
        [[ "$rel" == custom/* ]] && continue
        [ -n "${is_new[$rel]:-}" ] && continue
        dest="$cfg/$rel"
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        if config_path_is_real "$cfg" "$rel" \
            && cmp -s <(git -C "$repo_root" show "$old_commit:$prefix$rel") "$dest"; then
            rm -f "$dest"
            parent="$(dirname "$dest")"
            while [ "$parent" != "$cfg" ] && rmdir "$parent" 2>/dev/null; do
                parent="$(dirname "$parent")"
            done
        else
            COMPOSITOR_EDITED_FILES+=("$dest")
        fi
    done
    return 0
}
