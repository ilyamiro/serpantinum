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

# Update ~/.config/<dir> from compositors/<comp>/ of new_commit on an update.
# Unedited files (byte-identical to the old commit's version) are replaced,
# missing ones are added, edited ones are kept and appended to
# COMPOSITOR_EDITED_FILES. A symlinked or missing ~/.config/<dir> is never
# written to (symlinked: differing files are listed as edited).
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

    local rel dest
    local -A in_new=()
    for rel in "${new_files[@]}"; do
        in_new["$rel"]=1
        [[ "$rel" == custom/* ]] && continue
        dest="$cfg/$rel"
        if [ "$new_from_git" != true ] && [ ! -f "$src_dir/$rel" ]; then
            continue
        fi

        if [ "$base_is_link" = true ]; then
            if [ -e "$dest" ] || [ -L "$dest" ]; then
                cmp -s <(_new_content "$rel") "$dest" || COMPOSITOR_EDITED_FILES+=("$dest")
            fi
            continue
        fi
        if ! config_path_is_real "$cfg" "$rel"; then
            COMPOSITOR_EDITED_FILES+=("$dest")
            continue
        fi
        if [ ! -e "$dest" ]; then
            mkdir -p "$(dirname "$dest")"
            _new_content "$rel" > "$dest" || continue
            [ -n "${is_exec[$rel]:-}" ] && chmod +x "$dest"
            continue
        fi
        cmp -s <(_new_content "$rel") "$dest" && continue
        if [ "$old_usable" = true ] && git -C "$repo_root" cat-file -e "$old_commit:$prefix$rel" 2>/dev/null \
            && cmp -s <(git -C "$repo_root" show "$old_commit:$prefix$rel") "$dest"; then
            _new_content "$rel" > "$dest"
        else
            COMPOSITOR_EDITED_FILES+=("$dest")
        fi
    done

    # Files that upstream deleted
    local parent
    for rel in "${old_files[@]}"; do
        [[ "$rel" == custom/* ]] && continue
        [ -n "${in_new[$rel]:-}" ] && continue
        dest="$cfg/$rel"
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        if [ "$base_is_link" = false ] && config_path_is_real "$cfg" "$rel" \
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
    unset -f _new_content
    return 0
}
