#!/bin/bash
# Install script for statick.radio plugin
# Copies plugin files to omarchy plugins directory

set -e

PLUGIN_ID="statick.radio"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
CONFIG_DIR="$HOME/.config/omarchy-radio"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🎵 Instalando $PLUGIN_ID..."
echo ""

# Create plugin directory
mkdir -p "$PLUGIN_DIR"

# Copy plugin files
echo "📋 Copiando archivos del plugin..."
cp "$SOURCE_DIR/manifest.json" "$PLUGIN_DIR/"
cp "$SOURCE_DIR/BarWidget.qml" "$PLUGIN_DIR/"
cp "$SOURCE_DIR/Panel.qml" "$PLUGIN_DIR/"
cp "$SOURCE_DIR/radio-control.sh" "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR/radio-control.sh"

# Create config directory
mkdir -p "$CONFIG_DIR"

# Create default stations config if not exists
if [ ! -f "$CONFIG_DIR/stations.conf" ]; then
    echo "📻 Creando configuración de estaciones por defecto..."
    cat > "$CONFIG_DIR/stations.conf" << 'EOF'
# Configuración de estaciones de radio
# Formato: id|nombre|url
# 
# Ejemplos de streams públicos:
1|Radio Exa 92.5 FM Ecuador|https://26573.live.streamtheworld.com/ECUADORAAC.aac
2|Radio Paradise|https://stream.radioparadise.com/aac-128
3|SomaFM Groove Salad|https://ice1.somafm.com/groovesalad-128-aac
4|SomaFM Drone Zone|https://ice1.somafm.com/dronezone-128-aac
EOF
    echo "✓ Configuración creada en: $CONFIG_DIR/stations.conf"
fi

echo ""
echo "✓ Plugin instalado en: $PLUGIN_DIR"
echo ""

# Check if mpv is installed
if ! command -v mpv &> /dev/null; then
    echo "⚠️  ADVERTENCIA: mpv no está instalado"
    echo "   Instálalo con: sudo pacman -S mpv"
    echo ""
fi

# Add to shell.json if not present
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
if [ -f "$SHELL_CONFIG" ]; then
    echo "📝 Verificando configuración de omarchy..."
    
    if ! grep -q "statick.radio" "$SHELL_CONFIG"; then
        echo "   Agregando widget a la barra..."
        
        # Backup shell.json
        cp "$SHELL_CONFIG" "$SHELL_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Try to add to right layout using jq if available
        if command -v jq &> /dev/null; then
            # Add to right array if it exists, otherwise create it
            jq '.bar.layout.right = (.bar.layout.right // []) + [{"id": "statick.radio"}]' \
                "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp" && mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
            echo "✓ Widget agregado a la barra (shell.json)"
        else
            echo "   ⚠️  jq no encontrado. Agrega manualmente a shell.json:"
            echo '     { "id": "statick.radio" }'
            echo "     en bar.layout.right"
        fi
    else
        echo "✓ Widget ya está configurado en shell.json"
    fi
fi

echo ""
echo "🎉 ¡Instalación completa!"
echo ""
echo "Para usar:"
echo "1. Recarga omarchy: omarchy reload"
echo "2. Haz clic en el widget de radio en la barra"
echo "3. Configura tus estaciones con el botón ⚙"
echo ""
echo "Para más información: cat $PLUGIN_DIR/README.md"