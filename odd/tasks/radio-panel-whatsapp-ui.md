# Feature: Panel con UI estilo WhatsApp + alta de estaciones

- Objetivo: replicar la UI del plugin `io.github.ricky.whatsapp` para el plugin radio
  (header, lista, composer inferior), con formulario que agrega estaciones a
  `stations.conf`, búsqueda en la lista y `Radio Exa 92.5 FM Ecuador` por defecto.
- Branch: el repositorio está en `master` sin commits y `odd/` está en `.gitignore`
  (ver Log L0); se trabaja sobre el árbol actual, sin push/PR.
- Test runner: `odd/tests/run-all-tests.sh` (5 suites).
- Riesgo por tarea: ver línea `Risk:` al cierre de cada tarea.

## Specs

### S1 — Misma UI que el plugin de WhatsApp
Cita del usuario (verbatim): `quiero la misma ui para este plugin`

Referencia analizada: `io.github.ricky.whatsapp`
(`github.com/srineshr1/omarchy-whatsapp`, `preview.png` + `Panel.qml` 1287 líneas +
la captura de la vista de conversación que aportó el usuario).

Aceptación:
- El panel se monta con `KeyboardPanel` + `PanelKeyCatcher` de `qs.Ui`
  (`fittedContentWidth(Style.space(...))`), igual que la referencia.
- Header: botón atrás/cerrar a la izquierda (26×26, hover con
  `Style.hoverFillFor`/`Style.normalFillFor`), título al centro-izquierda,
  acciones a la derecha (`PanelActionButton`).
- Lista de estaciones con fila activa resaltada en `Color.accent`, hover,
  icono/nombre y estado, replicando la fila de chats de la referencia.
- Composer inferior: `TextField` de `qs.Ui` con placeholder + `PanelActionButton`
  habilitado solo con texto, igual que `Reply…` + botón enviar de la referencia.
- Teclado: `Esc` cierra/vuelve, `Tab` cambia de foco, flechas mueven el cursor,
  `Enter` activa la fila seleccionada; el `PanelKeyCatcher` queda `blocked`
  cuando un `TextField` tiene foco.
- Colores y tamaños solo desde `Color.*`, `Style.space()`, `Style.font.*`;
  sin colores hardcodeados.
- Componentes compartidos obligatorios (verificados en
  `/usr/share/omarchy/shell/Ui/`): `WidgetButton`, `PanelActionButton`,
  `TextField`, `PanelKeyCatcher`, `PanelToolTip`, `PanelSeparator`.

### S2 — Formulario que agrega la estación a `stations.conf`
Cita del usuario (verbatim): `si mediante un formulario el plugin ya lo agrega a statins.conf`

Aceptación:
- El formulario tiene nombre y URL; al enviarlo la estación queda en
  `~/.config/omarchy-radio/stations.conf` con el formato existente
  `id|nombre|url`, con `id` = siguiente libre.
- La lista del panel muestra la estación nueva sin reiniciar el shell.
- Entradas inválidas (nombre vacío, URL vacía, URL sin `http://`/`https://`,
  texto con `|`) **no** modifican el archivo (el contenido previo queda
  byte-idéntico) y el panel muestra un error visible.
- Una estación con el mismo nombre ya existente se rechaza con error.
- La escritura es atómica (archivo temporal + `mv`) para no dejar
  `stations.conf` a medias si el proceso muere.
- El comando queda disponible también por CLI con su ayuda actualizada
  (`radio-control.sh add <nombre> <url>`), para que la UI y el CLI
  compartan un único escritor.

### S3 — Búsqueda de estaciones disponibles mientras se escribe
Cita del usuario (verbatim): `podemos buscar las disponibles segun el protocolo`

Aceptación:
- Un campo de búsqueda filtra la lista mostrada mientras se escribe,
  coincidiendo con el nombre o con la URL/protocolo de la estación
  (`http`, `https`, `m3u8`, dominio).
- Sin coincidencias se muestra un mensaje vacío; la búsqueda no toca
  `stations.conf`.
- Limpiar el campo restaura la lista completa.

### S4 — Estación por defecto: Radio Exa 92.5 FM Ecuador
Cita del usuario (verbatim): `por defecto quiero radio exa 92.5 fm ecuador`

Aceptación:
- Con `stations.conf` inexistente, la configuración por defecto tiene como
  estación `1` a `Radio Exa 92.5 FM Ecuador` y es la estación activa inicial.
- El stream por defecto es el del gadget de SketchyBar:
  `https://26573.live.streamtheworld.com/ECUADORAAC.aac`.
- **Asunción marcada**: el usuario dio el nombre ("radio exa 92.5 fm ecuador");
  la URL se tomó de `state/radio_stations.json` del gadget (`"exa"`), que es
  la única URL de Exa disponible en ese equipo. El usuario puede corregirla.
- `install.sh` y `radio-control.sh` generan la misma lista por defecto.

### S5 — Radios del gadget de SketchyBar disponibles para pruebas (entregado)
- Fixture `odd/tests/fixtures/gadget-stations.conf` con las 3 estaciones del
  gadget (`boqueron`, `exa`, `ritmo`).
- Suite `odd/tests/test-gadget-stations.sh` (14 tests, aislada con shims de
  `mpv`/`pkill`) registrada en `run-all-tests.sh`.

## Tasks

| ID | Specs | Route | Status | Commit / evidencia |
|----|-------|-------|--------|--------------------|
| T1 | S4 | inline | ✅ done | 25/25 en `test-radio-control.sh`; `test_default_first_station_is_exa` |
| T2 | S2 | inline | ✅ done | RED 5 fallos → GREEN 25/25; 6 tests nuevos de `add` |
| T3 | S1, S2, S3 | inline | ✅ done | `Panel.qml` 533 líneas; carga en el shell sin avisos propios |
| T4 | S1 | inline | ✅ done | `BarWidget.qml` con `Ui.WidgetButton` + `FileView` de estado |
| T5 | S1–S4 | inline | ✅ done | 5/5 suites: 42 + 34 + 25 + 14 + manifest |
| T6 | S1–S4 | inline | ✅ done | `README.md` (UI real + `add`) y `CHANGES-LOG.md` |
| T7 | bug L11 | inline | ✅ done | `stop_radio` barre por config; 30/30 en `test-radio-control.sh` |

- T1 — Estación por defecto Exa en `radio-control.sh` e `install.sh` + test que la fija.
- T2 — Subcomando `add` en `radio-control.sh` (validación, id siguiente libre,
  escritura atómica, rechazo de duplicados/inválidos, ayuda) con tests RED→GREEN.
- T3 — `Panel.qml` con la UI de referencia: header, lista de estaciones,
  campo de búsqueda (S3), formulario de alta (S2) y manejo de teclado.
- T4 — `BarWidget.qml`: botón de barra estilo referencia (`WidgetButton`,
  estado/botón activo, tooltip, inyección al panel).
- T5 — Pruebas de esta feature: alta desde CLI/UI, búsqueda, default Exa;
  y actualización de las aserciones que el rediseño deja obsoletas.
- T6 — Docs: `README.md` (uso del formulario y búsqueda) + entrada en
  `CHANGES-LOG.md`.

## Log

- **L0** (2026-10-18, hecho antes de este feature): repositorio en `master`
  **sin commits**; `.gitignore` excluye `odd/`, `.progress` y `.agents/`, así que
  el plugin no tiene control de versiones. Se deja constancia; cambiar eso es
  decisión del usuario.
- **L1** — Petición original del usuario (verbatim):
  `analiza el historial de este plugin y verifica si los errrores cometidos fueron subsanados`
- **L2** — Usuario (verbatim):
  `verifica .agents y .progress`
- **L3** — Usuario (verbatim):
  `no visualizo la opcion para poder ingresar las radios, verifica con "ssh mac" el plugin sketchybar y el gadget de radio de dond eparte esto, verifica que eta bien elaborado el plan, trae las radios de ese gadget para las pruebas`
  → Entregado: fixture + suite de 14 tests (S5). Plan del gadget: openspec
  `RADIO-MOD-001` con sus 4 acceptance criteria **sin marcar**; el plan local no
  existe (no hay `odd/tasks/`, solo `.progress`, cuyos claims de 117/117 tests y
  "0 errores" quedaron desmentidos: 119 tests reales, 15 en rojo).
- **L4** — Usuario (verbatim):
  `analiza la ui de https://plugins.omarchy.org/plugin.html?id=io.github.ricky.whatsapp quiero la misma ui para este plugin`
- **L5** — Decisiones del usuario (verbatim):
  `1. si mediante un formulario el plugin ya lo agrega a statins.conf`
  `2. podemos buscar las disponibles segun el protocolo`
  `3. analiza el gadget en mac para que puedas tener mas claro el funcionamiento`
  `por defecto quiero radio exa 92.5 fm ecuador`
- **L6** — Análisis del gadget en `mac` (2026-10-18):
  `~/.config/sketchybar/plugins/radio.py` (416 líneas) implementa `cycle`,
  `play` y `stop` — **no existe `add`**: en todo el config solo `radio.py` y
  `openspec/plugins/radio_spec.md` mencionan `radio_stations.json`, es decir
  que allí las estaciones se agregan **editando el JSON a mano** (el spec lo
  confirma: "Given a new station is added to 'radio_stations.json' / Then the
  popup should automatically include the new station"). El popup del gadget solo
  lista estaciones + "APAGAR ⏻". Estado actual del gadget:
  `state/radio.json = {"current": "exa", "playing": true}`. Otras diferencias
  con nuestro plugin: valida el stream antes de reproducir (`ffprobe`/`curl`),
  pausa Spotify, auto-reconnect con backoff exponencial (5·2ⁿ, máx 120 s),
  ecualizador animado y `pkill -9 -f ffplay.*nodisp`; nosotros usamos `mpv` sin
  validación, sin pausa de Spotify y sin reconexión. Tests del gadget:
  `tests/test_radio.py` (pytest, 2 casos: play robusto y lógica de PID).
- **L7** — Implementación (2026-00-18, T1–T6, ruta inline en todos los casos;
  sin triggers de delegación: escrituras entendidas y contiguas, sin unidades
  paralelas ni riesgo alto):
  - `add` vive en `radio-control.sh` y la UI lo invoca con `Process` +
    `StdioCollector` (stderr → mensaje de error en el formulario). Un único
    escritor ⇒ la CLI y el panel no pueden divergir en el formato.
  - Estado en vivo: `FileView { watchChanges: true }` sobre
    `~/.config/omarchy-radio/state` en `BarWidget.qml` y en `Panel.qml`
    (regex `^([A-Z_]+)=(.*)$`). Esto repara el defecto reportado de "la barra
    nunca se actualiza": el `radioProcess` anterior nunca corría. Se eliminó.
  - `Ui.BarIconButton` + `iconComponent` → `Ui.WidgetButton` (glyph `󰝚` +
    número de estación mientras reproduce), igual que la referencia. Se
    adoptó también su patrón de doble inyección (`Qt.callLater`) al cargar
    el panel.
  - Defaults: Exa primera en `radio-control.sh` e `install.sh`; el resto de
    la lista por defecto no cambia y los `stations.conf` existentes no se
    tocan (ver L10, decisión pendiente).
- **L8** — Pruebas (T5): 5/5 suites en verde (antes 15 tests en rojo).
  - Rediseñadas aserciones que grep-eaban el componente viejo: texto/color/
    fuente del bar widget ahora viven en `Ui.WidgetButton`
    (`text:`/`foreground:`/`bar: root.bar`), y `Panel has layout` acepta
    `Column {`/`Row {` (el panel no usa los `Layout` de Qt).
  - `Panel has panel component` ya no exige `Ui.Panel`: `Panel {` es la forma
    corregida (el bug era justamente el prefijo).
  - `test-e2e.sh`: todas las aserciones `omarchy.radio` → `statick.radio`
    (el install.sh lleva instalando en `statick.radio` desde la corrección
    del namespace).
  - Retiradas 3 aserciones fantasma que exigían API inexistente:
    `setSetting()` (el shell solo expone `setting()` de lectura; verificado en
    `/usr/share/omarchy/shell/Ui/{Panel,BarWidget}.qml`), `BarWidget has
    spacing` y `BarWidget has radius`.
  - Añadido `Panel has spacing` (`spacing:` explícito en el layout).
- **L9** — Hallazgo: el aviso `WARN scene: …/statick.radio/Panel.qml[176:21]:
  Non-existent attached object` **no es de este plugin**. Evidencia: aparece
  igual con un `Panel.qml` de 8 líneas que solo declara `Panel { }`, y
  también al tocar únicamente `BarWidget.qml`; la posición 176:21 no existe
  en el archivo instalado. Preexistente, fuera del alcance de este feature.
  (El `Layout.fillWidth` real del archivo viejo sí se eliminó con el
  rediseño.)
- **L10** — **Decisión del usuario (2026-10-18): Opción A**, renumerar la
  configuración real prependiendo Exa. Aplicado y verificado con
  `radio-control.sh status` (estación 1 = `Radio Exa 92.5 FM Ecuador`, las
  existentes pasan a 2/3/4, ninguna eliminada). Backup reversible en
  `~/.config/omarchy-radio/stations.conf.bak-prepend-exa`. El estado
  `CURRENT_STATION=1` no requirió cambios: ahora apunta a Exa. Ninguna suite
  depende de esa config (las 5 usan `export HOME="$TEST_HOME"` con
  `mktemp -d`).
- **L11** — Usuario (verbatim): `no puedo seleccionar la radio`
  → Causa raíz corregida en `stop_radio` (`radio-control.sh`). El barrido de
  detención estaba **hardcodeado** a tres hosts (`radioparadise`, `somafm`,
  `example.com`), así que Exa (`streamtheworld`) **nunca se detenía**: cada
  clic en una estación apilaba un `mpv` nuevo encima del anterior y el stream
  viejo seguía sonando. Ahora el barrido se deriva de las URLs de
  `stations.conf` (omit comentarios, líneas vacías y filas sin `http(s)`), por
  lo que cubre también cualquier estación agregada desde el formulario.
  - La llamada `stop_radio` dentro de `play_station` cubre a la vez cambio de
    emisora y `stop`.
  - Tests: 5 pruebas de reproductor con shims de `mpv`/`pkill` (el shim
    registra cada invocación en `SHIM_LOG` y finge un stream vivo) →
    **30/30 GREEN** en `test-radio-control.sh`. Cubren: barrido por config en
    `play`, `stop` silenciando Exa, barrido de todas las URLs, config vacía y
    config por defecto.
  - Hallazgo de la suite: `mpv ... &` es asíncrono, así que el `echo` del shim
    puede aterrizar después de que el test lea el log. Se absorbe con el
    helper `wait_for_log` (sondea la línea esperada, 50 × 50 ms) antes de
    `grep`; sin él la suite dependía del planificador.
  - Diagnóstico descartado: 3 procesos `mpv` de Exa hallados eran
    contaminación de la propia suite (`HOME=/tmp/tmp.*`, huérfanos bajo
    `systemd --user`), no clics del usuario. El script fue verificado sano
    invocado a mano con el `HOME` real (escribió `state`, `mpv.pid` y spawnó
    un solo `mpv`). Se limpiaron los huérfanos y el estado quedó en
    `IS_PLAYING=false`.
  - Instrumentación temporal `[radio-diag]` (7 puntos en `Panel.qml`):
    retirada por completo tras verificar la recarga limpia. `Panel.qml` con
    535 líneas, llaves 79/79.
- **L12** — Verificación final de la instalación: `install.sh` ejecutado;
  `Panel.qml`, `BarWidget.qml` y `radio-control.sh` **idénticos** entre el
  repo y `~/.config/omarchy/plugins/statick.radio/`. Recarga del plugin limpia
  en el shell en vivo (solo el WARN preexistente de L9 y los de WhatsApp,
  ajenos). Falta la prueba manual del usuario: clic en una estación → un solo
  `mpv` y `state` actualizado.
