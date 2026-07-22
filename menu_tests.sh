#!/bin/bash
source /usr/local/bin/_config_and_utils.sh

# ----------------------------------------------------------------------
# ТЕСТЫ И СКАНЕР (Вынесенный блок)
# ----------------------------------------------------------------------

function prepare_scanner {
    SCANNER_DIR="/root/scanner"
    SCANNER_BIN="$SCANNER_DIR/RealiTLScanner"
    MMDB_FILE="$SCANNER_DIR/Country.mmdb"

    # Создаем папку, если ее нет
    if [ ! -d "$SCANNER_DIR" ]; then
        mkdir -p "$SCANNER_DIR"
    fi

    # Проверка бинарника (XTLS)
    if [ ! -f "$SCANNER_BIN" ]; then
        echo -e "${YELLOW}>>> Сканер не найден. Загрузка RealiTLScanner (XTLS)...${NC}"
        wget -qO "$SCANNER_BIN" "https://github.com/XTLS/RealiTLScanner/releases/latest/download/RealiTLScanner-linux-64"
        chmod +x "$SCANNER_BIN"
    fi

    # Проверка GeoIP базы (Loyalsoldier)
    if [ ! -f "$MMDB_FILE" ]; then
        echo -e "${YELLOW}>>> База GeoIP не найдена. Загрузка Country.mmdb (Loyalsoldier)...${NC}"
        wget -qO "$MMDB_FILE" "https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb"
    fi
    
    # Указываем путь к бинарнику для функции run_scanner
    SCANER_PATH="$SCANNER_BIN"
    cd "$SCANNER_DIR" || return
}

function run_scanner {
    # Сначала проверяем и загружаем файлы
    prepare_scanner

    PARAMS=""
    
    echo -e "\n${CYAN}>>> ЗАПУСК Realitls Scaner${NC}"
    echo -e "${YELLOW}Доступные параметры:${NC}"
    echo "  1) 📄  -in (Файл со списком IP/CIDR)"
    echo "  2) 🎯  -addr (Один IP/CIDR или домен)"
    echo "  3) 🌐  -url (URL со списком доменов)"
    echo -e " ${RED}X) ❌  Отмена${NC}"
    
    read -p "Выберите метод ввода [1-3, X]: " method

    case $method in
        1) read -p "Путь к файлу (-in): " INPUT_VAL;
            PARAMS+=" -in $INPUT_VAL" ;;
        2) read -p "IP/Домен (-addr): " INPUT_VAL; PARAMS+=" -addr $INPUT_VAL" ;;
        3) read -p "URL (-url): " INPUT_VAL; PARAMS+=" -url $INPUT_VAL" ;;
        [Xx]) echo -e "${RED}Отмена запуска.${NC}"; return ;;
        *) echo -e "${RED}❌ Неверный ввод.${NC}"; return ;;
    esac

    read -p "Порт (default 443): " PORT_VAL
    if [[ ! -z "$PORT_VAL" ]]; then PARAMS+=" -port $PORT_VAL"; fi

    read -p "Потоки (default 2): " THREAD_VAL
    if [[ ! -z "$THREAD_VAL" ]]; then PARAMS+=" -thread $THREAD_VAL"; fi

    read -p "Таймаут (default 10): " TIMEOUT_VAL
    if [[ ! -z "$TIMEOUT_VAL" ]]; then PARAMS+=" -timeout $TIMEOUT_VAL"; fi

    read -p "Файл вывода (default out.csv): " OUTPUT_VAL
    if [[ ! -z "$OUTPUT_VAL" ]]; then PARAMS+=" -out $OUTPUT_VAL"; fi
    
    read -p "Использовать IPv6 (-46)? [y/N]: " IPV6_VAL
    if [[ "$IPV6_VAL" =~ ^[Yy]$ ]]; then PARAMS+=" -46"; fi

    read -p "Подробный вывод (-v)? [y/N]: " VERBOSE_VAL
    if [[ "$VERBOSE_VAL" =~ ^[Yy]$ ]]; then PARAMS+=" -v"; fi

    echo -e "\n${YELLOW}ЗАПУСК КОМАНДЫ:${NC} $SCANER_PATH $PARAMS"
    $SCANER_PATH $PARAMS
    echo -e "\n${GREEN}Scaner завершил работу.${NC}"
}
# ----------------------------------------------------------------------
# CENSORCHECK (встроенный, локальный запуск)
# ----------------------------------------------------------------------
CENSORCHECK_CONFIG_DIR="/root/.vps-menu"
CENSORCHECK_CONFIG_FILE="$CENSORCHECK_CONFIG_DIR/censorcheck.env"
CENSORCHECK_SCRIPT="/usr/local/bin/censorcheck.sh"
CENSORCHECK_FALLBACK_URL="https://raw.githubusercontent.com/adkudryashov/VPS-main-menu/main/censorcheck.sh"

function configure_ripe_key {
    mkdir -p "$CENSORCHECK_CONFIG_DIR"
    echo -e "\n${CYAN}>>> Настройка RIPE Atlas API-ключа${NC}"
    echo -e "${YELLOW}Ключ нужен для 'радара ТСПУ' — проверки доступности этого сервера из сетей РФ${NC}"
    echo -e "${YELLOW}(Ростелеком, МТС, МГТС, Билайн, ТТК, Мегафон и др.).${NC}"
    echo -e "Получить бесплатный ключ можно здесь: ${CYAN}https://atlas.ripe.net/keys/${NC}"

    if [[ -f "$CENSORCHECK_CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CENSORCHECK_CONFIG_FILE"
        if [[ -n "$RIPE_API_KEY" ]]; then
            echo -e "Текущий ключ: ${GREEN}${RIPE_API_KEY:0:8}...${NC}"
        fi
    fi

    read -p "Введите новый ключ (Enter — оставить без изменений): " NEW_KEY
    if [[ -n "$NEW_KEY" ]]; then
        printf -v NEW_KEY_ESC '%q' "$NEW_KEY"
        {
            echo "RIPE_API_KEY=$NEW_KEY_ESC"
        } > "$CENSORCHECK_CONFIG_FILE"
        chmod 600 "$CENSORCHECK_CONFIG_FILE"
        echo -e "${GREEN}✅ Ключ сохранён в $CENSORCHECK_CONFIG_FILE${NC}"
    else
        echo -e "${YELLOW}Оставлено без изменений.${NC}"
    fi
}

function run_censorcheck {
    local mode="$1" # all | geoblock | dpi
    local script="$CENSORCHECK_SCRIPT"

    if [[ ! -f "$script" ]]; then
        echo -e "${YELLOW}>>> Локальный censorcheck.sh не найден, загружаю актуальную версию...${NC}"
        script="/tmp/censorcheck.sh"
        if ! wget -qO "$script" "$CENSORCHECK_FALLBACK_URL"; then
            echo -e "${RED}❌ Не удалось загрузить censorcheck.sh. Проверьте подключение к интернету.${NC}"
            return
        fi
    fi
    chmod +x "$script" 2>/dev/null

    echo -e "${CYAN}>>> Запуск Censorcheck (режим: $mode)...${NC}"
    CENSORCHECK_CONFIG="$CENSORCHECK_CONFIG_FILE" bash "$script" --mode "$mode"
}

# ----------------------------------------------------------------------
# DPI DETECTOR & SNI SCAN
# ----------------------------------------------------------------------

function run_dpi_detector {
    echo -e "\n${CYAN}>>> Подготовка DPI Detector (через Docker)...${NC}"
    
    # 1. Проверяем, установлен ли Docker. Если нет — ставим штатным способом
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker не найден. Начинаю установку...${NC}"
        sudo apt-get update && sudo apt-get install -y docker.io
        sudo systemctl enable --now docker
        echo -e "${GREEN}Docker успешно установлен!${NC}"
    fi

    # 2. Запуск контейнера
    echo -e "${GREEN}✅ Запуск DPI Detector...${NC}"
    echo -e "${YELLOW}(Образ обновится автоматически. Для выхода нажмите Ctrl+C)${NC}"
    sleep 1
    
    # --rm удаляет контейнер после закрытия (не копит мусор)
    # -it запускает в интерактивном режиме с нормальным отображением меню
    # --pull=always всегда проверяет и качает свежую версию перед запуском
    sudo docker run --rm -it --pull=always ghcr.io/runnin4ik/dpi-detector:latest
    
    echo -e "\n${BLUE}------------------------------------------------------${NC}"
    read -p "Нажмите Enter для возврата в меню..."
}

function run_sni_scan {
    echo -e "\n${CYAN}>>> Подготовка SNI Scan...${NC}"
    
    # 1. Проверка Python3
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}Установка Python3...${NC}"
        sudo apt-get update && sudo apt-get install -y python3 git
    fi

    local DIR="/root/sni-scan"
    
    # 2. Клонирование или обновление
    if [ ! -d "$DIR" ]; then
        echo -e "${YELLOW}Клонирование репозитория...${NC}"
        git clone https://github.com/dewil/sni-scan.git "$DIR"
    else
        echo -e "${YELLOW}Обновление файлов...${NC}"
        cd "$DIR" && git pull -q
    fi

    cd "$DIR" || return

    # 3. Запрос параметров у пользователя
    echo -e "${BLUE}------------------------------------------------------${NC}"
    read -p "Укажите маску подсети для скана [по умолчанию 24]: " subnet_mask
    subnet_mask=${subnet_mask:-24}

    # 4. Запуск
    echo -e "${GREEN}✅ Запуск сканирования сети (/$subnet_mask)...${NC}"
    echo -e "${YELLOW}(Отчет будет сохранен в $DIR/report.md)${NC}"
    echo -e "${YELLOW}(Для прерывания нажмите Ctrl+C)${NC}"
    sleep 1
    
    python3 sni-scan.py -m "$subnet_mask" -o report.md
    
    echo -e "\n${GREEN}✅ Готово! Результаты можно посмотреть в $DIR/report.md${NC}"
    echo -e "${BLUE}------------------------------------------------------${NC}"
    read -p "Нажмите Enter для возврата в меню..."
}
function run_tests_menu {
    while true; do
        clear
        echo -e "${CYAN}======================================================${NC}"
        echo -e "${CYAN}             🧪 МЕНЮ ТЕСТОВ СЕРВЕРА 🧪                ${NC}"
        echo -e "${CYAN}======================================================${NC}"
        echo -e "${YELLOW}1) 🌍  IP region${NC}"
        echo -e "${YELLOW}2) 🚧  Censorcheck: проверка геоблока (доступность сервисов)${NC}"
        echo -e "${YELLOW}3) 🇷🇺  Censorcheck: радар ТСПУ (доступность сервера из сетей РФ)${NC}"
        echo -e "${YELLOW}4) 🧪  Censorcheck: полная проверка (геоблок + радар ТСПУ)${NC}"
        echo -e "${YELLOW}5) 🔑  Censorcheck: настроить RIPE Atlas API-ключ${NC}"
        echo -e "${YELLOW}6) 🚀  Тест до российских iPerf3 серверов${NC}"
        echo -e "${YELLOW}7) 📊  YABS Benchmark${NC}"
        echo -e "${YELLOW}8) 🛡️   IPQuality. Проверка IP сервера на блокировки зарубежными сервисами${NC}"
        echo -e "${YELLOW}9) 📡  Параметры сервера и проверка скорости к зарубежным провайдерам${NC}"
        echo -e "${YELLOW}10)💻  Тест на процессор${NC}"
        echo -e "${YELLOW}11)🔍  Запуск Realitls Scaner${NC}"
		echo -e "${YELLOW}12)🕵️‍♂️  Запустить DPI Detector (Анализ цензуры)${NC}"
        echo -e "${YELLOW}13)🔍  Запустить SNI Scan (Скан подсети)${NC}"
        echo -e "${RED}X) 🔙  Назад в главное меню${NC}"
        echo -e "${BLUE}------------------------------------------------------${NC}"
        
        read -p "Ваш выбор [1-13, X]: " choice
        echo ""

        case $choice in
            1)
                echo -e "${CYAN}>>> Запуск IP region...${NC}"
                bash <(wget -qO- https://ipregion.vrnt.xyz)
                ;;
            2) run_censorcheck geoblock ;;
            3) run_censorcheck dpi ;;
            4) run_censorcheck all ;;
            5) configure_ripe_key ;;
            6)
			# --- ПРОВЕРКА И УСТАНОВКА IPERF3 ---
if ! command -v iperf3 &> /dev/null; then
    echo -e "${YELLOW}>>> iperf3 не найден. Установка...${NC}"
    sudo apt update && sudo apt install -y iperf3
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ iperf3 успешно установлен.${NC}"
    else
        echo -e "${RED}✗ Ошибка при установке iperf3. Тесты могут не работать.${NC}"
    fi
fi
                echo -e "${CYAN}>>> Тест до российских iPerf3 серверов...${NC}"
                bash <(wget -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh)
                ;;
			7)
                echo -e "${CYAN}>>> Запуск YABS...${NC}"
                curl -sL yabs.sh | bash -s -- -4
                ;;
			8)
                echo -e "${CYAN}>>> Проверка IP сервера на блокировки зарубежными сервисами...${NC}"
                 bash <(curl -Ls https://Check.Place) -EI
                ;;
			9)
                echo -e "${CYAN}>>> Параметры сервера и проверка скорости к зарубежным провайдерам...${NC}"
                wget -qO- bench.sh | bash
                ;;

			10)
                echo -e "${CYAN}>>> Запуск теста на процессор...${NC}"
                # Проверка sysbench прямо перед запуском
    if ! command -v sysbench &> /dev/null; then
        echo -e "${YELLOW}>>> sysbench не найден. Установка...${NC}"
        sudo apt update && sudo apt install -y sysbench
    fi
				sysbench cpu run --threads=1
                ;;	
            11) run_scanner ;;
			12)
                run_dpi_detector
                ;;
            13)
                run_sni_scan
                ;;
            [Xx]) return ;;
            *) echo -e "${RED}❌ Неверный ввод.${NC}" ;;
        esac
        read -p "Нажмите Enter для продолжения..."
    done
}
run_tests_menu
