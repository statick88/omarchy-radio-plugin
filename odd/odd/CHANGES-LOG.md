# Correcciones del Plugin Radio - Problemas Solucionados

## Resumen de Problemas y Soluciones

### Problema 1: Plugin no aparecía en omarchy
**Error**: `omarchy.radio` no aparecía en `omarchy plugin list`

**Causa**: El namespace `omarchy.*` está reservado para plugins de primera parte

**Solución**:
```bash
cd ~/.config/omarchy/plugins
mv omarchy.radio statick.radio
# Actualizar IDs en archivos
sed -i 's/omarchy\.radio/statick.radio/g' manifest.json BarWidget.qml Panel.qml
# Actualizar shell.json
jq '.bar.layout.right = [.bar.layout.right[] | if .id == "omarchy.radio" then .id = "statick.radio" else . end]' shell.json > shell.json.tmp
mv shell.json.tmp shell.json
```

**Resultado**: ✅ Plugin aparece como `statick.radio enabled`

---

### Problema 2: Error "Color is not defined"
**Error en logs**:
```
ReferenceError: Color is not defined
```

**Causa**: Falta importar `qs.Commons` que contiene el singleton `Color`

**Solución**: Agregar import en BarWidget.qml y Panel.qml
```qml
import qs.Commons  // Agregar este import
```

**Resultado**: ✅ Sin errores de Color

---

### Problema 3: Error "KeyboardPanel is not a type"
**Error en logs**:
```
KeyboardPanel is not a type
```

**Causa**: Uso incorrecto de `Ui.Panel` en lugar de `Panel`

**Solución**: Corregir Panel.qml
```qml
// ANTES (incorrecto)
import qs.Ui as Ui
Ui.Panel {
    KeyboardPanel {
        // ...
    }
}

// DESPUÉS (correcto)
import qs.Ui
Panel {
    KeyboardPanel {
        // ...
    }
}
```

**Resultado**: ✅ Panel carga correctamente

---

### Problema 4: BarWidget no mostraba icono
**Causa**: `Ui.BarIconButton` requiere `iconComponent`, no hijos directos

**Solución**: Estructura correcta del BarWidget
```qml
Ui.BarIconButton {
    id: button
    iconComponent: Component {
        Item {
            // Contenido del icono aquí
            Text {
                text: "󰝚"
                // ...
            }
        }
    }
}
```

**Resultado**: ✅ Icono de radio visible en la barra

---

## Archivos Corregidos

### 1. BarWidget.qml
- ✅ Import `qs.Commons` agregado
- ✅ Estructura `iconComponent` corregida
- ✅ Panel loader restaurado
- ✅ Toggle de panel funcionando

### 2. Panel.qml
- ✅ Import `qs.Commons` agregado
- ✅ Import `qs.Ui` (sin alias)
- ✅ Componente `Panel` (no `Ui.Panel`)
- ✅ Imports de `Quickshell` y `QtQuick.Controls`

### 3. manifest.json
- ✅ ID actualizado a `statick.radio`
- ✅ Todos los campos válidos

### 4. install.sh
- ✅ Script actualizado con nuevo ID

---

## Verificación Final

### Estado del Plugin
```bash
$ omarchy plugin list | grep radio
statick.radio    enabled   third-party bar-widget,overlay    Radio
```

### Archivos Instalados
```
~/.config/omarchy/plugins/statick.radio/
├── BarWidget.qml    (3.1K)
├── manifest.json    (1.0K)
├── Panel.qml        (6.8K)
└── radio-control.sh (5.4K) [executable]
```

### Script de Control Funcionando
```bash
$ radio-control.sh status
Estado actual:
  Estación: 1
  Reproduciendo: false
  Volumen: 80%

Estaciones disponibles:
  ▶ 1. Radio Paradise
    2. SomaFM Groove Salad
    3. SomaFM Drone Zone
```

### Errores en Logs: 0

---

## Lecciones Aprendidas

1. **Namespaces en omarchy**: Los plugins de tercero NO deben usar `omarchy.*`
2. **Imports necesarios**: `qs.Commons` es requerido para `Color`, `Style`, etc.
3. **Componente Panel**: Usar `Panel {` directamente, no `Ui.Panel {`
4. **BarIconButton**: Requiere `iconComponent`, no hijos directos
5. **Verificar logs**: Siempre revisar `journalctl --user -u omarchy` para errores QML

---

## Comandos Útiles

```bash
# Ver plugins
omarchy plugin list | grep radio

# Reiniciar shell
omarchy restart shell

# Ver errores
journalctl --user --since "5 minutes ago" | grep -i "statick.radio"

# Probar radio
~/.config/omarchy/plugins/statick.radio/radio-control.sh status

# Recargar config
omarchy refresh shell
```
---

## Panel con UI estilo WhatsApp + alta de estaciones (2026-10-18)

### Cambio: panel rediseñado con la estructura del plugin `io.github.ricky.whatsapp`
**Antes**: `Panel.qml` (214 líneas) mezclaba lista, controles y volumen en un
único `Column`, con un `Layout.fillWidth` dentro de un `Row` que generaba el
aviso `Non-existent attached object` en el shell.

**Ahora**: `Panel.qml` (533 líneas) replica la estructura de la referencia:
header (botón `←`, título + estado, `⏮ ▶ ⏭ ＋`), lista de estaciones con fila
activa resaltada, y composer inferior. Reutiliza los componentes compartidos
`KeyboardPanel`, `PanelKeyCatcher`, `TextField`, `PanelActionButton`,
`PanelSeparator` en lugar de reimplementarlos. El `Layout.fillWidth` inválido
ya no existe.

### Cambio: las estaciones se agregan desde el formulario (y desde la CLI)
`radio-control.sh add <nombre> <url>` es el único escritor de
`stations.conf` (la UI lo invoca, así que CLI y panel no pueden divergir):

- valida nombre/URL no vacíos, URL `http(s)://` y ausencia de `|`
- rechaza duplicados por nombre
- usa el siguiente id libre
- escribe de forma atómica (archivo temporal + `mv`)
- con entrada inválida el archivo queda byte-idéntico

### Cambio: búsqueda de estaciones
El campo superior filtra la lista mientras se escribe, por nombre o por
URL/protocolo (`https`, `m3u8`, dominio…). No modifica `stations.conf`.

### Cambio: estado en vivo barra ↔ panel
`BarWidget.qml` y `Panel.qml` leen `~/.config/omarchy-radio/state` con
`FileView` (con `watchChanges`), así el icono de la barra, el número de
estación, el resaltado de la fila activa y el play/pause del header se
actualizan cuando `radio-control.sh` cambia el estado. Antes el estado se
derivaba de un `Process` que nunca corría, así que la barra nunca se
actualizaba. El `radioProcess` muerto se eliminó.

### Cambio: widget de barra con el componente compartido
`Ui.BarIconButton` + `iconComponent` → `Ui.WidgetButton` (glyph `󰝚` + número
de estación mientras reproduce), como la referencia.

### Cambio: estación por defecto
Configuración generada por `install.sh` y por `radio-control.sh` (solo cuando
`stations.conf` no existe) empieza por
`1|Radio Exa 92.5 FM Ecuador|https://26573.live.streamtheworld.com/ECUADORAAC.aac`.
El orden del resto de las estaciones por defecto no cambia. **Los
`stations.conf` existentes no se modifican.**

### Pruebas
- 5 suites en verde: `radio-control.sh` 25, `manifest.json`, `gadget stations`
  14, `QML Integration` 42, `E2E Workflow` 34 (antes 15 tests en rojo).
- Nuevas: default Exa, `add` (append, URL no-http, `|` en nombre, duplicado,
  nombre vacío, ayuda).
- Aserciones actualizadas porque cambiaron de implementación (el texto/color/
  fuente ahora viven en el componente compartido) y porque los tests afirmaban
  la identidad vieja `omarchy.radio` y `Ui.Panel` (el bug ya corregido).
- Retiradas 3 aserciones fantasma que exigían API inexistente en el shell:
  `setSetting()` (el contrato solo expone `setting()` de lectura),
  `BarWidget has spacing` y `BarWidget has radius` (el widget ya no dibuja
  formas ni espaciado propio; ahora es un componente compartido).

### Nota sobre el aviso `Non-existent attached object [176:21]`
Sigue apareciendo al recargar el plugin, pero **no es de este código**: se
reproduce con un `Panel.qml` de 8 líneas que solo declara `Panel { }`, y
también aparece al tocar únicamente `BarWidget.qml`. La posición 176:21 no
existe en el archivo instalado. No proviene de este plugin.
