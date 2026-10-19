#!/bin/bash
# Radio plugin control script
# Usage: radio-control.sh [play|stop|toggle|next|prev|add|status] [station]

CONFIG_DIR="$HOME/.config/omarchy-radio"
CONFIG_FILE="$CONFIG_DIR/stations.conf"
STATE_FILE="$CONFIG_DIR/state"
PID_FILE="$CONFIG_DIR/mpv.pid"

# Create config dir if not exists
mkdir -p "$CONFIG_DIR"

# Create default config if not exists
create_default_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuración de estaciones de radio
# Formato: id|nombre|url
1|Radio Exa 92.5 FM Ecuador|https://26573.live.streamtheworld.com/ECUADORAAC.aac
2|Radio Paradise|https://stream.radioparadise.com/aac-128
3|SomaFM Groove Salad|https://ice1.somafm.com/groovesalad-128-aac
4|SomaFM Drone Zone|https://ice1.somafm.com/dronezone-128-aac
EOF
    fi
}

# Load current state
load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
    else
        CURRENT_STATION=1
        IS_PLAYING=false
        VOLUME=80
        save_state
    fi
}

# Save state
save_state() {
    cat > "$STATE_FILE" << EOF
CURRENT_STATION=$CURRENT_STATION
IS_PLAYING=$IS_PLAYING
VOLUME=$VOLUME
EOF
}

# Get station info from config
get_station() {
    local station_num=$1
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    grep "^${station_num}|" "$CONFIG_FILE" 2>/dev/null | head -1
}

# Count total stations
count_stations() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo 0
        return
    fi
    grep -c "^[0-9]" "$CONFIG_FILE" 2>/dev/null || echo 0
}

# Play station
play_station() {
    local station_num=${1:-$CURRENT_STATION}
    
    # Create config if it doesn't exist
    create_default_config
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: No se pudo crear el archivo de configuración" >&2
        exit 1
    fi
    
    local station_info=$(get_station "$station_num")
    
    if [ -z "$station_info" ]; then
        echo "Error: Estación $station_num no encontrada" >&2
        exit 1
    fi
    
    local station_name=$(echo "$station_info" | cut -d'|' -f2)
    local station_url=$(echo "$station_info" | cut -d'|' -f3)
    
    # Stop existing player
    stop_radio 2>/dev/null || true
    
    # Check if mpv is available
    if ! command -v mpv &> /dev/null; then
        echo "Error: mpv no encontrado. Instala con: sudo pacman -S mpv" >&2
        exit 1
    fi
    
    # Start mpv in background
    echo "Reproduciendo: $station_name"
    mpv --no-video --volume="$VOLUME" "$station_url" &
    MPV_PID=$!
    
    # Save state
    CURRENT_STATION=$station_num
    IS_PLAYING=true
    save_state
    echo $MPV_PID > "$PID_FILE"
    
    echo "✓ PID: $MPV_PID"
}

# Stop radio
stop_radio() {
    if [ -f "$PID_FILE" ]; then
        local PID=$(cat "$PID_FILE")
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "Radio detenida"
        fi
        rm -f "$PID_FILE"
    fi
    
    # Also kill every mpv stream listed in stations.conf: the sweep comes
    # from the file, so any host (the default streamtheworld Exa stream, or a
    # station added from the panel) is silenced, never from a hardcoded list.
    if [ -f "$CONFIG_FILE" ]; then
        local sweep_url
        while IFS='|' read -r _id _name sweep_url; do
            # Only a line that really carries an http(s) stream URL counts:
            # it skips comments, blank lines and malformed rows.
            case "$sweep_url" in
                http://*|https://*) ;;
                *) continue ;;
            esac
            pkill -f "mpv.*${sweep_url}" 2>/dev/null || true
        done < "$CONFIG_FILE"
    fi
    
    IS_PLAYING=false
    save_state
}

# Toggle play/stop
toggle_radio() {
    if [ "$IS_PLAYING" = true ]; then
        stop_radio
    else
        play_station "$CURRENT_STATION"
    fi
}

# Next/prev station
next_station() {
    local total=$(count_stations)
    if [ "$total" -eq 0 ]; then
        echo "Error: No hay estaciones configuradas" >&2
        exit 1
    fi
    CURRENT_STATION=$((CURRENT_STATION % total + 1))
    play_station "$CURRENT_STATION"
}

prev_station() {
    local total=$(count_stations)
    if [ "$total" -eq 0 ]; then
        echo "Error: No hay estaciones configuradas" >&2
        exit 1
    fi
    if [ "$CURRENT_STATION" -le 1 ]; then
        CURRENT_STATION=$total
    else
        CURRENT_STATION=$((CURRENT_STATION - 1))
    fi
    play_station "$CURRENT_STATION"
}

# Show status
show_status() {
    load_state
    
    echo "Estado actual:"
    echo "  Estación: $CURRENT_STATION"
    echo "  Reproduciendo: $IS_PLAYING"
    echo "  Volumen: $VOLUME%"
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Estaciones disponibles:"
        while IFS='|' read -r id name url; do
            if [[ "$id" =~ ^[0-9]+$ ]]; then
                local marker="  "
                if [ "$id" = "$CURRENT_STATION" ]; then
                    marker="▶ "
                fi
                echo "  $marker$id. $name"
            fi
        done < "$CONFIG_FILE"
    else
        echo "No hay estaciones configuradas."
        echo "Se creará configuración por defecto en el próximo play."
    fi
}

# Add a station (S2): validate, keep the file byte-identical on error,
# and write atomically so a crash never leaves stations.conf half-written.
add_station() {
    local name="$1"
    local url="$2"

    if [ -z "$name" ]; then
        echo "Error: el nombre de la estación no puede estar vacío" >&2
        exit 1
    fi
    if [ -z "$url" ]; then
        echo "Error: la URL no puede estar vacía" >&2
        exit 1
    fi
    if [[ "$name" == *"|"* || "$name" == *$'\n'* ]]; then
        echo 'Error: el nombre no puede contener "|" ni saltos de línea' >&2
        exit 1
    fi
    case "$url" in
        http://*|https://*) ;;
        *)
            echo "Error: la URL debe empezar por http:// o https://" >&2
            exit 1
            ;;
    esac
    if [[ "$url" == *"|"* || "$url" == *$'\n'* ]]; then
        echo 'Error: la URL no puede contener "|" ni saltos de línea' >&2
        exit 1
    fi

    create_default_config

    if grep -Fq "|$name|" "$CONFIG_FILE"; then
        echo "Error: la estación \"$name\" ya existe" >&2
        exit 1
    fi

    local max_id=0 id ignored
    while IFS='|' read -r id ignored; do
        if [[ "$id" =~ ^[0-9]+$ ]] && [ "$id" -gt "$max_id" ]; then
            max_id=$id
        fi
    done < "$CONFIG_FILE"

    local tmp
    tmp=$(mktemp "$CONFIG_DIR/.stations.conf.XXXXXX") 2>/dev/null
    if [ -z "$tmp" ]; then
        echo "Error: no se pudo crear el archivo temporal de configuración" >&2
        exit 1
    fi

    if ! { cat "$CONFIG_FILE"; printf '%s|%s|%s\n' "$((max_id + 1))" "$name" "$url"; } > "$tmp"; then
        rm -f "$tmp"
        echo "Error: no se pudo escribir la configuración" >&2
        exit 1
    fi

    if ! mv "$tmp" "$CONFIG_FILE"; then
        rm -f "$tmp"
        echo "Error: no se pudo actualizar la configuración" >&2
        exit 1
    fi

    echo "✓ Estación agregada: $name"
}

# Main
create_default_config
load_state

case "${1:-status}" in
    play)
        play_station "${2:-$CURRENT_STATION}"
        ;;
    stop)
        stop_radio
        ;;
    toggle)
        toggle_radio
        ;;
    next)
        next_station
        ;;
    prev)
        prev_station
        ;;
    add)
        add_station "${2:-}" "${3:-}"
        ;;
    status)
        show_status
        ;;
    *)
        echo "Uso: $0 [play|stop|toggle|next|prev|add|status] [station]" >&2
        echo "" >&2
        echo "Comandos:" >&2
        echo "  play [station]  - Reproducir estación específica" >&2
        echo "  stop           - Detener radio" >&2
        echo "  toggle         - Alternar play/stop" >&2
        echo "  next           - Siguiente estación" >&2
        echo "  prev           - Estación anterior" >&2
        echo "  add <nombre> <url> - Agregar una estación a stations.conf" >&2
        echo "  status         - Mostrar estado actual" >&2
        exit 1
        ;;
esac