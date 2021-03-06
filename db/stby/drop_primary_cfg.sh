#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/dblib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME -db=name"

info "Running : $ME $*"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
			shift
			;;

		-db=*)
			db=$(to_upper ${1##*=})
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

exit_if_param_undef db		"$str_usage"

function sqlcmd_drop_primary_cfg
{
	to_exec "alter system reset standby_file_management scope=spfile sid='*';"

	to_exec "alter system reset log_archive_config scope=spfile sid='*';"

	to_exec "alter system reset fal_server scope=spfile sid='*';"

	to_exec "alter system reset log_archive_dest_1 scope=spfile sid='*';"

	to_exec "alter system reset log_archive_dest_2 scope=spfile sid='*';"

	to_exec "alter system reset log_archive_dest_state_2 scope=spfile sid='*';"

	to_exec "alter system reset remote_login_passwordfile scope=spfile sid='*';"

	# Les 2 paramètres ne sont pas positionné, mais me sert de mémo pour ailleurs.
	to_exec "alter system reset db_file_name_convert scope=spfile sid='*';"

	to_exec "alter system reset log_file_name_convert scope=spfile sid='*';"
	#	--

	to_exec "alter system reset dg_broker_config_file1 scope=spfile sid='*';"

	to_exec "alter system reset dg_broker_config_file2 scope=spfile sid='*';"

	to_exec "alter system reset dg_broker_start scope=spfile sid='*';"

	to_exec "alter database no force logging;"

	to_exec "shutdown immediate"
	to_exec "startup"
}

function remove_broker_cfg
{
	line_separator
dgmgrl -silent -echo<<EOS 
connect sys/$oracle_password
disable configuration;
remove configuration;
EOS
	LN

	line_separator
	exec_cmd -c sudo -u grid -i "asmcmd rm -f DATA/$db/dr1db_*.dat"
	LN
}

function remove_SRLs
{
	line_separator
	sqlplus -s sys/$oracle_password as sysdba<<EOS
	@drop_standby_redolog.sql
EOS
	LN
}

function create_services
{
typeset -r query=\
"select
	c.name
from
	gv\$containers c
	inner join gv\$instance i
		on  c.inst_id = i.inst_id
	where
		i.instance_name = '$db'
	and	c.name not in ( 'PDB\$SEED', 'CDB\$ROOT' );
"

	while read pdbName
	do
		[ x"$pdbName" == x ] && continue

		line_separator
		exec_cmd "$ROOT/db/create_srv_for_single_db.sh -db=$db -pdbName=$pdbName"
		LN
	done<<<"$(sqlplus_exec_query "$query")"
}

info "Load env for $db"
ORACLE_SID=$db
ORAENV_ASK=NO . oraenv
LN

remove_broker_cfg

remove_SRLs

line_separator
exec_cmd -c $ROOT/db/drop_all_services.sh -db=$db
LN

create_services

line_separator
sqlplus_cmd "$(sqlcmd_drop_primary_cfg)"
LN
