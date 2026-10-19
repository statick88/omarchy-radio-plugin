# Feature: stop/stop_radio barre streams reales de stations.conf (locator: odd/tasks/radio-stop-sweep-real.md)

- Objetivo: `stop` y cambio de estación deben silenciar CUALQUIER stream listado en
  `stations.conf`, no solo una lista hardcodeada; y la barra no debe truncar la
  estación a 5.
- Rama/estado: repo en `master` sin commits; `odd/` es gitignorado (ver L1). Ruta: inline.
- Test runner: `cd odd/tests && ./run-all-tests.sh` (5 suites; aislamiento con `HOME=$(mktemp -d)`).
- Validación: RDD activo (`gentle-ai review mode status` = on, global).

## Specs

### S1 — `stop`/cambio de estación barren todo `stations.conf`

`stop_radio()` en `radio-control.sh` debe matar todo proceso mpv cuya línea de
comandos contenga alguna URL configurada, en lugar de una lista fija de hosts:

- Antes (defecto, líneas 123-125): `pkill -f "mpv.*radioparadise"`,
  `pkill -f "mpv.*somafm"`, `pkill -f "mpv.*example.com"` — la estación por
  defecto (`https://26573.live.streamtheworld.com/ECUADORAAC.aac`) queda fuera
  y sigue sonando en background al cambiar de estación (dos mpv a la vez).
- Requisito: por cada fila `id|nombre|url` de `stations.conf`, un `pkill -f` que
  case `mpv` + la URL exacta de esa fila. Cualquier host debe ser cubierto,
  incluido `streamtheworld.com` y cualquier estación agregada por el formulario.
- Requisito: la URL se usa como regex, así que los puntos deben ir escapados
  para que `a.b` no case `axb` (falso positivo contra otro proceso).
- Requisito: `stations.conf` ausente o sin filas válidas no rompe `stop` ni
  `play` (solo se omite el sweep; el kill por PID file sigue funcionando).
- Afecta a `play`, `stop`, `next`, `prev` y `toggle`, porque todos pasan por
  `stop_radio()` (`play_station` lo llama en la línea 89).

### S2 — La barra no trunca la estación a 5

- Antes: `BarWidget.qml:26` → `Math.max(1, Math.min(5, setting("station", 1)))`,
  con `stations.conf` soportando N estaciones y `Panel.qml` ciclando por
  `root.stations.length` sin tope.
- Requisito: el tope sube a 20, de modo que el badge de la barra y el ciclado
  `next`/`prev` alcanzan cualquier estación realista sin mentir sobre la actual.
- Fuera de alcance (queda registrado): `next_station()`/`prev_station()` usan
  `count_stations` como si los ids fueran contiguos 1..N; con huecos en la
  numeración puede intentar una estación inexistente.

## Tasks

- T1 (S1) RED: test `Player: stop sweeps every configured stream URL` en rojo
  contra el código actual. Ruta: inline. ✅ RED observado (3 en rojo).
- T2 (S1) GREEN: `stop_radio()` deriva el sweep de `stations.conf`. Ruta: inline.
  ✅ 30/30. Fix adicional: el loop usaba la variable `station_url`, que en bash
  (scope dinámico) pisaba la `local` del caller `play_station` y dejaba a mpv
  sin URL; renombrada a `sweep_url` (local).
- T3 (S2) Subir clamp de estación a 20 en `BarWidget.qml`. Ruta: inline. ✅
- T4 (S1-S2) Las 5 suites en verde + instalar en el equipo real. Ruta: inline.
  ✅ 5/5 suites estables en 3 corridas; radio-control 30/30 en 5 corridas.
  Race condition del suite corregida (ver L4).
- T5 (todo) Reescribir `.progress` y `.agents/MISION|VISION` con métricas reales.
  Ruta: inline. ✅

## Log

- L1 (verbatim del usuario): "analiza el estado actual del plugin" → diagnóstico:
  `radio-control.sh` en rojo 25/27; causa raíz `stop_radio()` con pkill hardcodeado
  que nunca mata `streamtheworld.com` (Exa, la estación 1 por defecto) → al cambiar
  de estación quedan dos mpv; `BarWidget.qml:26` clampa estación a 5. Plugin
  instalado idéntico a `odd/`, defecto vivo en el equipo.
- L2 (verbatim del usuario): "si con odd y valida con rdd, actualiza .progress y .agents"
  → autoriza implementación, validación RDD y actualización de los dos artefactos.
- L3: T1 RED observado (3 en rojo: sweep hardcoded + 2 tests originales). T2 GREEN
  corrigió dos defectos: (a) el pkill hardcodeado → sweep derivado de stations.conf
  con guard `case` que solo acepta `http(s)://`; (b) shadowing de `station_url`
  entre `stop_radio` y `play_station` que enviaba URL vacía a mpv.
- L4: el test `play stops previous stream` era flaky por una race condition del
  SUITE, no del plugin: el shim de mpv corría en background (`mpv ... &`) y el
  test limpiaba el log antes de que el proceso escribiera, contando 2 líneas MPV.
  Corregido quitando el `sleep 30` del shim y añadiendo la barrera
  `wait_for_log()` que espera la escritura antes de limpiar el log. Evidencia:
  radio-control 30/30 en 5 corridas; runner 5/5 suites en 3 corridas.
- L5 (T5): `.progress` reescrito con métricas reales (antes reclamaba 117/117,
  100% coverage, "Production Ready" y animaciones, todo falso). `.agents/MISION|VISION`
  pasan a separar lo implementado de lo aspiracional. Totales reales:
  radio-control 30, manifest 22, gadget 13 (+1 skip opt-in de red), QML 42, E2E 34.
