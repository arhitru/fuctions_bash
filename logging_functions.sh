# ============================================================================
# Функции логирования
# ============================================================================
init_logging() {
    # Проверяем, не инициализировано ли уже логирование
    if [ -z "$LOGGING_INITIALIZED" ]; then
        # Создаем директорию для логов если её нет
        if [ ! -d "$LOG_DIR" ]; then
            mkdir -p "$LOG_DIR"
        fi
        
        # Перенаправляем весь вывод в лог-файл и в syslog
        exec 3>&1 4>&2
        exec 1> >(tee -a "$LOG_FILE" | logger -t "$SCRIPT_NAME" -p user.info)
        exec 2> >(tee -a "$LOG_FILE" | logger -t "$SCRIPT_NAME" -p user.err)
        
        LOGGING_INITIALIZED=1
        export LOGGING_INITIALIZED
        
        echo "================================================================================"
        echo "=== Начало установки: $(date) ==="
        echo "=== Режим выполнения: $([ $AUTO_MODE -eq 1 ] && echo "AUTO" || echo "INTERACTIVE") ==="
        echo "=== Лог-файл: $LOG_FILE ==="
        echo "================================================================================"
    fi
}

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    printf "\033[32;1m[INFO] %s\033[0m\n" "$1" >&3 2>/dev/null || true
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    printf "\033[33;1m[WARN] %s\033[0m\n" "$1" >&3 2>/dev/null || true
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    printf "\033[31;1m[ERROR] %s\033[0m\n" "$1" >&3 2>/dev/null || true
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    printf "\033[34;1m[SUCCESS] %s\033[0m\n" "$1" >&3 2>/dev/null || true
}

log_debug() {
    if [ "$DEBUG" = "1" ]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1"
        printf "\033[36;1m[DEBUG] %s\033[0m\n" "$1" >&3 2>/dev/null || true
    else
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

log_question() {
    echo "[QUESTION] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    printf "[QUESTION] %s" "$1" >&3 2>/dev/null || true
}

log_questions() {
    echo "[QUESTION] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    printf "[QUESTION] %s\n" "$1" >&3 2>/dev/null || true
}

