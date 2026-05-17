#!/bin/bash

admin_is_main_menu() {
    is_main_start=1
    while :; do
        clear
        echo -e "\e[96m=====================================================\e[0m"
        echo -e "\e[96m          Sing-box-EV 魔改管理面板 $is_sh_ver\e[0m"
        echo -e "\e[96m=====================================================\e[0m"

        local caddy_show=""
        if [[ $is_caddy ]]; then
            caddy_show=" | Caddy: ${is_caddy_status}"
        fi
        echo -e "  [状态] Core: ${is_core_ver} (${is_core_status})${caddy_show}"
        echo -e "\e[90m-----------------------------------------------------\e[0m"

        echo -e "  \e[93m◈ 节点管理\e[0m"
        echo -e "    \e[92m(1)\e[0m 添加配置        \e[92m(2)\e[0m 更改配置"
        echo -e "    \e[92m(3)\e[0m 查看单节点      \e[92m(4)\e[0m 删除配置\n"

        echo -e "  \e[93m◈ 系统控制\e[0m"
        echo -e "    \e[92m(5)\e[0m 启动/停止       \e[92m(6)\e[0m 自动更新/清理"
        echo -e "    \e[92m(7)\e[0m 完全卸载        \e[92m(8)\e[0m 帮助文档\n"

        echo -e "  \e[93m◈ 高级工具\e[0m"
        echo -e "    \e[92m(9)\e[0m 进阶选项       \e[92m(10)\e[0m 关于本脚本"
        echo -e "    \e[92m(0)\e[0m 退出面板"
        echo -e "\e[90m-----------------------------------------------------\e[0m"

        echo -ne "➡️ 请输入对应的数字进行操作 [\e[91m0-10\e[0m]: "
        read REPLY

        if [[ ! $REPLY ]]; then continue; fi
        if [[ "$REPLY" == "0" ]]; then exit; fi
        if [[ "$REPLY" =~ ^([1-9]|10)$ ]]; then break; fi
        echo -e "\e[31m输入错误, 请输入 0-10 之间的数字\e[0m"
        sleep 1
    done

    case $REPLY in
        1) add ;;
        2) change ;;
        3) info ;;
        4) del ;;
        5)
            ask list is_do_manage "启动 停止 重启" "" "\n请选择系统服务状态:"
            manage $REPLY &
            msg "\n管理状态执行: $(_green $is_do_manage)\n"
            ;;
        6) cron_task ;;
        7) uninstall ;;
        8)
            msg
            load help.sh
            show_help
            ;;
        9)
            ask list is_do_other "节点订阅(Sub) 一键查看所有节点信息 启用BBR 查看日志 测试运行 重装脚本 设置DNS 手动更新 系统诊断(doctor) 查看快照列表 手动创建快照 回滚快照" "" "\n请选择进阶工具:"
            case $REPLY in
                1) gen_sub ;;
                2) show_all_nodes ;;
                3) _try_enable_bbr ;;
                4) log_set ;;
                5) get test-run ;;
                6) get reinstall ;;
                7) dns_set ;;
                8)
                    is_tmp_list=("更新$is_core_name" "更新脚本")
                    if [[ $is_caddy ]]; then is_tmp_list+=("更新Caddy"); fi
                    ask list is_do_update "" "\n请选择手动更新:"
                    update $REPLY
                    ;;
                9) doctor ;;
                10) backup_list ;;
                11)
                    unset is_snapshot_id
                    snapshot_ensure "manual-menu"
                    ;;
                12) rollback ;;
            esac
            ;;
        10)
            load help.sh
            about
            ;;
    esac
}
