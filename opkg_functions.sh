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

replace_package() {
    local old_pkg=$1
    local new_pkg=$2
    
    log_info "Замена пакета $old_pkg на $new_pkg..."
    
    if ! opkg list-installed | grep -q "^$old_pkg "; then
        log_info "Пакет $old_pkg не установлен"
    fi
    
    if opkg list-installed | grep -q "^$new_pkg "; then
        log_info "Пакет $new_pkg уже установлен"
        return 0
    fi
    
    # Создаем временную директорию для кэша
    local tmp_dir="/tmp"
    
    # Скачиваем новый пакет
    if ! opkg download "$new_pkg" --cache /tmp > /tmp/opkg_download.log 2>&1; then
        log_error "Не удалось скачать пакет $new_pkg"
        cat /tmp/opkg_download.log >> "$LOG_FILE"
        rm -rf /tmp/opkg_download.log
        return 1
    fi
    
    # Удаляем старый пакет
    if opkg list-installed | grep -q "^$old_pkg "; then
        log_info "Удаление пакета $old_pkg..."
        if ! opkg remove "$old_pkg" --force-depends > /tmp/opkg_remove.log 2>&1; then
            log_warn "Проблемы при удалении $old_pkg"
            cat /tmp/opkg_remove.log >> "$LOG_FILE"
        fi
        rm -f /tmp/opkg_remove.log
    fi
    
    # Устанавливаем новый пакет
    if opkg install "$new_pkg" --cache /tmp > /tmp/opkg_install.log 2>&1; then
        cat /tmp/opkg_install.log >> "$LOG_FILE"
        log_success "Пакет $new_pkg успешно установлен"
        rm -rf /tmp/opkg_install.log /tmp/opkg_download.log
        return 0
    else
        log_error "Не удалось установить пакет $new_pkg"
        cat /tmp/opkg_install.log >> "$LOG_FILE"
        rm -rf /tmp/opkg_install.log /tmp/opkg_download.log
        return 1
    fi
}