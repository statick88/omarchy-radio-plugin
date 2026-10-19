# statick.radio

Plugin de radio hermoso y fácil de usar para Omarchy.

## ✨ Características

- 🎨 **UI moderna y atractiva** - Diseño limpio con animaciones suaves
- 🎵 **Reproducción de streams** - Usa mpv para audio de alta calidad
- ⚙️ **Configuración fácil** - Agrega/edita/elimina estaciones desde la interfaz
- 🎨 **Colores por estación** - Cada estación tiene su propio color
- 🔊 **Control de volumen** - Slider integrado en el panel
- 📱 **Panel desplegable** - Click en el widget abre el panel de control

## 🚀 Instalación

```bash
cd /home/statick/Projects/radio/odd
./install.sh
```

## 🎮 Controles

### En la barra (widget):
- **Clic izquierdo**: Abrir/cerrar panel de control
- Mientras reproduce, el icono muestra el número de estación y se colorea en `accent`

### En el panel:
- **⏮ ▶ ⏭**: Controles de reproducción (también con `next`/`prev`/`toggle`)
- **＋**: Abrir/cerrar el formulario para agregar una estación
- **Campo de búsqueda**: Filtra la lista mientras escribes (por nombre o por URL/protocolo)
- **Clic en estación**: Reproducir esa estación (la activa queda resaltada)
- **Slider**: Control de volumen (0-100%)

### Teclado (en panel):
- `Esc`: Cierra el panel; dentro de un campo, primero borra su texto
- `Tab`: Alterna el foco entre el campo de búsqueda y la lista
- `↑` / `↓`: Mover la estación seleccionada en la lista
- `Enter`: Reproducir la estación seleccionada (o enviar el formulario)

## ⚙️ Configuración de estaciones

### Método 1: Desde la UI (Recomendado)
1. Click en el widget de radio para abrir el panel
2. Click en `＋` para abrir el formulario
3. Escribe el nombre y la URL del stream (debe empezar por `http://` o `https://`)
4. Click en ` ` o presiona `Enter`

La estación se escribe en `~/.config/omarchy-radio/stations.conf` (con el
siguiente id libre) y aparece en la lista sin recargar nada. Un nombre
repetido o una URL inválida se rechaza y el archivo queda intacto.

### Método 2: Editar archivo directamente
Edita `~/.config/omarchy-radio/stations.conf`:

```
# Formato: id|nombre|url
1|Radio Clásica|https://stream.example.com/classica
2|Rock FM|https://stream.example.com/rock
3|Jazz Lounge|https://stream.example.com/jazz
```

## 📺 Streams de ejemplo

Aquí tienes algunas radios con streams públicos:

```
1|Radio Paradise|https://stream.radioparadise.com/aac-128
2|SomaFM Groove Salad|https://ice1.somafm.com/groovesalad-128-aac
3|SomaFM Drone Zone|https://ice1.somafm.com/dronezone-128-aac
```

## 🎨 Personalización

### Cambiar colores
Los colores de las estaciones están definidos en `Panel.qml`:
```javascript
readonly property var stationColors: ["#8b5cf6", "#ef4444", "#f59e0b", "#10b981", "#3b82f6"]
```

### Agregar más estaciones
Puedes agregar tantas estaciones como quieras desde la UI o el archivo de configuración.

## 📋 Integración con Omarchy

Agrega el widget a tu barra editando `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        { "id": "statick.radio" }
      ]
    }
  }
}
```

## 🔧 Comandos manuales

```bash
# Controlar radio desde terminal
~/.config/omarchy/plugins/statick.radio/radio-control.sh play 1  # Reproducir estación 1
~/.config/omarchy/plugins/statick.radio/radio-control.sh stop     # Parar
~/.config/omarchy/plugins/statick.radio/radio-control.sh toggle   # Alternar
~/.config/omarchy/plugins/statick.radio/radio-control.sh add "Mi Radio" "https://stream.example.com/live"  # Agregar estación
```

## 📦 Dependencias

- **mpv**: Reproductor de audio (requerido)

```bash
# Arch Linux/Manjaro
sudo pacman -S mpv

# Ubuntu/Debian
sudo apt install mpv
```

## 🎯 Atajos de teclado sugeridos

Agrega a tu configuración de omarchy:

```json
{
  "keybindings": [
    { "key": "Super+Shift+R", "command": "omarchy-shell statick.radio overlay" }
  ]
}
```

## 🐛 Solución de problemas

### No se reproduce audio
1. Verifica que mpv está instalado: `which mpv`
2. Prueba el stream manualmente: `mpv <url>`
3. Revisa los logs: `journalctl --user -u omarchy -f`

### El widget no aparece
1. Verifica que el plugin está instalado: `ls ~/.config/omarchy/plugins/statick.radio/`
2. Recarga omarchy: `omarchy reload`
3. Revisa el shell.json: `cat ~/.config/omarchy/shell.json`

### No carga las estaciones
1. Verifica el archivo: `cat ~/.config/omarchy-radio/stations.conf`
2. Permisos: `ls -la ~/.config/omarchy-radio/`

## 📄 Licencia

MIT