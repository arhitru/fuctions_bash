# ============================================================================
# Функции управления выполнением
# ============================================================================
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Этот скрипт должен выполняться от root"
        exit 1
    fi
}

check_single_instance() {
    if [ -f "$LOCK_FILE" ]; then
        if kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
            log_error "Скрипт уже запущен (PID: $(cat "$LOCK_FILE"))"
            exit 1
        else
            log_warn "Обнаружен устаревший lock-файл, удаляем"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE" "$PID_FILE"; log_info "Скрипт завершен"; exec 1>&3 2>&4' EXIT
    echo $$ > "$PID_FILE"
}
