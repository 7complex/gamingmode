set -euo pipefail
BACKUP_DIR="/var/tmp/gaming_mode_backup"
LOG_FILE="/var/log/gaming_mode.log"
HIGH_MODE=0
SILENT=0
mkdir -p "$BACKUP_DIR" 2>/dev/null
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi
PROTECTED_PROCS=(
    "brave" "vesktop" "discord" "steam" "gamescope" "mangohud" "gamemode"
    "Xorg" "xinit" "systemd" "kwin" "plasmashell" "gnome-shell" "budgie-wm"
    "cinnamon" "xfce4-session" "openbox" "i3" "sway" "wayland"
    "pipewire" "pulseaudio" "wireplumber" "dbus-daemon" "polkitd"
    "ssh-agent" "gpg-agent" "bash" "zsh" "fish" "tmux" "screen"
    "login" "lightdm" "gdm" "sddm"
    "java" "minecraft" "Minecraft"  
)
BLOAT_PROCS=(
    "update-notifier" "packagekitd" "gnome-software" "snapd" "flatpak"
    "appstream" "zeitgeist" "tracker" "gnome-initial-setup"
    "nautilus" "thunar" "pcmanfm" "caja" "nemo" "file-roller"
    "evince" "eog" "shotwell" "rhythmbox" "totem" "gnome-calendar"
    "gnome-contacts" "gnome-maps" "gnome-characters" "gnome-logs"
    "gnome-usage" "gnome-disk-utility" "gnome-terminal" "konsole"
    "xfce4-terminal" "terminator" "tilix" "alacritty" "kitty" "wezterm"
)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}
msg() {
    if [ $SILENT -eq 0 ]; then
        echo -e "$*"
    fi
    log "$*"
}
msg_error() {
    if [ $SILENT -eq 0 ]; then
        echo -e "${RED}ERRO: $*${NC}" >&2
    fi
    log "ERRO: $*"
}
msg_ok() {
    if [ $SILENT -eq 0 ]; then
        echo -e "${GREEN}$*${NC}"
    fi
    log "OK: $*"
}
msg_warn() {
    if [ $SILENT -eq 0 ]; then
        echo -e "${YELLOW}AVISO: $*${NC}"
    fi
    log "AVISO: $*"
}
check_dependencies() {
    msg "--- Verificando dependências ---"
    local mandatory=(
        "lscpu:util-linux"
        "lspci:pciutils"
        "sensors:lm-sensors"
        "iostat:sysstat"
        "ping:iputils-ping"
        "awk:gawk"
    )
    local optional=(
        "intel_gpu_top:intel-gpu-tools"
        "iotop:iotop"
        "dmidecode:dmidecode"
        "powertop:powertop"
        "nvidia-smi:nvidia-smi"   
        "rocm-smi:rocm-smi-lib"
    )
    local to_install=()
    for item in "${mandatory[@]}"; do
        cmd="${item%:*}"
        pkg="${item
        if ! command -v "$cmd" &>/dev/null; then
            if ! dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
                msg_warn "Faltando: $cmd (pacote: $pkg)"
                to_install+=("$pkg")
            fi
        fi
    done
    for item in "${optional[@]}"; do
        cmd="${item%:*}"
        pkg="${item
        if ! command -v "$cmd" &>/dev/null; then
            if ! dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
                msg_warn "Opcional: $cmd (pacote: $pkg) - Instale para mais funcionalidades."
            fi
        fi
    done
    if [ ${
        msg "Pacotes obrigatórios faltando: ${to_install[*]}"
        if [ $SILENT -eq 0 ]; then
            read -p "Deseja instalá-los agora? (s/N) " -n 1 -r
            echo
        else
            REPLY="s"
        fi
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            if [ "$EUID" -eq 0 ]; then
                apt-get update && apt-get install -y "${to_install[@]}"
            else
                sudo apt-get update && sudo apt-get install -y "${to_install[@]}"
            fi
            hash -r
            msg_ok "Dependências instaladas."
        else
            msg_warn "Continuando sem instalar; algumas funções podem falhar."
        fi
    else
        msg_ok "Todas as dependências obrigatórias já estão instaladas."
    fi
}
info_cpu() {
    echo "--- CPU ---"
    lscpu | grep -E "Model name|Socket|Thread|Core|MHz|Cache" 2>/dev/null || echo "lscpu não disponível"
    echo
}
info_gpu() {
    echo "--- GPU ---"
    lspci | grep -E "VGA|3D|Display" | head -5
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader
    elif command -v rocm-smi &>/dev/null; then
        rocm-smi --showtemp --showpower
    elif command -v intel_gpu_top &>/dev/null; then
        echo "Uso da GPU Intel (amostra):"
        timeout 1 intel_gpu_top -l -s 1 | grep -E "render|bit|video" | head -5
    fi
    echo
}
info_mem() {
    echo "--- Memória ---"
    free -h
    echo
    if command -v swapon &>/dev/null; then
        echo "Swap:"
        swapon --show
    else
        echo "swapon não encontrado (instale util-linux)"
    fi
    echo
}
info_temp() {
    echo "--- Temperaturas ---"
    if command -v sensors &>/dev/null; then
        sensors | grep -E "Core|Package|CPU|GPU|temp" | head -15
    else
        echo "sensors não instalado."
    fi
    echo
}
info_disk() {
    echo "--- Discos ---"
    df -h / /home 2>/dev/null || df -h /
    echo
    if command -v iostat &>/dev/null; then
        echo "I/O (amostra):"
        iostat -d 1 2 | tail -10
    fi
    echo
}
info_network() {
    echo "--- Rede (latência) ---"
    ping -c 3 8.8.8.8 2>/dev/null | tail -2 || echo "Sem rede"
    echo
}
info_processos_top() {
    echo "--- Top 10 processos (CPU e Memória) ---"
    echo "CPU:"
    ps aux --sort=-%cpu | head -11 | awk '{print $2, $3, $4, $11}'
    echo
    echo "Memória:"
    ps aux --sort=-%mem | head -11 | awk '{print $2, $3, $4, $11}'
    echo
}
info_io_top() {
    echo "--- Top 5 I/O ---"
    if command -v iotop &>/dev/null; then
        sudo iotop -b -n 1 -o -q | head -6 2>/dev/null || echo "iotop precisa de root"
    else
        echo "iotop não instalado"
    fi
    echo
}
info_interrupts() {
    echo "--- Interrupções e context switches ---"
    cat /proc/interrupts | head -10
    echo "Context switches: $(cat /proc/stat | grep ctxt | awk '{print $2}')"
    echo
}
info_services() {
    echo "--- Serviços ativos (systemd) ---"
    systemctl list-units --type=service --state=running | grep -E "cups|bluetooth|NetworkManager|accounts-daemon" | head -10
    echo
}
gather_all_info() {
    echo "========================================="
    echo "   INFORMAÇÕES DO SISTEMA (GAMING MODE)"
    echo "========================================="
    date
    echo
    info_cpu
    info_gpu
    info_mem
    info_temp
    info_disk
    info_network
    info_processos_top
    info_io_top
    info_interrupts
    info_services
}
kill_bloat() {
    msg "--- Matando processos não essenciais (bloat) ---"
    local killed=0
    for proc in "${BLOAT_PROCS[@]}"; do
        pids=$(pgrep -f "$proc" 2>/dev/null)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                comm=$(ps -p "$pid" -o comm= 2>/dev/null)
                protected=0
                for p in "${PROTECTED_PROCS[@]}"; do
                    if [[ "$comm" =~ $p ]]; then
                        protected=1
                        break
                    fi
                done
                if [ $protected -eq 0 ]; then
                    msg "Matando $comm (PID $pid)"
                    kill -9 "$pid" 2>/dev/null && killed=$((killed+1))
                fi
            done
        fi
    done
    msg_ok "Total de processos mortos: $killed"
}
backup_sysctl() {
    sysctl vm.swappiness > "$BACKUP_DIR/swappiness.bak" 2>/dev/null || true
    sysctl vm.vfs_cache_pressure > "$BACKUP_DIR/vfs_cache_pressure.bak" 2>/dev/null || true
    sysctl kernel.numa_balancing > "$BACKUP_DIR/numa_balancing.bak" 2>/dev/null || true
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor > "$BACKUP_DIR/scaling_governor.bak" 2>/dev/null || true
    fi
    for disk in /sys/block/sd*/queue/scheduler; do
        if [ -f "$disk" ]; then
            cat "$disk" > "${BACKUP_DIR}/scheduler_$(basename $(dirname $disk)).bak" 2>/dev/null || true
        fi
    done
    sysctl vm.dirty_ratio > "$BACKUP_DIR/dirty_ratio.bak" 2>/dev/null || true
    sysctl vm.dirty_background_ratio > "$BACKUP_DIR/dirty_background_ratio.bak" 2>/dev/null || true
    sysctl vm.dirty_expire_centisecs > "$BACKUP_DIR/dirty_expire_centisecs.bak" 2>/dev/null || true
    if [ $HIGH_MODE -eq 1 ]; then
        sysctl net.core.rmem_max > "$BACKUP_DIR/rmem_max.bak" 2>/dev/null || true
        sysctl net.core.wmem_max > "$BACKUP_DIR/wmem_max.bak" 2>/dev/null || true
        sysctl net.ipv4.tcp_rmem > "$BACKUP_DIR/tcp_rmem.bak" 2>/dev/null || true
        sysctl net.ipv4.tcp_wmem > "$BACKUP_DIR/tcp_wmem.bak" 2>/dev/null || true
        sysctl net.core.netdev_max_backlog > "$BACKUP_DIR/netdev_max_backlog.bak" 2>/dev/null || true
    fi
}
set_performance_normal() {
    msg "--- Aplicando ajustes normais ---"
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
        msg_ok "Governor CPU definido para performance"
    fi
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swappiness=10
    if [ $ram_gb -ge 16 ]; then
        swappiness=5
    elif [ $ram_gb -ge 8 ]; then
        swappiness=10
    else
        swappiness=20
    fi
    sysctl -w vm.swappiness=$swappiness 2>/dev/null
    sysctl -w vm.vfs_cache_pressure=50 2>/dev/null
    sysctl -w kernel.numa_balancing=0 2>/dev/null
    if [ -f /proc/sys/kernel/sched_rt_runtime_us ]; then
        sysctl -w kernel.sched_rt_runtime_us=-1 2>/dev/null
    fi
    sysctl -w vm.dirty_ratio=10 2>/dev/null
    sysctl -w vm.dirty_background_ratio=5 2>/dev/null
    sysctl -w vm.dirty_expire_centisecs=3000 2>/dev/null
    for disk in /sys/block/sd*/queue/scheduler; do
        if [ -f "$disk" ]; then
            if echo "$disk" | grep -q "nvme"; then
                echo "none" > "$disk" 2>/dev/null && msg_ok "I/O scheduler set to none for $(basename $(dirname $disk))"
            else
                echo "noop" > "$disk" 2>/dev/null && msg_ok "I/O scheduler set to noop for $(basename $(dirname $disk))"
            fi
        fi
    done
    sysctl -w net.core.rmem_max=16777216 2>/dev/null
    sysctl -w net.core.wmem_max=16777216 2>/dev/null
    sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" 2>/dev/null
    sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" 2>/dev/null
    sysctl -w net.core.netdev_max_backlog=30000 2>/dev/null
    msg_ok "Ajustes normais aplicados."
}
set_performance_high() {
    msg "--- Aplicando ajustes HIGH (hardware dedicado, RAM≥16GB) ---"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi -pm 1 2>/dev/null && msg_ok "NVIDIA: modo persistência ativado"
    elif command -v rocm-smi &>/dev/null; then
        rocm-smi --setperflevel high 2>/dev/null && msg_ok "AMD: perfil high setado"
    fi
    if command -v powertop &>/dev/null; then
        if [ $SILENT -eq 0 ]; then
            read -p "Aplicar powertop --auto-tune? (s/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                powertop --auto-tune &>/dev/null && msg_ok "Powertop aplicado."
            fi
        else
            powertop --auto-tune &>/dev/null && msg_ok "Powertop aplicado (silencioso)."
        fi
    else
        msg_warn "Powertop não instalado (sudo apt install powertop)"
    fi
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && msg_ok "Cache de páginas limpo."
    if [ -f /proc/irq/*/smp_affinity ]; then
        msg_warn "Afinidade de IRQ não ajustada (opcional)."
    fi
    msg_ok "Ajustes HIGH aplicados."
}
set_game_priority() {
    local game_patterns=("java" "mono" "csgo" "hl2" "RocketLeague" "Wine" "proton" "minecraft" "Minecraft")
    for pattern in "${game_patterns[@]}"; do
        pgrep -f "$pattern" 2>/dev/null | while read -r pid; do
            renice -n -10 -p "$pid" 2>/dev/null && msg_ok "Prioridade aumentada para PID $pid ($pattern)"
            ionice -c 1 -n 0 -p "$pid" 2>/dev/null && msg_ok "I/O prioridade alta para PID $pid"
        done
    done
}
stop_services() {
    local services=("cups" "bluetooth" "accounts-daemon" "ModemManager")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc" && msg "Parado: $svc"
            echo "$svc" >> "$BACKUP_DIR/stopped_services.list" 2>/dev/null
        fi
    done
}
restart_services() {
    if [ -f "$BACKUP_DIR/stopped_services.list" ]; then
        while read -r svc; do
            systemctl start "$svc" && msg "Reiniciado: $svc"
        done < "$BACKUP_DIR/stopped_services.list"
        rm -f "$BACKUP_DIR/stopped_services.list"
    fi
}
restore_defaults() {
    msg "--- Restaurando configurações originais ---"
    if [ -f "$BACKUP_DIR/swappiness.bak" ]; then
        sysctl -p "$BACKUP_DIR/swappiness.bak" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/vfs_cache_pressure.bak" ]; then
        sysctl -p "$BACKUP_DIR/vfs_cache_pressure.bak" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/numa_balancing.bak" ]; then
        sysctl -p "$BACKUP_DIR/numa_balancing.bak" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/scaling_governor.bak" ]; then
        gov=$(cat "$BACKUP_DIR/scaling_governor.bak")
        echo "$gov" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
        msg "Governor restaurado para $gov"
    else
        echo "powersave" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
    fi
    for disk in /sys/block/sd*/queue/scheduler; do
        local dev=$(basename $(dirname "$disk"))
        if [ -f "${BACKUP_DIR}/scheduler_${dev}.bak" ]; then
            sch=$(cat "${BACKUP_DIR}/scheduler_${dev}.bak")
            echo "$sch" > "$disk" 2>/dev/null && msg "Scheduler restaurado para $dev: $sch"
        fi
    done
    if [ -f "$BACKUP_DIR/dirty_ratio.bak" ]; then
        sysctl -p "$BACKUP_DIR/dirty_ratio.bak" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/dirty_background_ratio.bak" ]; then
        sysctl -p "$BACKUP_DIR/dirty_background_ratio.bak" 2>/dev/null || true
    fi
    if [ -f "$BACKUP_DIR/dirty_expire_centisecs.bak" ]; then
        sysctl -p "$BACKUP_DIR/dirty_expire_centisecs.bak" 2>/dev/null || true
    fi
    if [ $HIGH_MODE -eq 1 ]; then
        if [ -f "$BACKUP_DIR/rmem_max.bak" ]; then
            sysctl -p "$BACKUP_DIR/rmem_max.bak" 2>/dev/null || true
        fi
        if [ -f "$BACKUP_DIR/wmem_max.bak" ]; then
            sysctl -p "$BACKUP_DIR/wmem_max.bak" 2>/dev/null || true
        fi
        if [ -f "$BACKUP_DIR/tcp_rmem.bak" ]; then
            sysctl -p "$BACKUP_DIR/tcp_rmem.bak" 2>/dev/null || true
        fi
        if [ -f "$BACKUP_DIR/tcp_wmem.bak" ]; then
            sysctl -p "$BACKUP_DIR/tcp_wmem.bak" 2>/dev/null || true
        fi
        if [ -f "$BACKUP_DIR/netdev_max_backlog.bak" ]; then
            sysctl -p "$BACKUP_DIR/netdev_max_backlog.bak" 2>/dev/null || true
        fi
    fi
    restart_services
    msg_ok "Restauração concluída."
}
show_status() {
    echo "--- STATUS DO GAMING MODE ---"
    echo "Governor atual: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo N/A)"
    echo "Swappiness: $(sysctl -n vm.swappiness 2>/dev/null)"
    echo "VFS cache pressure: $(sysctl -n vm.vfs_cache_pressure 2>/dev/null)"
    echo "NUMA balancing: $(sysctl -n kernel.numa_balancing 2>/dev/null)"
    echo "Dirty ratio: $(sysctl -n vm.dirty_ratio 2>/dev/null)"
    echo "Dirty background: $(sysctl -n vm.dirty_background_ratio 2>/dev/null)"
    echo "I/O scheduler: $(cat /sys/block/sd*/queue/scheduler 2>/dev/null | head -1)"
    echo
    echo "Processos com alta carga (CPU > 5% ou MEM > 5%):"
    ps aux | awk '$3>5.0 || $4>5.0' | awk '{print $2, $3, $4, $11}' | head -15
    echo
    if [ -f "$BACKUP_DIR/gaming_active" ]; then
        echo "Modo gaming ATIVO (flag presente)."
    else
        echo "Modo gaming INATIVO."
    fi
}
auto_mode() {
    msg "--- Modo automático iniciado (detectando Minecraft) ---"
    while true; do
        if pgrep -f "java.*minecraft" >/dev/null 2>&1; then
            if [ ! -f "$BACKUP_DIR/gaming_active" ]; then
                msg "Minecraft detectado. Ativando modo gaming..."
                if [ $HIGH_MODE -eq 1 ]; then
                    "$0" --enable --high --silent
                else
                    "$0" --enable --silent
                fi
                touch "$BACKUP_DIR/gaming_active"
            fi
        else
            if [ -f "$BACKUP_DIR/gaming_active" ]; then
                msg "Minecraft fechado. Desativando modo gaming..."
                "$0" --disable --silent
                rm -f "$BACKUP_DIR/gaming_active"
            fi
        fi
        sleep 10
    done
}
show_help() {
    cat <<EOF
Uso: $0 [OPÇÃO] [--high] [--silent]
Opções principais:
  --enable    Ativa o modo gaming (ajustes normais)
  --disable   Desativa o modo gaming (restaura configurações)
  --status    Mostra status atual e parâmetros
  --info      Mostra diagnóstico completo (sem alterações)
  --help      Exibe esta ajuda
Flags adicionais:
  --high      Ativa otimizações para hardware high-end (GPU dedicada, RAM≥16GB, Powertop, etc.)
  --silent    Modo silencioso (sem perguntas, saída mínima) - útil para scripts
Modo automático:
  --auto      Fica monitorando a execução do Minecraft e ativa/desativa automaticamente
Exemplos:
  sudo $0 --enable                     
  sudo $0 --enable --high              
  $0 --info                            
  $0 --auto --high                     
O script deve ser executado como root (sudo) para aplicar ajustes.
EOF
}
ACTION=""
while [[ $
    case "$1" in
        --enable|--disable|--status|--info|--help|--auto)
            ACTION="$1"
            shift
            ;;
        --high)
            HIGH_MODE=1
            shift
            ;;
        --silent)
            SILENT=1
            shift
            ;;
        *)
            echo "Opção inválida: $1"
            show_help
            exit 1
            ;;
    esac
done
if [ -z "$ACTION" ]; then
    show_help
    exit 0
fi
if [[ "$ACTION" == "--enable" || "$ACTION" == "--disable" || "$ACTION" == "--auto" ]]; then
    if [ "$EUID" -ne 0 ]; then
        msg_error "Esta ação requer root. Use sudo."
        exit 1
    fi
fi
case "$ACTION" in
    --enable)
        check_dependencies
        backup_sysctl
        gather_all_info        
        kill_bloat
        set_performance_normal
        if [ $HIGH_MODE -eq 1 ]; then
            set_performance_high
        fi
        set_game_priority
        stop_services
        touch "$BACKUP_DIR/gaming_active"
        msg_ok "Modo gaming ATIVADO (HIGH=$HIGH_MODE)."
        log "Modo gaming ativado (HIGH=$HIGH_MODE)"
        ;;
    --disable)
        restore_defaults
        rm -f "$BACKUP_DIR/gaming_active"
        msg_ok "Modo gaming DESATIVADO."
        log "Modo gaming desativado."
        ;;
    --status)
        show_status
        ;;
    --info)
        check_dependencies
        gather_all_info
        ;;
    --auto)
        check_dependencies
        auto_mode
        ;;
    --help)
        show_help
        ;;
    *)
        echo "Erro interno: ação não reconhecida."
        exit 1
        ;;
esac
exit 0
