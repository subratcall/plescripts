#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -prefixInstance=<str>"

typeset prefixInstance=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-prefixInstance=*)
			prefixInstance=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

exit_if_param_undef		prefixInstance 	"$str_usage"

typeset	-ri	max_nodes=$(olsnodes | wc -l)

info "Update /etc/oratab on $(hostname -s)"
info "Add all instances, useful for Policy Managed and RAC One Node"
for inode in $( seq 1 $max_nodes )
do
	INSTANCE=$prefixInstance$inode

	grep "$INSTANCE" /etc/oratab 2>/dev/null 1>&2
	if [ $? -eq 0 ]
	then
		info "$INSTANCE present in /etc/oratab"
	else
		exec_cmd "echo \"${INSTANCE}:/u01/app/oracle/$oracle_release/dbhome_1:N	#added by bibi\" >> /etc/oratab"
	fi
done

