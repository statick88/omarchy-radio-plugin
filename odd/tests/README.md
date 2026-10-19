# Test Suite para statick.radio

## Fases de Testing

### 1. TDD (Test-Driven Development)
- Tests unitarios para radio-control.sh
- Validación de manifest.json
- Tests de lógica de estaciones
- Tests de persistencia de estado
- `add`: alta de estaciones (validación, id libre, duplicados, escritura
  atómica — el archivo queda byte-idéntico ante entradas inválidas)
- Estación por defecto: `1|Radio Exa 92.5 FM Ecuador|…` en configs nuevas

### 2. Gadget Stations (SketchyBar)
- Fixture `fixtures/gadget-stations.conf` con las 3 estaciones importadas
  del gadget de SketchyBar (`state/radio_stations.json` en `mac`)
- Parseo, `status`, ciclo `next`/`prev` y rechazo de estación inexistente
- Aislamiento: `mpv` y `pkill` se reemplazan por shims en `PATH`, así la
  suite no toca la reproducción en vivo ni mata procesos del sistema
- Streams en vivo (opt-in): `LIVE_STREAMS=1 ./test-gadget-stations.sh`

### 3. Integration Tests
- Carga del plugin en omarchy
- Comunicación BarWidget ↔ Panel
- File I/O para configuración
- Procesos mpv

### 4. E2E Tests
- Flujo completo: instalar → configurar → reproducir
- UI interactions
- Persistencia entre sesiones

### 5. RDD (Receipt-Driven Development)
- Validación de calidad de código
- Verificación de contratos
- Checks de seguridad

## Ejecutar pruebas
./run-all-tests.sh