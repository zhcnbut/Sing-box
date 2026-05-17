# ==========================================
# Sing-box-EV Core Business Logic
# ==========================================

. "$is_sh_dir/src/core/00_env.sh"
. "$is_sh_dir/src/core/10_ui.sh"
. "$is_sh_dir/src/core/ui/prompt.sh"
. "$is_sh_dir/src/core/20_validate.sh"
. "$is_sh_dir/src/core/25_domain.sh"
. "$is_sh_dir/src/core/30_runtime.sh"
. "$is_sh_dir/src/core/40_node_query.sh"
. "$is_sh_dir/src/core/50_node_write.sh"
. "$is_sh_dir/src/core/60_sub.sh"
. "$is_sh_dir/src/core/admin/update.sh"
. "$is_sh_dir/src/core/admin/uninstall.sh"
. "$is_sh_dir/src/core/70_admin.sh"

msg() { ui_msg "$@"; }
msg_ul() { ui_msg_ul "$@"; }
pause() { ui_pause; }

show_list() { ui_show_list "$@"; }

is_test() { validate_is_test "$@"; }

is_port_used() { validate_is_port_used "$@"; }

create() { write_create "$@"; }

change() { write_change "$@"; }

del() { write_del "$@"; }

get() { query_get "$@"; }

info() { query_info "$@"; }

show_all_nodes() { query_show_all_nodes "$@"; }

gen_sub() { sub_gen_sub; }

add() { write_add "$@"; }

footer_msg() { ui_footer_msg; }

url_qr() { query_url_qr "$@"; }

manage() { runtime_manage "$@"; }

cron_task() { runtime_cron_task; }

snapshot_ensure() { runtime_snapshot_ensure "$@"; }

backup_list() { runtime_snapshot_list; }

rollback() { runtime_snapshot_restore "$@"; }

doctor() { runtime_doctor; }

domain() { domain_manage "$@"; }

update() { admin_update "$@"; }

uninstall() { admin_uninstall "$@"; }

is_main_menu() { admin_is_main_menu "$@"; }

main() { admin_main "$@"; }
