# ============================================================================
# Функции работы с opkg
# ============================================================================
configure_opkg() {
    log_info "Настройка opkg..."
    
    # Сохранение списков пакетов на extroot
    if grep -q "^lists_dir\s*ext\s*/usr/lib/opkg/lists" /etc/opkg.conf 2>/dev/null; then
        log_info "Конфигурация opkg уже настроена"
    else
        sed -i -r -e "s/^(lists_dir\sext\s).*/\1\/usr\/lib\/opkg\/lists/" /etc/opkg.conf
        log_success "Конфигурация opkg обновлена"
    fi
}

update_opkg() {
    log_info "Обновление списков пакетов..."

    local retry=0
    while [ $retry -lt $RETRY_COUNT ]; do
        if opkg update > /tmp/opkg_update.log 2>&1; then
            log_success "Списки пакетов успешно обновлены"
            cat /tmp/opkg_update.log >> "$LOG_FILE"
            rm -f /tmp/opkg_update.log
            return 0
        else
            retry=$((retry + 1))
            log_warn "Попытка $retry из $RETRY_COUNT не удалась"
            sleep 5
        fi
    done
    
    log_error "Не удалось обновить списки пакетов после $RETRY_COUNT попыток"
    cat /tmp/opkg_update.log >> "$LOG_FILE"
    rm -f /tmp/opkg_update.log
    return 1
}

install_package() {
    local pkg=$1
    local retry=0
    
    if opkg list-installed | grep -q "^$pkg "; then
        log_info "Пакет $pkg уже установлен"
        return 0
    fi
    
    log_info "Установка пакета: $pkg"
    
    while [ $retry -lt $RETRY_COUNT ]; do
        if opkg install "$pkg" > /tmp/opkg_install.log 2>&1; then
            cat /tmp/opkg_install.log >> "$LOG_FILE"
            log_success "Пакет $pkg успешно установлен"
            rm -f /tmp/opkg_install.log
            return 0
        else
            retry=$((retry + 1))
            log_warn "Попытка $retry из $RETRY_COUNT установки $pkg не удалась"
            sleep 5
        fi
    done
    
    log_error "Не удалось установить пакет $pkg после $RETRY_COUNT попыток"
    cat /tmp/opkg_install.log >> "$LOG_FILE"
    rm -f /tmp/opkg_install.log
    
    if [ $AUTO_MODE -eq 0 ]; then
        echo -n "Продолжить выполнение? (y/N): " >&3
        read -r answer
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            exit 1
        fi
    fi
    
    return 1
}