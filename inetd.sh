#!/bin/sh /etc/rc.common
# Copyright (C) 1999–2019 NPO NpoTelecom.ru
# Copyright (C) 2019 Yunusov Ruslan

START=60
STOP=20
USE_PROCD=1
#PROCD_DEBUG=1

NAME=inetd
PROG=/usr/sbin/inetd
CFG_FILE=/tmp/inetd.conf

prepare_cfg_file() {
    > ${CFG_FILE}
    echo "# The script created this file, don't edit it." > ${CFG_FILE}
}

write_to_cfg_file() {
    echo "${1}" >> ${CFG_FILE}
}

ftp_instance() {
    local enable port directory interface upload user \
        idle_timeout abs_timeout
    uci_validate_section ${NAME} ${NAME} ftpd \
        'enable:bool:1' \
        'port:list(port):22' \
        'directory:string:/tmp' \
        'interface:list(string)' \
        'upload:bool:1' \
        'user:string:root' \
        'idle_timeout:uinteger' \
        'abs_timeout:uinteger'|| {
       echo "validation failed"
       return 1
    }
    [[ "${enable}" -eq 0 ]] && {
        return 1
    }
    record="${port} stream tcp nowait ${user} ftpd ftpd"
    [[ "${upload}" -eq 1 ]] && record="${record} -w"
    [[ -n "${idle_timeout}" ]] && record="${record} -t ${idle_timeout}"
    [[ -n "${abs_timeout}" ]] && record="${record} -T ${abs_timeout}"
    record="${record} ${directory}"
    write_to_cfg_file "${record}"
    return 0
}

telnet_instance() {
    local enable BannerFile interface port user
    uci_validate_section ${NAME} ${NAME} telnetd \
        'enable:bool:1' \
        'interface:list(string)' \
        'port:list(port):23' \
        'user:string:root' \
        'BannerFile:string:/etc/banner'|| {
       echo "validation failed"
       return 1
    }
    [[ "${enable}" -eq 0 ]] && {
        return 1
    }
    record="${port} stream tcp nowait ${user} telnetd telnetd"
    [[ -n "${BannerFile}" ]] && record="${record} -f ${BannerFile}"
    write_to_cfg_file "${record}"
    return 0
}

start_service() {
    local service
    prepare_cfg_file
    config_load ${NAME}
    procd_open_instance ${NAME}
    procd_set_param command ${PROG} -f ${CFG_FILE}
    procd_set_param respawn
    procd_set_param file ${CFG_FILE}
    procd_open_data
    json_add_array firewall
# firewall rule
    json_close_array
    json_add_array service
    ftp_instance
    [[ $? -eq 0 ]] && json_add_string "ftpd" "ftpd"
    telnet_instance
    [[ $? -eq 0 ]] && json_add_string "telnetd" "telnetd"
    json_close_array
    procd_close_data
    procd_close_instance
}

stop_service() {
    pidof "${NAME}" >/dev/null 2>&1
    [[ $? -ne 0 ]] && return 1

    rm ${CFG_FILE} 2>/dev/null
    json_load "$(ubus call service get_data '{"name":"inetd","instance":"inetd","type":"service"}')"
    json_select "inetd"
    json_select "inetd"
    json_select "service"

    local Index="1" Status
    while json_get_type Status ${Index} && [[ "${Status}" = string ]]; do
        json_get_var Status "$((Index++))"
        killall "${Status}" 2>/dev/null
    done
}

