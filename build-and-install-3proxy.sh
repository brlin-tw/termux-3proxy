#!/usr/bin/env bash
# Build and install 3proxy from its source code
#
# Copyright 2024 林博仁(Buo-ren, Lin) <buo.ren.lin+copyright@gmail.com>
# SPDX-License-Identifier: CC-BY-SA-4.0

printf \
    'Info: Configuring the defensive interpreter behaviors...\n'
set_opts=(
    # Terminate script execution when an unhandled error occurs
    -o errexit
    -o errtrace

    # Terminate script execution when an unset parameter variable is
    # referenced
    -o nounset
)
if ! set "${set_opts[@]}"; then
    printf \
        'Error: Unable to configure the defensive interpreter behaviors.\n' \
        1>&2
    exit 1
fi

printf \
    'Info: Checking the existence of the required commands...\n'
required_commands=(
    date
    mktemp
    pkg
    realpath
)
flag_required_command_check_failed=false
for command in "${required_commands[@]}"; do
    if ! command -v "${command}" >/dev/null; then
        flag_required_command_check_failed=true
        printf \
            'Error: This program requires the "%s" command to be available in your command search PATHs.\n' \
            "${command}" \
            1>&2
    fi
done
if test "${flag_required_command_check_failed}" == true; then
    printf \
        'Error: Required command check failed, please check your installation.\n' \
        1>&2
    exit 1
fi

printf \
    'Info: Configuring the convenience variables...\n'
if test -v BASH_SOURCE; then
    # Convenience variables may not need to be referenced
    # shellcheck disable=SC2034
    {
        printf \
            'Info: Determining the absolute path of the program...\n'
        if ! script="$(
            realpath \
                --strip \
                "${BASH_SOURCE[0]}"
            )"; then
            printf \
                'Error: Unable to determine the absolute path of the program.\n' \
                1>&2
            exit 1
        fi
        script_dir="${script%/*}"
        script_filename="${script##*/}"
        script_name="${script_filename%%.*}"
    }
fi
# Convenience variables may not need to be referenced
# shellcheck disable=SC2034
{
    script_basecommand="${0}"
    script_args=("${@}")
}

printf \
    'Info: Setting the ERR trap...\n'
trap_err(){
    printf \
        'Error: The program prematurely terminated due to an unhandled error.\n' \
        1>&2
    exit 99
}
if ! trap trap_err ERR; then
    printf \
        'Error: Unable to set the ERR trap.\n' \
        1>&2
    exit 1
fi

printf \
    'Info: Checking runtime parameters...\n'
if ! test -v PREFIX; then
    printf \
        'Error: Termux environment not detected.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing the runtime dependency packages...\n'
runtime_dependencies_pkgs=(
    binutils
    git
    make
)
if ! pkg install "${runtime_dependencies_pkgs[@]}"; then
    printf \
        'Error: Unable to install the runtime dependency packages.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Determining the operation timestamp...\n'
if ! operation_timestamp="$(date +%Y%m%d-%H%M%S)"; then
    printf \
        'Error: Unable to determine the operation timestamp.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Creating the temporary directory...\n'
mktemp_opts=(
    -d
    -t
)
if ! tmpdir="$(mktemp "${mktemp_opts[@]}" "${script_name}-${operation_timestamp}.XXXXXX")"; then
    printf \
        'Error: Unable to create the temporary directory.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Setting the EXIT trap to cleanup the temporary directory...\n'
trap_exit(){
    if test -e "${tmpdir}"; then
        if ! rm -rf "${tmpdir}"; then
            printf \
                'Warning: Unable to cleanup the %s temporary directory.\n' \
                "${tmpdir}" \
                1>&2
        fi
    fi
}
if ! trap trap_exit EXIT; then
    printf \
        'Error: Unable to set the EXIT trap.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Changing the working directory to %s...\n' \
    "${tmpdir}"
if ! cd "${tmpdir}"; then
    printf \
        'Error: Unable to change the working directory to %s.' \
        "${tmpdir}" \
        1>&2
    exit 2
fi

printf \
    'Info: Fetching a copy of the 3proxy source code...\n'
git_clone_opts=(
    --depth=100
)
if ! git clone "${git_clone_opts[@]}" https://github.com/3proxy/3proxy.git; then
    printf \
        'Error: Unable to fetch a copy of the 3proxy source code.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Changing the working directory to the 3proxy source directory...\n'
if ! cd 3proxy; then
    printf \
        'Error: Unable to change the working directory to the 3proxy source directory.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Enabling the Linux Makefile...\n'
ln_opts=(
    # Create symbolic link
    -s
)
if ! ln "${ln_opts[@]}" Makefile.Linux Makefile; then
    printf \
        'Error: Unable to enable the Linux Makefile...\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Building 3proxy...\n'
make_params=(
    prefix="${PREFIX}/local"
    man_prefix="${PREFIX}/local"
    chroot_prefix="${PREFIX}/local"
    CHROOTREL=../../local/3proxy
    ETCDIR="${PREFIX}/etc/3proxy"
    SHELL='sh -x'
)
if ! make "${make_params[@]}"; then
    printf \
        'Error: Unable to build 3proxy.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing 3proxy...\n'
make_params+=(
    INSTALL="${PREFIX}/bin/install"
)
if ! make install "${make_params[@]}"; then
    printf \
        'Error: Unable to install 3proxy.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Operation completed without errors.\n'
