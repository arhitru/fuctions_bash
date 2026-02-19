# ============================================================================
# Функции проверки системы
# ============================================================================
check_system_load() {
    # Проверяем что система загрузилась
    log_info "Проверка системы:"
    uptime >> $LOG_FILE 2>&1
    ifconfig >> $LOG_FILE 2>&1
}

check_net_up() {
    local NET_WAIT_SEC=$1
    # Ждем запуска сети
    log_info "Ожидание сети..."
    for i in $(seq 1 $NET_WAIT_SEC); do
        if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
            log_success "Сеть доступна"
            break
        fi
        sleep 1
    done
}

check_model_router() {
    # Проверка модели устройства
    if [ -f /tmp/sysinfo/model ]; then
        MODEL_ROUTER=$(cat /tmp/sysinfo/model)
        log_info "Модель устройства: $MODEL_ROUTER"
    else
        MODEL_ROUTER="Unknown"
        log_warn "Не удалось определить модель устройства"
    fi
    export MODEL_ROUTER
}

check_version_openwrt(){
    # Проверка версии OpenWrt
    if [ -f /etc/os-release ]; then
        # shellcheck source=/etc/os-release
        . /etc/os-release
        log_info "Версия OpenWrt: $OPENWRT_RELEASE"
        
        VERSION=$(grep 'VERSION=' /etc/os-release | cut -d'"' -f2)
        VERSION_ID=$(echo "$VERSION" | awk -F. '{print $1}')
        
        # Проверка совместимости
        if [ "$VERSION_ID" -lt 19 ]; then
            log_warn "Версия OpenWrt ($VERSION_ID) может быть несовместима"
        fi
    else
        VERSION_ID=0
        log_warn "Не удалось определить версию OpenWrt"
    fi
    export VERSION_ID
}

check_disk_space() {
    local need_free_spase=$1
    local free_space
    free_space=$(df /overlay | awk 'NR==2 {print $4}')
    local free_space_mb=$((free_space / 1024))
    
    log_info "Свободное место на overlay: ${free_space_mb}MB"
    
    if [ "$free_space_mb" -lt $need_free_spase ]; then
        log_error "Недостаточно свободного места ($free_space_mb). Требуется минимум $need_free_spase"
        if [ $AUTO_MODE -eq 0 ] && [ -t 0 ]; then
            echo -n "Продолжить? (y/N): " >&3
            read -r answer
            if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

check_internet() {
    log_info "Проверка подключения к интернету..."
    
    local test_hosts="openwrt.org google.com cloudflare.com"
    local connected=0
    
    for host in $test_hosts; do
        if ping -c 1 -W 3 "$host" >/dev/null 2>&1; then
            log_info "Подключение к $host успешно"
            connected=1
            break
        fi
    done
    
    if [ $connected -eq 0 ]; then
        log_error "Нет подключения к интернету"
        return 1
    fi
    
    return 0
}

check_time_sync() {
    log_info "Проверка синхронизации времени..."
    
    local current_year
    current_year=$(date +%Y)
    
    if [ "$current_year" -lt 2023 ]; then
        log_warn "Время не синхронизировано: $(date)"
        
        if [ $AUTO_MODE -eq 1 ]; then
            log_info "Автоматическая синхронизация времени..."
            for ntp_server in $NTP_SERVERS; do
                if ntpd -n -q -p "$ntp_server" >/dev/null 2>&1; then
                    log_success "Время синхронизировано с $ntp_server"
                    break
                fi
            done
        else
            echo -n "Синхронизировать время? (Y/n): " >&3
            read -r answer
            if [ "$answer" != "n" ] && [ "$answer" != "N" ]; then
                for ntp_server in $NTP_SERVERS; do
                    if ntpd -n -q -p "$ntp_server" >/dev/null 2>&1; then
                        log_success "Время синхронизировано с $ntp_server"
                        break
                    fi
                done
            fi
        fi
    else
        log_info "Время синхронизировано: $(date)"
    fi
}
