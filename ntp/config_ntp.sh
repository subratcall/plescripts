#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -role=[infra|master]
Configure NTP for infra or master server (use chrony).
"

typeset role=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			shift
			;;

		-role=*)
			role=${1##*=}
			shift
			;;

		-h|-help|help)
			info "$str_usage"
			LN
			exit 1
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_invalid role "master infra" "$str_usage"

typeset -r chrony_conf=/etc/chrony.conf
exit_if_file_not_exist $chrony_conf

[ $role = master ] && time_server=$infra_hostname || time_server=$master_time_server

if [ $time_server != internet ]
then
	info "Config $chrony_conf"
	exec_cmd "cp $chrony_conf ${chrony_conf}.backup"
	exec_cmd "sed -i '/^server.*iburst$/d' $chrony_conf"
	exec_cmd "sed -i '3i\server $time_server iburst' $chrony_conf"
	exec_cmd "sed -i 's/.*allow .*/allow ${infra_network}.0\/$if_pub_prefix/g' $chrony_conf"
	LN
fi

if [ $role == infra ]
then
	info "Config firewall"
	exec_cmd "firewall-cmd --add-service=ntp --permanent --zone=trusted"
	exec_cmd "firewall-cmd --reload"
	LN
fi

info "Enabled & start chrony"
exec_cmd "systemctl enable chronyd"
exec_cmd "systemctl start chronyd"
LN

