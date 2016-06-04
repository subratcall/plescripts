#!/bin/sh

#	ts=4 sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/memory/memorylib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage="Usage : $ME -db_type=<single|rac*>"

typeset db_type=undef

while [ $# -ne 0 ]
do
	case $1 in
		-emul)
			EXEC_CMD_ACTION=NOP
			first_args=-emul
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

exit_if_param_undef db_type	"$str_usage"

function disable_selinux
{
	typeset -r selinux_cfg="/etc/selinux/config"

	if [ ! -f $selinux_cfg ]
	then
		error "$selinux_cfg not exists"
	fi

	if [ $(getenforce) != Disabled ]
	then
		info "Désactivation de SELINUX pour utilisation de oracleasm."
		info "	TODO : trouver comment définir les règles"
		exec_cmd "sed -i \"s/^SELINUX=enforcing/SELINUX=disabled/g\" $selinux_cfg"
	else
		info "SELinux already disabled."
	fi
}

function set_limit
{
	typeset -r domain=$1
	typeset -r type=$2
	typeset -r item=$3
	typeset -r value=$4

	exec_cmd "sed -i \"/^$domain\s\{1,\}$type\s\{1,\}$item\s.*$/d\" /etc/security/limits.conf"
	exec_cmd "printf \"%-8s %-6s %-8s %10s\n\" $domain $type $item $value >> /etc/security/limits.conf"
}

function memory_setting
{
	typeset -ri	ram_kb=$(memory_total_kb)
	typeset -ri percent=$oracle_grid_mem_lock_pct
	typeset -ri	mem_limit=$(echo "($percent*$ram_kb)/100" | bc)

	info "RAM                             : $(fmt_kb2mb $ram_kb)"
	info "locked address space for oracle : $(fmt_kb2mb $mem_limit) (${percent}% of $(fmt_kb2mb $ram_kb))"
	info "locked address space for grid   : $(fmt_kb2mb $mem_limit) (${percent}% of $(fmt_kb2mb $ram_kb))"
	LN

	info "Met à jour les limites mémoire."
	LN

	set_limit oracle soft memlock $mem_limit
	LN

	set_limit oracle hard memlock $mem_limit
	LN

	set_limit grid soft memlock $mem_limit
	LN

	set_limit grid hard memlock $mem_limit
	LN

	info "Divers :"
	LN

	set_limit grid hard nproc  16384
	LN

	set_limit grid hard nofile 65536
	LN
}

function hugepages_setting
{
	typeset -ri hugepages=$rdbms_alloc_hugepages

	typeset -ri id_group_dba=$(grep "^dba" /etc/group | cut -d':' -f3)

	info "Permet aux membres du group DBA d'utiliser des hugepages"
	update_value vm.hugetlb_shm_group $id_group_dba $sysctl_file
	exec_cmd "sysctl -w vm.hugetlb_shm_group=$id_group_dba"
	exec_cmd "sysctl -n vm.hugetlb_shm_group"
	LN

	info "Allocation de ${hugepages} hugepages"
	update_value vm.nr_hugepages $hugepages $sysctl_file
	exec_cmd "sysctl -w vm.nr_hugepages=$hugepages"
	exec_cmd "sysctl -n vm.nr_hugepages"
	LN
}

function dev_shm_setting
{
	info "mount /dev/shm on startup"

	exec_cmd "sed -i \"/^.*\/dev\/shm.*/d\" /etc/fstab"

	case "$max_shm_size" in
		config)
			[ $db_type = single ] && shm_size=$min_shm_size_single || shm_size=$min_shm_size_rac
			exec_cmd "echo \"tmpfs	/dev/shm	tmpfs	defaults,size=$shm_size 0 0\" >> /etc/fstab"
			LN
			;;

		auto)
			exec_cmd "echo \"tmpfs	/dev/shm	tmpfs	defaults 0 0\" >> /etc/fstab"
			LN
			;;

		*)
			error "max_shm_size='$max_shm_size' invalid."
			exit 1
			;;
	esac
}

#	Depuis la 11.2.0.4 il n'est plus nécessaire de désactiver selinux.
#line_separator
#disable_selinux
#LN

line_separator
memory_setting
LN

line_separator
hugepages_setting
LN

line_separator
dev_shm_setting
LN

exit
