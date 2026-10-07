# Progress Log

Chronological record of work performed, files changed, validation results, and errors.

## Session: 2026-10-06

### Phase 1: Requirements & Discovery

- **Status:** complete
- Actions taken:
  - Inspected the full project: `Match`, `GameLoop`, spawners, `EnemyRegistry`,
    XP/level-up, combat loop, UI, remotes, persistence prep.
  - Documented reusable systems and integration points for `MissionManager`.
- Files created/modified:
  - `.planning/2026-10-07-mission-progression/findings.md`

### Phase 2: Planning & Structure

- **Status:** complete
- Actions taken:
  - Defined `MissionDefinition` / `MapDefinition` relationship, mission states,
    objective model, boss integration, rewards/unlocks split, server/client
    boundary, and `Profile` persistence interface.
  - Decisions recorded in `task_plan.md` and `docs/MISSION_CONTRACT.md`.
- Files created/modified:
  - `docs/MISSION_CONTRACT.md`, `tasks/todo.md`

### Phase 3: Core Implementation

- **Status:** complete
- Actions taken:
  - Lune-safe `Definitions/Maps.luau` (plain-number tables) + added
    `AbandonedFactory`.
  - `Registry.luau` registers/validates Maps + Missions (cross-references to
    map/enemy/boss/unlock, boss tag, objective types).
  - New `src/server/Missions/*`: `ObjectiveSystem`, `Objectives/{Survive,
    KillEnemy, KillElite, DefeatBoss}`, `BossSystem`, `RewardSystem`,
    `UnlockSystem`, `MissionManager`.
  - `EnemyRegistry.onKilled` normalized kill events; `EnemySpawner`
    mission configuration; `Difficulty` semantics fixed.
  - `Match` gained `onStateChanged`, `setAutoVictory`, `returnToSelect`,
    `MissionSelect`; `GameLoop` calls `MissionManager.update`; `Main.server`
    wires remotes/state/join.
  - `Data/Profile.luau` session-only per-player progression (documented
    DataStore TODO).
- Files created/modified:
  - `src/shared/{Types,Registry,Remotes}.luau`,
    `src/shared/Definitions/{Maps,Missions}.luau`,
    `src/shared/Definitions/Enemies/*`,
    `src/server/Missions/*`, `src/server/Data/Profile.luau`,
    `src/server/{Match,GameLoop,Main.server}.luau`,
    `src/server/{Spawning/Difficulty,Spawning/EnemySpawner,Enemies/EnemyRegistry}.luau`,
    `default.project.json`

### Phase 4: First Playable Mission Progression

- **Status:** complete
- Actions taken:
  - `AbandonedMine_01` First Descent (survive 5 min), `AbandonedMine_02`
    Something Is Down There (survive 6 min + kill 1 elite), `AbandonedMine_03`
    Deep Extraction (survive 8 min, higher pressure), `AbandonedMine_Boss`
    Guardian of the Mine (survive 60 s + defeat `mine_guardian`).
  - Sequential unlocks: 01 → 02 → 03 → Boss; boss mission grants the next map.
- Files created/modified:
  - `src/shared/Definitions/Missions.luau`,
    `src/shared/Definitions/Enemies/{Fast,Tank,Elite,MineGuardian}.luau`

### Phase 5: UI, Progression & Persistence

- **Status:** complete
- Actions taken:
  - `UI/MissionPanel.luau` (available/locked/completed list, objective and
    unlock hints, start requests), `UI/MissionHud.luau` (objectives, timer, boss
    health), `ResultPanel` shows `MissionResult` rewards.
  - Server drives all list/update/result payloads; client only requests.
  - Persistence exposed through `Profile` interface; DataStore wiring is a
    documented follow-up (not required while matches are session-based).
- Files created/modified:
  - `src/client/UI/{MissionPanel,MissionHud,ResultPanel,UIKit}.luau`,
    `src/client/Main.client.luau`

### Phase 6: Testing & Verification

- **Status:** complete
- Actions taken:
  - Local static/unit checks + Studio MCP playtest (see Test Results).
- Files created/modified:
  - `src/tests/headless.luau`

### Phase 7: Delivery & Architecture Review

- **Status:** complete
- Actions taken:
  - Reviewed coupling, duplication, and hardcoded IDs; confirmed new
    missions/bosses/objectives are additive definitions only.
  - Confirmed the DoD flow end-to-end.
- Files created/modified:
  - `task_plan.md`, `progress.md`, `docs/MISSION_CONTRACT.md`, `tasks/todo.md`

## Test Results

| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| StyLua | `stylua src` | no diffs | clean | ✅ |
| Selene | `selene src` | 0 errors/warnings | 0/0, 0 parse errors | ✅ |
| Headless | `lune run src/tests/headless.luau` | all pass | 2108/2108 | ✅ |
| Build | `rojo build --output "Juego-Fase1.rbxlx"` | builds | built | ✅ |
| Locked mission rejected | `requestStart(AbandonedMine_02)` at lobby | `false, "mission locked"` | `false, "mission locked"` | ✅ |
| Mission 01 start | `requestStart(AbandonedMine_01)` | Active, spawns enemies | Active, enemies spawning, LevelUp works | ✅ |
| Mission 01 completion | force `complete()` | rewards + 02 unlocked | +100, `AbandonedMine_02` unlocked, Victory → MissionSelect | ✅ |
| Return to lobby | after victory | `MissionSelect`, 02 Available | correct; 01 Completed | ✅ |
| Mission 02 objectives | `requestStart(AbandonedMine_02)` | Survive 360 + KillElite 1 | exact, correct labels | ✅ |
| Failure path | kill player | Failed, no rewards, retryable | Failed, currency unchanged, 02 still Available | ✅ |
| Retry | restart failed mission | succeeds | `true`, Playing | ✅ |
| Boss spawn + defeat | shorten boss mission in runtime, kill boss | DefeatBoss completes | boss spawned, DefeatBoss complete, mission completed | ✅ |
| Boss reward + map unlock | after boss completion | +500, next map unlocked | currency 100→600, `AbandonedFactory` unlocked, MissionSelect | ✅ |
| Runtime logs | MCP `get_runtime_logs` | no errors | only benign `Player:Move ... no character` warn | ✅ |

## Error Log

| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-10-06 | `setTimeout` unavailable in Code Mode runtime | 1 | Split the check into separate tool round-trips instead of sleeping in JS |
| 2026-10-06 | Mission appeared to auto-start during MCP test | 1 | Not a bug: the earlier aborted script had already issued `requestStart` before the JS error |

## 5-Question Reboot Check

| Question | Answer |
|----------|--------|
| Where am I? | Complete (Phases 1–7) |
| Where am I going? | Delivery: commit + push; optional DataStore + co-op follow-ups |
| What's the goal? | Server-authoritative mission-based map progression, data-driven and modular |
| What have I learned? | See `findings.md` |
| What have I done? | See above; full DoD flow verified locally and in Studio via MCP |

## Session: 2026-10-06 (hotfixes post-entrega)

### Fix 1 — Warning `Player:Move called, but player currently has no character.`

- **Causa:** el `ControlModule` interno de Roblox intenta mover al jugador sin
  personaje (`Players.CharacterAutoLoads = false`).
- **Fix** en `src/client/Input/RunInput.luau`:
  - Los controles solo se habilitan con un `Humanoid` presente (el estado deseado
    se recuerda y se aplica en `CharacterAdded`, esperando al `Humanoid`).
  - `moveFunction` del `ControlModule` envuelta para que nunca mueva sin `Humanoid`
    (cubre la ventana previa al arranque del script).
  - Se desactivan al instante en `CharacterRemoving`.
- **Verificado:** playtest limpio con 0 warnings/errores en runtime.

### Fix 2 — Modo dev: subir de nivel con todo maxeado congelaba el reloj

- **Causa:** `Match.beginLevelUp()` entraba en `LevelUp` aunque no hubiera cartas
  que ofrecer (`#offers == 0`) y el estado solo se recuperaba tras el timeout.
- **Fix:** `LevelUp.begin` descarta los niveles sin carta (`#offers == 0` →
  `queued = 0`, `pending = nil`); `beginLevelUp` solo pausa si al menos un jugador
  tiene cartas; el encadenamiento de niveles también reanuda si la generación se
  queda vacía.
- **Verificado:** con todo al máximo y 3 s de espera, `state = Playing` y el
  `elapsed` avanzó ~3 s.

### Fix 3 — No elegir carta no elegía nada

- **Causa:** la autoelección exigía `queuedLevels > 0`, pero `begin` ponía
  `queued = 0`, así que nunca se disparaba.
- **Fix:** tras `LevelUpTimeout` (15 s) se elige la primera carta pendiente
  (`#offers > 0`), aplicada siempre por el servidor.
- **Verificado:** 40 niveles pendientes se auto-consumieron y la partida volvió a
  `Playing` sin ninguna elección manual.

## Test Results

| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| Playtest: warning `Player:Move` | arranque sin personaje | sin warnings | 0 warnings/errors | ✅ |
| Playtest: timeout sin elegir | subir de nivel, no elegir, esperar 18 s | autoelección 1ª carta y reanudar | 40 cartas auto-consumidas, `Playing` | ✅ |
| Playtest: dev todo maxeado | maxear mejoras/armas + XP | no pausa, el tiempo avanza | `Playing`, `elapsed` +3 s, 0 ofertas | ✅ |
| Playtest: muerte/respawn | morir, esperar 8 s | `MissionSelect`, vivo, sin warnings | OK y log limpio | ✅ |

## Error Log

| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-10-06 | `eval_client_runtime`: string malformada (`\n` real embebido) | 1 | Escapar `\\n` dentro del código Lua embebido |
| 2026-10-06 | No se pudo leer `PlayerModule.Source` (sin capability de plugin) | 1 | Inspeccionar el módulo de controles en runtime (`controls.moveFunction`) y parchearlo |

---

*Update this file after completing a phase, running validation, or encountering an error.*

## Session: 2026-10-06 (HUD + persistencia + menú premium + botón dev)

### Fix 1 — La HUD de misión no se actualizaba en vivo

- **Causa (doble):**
  - `MissionManager.broadcastUpdate()` solo se enviaba en transiciones (start, boss,
    complete/fail, selección), nunca durante `Active`: la HUD quedaba congelada en la
    instantánea inicial.
  - La place abierta en Studio tenía **remotes duplicados** (`RequestMission`,
    `MissionUpdate`, `MissionFinished`, `MissionList` ×2): el servidor disparaba en una
    instancia y el cliente escuchaba en la otra → los eventos de misión no llegaban.
    (El source es limpio: `default.project.json` y `rojo build` los generan una sola vez.)
- **Fix:**
  - `MissionManager.update` reenvía el snapshot periódicamente (intervalo 0.2 s, igual
    que el HUD general) mientras la misión está `Active`.
  - Se eliminaron los 4 duplicados de `ReplicatedStorage.Remotes` en la place en vivo.
- **Verificado:** HUD del cliente hace tick sola (`0:47 → 0:49`, `47/300 → 49/300`)
  sin ninguna interacción.

### Fix 2 — Botón dev "+30 s" (Admin)

- **Causa:** no existía forma de adelantar el reloj de partida para probar fases tardías.
- **Fix:** comando admin `skip_time` (solo Studio, en `Admin.init`):
  - `Match.advanceTime(seconds)`: `elapsed += seconds` + broadcast (el spawner, la
    dificultad y el boss ven el nuevo reloj al instante).
  - `MissionManager.skipTime(seconds)`: adelanta los objetivos `Survive` (genérico a
    runtimes, sin rama por misión).
  - Botón en `AdminMenu` (`MAIN_BUTTONS = 5`): `"+30 s"` → `skip_time` 30.
- **Verificado:** desde el cliente `AdminCommand:FireServer("skip_time", 30)` →
  reloj `0:07 → 0:37`, objetivo `7/300 → 37/300` en la HUD.

### Fix 3 — Persistencia de progreso (DataStore)

- **Causa:** `Profile` era solo de sesión; al reiniciar se perdía lo completado.
- **Fix:** `src/server/Data/Profile.luau` ahora:
  - Carga asíncrona por jugador (DataStore `MissionProgress`/`v1`, key = UserId),
    reconciliada contra `Registry` (solo IDs conocidos, moneda saneada y clampada).
  - Escrituras diferidas con debounce (4 s) en cada mutación; guardado en
    `PlayerRemoving` y `BindToClose` a modo de red de seguridad.
  - `Profile.onLoaded` → `Main.server` reenvía la lista al terminar de cargar.
  - En Studio sin "Studio Access to API Services" degrada a sesión y avisa.
- **Verificado:** completar misión 01 → `completed01` y `unlocked02` en el DataStore;
  reiniciar el servidor (nuevo playtest) → `Completed`, `Available`, moneda y mapas
  cargados desde el DataStore.

### Fix 4 — Menú de selección de misión (rediseño premium)

- **Causa:** layout con tamaños en porcentaje dentro de las tarjetas; la descripción
  (`1,-70`) desbordaba la tarjeta y pisaba recompensas y botón; el meta se entraba en
  el título.
- **Fix:** `MissionPanel` reconstruido: alturas de fila calculadas en píxeles y
  apiladas (strip de acento, título + píldora de estado, meta, objetivos, descripción,
  divisor, recompensas, pie con botón/pista), `ClipsDescendants`, hover en disponibles,
  panel 760×600 con gradiente y borde dorado.
- **Verificado:** geometría absoluta de las 5 tarjetas sin solapamientos (chequeo
  programático de rects en el cliente).

## Test Results

| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| StyLua | `stylua src` | no diffs | clean | ✅ |
| Selene | `selene src` | 0 errores/avisos | 0/0, 0 parse errors | ✅ |
| Headless | `lune run src/tests/headless.luau` | all pass | 2109/2109 | ✅ |
| Build | `rojo build --output "Juego-Fase1.rbxlx"` | builds | built | ✅ |
| HUD live | misión 01 activa, esperar 1.2 s | clock/objetivos avanzan solos | `0:47 → 0:49`, `47/300 → 49/300` | ✅ |
| skip_time | `AdminCommand:FireServer("skip_time", 30)` | reloj +30, objetivo +30 | `0:07 → 0:37`, `7/300 → 37/300` | ✅ |
| Persistencia | completar 01, reiniciar servidor | 01 Completed, 02 unlocked al entrar | `completed01`, `unlocked02`, moneda 1150, mapa factory cargados | ✅ |
| Remotes duplicados | contar `Remotes` en la place | sin duplicados | 4 eliminados, todos únicos | ✅ |
| Menú | geometry de tarjetas en cliente | sin solapes | 4 tarjetas, filas apiladas, sin intersección | ✅ |
| Botón admin | lista de botones en `AdminMenu` | "+30 s" presente | `skip_time` "+30 s" | ✅ |

## Error Log

| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-10-06 | HUD sin datos pese al nuevo broadcast | 1 | Diagnóstico con marcador: remotes duplicados en la place; dedupe en vivo |
| 2026-10-06 | Playtest "ends" / roles no presentes por momentos | 1 | Parpadeo del MCP y playtests del usuario; reintentar tras `solo_playtest status` |
