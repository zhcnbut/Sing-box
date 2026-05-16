#!/bin/bash

write_change() {
    is_change=1
    is_dont_show_info=1
    if [[ $2 ]]; then
        case ${2,,} in
            full) is_change_id=full ;;
            new) is_change_id=0 ;;
            port) is_change_id=1 ;;
            host) is_change_id=2 ;;
            path) is_change_id=3 ;;
            pass | passwd | password) is_change_id=4 ;;
            id | uuid) is_change_id=5 ;;
            ssm | method | ss-method | ss_method) is_change_id=6 ;;
            dda | door-addr | door_addr) is_change_id=7 ;;
            ddp | door-port | door_port) is_change_id=8 ;;
            key | publickey | privatekey) is_change_id=9 ;;
            sni | servername | servernames) is_change_id=10 ;;
            web | proxy-site) is_change_id=11 ;;
            *)
                if [[ $is_try_change ]]; then return; fi
                err "无法识别 ($2) 更改类型."
                ;;
        esac
    fi
    if [[ $is_try_change ]]; then
        return
    fi
    if [[ $is_dont_auto_exit ]]; then
        get info $1
    else
        if [[ $is_change_id ]]; then
            is_change_msg=${change_list[$is_change_id]}
            if [[ $is_change_id == 'full' ]]; then
                if [[ $3 ]]; then
                    is_change_msg="更改多个参数"
                else
                    is_change_msg=
                fi
            fi
            if [[ $is_change_msg ]]; then
                _green "\n快速执行: $is_change_msg"
            fi
        fi
        info $1
        if [[ $is_auto_get_config ]]; then
            msg "\n自动选择: $is_config_file"
        fi
    fi

    is_old_net=$net
    if [[ $is_tcp_http ]]; then net=http; fi
    if [[ $host ]]; then net=$is_protocol-$net-tls; fi
    if [[ $is_reality && $net_type =~ 'http' ]]; then net=rh2; fi

    if [[ $3 == 'auto' ]]; then is_auto=1; fi
    is_dont_show_info=
    if [[ ! $is_change_id ]]; then
        ask set_change_list
        is_change_id=${is_can_change[$REPLY - 1]}
    fi

    snapshot_ensure "write-change"

    case $is_change_id in
        full) add $net ${@:3} ;;
        0)
            is_set_new_protocol=1
            add ${@:3}
            ;;
        1)
            is_new_port=$3
            if [[ $host && ! $is_caddy || $is_no_auto_tls ]]; then
                err "($is_config_file) 不支持更改端口, 因为没啥意义."
            fi
            if [[ $is_new_port && ! $is_auto ]]; then
                if [[ ! $(is_test port $is_new_port) ]]; then err "请输入正确的端口, 可选(1-65535)"; fi
                if [[ $is_new_port != 443 && $(is_test port_used $is_new_port) ]]; then err "无法使用 ($is_new_port) 端口"; fi
            fi
            if [[ $is_auto ]]; then
                get_port
                is_new_port=$tmp_port
            fi
            if [[ ! $is_new_port ]]; then ask string is_new_port "请输入新端口"; fi
            if [[ $is_caddy && $host ]]; then
                if [[ $is_dry_run ]]; then
                    msg "DRY-RUN: 将更新 Caddy 端口映射 -> host=$host https_port=$is_new_port"
                    msg "DRY-RUN: 将重启 caddy"
                    return
                fi
                net=$is_old_net
                is_https_port=$is_new_port
                load caddy.sh
                caddy_config $net
                manage restart caddy &
                info
            else
                add $net $is_new_port
            fi
            ;;
        2)
            is_new_host=$3
            if [[ ! $host ]]; then err "($is_config_file) 不支持更改域名."; fi
            if [[ ! $is_new_host ]]; then ask string is_new_host "请输入新域名"; fi
            old_host=$host
            add $net $is_new_host
            ;;
        3)
            is_new_path=$3
            if [[ ! $path ]]; then err "($is_config_file) 不支持更改路径."; fi
            if [[ $is_auto ]]; then
                get_uuid
                is_new_path=/$tmp_uuid
            fi
            if [[ ! $is_new_path ]]; then ask string is_new_path "请输入新路径"; fi
            add $net auto auto $is_new_path
            ;;
        4)
            is_new_pass=$3
            if [[ $ss_password || $password ]]; then
                if [[ $is_auto ]]; then
                    get_uuid
                    is_new_pass=$tmp_uuid
                    if [[ $ss_password ]]; then is_new_pass=$(get ss2022); fi
                fi
            else
                err "($is_config_file) 不支持更改密码."
            fi
            if [[ ! $is_new_pass ]]; then ask string is_new_pass "请输入新密码"; fi
            password=$is_new_pass
            ss_password=$is_new_pass
            is_socks_pass=$is_new_pass
            add $net
            ;;
        5)
            is_new_uuid=$3
            if [[ ! $uuid ]]; then err "($is_config_file) 不支持更改 UUID."; fi
            if [[ $is_auto ]]; then
                get_uuid
                is_new_uuid=$tmp_uuid
            fi
            if [[ ! $is_new_uuid ]]; then ask string is_new_uuid "请输入新 UUID"; fi
            add $net auto $is_new_uuid
            ;;
        6)
            is_new_method=$3
            if [[ $net != 'ss' ]]; then err "($is_config_file) 不支持更改加密方式."; fi
            if [[ $is_auto ]]; then is_new_method=$is_random_ss_method; fi
            if [[ ! $is_new_method ]]; then
                ask set_ss_method
                is_new_method=$ss_method
            fi
            add $net auto auto $is_new_method
            ;;
        7)
            is_new_door_addr=$3
            if [[ $net != 'direct' ]]; then err "($is_config_file) 不支持更改目标地址."; fi
            if [[ ! $is_new_door_addr ]]; then ask string is_new_door_addr "请输入新的目标地址"; fi
            door_addr=$is_new_door_addr
            add $net
            ;;
        8)
            is_new_door_port=$3
            if [[ $net != 'direct' ]]; then err "($is_config_file) 不支持更改目标端口."; fi
            if [[ ! $is_new_door_port ]]; then
                ask string door_port "请输入新的目标端口"
                is_new_door_port=$door_port
            fi
            add $net auto auto $is_new_door_port
            ;;
        9)
            is_new_private_key=$3
            is_new_public_key=$4
            if [[ ! $is_reality ]]; then err "($is_config_file) 不支持更改密钥."; fi
            if [[ $is_dry_run ]]; then
                if [[ $is_auto ]]; then
                    msg "DRY-RUN: 将自动生成新的 Reality 密钥对并写入配置: $is_config_file"
                else
                    msg "DRY-RUN: 将更新 Reality 密钥 -> config=$is_config_file"
                fi
                return
            fi
            if [[ $is_auto ]]; then
                get_pbk
                add $net
            else
                if [[ $is_new_private_key && ! $is_new_public_key ]]; then err "无法找到 Public key."; fi
                if [[ ! $is_new_private_key ]]; then ask string is_new_private_key "请输入新 Private key"; fi
                if [[ ! $is_new_public_key ]]; then ask string is_new_public_key "请输入新 Public key"; fi
                if [[ $is_new_private_key == $is_new_public_key ]]; then err "Private key 和 Public key 不能一样."; fi
                is_tmp_json=$is_conf_dir/$is_config_file-$uuid
                cp -f $is_conf_dir/$is_config_file $is_tmp_json
                sed -i s#$is_private_key #$is_new_private_key# $is_tmp_json
                $is_core_bin check -c $is_tmp_json &> /dev/null
                if [[ $? != 0 ]]; then
                    is_key_err=1
                    is_key_err_msg="Private key 无法通过测试."
                fi
                sed -i s#$is_new_private_key #$is_new_public_key# $is_tmp_json
                $is_core_bin check -c $is_tmp_json &> /dev/null
                if [[ $? != 0 ]]; then
                    is_key_err=1
                    is_key_err_msg+="Public key 无法通过测试."
                fi
                rm $is_tmp_json
                if [[ $is_key_err ]]; then err $is_key_err_msg; fi
                is_private_key=$is_new_private_key
                is_public_key=$is_new_public_key
                is_test_json=
                add $net
            fi
            ;;
        10)
            is_new_servername=$3
            if [[ ! $is_reality ]]; then err "($is_config_file) 不支持更改 serverName."; fi
            if [[ $is_auto ]]; then is_new_servername=$(domain_pick_for_reality); fi
            if [[ ! $is_new_servername ]]; then is_new_servername=$is_random_servername; fi
            if [[ ! $is_new_servername ]]; then ask string is_new_servername "请输入新的 serverName"; fi
            is_servername=$is_new_servername
            add $net
            ;;
        11)
            is_new_proxy_site=$3
            if [[ ! $is_caddy && ! $host ]]; then err "($is_config_file) 不支持更改伪装网站."; fi
            if [[ ! -f $is_caddy_conf/${host}.conf.add ]]; then err "无法配置伪装网站."; fi
            if [[ ! $is_new_proxy_site ]]; then ask string is_new_proxy_site "请输入新的伪装网站 (例如 example.com)"; fi
            proxy_site=$(sed 's#^.*//##;s#/$##' <<< $is_new_proxy_site)
            if [[ $is_dry_run ]]; then
                msg "DRY-RUN: 将更新伪装网站 -> host=$host proxy_site=$proxy_site"
                msg "DRY-RUN: 将重启 caddy"
                return
            fi
            load caddy.sh
            caddy_config proxy
            manage restart caddy &
            msg "\n已更新伪装网站为: $(_green $proxy_site) \n"
            ;;
        12)
            if [[ ! $is_socks_user ]]; then err "($is_config_file) 不支持更改用户名 (Username)."; fi
            ask string is_socks_user "请输入新用户名 (Username)"
            add $net
            ;;
    esac
}
