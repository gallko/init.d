#!/bin/sh /etc/rc.common
# Copyright (C) 1999–2019 NPO NpoTelecom.ru
# Copyright (C) 2019 Yunusov Ruslan

START=12
STOP=89

USE_PROCD=1
#PROCD_DEBUG=1

NAME=syslogd
PROG=/sbin/syslogd

#        -n              Run in foreground
#        -R HOST[:PORT]  Log to HOST:PORT (default PORT:514)
#        -L              Log locally and via network (default is network only if -R)
#        -C[size_kb]     Log to shared mem buffer (use logread to read it)
#        -K              Log to kernel printk buffer (use dmesg to read it)
#        -O FILE         Log to FILE (default: /var/log/messages, stdout if -)
#        -s SIZE         Max size (KB) before rotation (default 200KB, 0=off)
#        -b N            N rotated logs to keep (default 1, max 99, 0=purge)
#        -l N            Log only messages more urgent than prio N (1-8)
#        -S              Smaller output
#        -D              Drop duplicates
#        -f FILE         Use FILE as config (default:/etc/syslog.conf)

validate_syslog() {
    uci_validate_section system system "${1}" \
        'log_local:bool:0' \
        'log_level:range(1,8):5' \
        'log_file:string:/tmp/log/messages.log' \
        'log_size:uinteger:200' \
        'log_count:range(0,99):1' \
        'log_remote:bool:0' \
        'log_ip:ipaddr' \
        'log_port:port:514'
}

start_syslog_daemon() {
    local log_local log_kernel log_level log_file \
          log_size log_count log_remote log_ip log_port args
    validate_syslog "${1}"
    [[ "${log_local}" -eq 1 ]] && {
        [[ -n "${log_file}" ]] && args="${args} -O ${log_file}"
        [[ -n "${log_size}" ]] && args="${args} -s ${log_size}"
        [[ -n "${log_count}" ]] && args="${args} -b ${log_count}"
    }
    [[ "${log_remote}" -eq 1 ]] && {
        [[ -n "${log_ip}" ]] && args="${args} -R ${log_ip}:${log_port}" || log_remote=0
    }
    [[ -n "${log_level}" ]] && args="${args} -l ${log_level}"
    [[ "${log_local}" -eq 1 && "${log_remote}" -eq 1 ]] && args="-L${args}"
    [[ "${log_local}" -eq 0 && "${log_remote}" -eq 0 ]] && return 1
    procd_open_instance ${NAME}
    procd_set_param command ${PROG} -n ${args}
    procd_set_param respawn
    procd_close_instance
}

start_service() {
    config_load system
    config_foreach start_syslog_daemon system
}

stop_service() {
    killall ${NAME} 2>/dev/null
}
