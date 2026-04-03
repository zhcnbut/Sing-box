#!/bin/bash

domain_init_store() {
    domain_custom_file="$is_sh_dir/domain_custom.list"
    domain_disabled_file="$is_sh_dir/domain_disabled.list"
    domain_health_file="$is_sh_dir/domain_health.cache"
    domain_recent_file="$is_sh_dir/domain_recent.list"

    mkdir -p "$is_sh_dir"
    [[ -f $domain_custom_file ]] || : >"$domain_custom_file"
    [[ -f $domain_disabled_file ]] || : >"$domain_disabled_file"
    [[ -f $domain_health_file ]] || : >"$domain_health_file"
    [[ -f $domain_recent_file ]] || : >"$domain_recent_file"
}

domain_normalize() {
    local v="$1"
    v="${v#http://}"
    v="${v#https://}"
    v="${v%%/*}"
    v="${v%%:*}"
    echo "${v,,}"
}

domain_sanitize_region() {
    case "${1,,}" in
    us | eu | apac | global) echo "${1,,}" ;;
    "" | auto) echo "$(domain_detect_region)" ;;
    *) echo "global" ;;
    esac
}

domain_detect_region() {
    if [[ $SB_DOMAIN_REGION ]]; then
        domain_sanitize_region "$SB_DOMAIN_REGION"
        return
    fi
    local tz
    tz="$(timedatectl show -p Timezone --value 2>/dev/null)"
    case "$tz" in
    Asia/* | Australia/* | Pacific/*) echo "apac" ;;
    Europe/* | Africa/*) echo "eu" ;;
    America/*) echo "us" ;;
    *) echo "global" ;;
    esac
}

domain_is_disabled() {
    local d="$1"
    grep -Fxq "$d" "$domain_disabled_file" 2>/dev/null
}

domain_collect_pool() {
    local region="$1"
    local line d w r
    declare -A seen=()

    while IFS= read -r line; do
        [[ -z $line ]] && continue
        IFS='|' read -r d w r <<<"$line"
        d="$(domain_normalize "$d")"
        [[ -z $d ]] && continue
        [[ -z $w ]] && w=5
        [[ -z $r ]] && r=global
        domain_is_disabled "$d" && continue
        [[ $r != "global" && $r != "$region" ]] && continue
        seen["$d"]="builtin|$w|$r"
    done < <(printf '%s\n' "${servername_pool[@]}")

    while IFS= read -r line; do
        [[ -z $line ]] && continue
        IFS='|' read -r d w r <<<"$line"
        d="$(domain_normalize "$d")"
        [[ -z $d ]] && continue
        [[ -z $w ]] && w=4
        [[ -z $r ]] && r=global
        domain_is_disabled "$d" && continue
        [[ $r != "global" && $r != "$region" ]] && continue
        seen["$d"]="custom|$w|$r"
    done <"$domain_custom_file"

    for d in "${!seen[@]}"; do
        echo "$d|${seen[$d]}"
    done
}

domain_cache_write() {
    local d="$1" ok="$2"
    local now
    now="$(date +%s)"
    echo "$d|$now|$ok" >>"$domain_health_file"
    tail -n 500 "$domain_health_file" >"${domain_health_file}.tmp" 2>/dev/null || true
    mv -f "${domain_health_file}.tmp" "$domain_health_file" 2>/dev/null || true
}

domain_probe() {
    local d="$1"
    if [[ ! $(is_test domain "$d") ]]; then
        return 1
    fi

    if command -v getent >/dev/null 2>&1; then
        getent ahosts "$d" >/dev/null 2>&1 || return 1
    fi

    if command -v timeout >/dev/null 2>&1; then
        timeout 4 bash -c "exec 3<>/dev/tcp/$d/443" >/dev/null 2>&1 || return 1
    elif command -v nc >/dev/null 2>&1; then
        nc -z -w 4 "$d" 443 >/dev/null 2>&1 || return 1
    fi

    if command -v openssl >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            timeout 6 bash -c "echo | openssl s_client -connect $d:443 -servername $d 2>/dev/null | grep -q 'BEGIN CERTIFICATE'" || return 1
        else
            echo | openssl s_client -connect "$d:443" -servername "$d" 2>/dev/null | grep -q 'BEGIN CERTIFICATE' || return 1
        fi
    fi

    return 0
}

domain_is_healthy() {
    local d="$1"
    local ttl=21600 now ts ok last
    now="$(date +%s)"
    last="$(grep -E "^${d//./\\.}\|" "$domain_health_file" 2>/dev/null | tail -n 1)"
    if [[ $last ]]; then
        IFS='|' read -r _ ts ok <<<"$last"
        if [[ -n $ts && $((now - ts)) -lt $ttl ]]; then
            [[ $ok == "ok" ]] && return 0 || return 1
        fi
    fi

    if domain_probe "$d"; then
        domain_cache_write "$d" ok
        return 0
    fi
    domain_cache_write "$d" fail
    return 1
}

domain_recent_contains() {
    local d="$1"
    tail -n 8 "$domain_recent_file" 2>/dev/null | grep -Fq "|$d"
}

domain_mark_recent() {
    local d="$1" now
    now="$(date +%s)"
    echo "$now|$d" >>"$domain_recent_file"
    tail -n 50 "$domain_recent_file" >"${domain_recent_file}.tmp" 2>/dev/null || true
    mv -f "${domain_recent_file}.tmp" "$domain_recent_file" 2>/dev/null || true
}

domain_weighted_pick() {
    local region="$1"
    local line d src w r
    local picks=()
    declare -A seen=()

    while IFS= read -r line; do
        [[ -z $line ]] && continue
        IFS='|' read -r d src w r <<<"$line"
        [[ -z $d ]] && continue
        [[ -z $w || $w -lt 1 ]] && w=1
        [[ $w -gt 20 ]] && w=20
        for ((i = 0; i < w; i++)); do
            picks+=("$d")
        done
    done < <(domain_collect_pool "$region")

    if [[ ${#picks[@]} -eq 0 ]]; then
        return
    fi

    for ((i = 0; i < 60; i++)); do
        d="${picks[$((RANDOM % ${#picks[@]}))]}"
        [[ -z $d ]] && continue
        if [[ -z ${seen[$d]} ]]; then
            seen["$d"]=1
            echo "$d"
        fi
    done

    for d in "${picks[@]}"; do
        if [[ -z ${seen[$d]} ]]; then
            seen["$d"]=1
            echo "$d"
        fi
    done
}

domain_pick_for_reality() {
    domain_init_store
    local region="${1:-$(domain_detect_region)}"
    local d selected
    local candidates=()
    mapfile -t candidates < <(domain_weighted_pick "$region")

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "$is_random_servername"
        return
    fi

    for d in "${candidates[@]}"; do
        domain_recent_contains "$d" && continue
        if domain_is_healthy "$d"; then
            selected="$d"
            break
        fi
    done

    if [[ ! $selected ]]; then
        for d in "${candidates[@]}"; do
            if domain_is_healthy "$d"; then
                selected="$d"
                break
            fi
        done
    fi

    if [[ ! $selected ]]; then
        selected="${candidates[0]}"
    fi

    domain_mark_recent "$selected"
    echo "$selected"
}

domain_manage() {
    domain_init_store
    local action="${1:-list}"
    local d w r line src region total ok_cnt fail_cnt last health

    case "${action,,}" in
    list | ls)
        region="$(domain_sanitize_region "$2")"
        msg "\n[Domain Pool] region=$region (global 会自动参与)"
        msg "domain | source | weight | region | health(cache)"
        while IFS= read -r line; do
            IFS='|' read -r d src w r <<<"$line"
            last="$(grep -E "^${d//./\\.}\|" "$domain_health_file" 2>/dev/null | tail -n 1)"
            health="-"
            if [[ $last ]]; then
                IFS='|' read -r _ _ health <<<"$last"
            fi
            msg "$d | $src | $w | $r | $health"
        done < <(domain_collect_pool "$region" | sort)
        msg
        ;;
    add)
        d="$(domain_normalize "$2")"
        w="${3:-5}"
        r="$(domain_sanitize_region "${4:-global}")"
        if [[ -z $d || ! $(is_test domain "$d") ]]; then
            err "请提供有效域名. 用法: sb domain add <domain> [weight] [region]"
        fi
        if [[ ! $w =~ ^[0-9]+$ ]]; then
            err "weight 需要是数字 (1-20)."
        fi
        [[ $w -lt 1 ]] && w=1
        [[ $w -gt 20 ]] && w=20

        grep -Fvx "$d" "$domain_disabled_file" >"${domain_disabled_file}.tmp" 2>/dev/null || true
        mv -f "${domain_disabled_file}.tmp" "$domain_disabled_file" 2>/dev/null || true
        grep -Ev "^${d//./\\.}\|" "$domain_custom_file" >"${domain_custom_file}.tmp" 2>/dev/null || true
        mv -f "${domain_custom_file}.tmp" "$domain_custom_file" 2>/dev/null || true
        echo "$d|$w|$r" >>"$domain_custom_file"
        msg "\n已添加域名: $d (weight=$w, region=$r)\n"
        ;;
    del | rm)
        d="$(domain_normalize "$2")"
        if [[ -z $d ]]; then
            err "请提供要删除的域名. 用法: sb domain del <domain>"
        fi
        grep -Ev "^${d//./\\.}\|" "$domain_custom_file" >"${domain_custom_file}.tmp" 2>/dev/null || true
        mv -f "${domain_custom_file}.tmp" "$domain_custom_file" 2>/dev/null || true
        if ! grep -Fxq "$d" "$domain_disabled_file"; then
            echo "$d" >>"$domain_disabled_file"
        fi
        msg "\n已移除域名: $d (内置域名将进入禁用列表)\n"
        ;;
    test)
        if [[ $2 && $(is_test domain "$(domain_normalize "$2")") ]]; then
            d="$(domain_normalize "$2")"
            if domain_is_healthy "$d"; then
                msg "\n[OK] $d 可用\n"
            else
                err "[FAIL] $d 不可用"
            fi
            return
        fi

        region="$(domain_sanitize_region "$2")"
        if [[ $3 ]]; then
            d="$(domain_normalize "$3")"
            if domain_is_healthy "$d"; then
                msg "\n[OK] $d 可用\n"
            else
                err "[FAIL] $d 不可用"
            fi
            return
        fi
        ok_cnt=0
        fail_cnt=0
        total=0
        msg "\n开始健康检查 region=$region ..."
        while IFS= read -r line; do
            IFS='|' read -r d src w r <<<"$line"
            ((total++))
            if domain_is_healthy "$d"; then
                ((ok_cnt++))
                msg "[OK] $d"
            else
                ((fail_cnt++))
                msg "[FAIL] $d"
            fi
        done < <(domain_collect_pool "$region" | sort)
        msg "\n检查完成: total=$total ok=$ok_cnt fail=$fail_cnt\n"
        ;;
    pick)
        region="$(domain_sanitize_region "$2")"
        d="$(domain_pick_for_reality "$region")"
        msg "$d"
        ;;
    *)
        msg
        msg "Domain 管理命令:"
        msg "  sb domain list [region]"
        msg "  sb domain add <domain> [weight] [region]"
        msg "  sb domain del <domain>"
        msg "  sb domain test [region] [domain]"
        msg "  sb domain pick [region]"
        msg
        ;;
    esac
}
