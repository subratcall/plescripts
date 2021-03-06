#!/bin/bash
# vim: ts=4:sw=4

. ~/plescripts/plelib.sh
. ~/plescripts/global.cfg
EXEC_CMD_ACTION=EXEC

typeset ORCL_RELEASE=undef
typeset ORACLE_RELEASE=undef
typeset db_type=undef

typeset -r str_usage="Usage $0 -release=aa.bb.cc.dd -db_type=[single|rac]"

#	ksh ou bash, mais ksh c'est trop chiant.
typeset -r the_shell=bash

while [ $# -ne 0 ]
do
	case $1 in
		-releaseoracle=*|-release=*)
			ORACLE_RELEASE=${1##*=}
			shift
			;;

		-db_type=*)
			db_type=${1##*=}
			shift
			;;

		*)
			error "'$1' invalid."
			LN
			info "$str_usage"
			exit 1
			;;
	esac
done

[ $ORACLE_RELEASE = undef ] &&	$ORACLE_RELEASE=$oracle_release

ORCL_RELEASE=${ORACLE_RELEASE:0:2}

info "Create grid profile."
exec_cmd "cp ~/plescripts/oracle_preinstall/grid_env.template  ~/plescripts/oracle_preinstall/grid_env"
case $db_type in
	rac)
		exec_cmd "sed -i \"s!GRID_HOME=!GRID_HOME=$\GRID_ROOT/app/$ORACLE_RELEASE/grid!\" ~/plescripts/oracle_preinstall/grid_env"
		;;

	single|single_fs)
		exec_cmd "sed -i \"s!GRID_HOME=!GRID_HOME=$\GRID_ROOT/app/grid/$ORACLE_RELEASE!\" ~/plescripts/oracle_preinstall/grid_env"
		;;

	*)
		error "type = '$db_type' invalid."
		LN
		info "$str_usage"
		LN
		exit 1
		;;
esac
LN

typeset -r profile_oracle=/tmp/profile_oracle

info "Create oracle profile."
exec_cmd "sed \"s/RELEASE_ORACLE/${ORACLE_RELEASE}/g\" \
			~/plescripts/oracle_preinstall/template_profile.oracle |\
			 sed \"s/ORA_NLSZZ/ORA_NLS${ORCL_RELEASE}/g\" > $profile_oracle"
LN

. $profile_oracle

if [ x"$GRID_ROOT" = x ]
then
	error "Error GRID_ROOT not define...."
	exit 1
fi

exec_cmd "~/plescripts/oracle_preinstall/remove_oracle_users_and_groups.sh"

line_separator
info "create all groups"
#Generic Name          OS Group    Admin Privilege   Description
#====================  ==========  ================  =================================
#OraInventory Owner    oinstall                      (Mandatory)
#OSDBA                 dba         SYSDBA            Full admin privileges (Mandatory)
#OSOPER                oper        SYSOPER           Subset of admin privileges
#
#OSDBA (for ASM)       asmdba
#OSASM                 asmadmin    SYSASM            ASM management
#OSOPER (for ASM)      asmoper
#
#OSBACKUPDBA           backupdba   SYSBACKUP         RMAN management
#OSDGDBA               dgdba       SYSDG             Data Guard management
#OSKMDBA               kmdba       SYSKM             Encryption key management

exec_cmd groupadd -g 1000 oinstall
#	asmadmin : util pour oracle asm.
exec_cmd groupadd -g 1200 asmadmin
exec_cmd groupadd -g 1201 asmdba
#	asmoper et oper sont facultatifs.
exec_cmd groupadd -g 1202 asmoper
exec_cmd groupadd -g 1203 oper
#
exec_cmd groupadd -g 1250 dba
LN

# Pour la 12cR1 : ignoré pour le moment.
#exec_cmd groupadd -g 1260 backupdba		#	RMAN management
#exec_cmd groupadd -g 1270 dgdba			#	Data Guard management
#exec_cmd groupadd -g 1280 kmdba			#	Encryption key management

line_separator
info "remove $GRID_ROOT/"
exec_cmd "rm -rf $GRID_ROOT/*"
LN

#	Charge la fonction make_vimrc_file
. ~/plescripts/oracle_preinstall/make_vimrc_file

#	Met à jour root également.
make_vimrc_file "/root"

line_separator
info "create users grid"
exec_cmd useradd -u 1100 -g oinstall -G dba,asmadmin,asmdba,asmoper \
			 -s /bin/${the_shell} -c \"Grid Infrastructure Owner\" grid

exec_cmd cp ~/plescripts/oracle_preinstall/grid_env /home/grid/grid_env
exec_cmd cp ~/plescripts/oracle_preinstall/rlwrap.alias /home/grid/rlwrap.alias

exec_cmd "sed \"s/RELEASE_ORACLE/${ORACLE_RELEASE}/g\"	\
			./template_profile.grid |					\
			sed \"s/ORA_NLSZZ/ORA_NLS${ORCL_RELEASE}/g\" > /home/grid/profile.grid"

if [ $the_shell == ksh ]
then
	exec_cmd "echo \" \" >> /home/grid/.profile"
	exec_cmd "echo \". /home/grid/profile.grid\" >> /home/grid/.profile"
	exec_cmd cp template_kshrc /home/grid/.kshrc
else
	exec_cmd "echo \" \" >> /home/grid/.bash_profile"
	exec_cmd "echo \". /home/grid/profile.grid\" >> /home/grid/.bash_profile"
	# Permet aux scripts utilisant ssh de continuer à fonctionner.
	exec_cmd "ln -s /home/grid/.bash_profile /home/grid/.profile"
fi
make_vimrc_file "/home/grid"
exec_cmd "find /home/grid | xargs chown grid:oinstall"
LN

line_separator
info "create user oracle"
exec_cmd useradd -u 1050 -g oinstall -G dba,asmdba,oper	\
			-s /bin/${the_shell} -c \"Oracle Software Owner\" oracle

exec_cmd cp ~/plescripts/oracle_preinstall/grid_env /home/oracle/grid_env
exec_cmd cp ~/plescripts/oracle_preinstall/rlwrap.alias /home/oracle/rlwrap.alias

exec_cmd "sed \"s/RELEASE_ORACLE/${ORACLE_RELEASE}/g\"	\
			./template_profile.oracle |					\
			sed \"s/ORA_NLSZZ/ORA_NLS${ORCL_RELEASE}/g\" > /home/oracle/profile.oracle"

if [ $the_shell == ksh ]
then
	exec_cmd "echo \" \" >> /home/oracle/.profile"
	exec_cmd "echo \". /home/oracle/profile.oracle\" >> /home/oracle/.profile"
	exec_cmd cp template_kshrc /home/oracle/.kshrc
else
	exec_cmd "echo \" \" >> /home/oracle/.bash_profile"
	exec_cmd "echo \". /home/oracle/profile.oracle\" >> /home/oracle/.bash_profile"
	# Permet aux scripts utilisant ssh de continuer à fonctionner.
	exec_cmd "ln -s /home/oracle/.bash_profile /home/oracle/.profile"
fi
make_vimrc_file "/home/oracle"
exec_cmd "find /home/oracle | xargs chown oracle:oinstall"
LN

line_separator
info "grid directories"
exec_cmd mkdir -p $GRID_BASE
exec_cmd mkdir -p $GRID_HOME
exec_cmd chown -R grid:oinstall $GRID_ROOT
LN

line_separator
info "oracle directories"
exec_cmd mkdir -p $ORACLE_BASE
exec_cmd mkdir -p $ORACLE_HOME
exec_cmd chown -R oracle:oinstall $ORACLE_BASE
LN

line_separator
info "set full permission for owner & group on $GRID_ROOT"
exec_cmd chmod -R 775 $GRID_ROOT
LN

grep grid_env /root/.bash_profile 1>/dev/null
if [ $? -ne 0 ]
then
	line_separator
	info "Update .bash_profile for root"
	(	echo "if [ -f /home/grid/grid_env ]"
		echo "then"
		echo "    . /home/grid/grid_env"
		echo "    export PATH=\$PATH:$GRID_HOME/bin"
		echo "fi"
		echo ". rlwrap.alias"
	)	>> /root/.bash_profile
	LN
	exec_cmd cp ~/plescripts/oracle_preinstall/rlwrap.alias /root/rlwrap.alias
fi

line_separator
info "set password for users oracle & grid"
exec_cmd "printf \"oracle\noracle\n\" | passwd oracle >/dev/null 2>&1"
exec_cmd "printf \"grid\ngrid\n\" | passwd grid >/dev/null 2>&1"
LN

line_separator
exec_cmd "rm ~/plescripts/oracle_preinstall/grid_env"
LN

grep -E "^oracle" /etc/sudoers >/dev/null 2>&1
if [ $? -ne 0 ]
then
	line_separator
	info "Config sudo for user oracle"
	exec_cmd "cp /etc/sudoers /tmp/suoracle"
	exec_cmd "echo \"oracle  ALL=(grid)  NOPASSWD:ALL\" >> /tmp/suoracle"
	exec_cmd "echo \"grid  ALL=(oracle)  NOPASSWD:ALL\" >> /tmp/suoracle"
	exec_cmd "visudo -c -f /tmp/suoracle"
	exec_cmd "mv /tmp/suoracle /etc/sudoers"
	LN
fi
