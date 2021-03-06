#!/bin/bash

# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset -r ME=$0
typeset -r str_usage=\
"Usage : $ME
Ce script vérifie que l'OS host remplie les conditions nécessaires au bon
fonctionnement de la démo."

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

typeset -i count_errors=0

line_separator
info -n "Test l'existence de '$HOME/plescripts' "
if [ ! -d "$HOME/plescripts" ]
then
	info -f "[$KO]"
	error "	Ce répertoire doit contenir tous les scripts récupérés depuis GitHub."
	count_errors=count_errors+1
else
	info -f "[$OK]"
fi

info -n "Test l'existence de '$HOME/$oracle_install/database/runInstaller' "
if [ ! -f "$HOME/$oracle_install/database/runInstaller" ]
then
	info -f "[$KO]"
	error "	Ce répertoire doit contenir les fichiers dézipés d'Oracle."
	count_errors=count_errors+1
else
	info -f "[$OK]"
fi

info -n "Test l'existence de '$HOME/$oracle_install/grid/runInstaller' "
if [ ! -f "$HOME/$oracle_install/grid/runInstaller" ]
then
	info -f "[$KO]"
	error "Ce répertoire doit contenir les fichiers dézipés du Grid."
	count_errors=count_errors+1
else
	info -f "[$OK]"
fi
LN

if [ $type_shared_fs == nfs ]
then
	info "$client_hostname doit exporter via NFS les répertoires :"
	info -n "	- $HOME/plescripts "
	grep "$HOME/plescripts" /etc/exports >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
		count_errors=count_errors+1
		info -f "[$KO]"
	else
		info -f "[$OK]"
	fi
fi

info -n "	- $HOME/$oracle_install "
grep "$HOME/$oracle_install" /etc/exports >/dev/null 2>&1
if [ $? -ne 0 ]
then
	count_errors=count_errors+1
	info -f "[$KO]"
else
	info -f "[$OK]"
fi
LN

line_separator
info -n "Test l'existence de $full_linux_iso_name "
if [ ! -f "$full_linux_iso_name" ]
then
	info -f "[$KO]"
	error "L'ISO d'installation d'Oracle Linux 7 n'existe pas."
	count_errors=count_errors+1
else
	info -f "[$OK]"
fi
LN

line_separator
info -n "Validation de resolv.conf "
if  grep -q ${infra_ip} /etc/resolv.conf &&  grep -q "search\s*$domain_name" /etc/resolv.conf
then
	info -f "[$OK]"
else
	info -f "[$KO]"
	count_errors=count_errors+1
fi
LN

line_separator
info -n "~/plescripts/shell dans le path "
if $(test_if_cmd_exists llog)
then
	info -f "[$OK]"
else
	info -f "[${BLUE}optional${NORM}] mais simplifie la vie."
fi
LN

line_separator
function in_path
{
	typeset		option=no
	if [ "$1" == "-o" ]
	then
		option=yes
		shift
	fi
	typeset -r	cmd=$1
	typeset -r	cmd_msg=$2

	typeset -r	distrib=$(grep ^NAME /etc/os-release | cut -d= -f2)

	typeset -r msg=$(printf "%-10s " $cmd)
	info -n "$msg"
	if $(test_if_cmd_exists $cmd)
	then
		info -f "[$OK]"
	else
		if [ $option == yes ]
		then
			info -f -n "[${BLUE}optional${NORM}]"
		else
			count_errors=count_errors+1
			info -f -n "[$KO]"
		fi
		info -f " $cmd_msg"
		[[ $option == no && $distrib == openSUSE ]] && ( exec_cmd -ci cnf $cmd; LN )
	fi
}

in_path VBoxManage	"Install VirtualVox"
in_path nc			"Install nc"
in_path ssh			"Install ssh"
in_path -o git		"Install git"
in_path -o tmux		"Install tmux"
LN

line_separator
exec_cmd -c "~/plescripts/shell/set_plescripts_acl.sh"
LN

line_separator
info -n "Script configure_global.cfg.sh exécuté "
hn=$(hostname -s)
if [[ "$hn" == "$client_hostname" && "$USER" == "$common_user_name" ]]
then
	info -f "[$OK]"
else
	info -f "[$KO]"
	if [ $count_errors -ne 0 ]
	then
		info "Corriger les erreurs précédentes avant d'exécuter configure_global.cfg.sh"
	fi
	count_errors=count_errors+1
fi
LN

line_separator
if [ $count_errors -ne 0 ]
then
	warning "$count_errors erreurs."
	info "Corriger les erreurs avant de continuer."
	exit 1
else
	info "Configuration conforme."
	exit 0
fi
