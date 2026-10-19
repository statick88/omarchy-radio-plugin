# RDD Quality Report - statick.radio

## Información del Proyecto
- **Plugin**: statick.radio
- **Fecha**: 2026-10-19 (actualización; el reporte previo reclamaba métricas falsas)
- **Autor**: statick
- **License**: MIT

## Métricas verificadas

Números tomados de la ejecución real de `odd/tests/run-all-tests.sh`
(142 tests, 141 pasan, 1 skip opt-in de red, 0 fallan). Antes de esta
actualización este reporte afirmaba "117/117 (100%)", "coverage 100%" y
"Production Ready", que eran falsos.

| Suite                     | Total | Pasan | Fallan |
|---------------------------|-------|-------|--------|
| radio-control.sh          | 30    | 30    | 0      |
| manifest.json             | 22    | 22    | 0      |
| gadget stations           | 14    | 13    | 0 (1 skip opt-in) |
| QML Integration           | 42    | 42    | 0      |
| E2E Workflow              | 34    | 34    | 0      |
| **TOTAL**                 | **142**| **141**| **0** |

Estabilidad: radio-control 30/30 en 5 corridas; runner 5/5 suites en 3 corridas.

## Corrección de esta iteración (S1/S2)

- `stop_radio()` barre todos los streams de `stations.conf` (antes hardcodeaba
  radioparadise/somafm/example.com y nunca mataba el stream por defecto
  streamtheworld → dos mpv simultáneos al cambiar de estación).
- El clamp de estación de la barra sube de 5 a 20.
- Race condition del suite corregida (barrera `wait_for_log`).

## Lo que NO está implementado (aspiracional)

Ver `.agents/MISION` (sección "Objetivo") y `.progress` (sección
"Pendiente / no implementado"): colores por estación, editar/eliminar
estaciones desde la UI, animaciones, subcomando de volumen, coverage real.

## Code Quality Checks

- Formato: QML con `pragma ComponentBehavior: Bound`; bash con `set` explícito.
- Aislamiento de tests: `HOME=$(mktemp -d)`, shims de mpv/pkill.
- Escritura atómica de `stations.conf`; entradas inválidas no modifican el archivo.
