# Solución: Plugin Radio no aparecía en omarchy

## Problema detectado
El plugin no aparecía en la lista de plugins de omarchy ni en la barra.

## Causa raíz
El ID del plugin `omarchy.radio` estaba reservado para plugins de primera parte de omarchy. Los plugins de tercero deben usar un prefijo diferente (como `statick.`, `user.`, etc.).

## Solución aplicada

### 1. Renombrar el plugin
```bash
cd ~/.config/omarchy/plugins
mv omarchy.radio statick.radio
```

### 2. Actualizar IDs en archivos
```bash
cd statick.radio
sed -i 's/omarchy\.radio/statick.radio/g' manifest.json BarWidget.qml Panel.qml
```

### 3. Actualizar shell.json
```bash
cd ~/.config/omarchy
jq '.bar.layout.right = [.bar.layout.right[] | if .id == "omarchy.radio" then .id = "statick.radio" else . end]' shell.json > shell.json.tmp
mv shell.json.tmp shell.json
```

### 4. Reiniciar omarchy
```bash
omarchy restart shell
```

## Verificación
```bash
omarchy plugin list | grep radio
# Output: statick.radio    enabled   third-party bar-widget,overlay Radio
```

## Archivos fuente actualizados
- `/home/statick/Projects/radio/odd/manifest.json`
- `/home/statick/Projects/radio/odd/BarWidget.qml`
- `/home/statick/Projects/radio/odd/Panel.qml`
- `/home/statick/Projects/radio/odd/install.sh`
- `/home/statick/Projects/radio/odd/README.md`

## Nota importante
Los plugins de omarchy usan namespaces:
- `omarchy.*` - Plugins de primera parte (oficiales)
- `statick.*`, `user.*`, `autor.*` - Plugins de tercero

Para plugins personalizados, SIEMPRE usar un namespace que no sea `omarchy.*`.