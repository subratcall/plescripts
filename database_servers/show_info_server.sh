#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db=<str>"

typeset db=undef

while [ $# -ne 0 ]
do
	case $1 in
		-db=*)
			db=${1##*=}
			shift
			;;

		*)
			error "Arg '$1' invalid."
			LN
			info $str_usage
			exit 1
			;;
	esac
done

[[ $db = undef ]] && [[ -v ID_DB ]] && db=$ID_DB
exit_if_param_undef db

typeset -r cfg_dir=~/plescripts/database_servers/$db

if [ ! -d $cfg_dir ]
then
	error "$db not exists."
	exit 1
fi

typeset -i max_nodes=0

function print_node # $1 node_file $2 idx
{
	typeset -r	file=$1
	typeset -ri	idx=$2

	exit_if_file_not_exist $file
	IFS=':' read db_type node_name node_ip node_vip_name node_vip node_priv_name node_priv_ip db_name inst_name< $file
	case $db_type in
		rac)
			info "Node #$(( $idx + 1 )) RAC : "
			;;

		std)
			info "Node #$(( $idx + 1 )) standalone : "
			;;
	esac

	info "	Server name    : ${node_name}       : ${node_ip}"
	if [ $db_type == rac ]
	then
		info "	vip            : ${node_vip_name}   : ${node_vip}"
		info "	Interco RAC    : ${node_name}-rac   : ${if_rac_network}.${node_priv_ip##*.}"
	fi
	info "	Interco iSCSI  : ${node_name}-iscsi : ${node_priv_ip}"
}

function print_scan
{
	typeset -r	file=$1
	exit_if_file_not_exist $file

	IFS=':' read scan_name vip1 vip2 vip3 < $file
	info "scan : $scan_name"
	info "          $vip1"
	info "          $vip2"
	info "          $vip3"
}

function print_disks
{
	typeset -r	file=$1
	exit_if_file_not_exist $file

	typeset -r upper_db=$(to_upper $db)
	typeset -i no_first_disk
	typeset -i no_last_disk
	typeset -i no_disks
	while IFS=':' read dg_name disk_size no_first_disk no_last_disk
	do
		if [ $dg_name = FS ]
		then
			info "FS of ${disk_size}Gb"
		else
			info "DG $dg_name :"
			no_last_disk=no_last_disk+1
			while [ $no_first_disk -lt $no_last_disk ]
			do
				disk_name=$(printf "S1DISK%s%02d" $upper_db $no_first_disk)
				info "$(printf "	%s %dGb\n" $disk_name $disk_size)"
				no_first_disk=no_first_disk+1
			done
			LN
		fi
	done < $file

	info "${BOLD}Note :${NORM}"
	info "\tLe n° des disques est informatif, il se peut, dans certains cas,"
	info "\tqu'ils soient différents."
	info "\tPar exemple si un FS est créée sur une LUN avant les disques pour ASM."
	LN
	info "\tLes n° des disques correspondront au n° de leurs LUNs."
	LN
}

for file in $(ls -rt $cfg_dir/node*)
do
	print_node $file $max_nodes
	LN
	max_nodes=max_nodes+1
done

if [ -f $cfg_dir/scanvips ]
then
	print_scan $cfg_dir/scanvips
	LN
fi

print_disks $cfg_dir/disks

