#!/bin/bash
# coding: utf8

pb::config() {
	## perlbottler config
	## adjust this according to your preferences
	
	PB_ROOT="${HOME}/perlbrew-here";
	PB_HOME="${ROOT}/.perlbrew";
	PB_VERSION="5.14.1";
	PB_MODULES=(
		Mojolicious
		Moose
	);
	PB_RMTEMPS=0;
};

pb::config.set_default() {
	## set config variables to their expected defaults
	## do not edit
	
	PB_ROOT="${HOME}/perl5/perlbrew";
	PB_HOME="${HOME}/.perlbrew";
	PB_VERSION="5.14.1";
	PB_MODULES=();
	PB_TEMP="${HOME}/.pb-temp-$RANDOM";
	PB_RMTEMPS=1;
	
	# PB_URL_PERLBREWINSTALL="http://xrl.us/perlbrewinstall"; # this was down during tests, so dereferenced link is used below
	PB_URL_PERLBREWINSTALL="https://raw.github.com/gugod/App-perlbrew/master/perlbrew-install";
	PB_URL_CPANMINUS="http://cpanmin.us";
};

pb::rmtemp() {
	if (( $PB_RMTEMPS )); then
		rm -f "$@";
	fi;
}

pb::_log() {
	pb::_lograw "[`date`] $@";
};

pb::_lograw() {
	echo -n -e "$@";
};

pb::log.debug() {
	pb::_log "DEBUG: $@\n";
};

pb::log.info() {
	pb::_log "* $@\n";
};

pb::log.warning() {
	pb::_log "!!! Warning: $@\n";
};

pb::log.error() {
	pb::_log "!!! ERROR: $@\n";
};

pb::log.fatal() {
	pb::_log "!!! FATAL: $@\n";
};

pb::log.progress.start() {
	pb::_log "=== $@"
};

pb::log.progress.ok() {
	pb::_lograw "   [ OK ]\n"
};

pb::log.progress.fail() {
	pb::_lograw "   [FAIL]\n"
};

pb::init() {
	pb::init.welcome;
	pb::init.load_config;
	pb::init.print_target_info;
	pb::init.tempdir;
};

pb::init.welcome() {
	pb::log.info "Started perlbottler-0.01.";
};

pb::init.load_config() {
	pb::config.set_default;
	pb::config;
};

pb::init.print_target_info() {
	local module_name;
	
	pb::log.debug "Perlbrew root: ${PB_ROOT}";
	
	if (( ${#PB_MODULES[@]} )); then {
		pb::log.info "${#PB_MODULES[@]} module(s) to be installed.";
		for module_name in ${PB_MODULES[@]}; do {
			pb::log.debug "\t * ${module_name}";
		}; done;
	} else {
		pb::log.info "No modules to be installed";
	} fi;
};

pb::init.tempdir() {
	mkdir -p ${PB_TEMP};
	
	return $?;
}

pb::app_exists() {
	if $(type $1 &>/dev/null); then {
		pb::log.info "Found $1";
		
		return 0;
	} else {
		pb::log.fatal "There is no $1 available. Please, install $1 in order to proceed.";
		
		return 1;
	} fi;
};

pb::folded_exec() {
	local output_log="${PB_TEMP}/pb-log-$RANDOM";
#	local output_log="${PB_TEMP}/pb-log";
	local __errcode;
	
	pb::log.progress.start "$1 (tail -f ${output_log} to monitor progress)";
	{
		{
			eval "$2";
		} &>${output_log};
		__errcode=$?;
		( # ugly hack to restore errcode
			exit ${__errcode};
		)
	} && {
		pb::log.progress.ok;
		pb::rmtemp ${output_log};
		
		return 0;
	} || {
		pb::log.progress.fail;
		pb::log.error "Failed with retcode ${__errcode}. Output log: ${output_log}";
		
		return 1;
	};
};

pb::install_perlbrew() {
	local perlbrewinstall="${PB_TEMP}/perlbrewinstall";
	
	{
		pb::folded_exec "Downloading Perlbrew..." "curl -Lk ${PB_URL_PERLBREWINSTALL} -o ${perlbrewinstall};";
	} && {
		export PERLBREW_ROOT="${PB_ROOT}";
		export PERLBREW_HOME="${PB_HOME}";
		export TMPDIR="${PB_TEMP}";
		mkdir -p ${PERLBREW_HOME};
		
		pb::folded_exec "Installing Perlbrew..." "bash ${perlbrewinstall};";
	} && {
		pb::rmtemp ${perlbrewinstall};
	};
	
	return $?;
};

pb::init_perlbrew() {
	pb::folded_exec "Initializing Perlbrew..." "${PB_ROOT}/bin/perlbrew init;";
	source ${PB_ROOT}/etc/bashrc;
	hash -r;
	
	return $?;
};

pb::update_bashrc() {
	local bashrc="${HOME}/.bashrc";
	local output_log="${PB_TEMP}/pb-log-$RANDOM";
	local __errcode;
	
	touch ${bashrc};
	(grep "# Please do not edit or remove this line \[perlbrew\]" ${bashrc} &>/dev/null) && {
		pb::log.info "No need to update ${bashrc}, already up to date";
	} || {
		pb::log.progress.start "Updating ${bashrc}...";
		
		{
			(
				{
					echo;
					echo "# Please do not edit or remove this line [perlbrew]";
					echo "export PERLBREW_ROOT=${PB_ROOT}";
					echo "export PERLBREW_HOME=${PB_HOME}";
					echo "source ${PB_ROOT}/etc/bashrc";
					echo;
				} >>${bashrc};
			) &>${output_log};
			__errcode=$?;
		} && {
			pb::log.progress.ok;
			pb::rmtemp ${output_log};
			
			source ${bashrc};
			
			return 0;
		} || {
			pb::log.progress.fail;
			pb::log.error "Failed with retcode ${__errcode}. Output log: ${output_log}";
			
			return 1;
		};
	};
};

pb::load_envdump() {
	local envdump=$1;
	local oldIFS;
	local line;
	local env_key;
	local env_value;
	
	while read line; do
		oldIFS=$IFS;
		IFS="=";
		
		set -- $line;
		
		env_key="$1";
		shift;
		env_value="$*";
		
		export "$env_key"="$env_value";
		pb::log:debug "$env_key"="$env_value";
	done < ${envdump};
}

pb::install_perl() {
	local envdump="${PB_TEMP}/env";
	
	{
		if ${PB_ROOT}/bin/perlbrew list | grep "perl-${PB_VERSION}" &>/dev/null; then {
			pb::log.info "perl-${PB_VERSION} is already installed";
		} else {
			pb::folded_exec "Installing perl-${PB_VERSION}..." "${PB_ROOT}/bin/perlbrew install ${PB_VERSION}";
		}; fi;
	} && {
		pb::log.debug "Cleaning envdump file"
		pb::rmtemp ${envdump} &>/dev/null;
		
#		pb::folded_exec "Update current environment to use perl-${PB_VERSION}..." "echo 'env >${envdump} && exit' | ${PB_ROOT}/bin/perlbrew use ${PB_VERSION}";
#		if [ -f ${envdump} ]; then {
#			pb::log.debug "perlbrew started subshell, so we have envdump";
#			pb::load_envdump ${envdump};
#			rm -f ${envdump};
#		} else {
#			pb::log.debug "perlbrew used current shell, so we do nothing";
#		}; fi;
		pb::folded_exec "Update current environment to use perl-${PB_VERSION}..." "perlbrew use ${PB_VERSION}";
	};
	
	return $?;
};

pb::install_cpanminus() {
	local cpanminusinstall="${PB_TEMP}/cpanminusinstall";
	
	{
		pb::folded_exec "Downloading cpanminus..." "curl -Lk ${PB_URL_CPANMINUS} -o ${cpanminusinstall};";
	} && {
		pb::folded_exec "Installing cpanminus..." "cat ${cpanminusinstall} | perl - App::cpanminus";
	} && {
		pb::rmtemp ${cpanminusinstall};
	};
	
	return $?;
};

pb::install_modules() {
	local module_name;
	
	if (( ${#PB_MODULES[@]} )); then {
		pb::log.info "${#PB_MODULES[@]} module(s) to be installed.";
		
		for module_name in ${PB_MODULES[@]}; do {
			{
				pb::folded_exec "Installing module ${module_name}..." "cpanm ${module_name}";
			} || {
				return 1;
			};
		}; done;
	} else {
		pb::log.info "No modules to be installed";
	} fi;
	
	return 0;
};

pb::cleanup() {
	pb::folded_exec "Cleaning now temporary directory ${PB_TEMP}..." "rm -rf ${PB_TEMP}";
	
	return $?;
}

pb::finished() {
	pb::log.info "Finished installation, everything should be fine now."
}

pb::main() {
	## entry function
	
	pb::init;
	pb::app_exists curl || return 1;
	pb::install_perlbrew || return 2;
	pb::init_perlbrew || return 3;
	pb::update_bashrc || return 4;
	pb::install_perl || return 5;
	pb::install_cpanminus || return 6;
	pb::install_modules || return 7;
	pb::cleanup || return 8;
	pb::finished;
	
	return 0;
};

pb::main "$@";
exit $?;
