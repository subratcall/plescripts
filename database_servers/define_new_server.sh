#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/networklib.sh
EXEC_CMD_ACTION=EXEC

. ~/plescripts/global.cfg

typeset -r ME=$0

typeset -r str_usage=\
"Usage : $ME
	-db=<identifiant>     identifiant de la base.
	[-luns_hosted_by=$disks_hosted_by] san|vbox
	[-max_nodes=1]        nombre de nœuds pour un RAC.
	[-size_dg_gb=24]      taille du DG ou du FS.
	[-size_lun_gb=8]      taille des LUNs si utilisation d'ASM.
	[-no_dns_test]        ne pas tester si les IPs sont utilisées.
	[-usefs]              ne pas utiliser ASM mais un FS.
	[-ip_node=<node>]     nœud IP, sinon prend la première IP disponible.
"
info "Running : $ME $*"

typeset		db=undef
typeset -i	ip_node=-1
typeset -i	max_nodes=1
typeset -i	size_dg_gb=24
typeset -i	size_lun_gb=8
typeset		dns_test=yes
typeset 	usefs=no
typeset		luns_hosted_by=$disks_hosted_by

#	rac si max_nodes vaut plus de 1
typeset		db_type=std

while [ $# -ne 0 ]
do
	case $1 in
		-size_lun_gb=*)
			size_lun_gb=${1##*=}
			shift
			;;

		-luns_hosted_by=*)
			luns_hosted_by=${1##*=}
			shift
			;;

		-db=*)
			db=$(to_lower ${1##*=})
			shift
			;;

		-ip_node=*)
			ip_node=${1##*=}
			shift
			;;

		-max_nodes=*)
			max_nodes=${1##*=}
			shift
			;;

		-size_dg_gb=*)
			size_dg_gb=${1##*=}
			shift
			;;

		-no_dns_test)
			dns_test=no
			shift
			;;

		-usefs)
			usefs=yes
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
			LN
			exit 1
			;;
	esac
done

exit_if_param_undef db	"$str_usage"

[ $max_nodes -gt 1 ] && [ $db_type != rac ] && db_type=rac

[ $db_type == rac ] && [ $usefs == yes ] && error "RAC on FS not supported." && exit 1

exec_cmd -ci "~/plescripts/validate_config.sh >/tmp/vc 2>&1"
if [ $? -ne 0 ]
then
	cat /tmp/vc
	rm -f /tmp/vc
	exit 1
fi
rm -f /tmp/vc

typeset -c	cfg_path=~/plescripts/database_servers/$db

function test_ip_node_used
{
	if [ $dns_test == yes ]
	then
		typeset -r ip_node=$1
		dns_test_if_ip_exist $ip_node
		if [ $? -ne 0 ]
		then
			error "IP $if_pub_network.$ip_node in used."
			exit 1
		fi
	fi
}

function normalyze_node
{
	typeset -ri	num_node=$1

	typeset -ri idx=num_node-1

	server_name=$(printf "srv%s%02d" $db $num_node)
	server_ip=$if_pub_network.$ip_node
	test_ip_node_used $ip_node

	server_private_ip=$if_iscsi_network.$ip_node
	ip_node=ip_node+1

	if [ $db_type == rac ]
	then
		test_ip_node_used $ip_node
		server_vip=$if_pub_network.$ip_node
	else
		server_vip=undef
	fi
	ip_node=ip_node+1

	echo "${db_type}:${server_name}:${server_ip}:${server_name}-vip:${server_vip}:${server_name}-priv:${server_private_ip}:${luns_hosted_by}" > $cfg_path/node${num_node}
}

function normalyze_scan
{
	buffer=${db}-scan

	typeset -i node_scan=$ip_node
	for i in $(seq 0 2)
	do
		scan_vip=$if_pub_network.$node_scan
		buffer=$buffer:${scan_vip}
		node_scan=node_scan+1
	done

	echo "$buffer" > $cfg_path/scanvips
}

#	Les n° de disques n'ont plus de sens, ils sont conservés car ils permettent
#	de déterminer le nombre de disques nécessaire.
function normalyse_asm_disks
{
	typeset -i i_lun=1

	if [ $db_type == rac ]
	then
		echo "CRS:6:1:3" > $cfg_path/disks
		i_lun=4
	fi

	typeset -ri max_luns=$( echo "$size_dg_gb / $size_lun_gb" | bc)

	buffer="DATA:${size_lun_gb}:$i_lun:"
	typeset -i last_lun=i_lun+max_luns
	i_lun=last_lun+1
	echo "$buffer$last_lun" >> $cfg_path/disks

	buffer="FRA:${size_lun_gb}:$i_lun:"
	last_lun=i_lun+max_luns
	i_lun=last_lun+1
	echo "$buffer$last_lun" >> $cfg_path/disks
}

function normalyse_fs_disks
{
	echo "FS:$size_dg_gb:1:1" > $cfg_path/disks
}

line_separator
if [ -d $cfg_path ]
then
	confirm_or_exit "$cfg_path exists, remove :"
	exec_cmd rm -rf $cfg_path
fi
exec_cmd mkdir $cfg_path
LN

typeset -i ip_range=1
[ $max_nodes -gt 1 ] && ip_range=max_nodes*2+3	# +3 adressse de scan
[ $ip_node -eq -1 ] && ip_node=$(ssh $dns_conn "~/plescripts/dns/get_free_ip_node.sh -range=$ip_range")

for i in $(seq 1 $max_nodes)
do
	normalyze_node $i
done
LN

[ $db_type == rac ] && normalyze_scan

typeset -i data_lun_count=$(($size_dg_gb / $size_lun_gb))
if [ $(($size_dg_gb % $size_lun_gb)) -ne 0 ]
then
	data_lun_count=$data_lun_count+1
	size_dg_gb=$(($size_lun_gb * $data_lun_count))
	LN
	info "Adjust DGs sizes to ${size_dg_gb}Gb."
	LN
fi

if [ $usefs == no ]
then
	normalyse_asm_disks
else
	normalyse_fs_disks
fi

~/plescripts/shell/show_info_server -db=$db

info -n "Run : ./clone_master.sh -db=$db"
[ $db_type == rac ] && info -f " -node=1" || LN
