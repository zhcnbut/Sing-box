#!/bin/bash

write_add() {
    unset custom_remark
    is_lower=${1,,}
    if [[ $is_lower ]]; then
        case $is_lower in
            ws | tcp | quic | http) is_new_protocol=VMess-${is_lower^^} ;;
            wss | h2 | hu | vws | vh2 | vhu | tws | th2 | thu) is_new_protocol=$(sed -E "s/^V/VLESS-/;s/^T/Trojan-/;/^(W|H)/{s/^/VMess-/};s/WSS/WS/;s/HU/HTTPUpgrade/" <<< ${is_lower^^})-TLS ;;
            r | reality) is_new_protocol=VLESS-REALITY ;;
            rh2) is_new_protocol=VLESS-HTTP2-REALITY ;;
            anytls) is_new_protocol=AnyTLS ;;
            cftunnel) is_new_protocol=CFtunnel ;;
            ss) is_new_protocol=Shadowsocks ;;
            door | direct) is_new_protocol=Direct ;;
            tuic) is_new_protocol=TUIC ;;
            hy | hy2 | hysteria*) is_new_protocol=Hysteria2 ;;
            trojan) is_new_protocol=Trojan ;;
            socks) is_new_protocol=Socks ;;
            *)
                for v in ${protocol_list[@]}; do
                    if [[ $(grep -E -i "^$is_lower$" <<< $v) ]]; then
                        is_new_protocol=$v
                        break
                    fi
                done
                if [[ ! $is_new_protocol ]]; then err "无法识别 ($1), 请使用: $is_core add [protocol] [args... | auto]"; fi
                ;;
        esac
    fi

    if [[ ! $is_new_protocol ]]; then ask set_protocol; fi

    case ${is_new_protocol,,} in
        *-tls)
            is_use_tls=1
            is_use_host=$2
            is_use_uuid=$3
            is_use_path=$4
            is_add_opts="[host] [uuid] [/path]"
            ;;
        vmess* | tuic*)
            is_use_port=$2
            is_use_uuid=$3
            is_add_opts="[port] [uuid]"
            ;;
        trojan* | hysteria*)
            is_use_port=$2
            is_use_pass=$3
            is_add_opts="[port] [password]"
            ;;
        *reality* | anytls)
            is_reality=1
            is_use_port=$2
            is_use_uuid=$3
            is_use_servername=$4
            is_add_opts="[port] [uuid] [sni]"
            ;;
        cftunnel)
            is_use_port=$2
            is_use_uuid=$3
            is_use_cf_token=$4
            is_add_opts="[port] [uuid] [cf_token]"
            ;;
        shadowsocks)
            is_use_port=$2
            is_use_pass=$3
            is_use_method=$4
            is_add_opts="[port] [password] [method]"
            ;;
        direct)
            is_use_port=$2
            is_use_door_addr=$3
            is_use_door_port=$4
            is_add_opts="[port] [remote_addr] [remote_port]"
            ;;
        socks)
            is_socks=1
            is_use_port=$2
            is_use_socks_user=$3
            is_use_socks_pass=$4
            is_add_opts="[port] [username] [password]"
            ;;
    esac

    if [[ $1 && ! $is_change ]]; then
        msg "\n使用协议: $is_new_protocol"
        is_err_tips="\n\n请使用: $(_green $is_core add $1 $is_add_opts) 来添加 $is_new_protocol 配置"
    fi

    if [[ $is_set_new_protocol ]]; then
        case $is_old_net in
            h2 | ws | httpupgrade)
                old_host=$host
                if [[ ! $is_use_tls ]]; then unset host is_no_auto_tls; fi
                ;;
            reality)
                net_type=
                if [[ ! $(grep -i reality <<< $is_new_protocol) ]]; then is_reality=; fi
                ;;
            ss) if [[ $(is_test uuid $ss_password) ]]; then uuid=$ss_password; fi ;;
        esac
        if [[ ! $(is_test uuid $uuid) ]]; then uuid=; fi
        if [[ $(is_test uuid $password) ]]; then uuid=$password; fi
    fi

    if [[ $is_no_auto_tls && ! $is_use_tls ]]; then err "$is_new_protocol 不支持手动配置 tls."; fi

    if [[ $2 ]]; then
        for v in is_use_port is_use_uuid is_use_host is_use_path is_use_pass is_use_method is_use_door_addr is_use_door_port is_use_servername; do
            if [[ ${!v} == 'auto' ]]; then unset $v; fi
        done

        if [[ $is_use_port ]]; then
            if [[ ! $(is_test port ${is_use_port}) ]]; then err "($is_use_port) 不是一个有效的端口. $is_err_tips"; fi
            if [[ $(is_test port_used $is_use_port) && ! $is_gen ]]; then err "无法使用 ($is_use_port) 端口. $is_err_tips"; fi
            port=$is_use_port
        fi
        if [[ $is_use_door_port ]]; then
            if [[ ! $(is_test port ${is_use_door_port}) ]]; then err "(${is_use_door_port}) 不是一个有效的目标端口. $is_err_tips"; fi
            door_port=$is_use_door_port
        fi
        if [[ $is_use_uuid ]]; then
            if [[ ! $(is_test uuid $is_use_uuid) ]]; then err "($is_use_uuid) 不是一个有效的 UUID. $is_err_tips"; fi
            uuid=$is_use_uuid
        fi
        if [[ $is_use_path ]]; then
            if [[ ! $(is_test path $is_use_path) ]]; then err "($is_use_path) 不是有效的路径. $is_err_tips"; fi
            path=$is_use_path
        fi
        if [[ $is_use_method ]]; then
            is_tmp_use_name=加密方式
            is_tmp_list=${ss_method_list[@]}
            for v in ${is_tmp_list[@]}; do
                if [[ $(grep -E -i "^${is_use_method}$" <<< $v) ]]; then
                    is_tmp_use_type=$v
                    break
                fi
            done
            if [[ ! ${is_tmp_use_type} ]]; then
                warn "(${is_use_method}) 不是一个可用的${is_tmp_use_name}."
                msg "${is_tmp_use_name}可用如下: "
                for v in ${is_tmp_list[@]}; do msg "\t\t$v"; done
                msg "$is_err_tips\n"
                exit 1
            fi
            ss_method=$is_tmp_use_type
        fi
        if [[ $is_use_pass ]]; then
            ss_password=$is_use_pass
            password=$is_use_pass
        fi
        if [[ $is_use_host ]]; then host=$is_use_host; fi
        if [[ $is_use_door_addr ]]; then door_addr=$is_use_door_addr; fi
        if [[ $is_use_servername == '--auto-sni' ]]; then unset is_use_servername; fi
        if [[ $is_use_servername ]]; then is_servername=$is_use_servername; fi
        if [[ $is_use_socks_user ]]; then is_socks_user=$is_use_socks_user; fi
        if [[ $is_use_socks_pass ]]; then is_socks_pass=$is_use_socks_pass; fi
        if [[ $is_use_cf_token ]]; then cf_token=$is_use_cf_token; fi
    fi

    if [[ $is_reality && ! $is_servername ]]; then
        is_servername=$(domain_pick_for_reality)
        if [[ ! $is_servername ]]; then is_servername=$is_random_servername; fi
        if [[ $is_servername ]]; then msg "Reality 自动选择 serverName: $(_green $is_servername)"; fi
    fi

    if [[ $is_use_tls ]]; then
        if [[ ! $is_no_auto_tls && ! $is_caddy && ! $is_gen && ! $is_dont_test_host ]]; then
            if [[ $(is_test port_used 80) || $(is_test port_used 443) ]]; then
                get_port
                is_http_port=$tmp_port
                get_port
                is_https_port=$tmp_port
                warn "端口 (80 或 443) 已经被占用, Caddy 将使用非标准端口实现自动配置 TLS, HTTP:$is_http_port HTTPS:$is_https_port\n"
                msg "请确定是否继续???"
                pause
            fi
            is_install_caddy=1
        fi
        if [[ ! $host ]]; then ask string host "请输入域名"; fi
        get host-test
    else
        if [[ $is_main_start ]]; then
            if [[ ! $port ]]; then
                get_port
                port=$tmp_port
                echo -e "\n--------------------------------------------------------"
                echo -e "端口分配: 已自动为您分配空闲端口 [\e[92m$port\e[0m]"
                echo -e "--------------------------------------------------------"
            fi

            if [[ $is_new_protocol == 'CFtunnel' ]]; then
                if [[ ! $cf_token ]]; then ask string cf_token "请输入 Cloudflare Tunnel Token"; fi
                if [[ ! $cf_domain ]]; then ask string cf_domain "请输入你准备为该节点绑定的 Cloudflare 域名 (例如 node1.example.com)"; fi
            fi

            case ${is_new_protocol,,} in
                socks)
                    if [[ ! $is_socks_user ]]; then ask string is_socks_user "请设置用户名"; fi
                    if [[ ! $is_socks_pass ]]; then ask string is_socks_pass "请设置密码"; fi
                    ;;
                shadowsocks)
                    if [[ ! $ss_method ]]; then ask set_ss_method; fi
                    if [[ ! $ss_password ]]; then ask string ss_password "请设置密码"; fi
                    ;;
            esac
        fi
    fi

    if [[ $is_new_protocol == 'Direct' ]]; then
        if [[ ! $door_addr ]]; then ask string door_addr "请输入目标地址"; fi
        if [[ ! $door_port ]]; then ask string door_port "请输入目标端口"; fi
    fi

    if [[ $(grep 2022 <<< $ss_method) ]]; then
        if [[ $ss_password ]]; then
            is_test_json=1
            create server Shadowsocks
            if [[ ! $tmp_uuid ]]; then get_uuid; fi
            is_test_json_save=$is_conf_dir/tmp-test-$tmp_uuid
            cat <<< "$is_new_json" > $is_test_json_save
            $is_core_bin check -c $is_test_json_save &> /dev/null
            if [[ $? != 0 ]]; then
                warn "Shadowsocks 协议不支持使用当前密码, 脚本将自动创建可用密码:)"
                ss_password=
                json_str=
            fi
            is_test_json=
            rm -f $is_test_json_save
        fi
    fi

    if [[ $is_main_start ]]; then
        echo ""
        echo -e "--------------------------------------------------------"
        read -p "请输入该节点的自定义备注 (如留空按回车，则默认使用 luopojunzi): " custom_remark
        if [[ -z "$custom_remark" ]]; then custom_remark="luopojunzi"; fi
        echo -e "--------------------------------------------------------"
    else
        custom_remark="luopojunzi"
    fi

    if [[ $is_install_caddy ]]; then
        _green "\n安装 Caddy 实现自动配置 TLS.\n"
        download caddy
        install_service caddy &> /dev/null
        is_caddy=1
        _green "安装 Caddy 成功.\n"
    fi

    create server $is_new_protocol
    info
}
