#!/bin/sh

#	ts=4	sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg

EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<str> -db_type=RAC|RACONENODE"

typeset db=undef
typeset db_type=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=${1##*=}
			shift
			;;

		-db_type=*)
			db_type=${1##*=}
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

exit_if_param_undef		db							"$str_usage"
exit_if_param_invalid	db_type "RAC RACONENODE"	"$str_usage"

typeset	-ri	max_nodes=$(olsnodes | wc -l)
typeset -r	upper_db=$(to_upper $db)

line_separator
info "Mise à jour de /etc/oratab sur $(hostname -s)"
info "Le nom de toutes les instances sont ajoutées, utile pour les RACs Policy managed & one node"
for inode in $( seq 1 $max_nodes )
do
	case $db_type in
		RAC)
			INSTANCE=${upper_db:0:8}$inode
			;;

		RACONENODE)
			INSTANCE=${upper_db:0:8}_$inode
			;;
	esac

	grep "$INSTANCE" /etc/oratab 2>/dev/null 1>&2
	if [ $? -eq 0 ]
	then
		info "$INSTANCE est déjà dans /etc/oratab"
	else
		exec_cmd "echo \"${INSTANCE}:/u01/app/oracle/$oracle_release/dbhome_1:N	#added by bibi\" >> /etc/oratab"
	fi
done
