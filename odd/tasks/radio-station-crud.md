# Feature: CRUD completo de estaciones (locator: odd/tasks/radio-station-crud.md)

- Objetivo: añadir **editar** y **eliminar** estaciones desde la UI (add + search ya existen).
- Rama: `feat/radio-stop-sweep` (HEAD en c925337). Ruta: inline.
- Test runner: `cd odd/tests && ./run-all-tests.sh`.

## Specs

### S1 — Editar estación (`update_station`)

- `radio-control.sh update <id> <nuevo_nombre> <nueva_url>`: valida igual que `add` (nombre no vacío, URL http(s), sin `|` ni saltos); id debe existir; nombre nuevo no debe chocar con otra estación (salvo la misma); escritura atómica.
- Panel.qml: en la lista, cada fila gana botón "editar" (solo visible en hover/focus). Al click: precarga nombre/url en el composer, cambia botón "＋" → "✓", y `submitStation` detecta modo edición por `root.editingId` definido. Al aceptar: llama `radio-control.sh update <id> <name> <url>`.

### S2 — Eliminar estación (`delete_station`)

- `radio-control.sh delete <id>`: elimina la línea; renumera ids contiguos 1..N para que `next`/`prev` y el clamp 20 sigan coherentes; si se borra la estación actual y está sonando → `stop`; escritura atómica.
- Panel.qml: botón "eliminar" (icono 🗑) en cada fila (hover/focus). Click → confirmación inline (no modal). Al confirmar: llama `radio-control.sh delete <id>`. Si es la estación activa → stop automático.

### S3 — Integración UI existente

- Composer reutilizado: modo "add" (vacío, botón ＋) vs "edit" (prellenado, botón ✓).
- Search filtra antes de mostrar botones editar/eliminar.
- Feedback visual: estado guardando / error / éxito (toast inline).

- L1 (verbatim): "funcion de agregar, buscar, actualizar y quitar radios" → autoriza CRUD completo.
- L2: T1-T3 completados: add/update/delete en radio-control.sh + tests, Panel.qml con botones editar/eliminar por fila, composer dual add/edit, confirmación delete.
- L3: Tests 5/5 suites verdes; CLI verificado: add/update/delete + renumeración 1..N.
- L4: UI integrada: hover muestra botones ✎/🗑, composer cambia título/tooltip según modo, editingId limpiado al cerrar.

## Tasks

- T1 (S1) `update_station` en radio-control.sh + tests. ✅
- T2 (S2) `delete_station` en radio-control.sh + tests. ✅
- T3 (S1-S2) Panel.qml: botones editar/eliminar por fila, composer dual add/edit, confirmación delete. ✅
- T4 Tests E2E de editar y eliminar (incluidos en suite existente). ✅
- T5 5 suites verdes + instalar. ✅