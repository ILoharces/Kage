# Kage — arquitectura

Proyecto Godot 4.6, duelo 1v1 estilo Spy vs Spy. Mapas editables en JSON (`user://maps/`).

## Flujo de partida

1. `Scenes/main.tscn` — orquestador (`Scripts/core/main.gd`).
2. Menú → `PlayMenu` / `MapEditor` → `LevelLayout` vía `MapStorage`.
3. `GameState.reset_match()` → `Mansion.begin_with_layout(layout)`.
4. HUD, Trapulator y cámaras se enlazan en `Main._bind_ui()`.

## Autoloads

| Nombre | Rol |
|--------|-----|
| `ItemDB` | Enums y datos de items, trampas, muebles, espías |
| `WeaponDB` | Registro de armas (`resources/weapons/*.tres`) |
| `GameState` | Inventario de objetos (maletín/items), trampas en stock, armas solo en manos, tiempo, victoria |
| `GameSettings` | Opciones persistentes (`use_ai_default`, modos de control por jugador) |
| `InputBindings` | Mapa fijo de acciones; aplica solo el slot del modo elegido (teclado+ratón o mando) |
| `DisplayConfig` | Tamaño habitación, panel stats, zoom |

## Carpetas

- `Scripts/core/` — `GridDirection`, `main.gd`, `MainLayout`, `MainScreens`, `MatchConfig`
- `Scripts/combat/` — `WeaponData`, `WeaponExecutor`, `AimController`, `AimResolver`
- `Scripts/actors/` — `SpyBase` + `SpyMovement/Combat/Interaction/Visual`, `Player`, `AiSpy`
- `Scripts/traps/` — `TrapRules` (disparar o desactivar una trampa según la contramedida en mano), `TrapStock` (trampas y contramedidas restantes por espía)
- `Scripts/world/` — `Mansion`, `MansionBuilder`, `MansionAiPaths`, `Room`, `RoomGeometry`, mapas
- `Scripts/ui/` — `MenuScreen` / `UiKit` (menús), `Hud`, `SpyHudPanel`, editor (`MapEditorGrid*` helpers), tema en `resources/ui/kage_theme.tres`

## Grupos de nodos

- `"spy"`, `"player"`, `"ai_spy"`
- `"room"`, `"furniture"`, `"door"`
- `"ground_pickup"`, `"dropped_item"`, `"dropped_weapon"`
- `"hud_root"`, `"minimap"`, `"map_overlay_root"`

## Checklist: cambiar algo

### Nueva trampa

1. `ItemDB` — enum `TrapId`, `TRAP_NAMES`, `TRAP_COLORS`, `TRAP_SITES` (mueble / puerta / habitación), `TRAP_HIT_NOTICES`
2. `ItemDB` — su contramedida: enum `CounterId`, `COUNTER_NAMES`, `COUNTER_COLORS`, `TRAP_TO_COUNTER`; icono en `ArtLibrary.COUNTERS`
3. `SpyCombat.apply_trap_effect` — efecto al dispararse
4. Disparo: llamar siempre a `TrapRules.trigger(spy, trap_id)`, que ya resuelve la desactivación con contramedida
5. Colocación: `SpyInteraction.try_place_trap` según `TRAP_SITES` (sitio nuevo = nueva rama ahí)
6. `TrapWheel` y Trapulator leen `ItemDB.get_all_traps()` / `get_all_counters()`: no hace falta tocarlos

### Contramedidas

- Se equipan en la mano (`HeldInventory.Kind.COUNTER`) desde el anillo exterior de la rueda o la columna derecha del Trapulator.
- Mueble o puerta con trampa + contramedida correcta en mano: la trampa se desactiva (`TrapRules.try_disarm`) y se gasta una unidad si el stock no es infinito.
- Bomba de tiempo: cualquier espía con el Desactivador dentro de la sala la anula, esté armada o en cuenta atrás.
- Stock inicial en `MatchConfig.starting_counters_per_kind` / `counters_infinite`.

### Nuevo item

1. `ItemDB` — enum `ItemId`
2. `GameState` — reglas maletín / inventario
3. `hud.gd` — slots de inventario

### Nuevo mueble

1. `ItemDB` — `FurnitureKind`
2. `furniture_placement.gd` — posiciones
3. `furniture.gd` — interacción

### Tiempo de partida / balance

- `resources/match_config.tres` (`MatchConfig`)
- `GameState.reset_match()` lee el resource

### Nuevo mapa

- Editor in-game o JSON en `user://maps/` (ver `levels/README.md`)
- `LevelLayout` + `Mansion.begin_with_layout`

### Direcciones de rejilla

- Usar `GridDirection.delta()` y `GridDirection.opposite()` — no duplicar `_dir_delta`.

### Nueva arma (combate PvP)

1. Crear `resources/weapons/mi_arma.tres` (`WeaponData`): `aim_profile`, `delivery`, daño, cooldown, etc.
2. (Opcional) Script `WeaponEffect` custom en `custom_effect` si la lógica no cabe en el delivery genérico.
3. Añadir al spawn en `MansionBuilder` o datos de mapa.
4. Probar: pickup suelo → arma en manos (no en caja de inventario) → apuntar → `fire_weapon` → daño / eliminación.

Las armas no comparten el inventario de objetos ni el stock de trampas: una sola en manos; al equipar trampa u otra arma, la anterior cae al suelo; al coger arma se sueltan maletín/objetos en manos. El bazooka dispara un cohete: daña y empuja, destruye el mueble que toca (la trampa desaparece sin saltar) y, si cruza una pared con sala detrás, abre un pasaje permanente en el punto del impacto.

No suele hacer falta tocar `Player`, `AimResolver` ni `WeaponExecutor` salvo un nuevo valor de `delivery`.

## Input y modos de control

Los controles **no se reasignan** en v1. En **Ajustes > Controles** cada jugador elige un modo; `InputBindings.apply_action()` registra en el `InputMap` solo el slot activo (teclado o mando), evitando solapes entre jugadores.

| Modo | Jugador | Movimiento / acciones | Apuntado (combate) |
|------|---------|----------------------|-------------------|
| Teclado y ratón | P1 | WASD, E/Q/R/Tab/M/Esc, clic disparo | Ratón |
| Mando | P1 o P2 | Stick izq., A/Y/X/LB/Start/Select, RT disparo | Stick der. (cursor virtual) |

Combinaciones válidas (2 jugadores locales):

- P1 teclado+ratón + P2 mando (1 mando)
- P1 mando + P2 mando (2 mandos)

Reglas:

- No se permiten dos jugadores en modo teclado a la vez.
- P2 «Teclado» está deshabilitado hasta definir teclas de apuntado.
- Con ambos en mando hace falta hardware: 2 mandos conectados (`PlayMenu` avisa al jugar).
- **Contra IA**: `InputBindings.set_ai_adaptive_controls(true)` al iniciar partida; P1 cambia entre teclado+ratón y mando según el último dispositivo usado (sin guardar en disco). El modo de J1 en Ajustes solo fija el valor inicial.

Persistencia: `user://game_settings.cfg` sección `controls` (`p1_control_mode`, `p2_control_mode`). Los bindings fijos viven en código (`InputBindings._build_default_bindings()`).

Movimiento y apuntado con mando respetan la inclinación del stick (no van siempre a fondo). Interactuar, trampas y disparo se leen por polling en `Player._process`, porque el espía vive dentro de un `SubViewport`.

La rueda de trampas (`TrapWheel`) se abre manteniendo `next_trap` / `p2_next_trap` en la posición del cursor (ratón, o mirilla si es mando). Soltar la tecla o pulsar disparar sobre un sector equipa esa trampa. Si ya llevas una trampa, la X del centro la suelta al confirmar encima; el centro vacío o fuera de la rueda cierra sin cambiar lo que llevas. Mientras está abierta, ese jugador no apunta ni dispara. Con mando, el stick de apuntar elige el sector. El anillo exterior contiene la contramedida de cada trampa, alineada con ella; con mando se llega llevando el stick casi al tope.

## Señales globales útiles

- `GameState.map_overlay_close_requested` — cerrar minimapa sin acoplar UI a `Main`
- `Mansion.player_room_changed` — habitación actual del jugador
