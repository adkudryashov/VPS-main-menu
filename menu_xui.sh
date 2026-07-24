#!/bin/bash
source /usr/local/bin/_config_and_utils.sh

# ----------------------------------------------------------------------
# X-UI PRO (3x-ui-pro): УПРАВЛЕНИЕ (Вынесенный блок)
# https://github.com/mozaroc/3x-ui-pro
# ----------------------------------------------------------------------

XUI_PRO_REPO="https://raw.githubusercontent.com/mozaroc/3x-ui-pro/main"

# Установщик и патч 3x-ui-pro очищают /etc/nginx/sites-enabled целиком.
# Если на сервере поднят стек telemt, его self-SNI vhost живёт в conf.d и
# это переживает — но vhost ссылается на пути из конфига панели, которые
# патч мог перегенерировать. Поэтому после обеих операций напоминаем
# прогнать диагностику.
function warn_telemt_after_panel_change {
    if [ -f /etc/telemt/telemt.toml ]; then
        echo -e "\n${YELLOW}⚠️  На сервере установлен стек telemt.${NC}"
        echo -e "${YELLOW}    Панель могла перегенерировать свои nginx-конфиги."
        echo -e "    Проверь маскировку: главное меню -> 'Стек telemt / MTProto'"
        echo -e "    -> 'Статус и диагностика'. При сбое — 'Восстановить маскировку'.${NC}"
    fi
}

function install_xui_pro {
    clear
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}          📥  УСТАНОВКА X-UI PRO (3x-ui-pro) 📥        ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${YELLOW}Устанавливает: 3x-ui, nginx, SSL (Let's Encrypt), Clash-подписку, диагностику сети.${NC}"
    echo -e "${YELLOW}Нужны два домена/поддомена: один для панели, другой для REALITY.${NC}"
    echo ""

    read -p "Автоопределение доменов (без ручного ввода)? [y/N]: " auto_domain
    local xui_args=()

    if [[ "$auto_domain" =~ ^[Yy]$ ]]; then
        xui_args+=(-auto_domain y)
    else
        read -p "Домен панели (например panel.example.com): " subdomain
        read -p "Домен для REALITY (другой домен/поддомен): " reality_domain
        [ -n "$subdomain" ] && xui_args+=(-subdomain "$subdomain")
        [ -n "$reality_domain" ] && xui_args+=(-reality_domain "$reality_domain")
    fi

    read -p "Версия 3x-ui (Enter = последняя): " version
    [ -n "$version" ] && xui_args+=(-version "$version")

    echo -e "${CYAN}>>> Запуск установки 3x-ui-pro...${NC}"
    bash <(curl -fsSL "$XUI_PRO_REPO/x-ui-latest.sh") "${xui_args[@]}"
    warn_telemt_after_panel_change
    read -p "Нажмите Enter для продолжения..."
}

function patch_xui_pro {
    echo -e "${CYAN}>>> Применение патча к текущей установке (без изменения БД)...${NC}"
    bash <(curl -fsSL "$XUI_PRO_REPO/x-ui-patch.sh")
    warn_telemt_after_panel_change
    read -p "Нажмите Enter для продолжения..."
}

function manage_adguard {
    while true; do
        clear
        echo -e "${CYAN}--- 🛡️  ADGUARD HOME (DNS-over-HTTPS + блокировка рекламы) ---${NC}"
        echo -e "${YELLOW}Ставится на домен панели, без отдельного домена и портов (через 443).${NC}"
        echo -e "${BLUE}------------------------------------------------------${NC}"
        echo -e "1) 📥  Установить / Обновить AdGuard Home"
        echo -e "2) 🗑️   Удалить AdGuard Home"
        echo -e "X) 🔙  Назад"
        echo -e "${BLUE}------------------------------------------------------${NC}"
        read -p "Выбор: " ag_choice
        case $ag_choice in
            1)
                bash <(curl -fsSL "$XUI_PRO_REPO/x-ui-adguard.sh")
                read -p "Нажмите Enter для продолжения..."
                ;;
            2)
                bash <(curl -fsSL "$XUI_PRO_REPO/x-ui-adguard.sh") -uninstall y
                read -p "Нажмите Enter для продолжения..."
                ;;
            [Xx]) return ;;
            *) echo -e "${RED}❌ Неверный ввод.${NC}" ;;
        esac
    done
}

function ensure_backup_script {
    if [ ! -x /usr/local/bin/x-ui-backup ]; then
        echo -e "${YELLOW}>>> Загрузка скрипта бэкапа...${NC}"
        sudo wget -qO /usr/local/bin/x-ui-backup "$XUI_PRO_REPO/assets/backup/x-ui-backup.sh"
        sudo chmod +x /usr/local/bin/x-ui-backup
    fi
}

function manage_backup {
    ensure_backup_script
    while true; do
        clear
        echo -e "${CYAN}--- 💾  БЭКАП / ВОССТАНОВЛЕНИЕ X-UI PRO ---------------${NC}"
        echo -e "1) 📦  Создать бэкап"
        echo -e "2) 📋  Список бэкапов"
        echo -e "3) ♻️   Восстановить из бэкапа"
        echo -e "X) 🔙  Назад"
        echo -e "${BLUE}------------------------------------------------------${NC}"
        read -p "Выбор: " b_choice
        case $b_choice in
            1) sudo x-ui-backup backup; read -p "Нажмите Enter для продолжения..." ;;
            2) sudo x-ui-backup list; read -p "Нажмите Enter для продолжения..." ;;
            3)
                sudo x-ui-backup list
                read -p "Введите полный путь к файлу бэкапа: " b_path
                if [ -n "$b_path" ]; then
                    sudo x-ui-backup restore "$b_path"
                fi
                read -p "Нажмите Enter для продолжения..."
                ;;
            [Xx]) return ;;
            *) echo -e "${RED}❌ Неверный ввод.${NC}" ;;
        esac
    done
}

function uninstall_xui_pro {
    read -p "$(echo -e "${RED}Полностью удалить X-UI Pro (панель, nginx, сертификаты)? [y/N]: ${NC}")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        bash <(curl -fsSL "$XUI_PRO_REPO/x-ui-latest.sh") -uninstall y
    fi
    read -p "Нажмите Enter для продолжения..."
}

function manage_xui_service {
    local SERVICE_NAME=$XUI_SERVICE
    while true; do
        clear
        echo -e "${CYAN}======================================================${NC}"
        echo -e "${CYAN}         🎛️  УПРАВЛЕНИЕ X-UI PRO (3x-ui-pro) 🎛️        ${NC}"
        echo -e "${CYAN}======================================================${NC}"

        STATUS_XUI=$(get_service_status $SERVICE_NAME)
        STATUS_DISPLAY=$(if [ "$STATUS_XUI" == "active" ]; then echo -e "${GREEN}РАБОТАЕТ${NC}"; else echo -e "${RED}ОСТАНОВЛЕН${NC}"; fi)
        echo -e "${BLUE}Текущий статус: [${STATUS_DISPLAY}]${NC}"
        echo -e "${BLUE}------------------------------------------------------${NC}"

        echo -e "${GREEN}1) 📥  Установить X-UI Pro (nginx, SSL, Clash, диагностика)${NC}"
        echo -e "${YELLOW}2) 🩹  Применить патч (обновить без изменения БД)${NC}"
        echo -e "${CYAN}3) 🛡️   AdGuard Home (опционально)${NC}"
        echo -e "${CYAN}4) 💾  Бэкап / Восстановление${NC}"
        echo -e "${YELLOW}5) 🚥  Статус / Запустить / Остановить / Перезапустить сервис${NC}"
        echo -e "${CYAN}6) 🖥️   Запустить панель X-UI (команда x-ui)${NC}"
        echo -e "${RED}7) 🗑️   Удалить X-UI Pro полностью${NC}"
        echo -e "${RED}X) 🔙  Назад${NC}"
        echo -e "${BLUE}------------------------------------------------------${NC}"

        read -p "Ваш выбор [1-7, X]: " choice
        echo ""

        case $choice in
            1) install_xui_pro ;;
            2) patch_xui_pro ;;
            3) manage_adguard ;;
            4) manage_backup ;;
            5)
                manage_service_status_restart $SERVICE_NAME
                ;;
            6)
                echo -e "${YELLOW}Запускаю X-UI... (Для выхода из X-UI используйте Ctrl+C)${NC}"
                if command -v x-ui &> /dev/null; then
                    x-ui
                elif [ -f "/usr/bin/x-ui" ]; then
                    /usr/bin/x-ui
                elif [ -f "/usr/local/bin/x-ui" ]; then
                    /usr/local/bin/x-ui
                else
                    echo -e "${RED}Команда x-ui не найдена.${NC}"
                fi
                read -p "Нажмите Enter для возврата в меню..."
                ;;
            7) uninstall_xui_pro ;;
            [Xx]) return ;;
            *) echo -e "${RED}❌ Неверный ввод.${NC}" ;;
        esac
    done
}
manage_xui_service
