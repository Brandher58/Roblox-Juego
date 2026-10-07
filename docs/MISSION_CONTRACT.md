# Mission Execution Contract

## 1. Mission Lifecycle

Estado aceptado:

```text
Locked
  ↓
Available
  ↓
Preparing
  ↓
Active
  ↓
Completing
  ↓
Completed
```

Fallo:

```text
Active
  ↓
Failed
  ↓
Available
```

Solo hay una fuente de verdad de estado de misión: el `MissionManager`/`MissionState`.

## 2. Mission Start Contract

```text
Client requests mission
        ↓
Server validates mission
        ↓
Server verifies unlock requirements
        ↓
Server verifies lobby/match state
        ↓
Server creates mission execution
        ↓
Map is prepared
        ↓
Players are spawned
        ↓
Mission becomes Active
```

El cliente nunca pasa directamente al estado,
solo envía una solicitud.

Validaciones del servidor:

- Existe `MissionDefinition` para `missionId`.
- Existe `MapDefinition` para `mission.MapId`.
- Recuperación de `MissionConfiguration` (spawner/enemies/difficulty).
- El mapa tiene spawn zones/mapping.
- La misión no está `Locked`; si no, el server lo detecta y rechaza.

Si falla: se rechaza y se devuelve error/ignored al cliente.

## 3. Mission Execution Context

```lua
type MissionContext = {
	MissionId: string,
	MapId: string,
	State: MissionState,
	ElapsedTime: number,
	RemainingTime: number?,
	Players: { Player },
	Objectives: { ObjectiveState },
	ActiveBoss: BossRuntime?,
	Difficulty: MissionDifficulty,
	EnemyConfiguration: EnemyConfiguration,
	Progress: { [string]: number },
}
```

No expone EnemyRegistry ni combat system.

## 4. Mission Responsibilities

El sistema de misiones:

- Preparar la misión durante `Preparing`.
- Mantener el estado: `Active`, `BossActive` si hubiera, `Completing`, `Completed`, `Failed`.
- Actualizar objetivos.
- Determinar completion/failure.
- Solicitar boss a través de boss logic.
- Generar `MissionResult`.
- Llamar a `RewardSystem` y `UnlockSystem`.

No es responsable de:

- Render UI, VFX, sonido.
- Crear armas/enemigos ni lógica de boss.
- Persistir datos arbitrary.
- Settear estados de match.

## 5. Map Contract

```text
Mission → MapId → Map System → Loaded Map
```

Map expone spawn zones, límites y spawn points.
Mission no conoce geometría.

## 6. Enemy Spawning Contract

```text
Mission → EnemyConfiguration → Spawner → EnemyRegistry → Enemy Instance
```

Mission configura:

- Enable/disable enemy types
- Weights
- Rates, difficulty multipliers
- Elite chance
- Wave config
- Max pressure

Spawner sigue implementando el spawn.

## 7. Objective Contract

Cada objective tiene:

```text
Initialize
Update/Event
Progress
Complete
Fail
Cleanup
```

`Update` can consume events for kill/items/timer.

## 8. Objective Completion Contract

Mission puede definir:

```lua
Objectives = {
	Mode = "All" | "Sequential" | "Some",
	Items = { ... },
}
```

MissionManager no toca ramas por tipo.

## 9. Boss Contract

```text
Mission → BossId → BossSystem → Spawn → Combat → Defeat → BossDefeated
```

El mission decide cuándo lo solicita; boss decide cómo pelea.

## 10. Mission Completion Contract

Todo required completo, boss defeated si required, sin failure:

1. STOP mission
2. Stop spawns
3. Resolver objectives
4. Resolver boss state
5. Generar `MissionResult`
6. Apply rewards/unlocks
7. Notify client
8. Cleanup
9. MissionManager reset
10. Return lobby

No rewards before success.

## 11. Mission Failure Contract

Fallo por todos muertos, forced fail, timer exhausted.

1. Failed
2. Cease mission
3. Stop spawns
4. Cleanup
5. No rewards
6. Mission -> Available
7. Notify
8. Return lobby

Player-death failure computed by Match? El Match no debe acceder a UI.

## 12. Mission Result

```lua
type MissionResult = {
	MissionId: string,
	Outcome: "Completed" | "Failed",
	Duration: number,
	Items: { ObjectiveResult },
	BossDefeated: boolean,
	Rewards: MissionRewards,
	Unlocks: UnlockSet,
}
```

Server produce, client receives a sanitized copy.

## 13. Cleanup Contract

Cada ejecución de misión limpia:

- Event connections
- Objective listeners
- Timers/tasks
- Sub-set spawning config
- References to boss
- Temporary state

Cleanup should be deterministic and must not leak.

## 14. Multiplayer Contract

La lógica corre en un estado compartido, no por jugador.

- Abstract: mission executes once.
- all players dead => Failed.
- Un player dies not immediately fail unless known script say.
- Join? Current game is simple.

## 15. Client Contract

Client shows UI and requests; no sets:

- Mission start requests
- Snapshot display
- Objective progress
- BossState/health
- Result view

## 16. Events / API Boundary

```lua
MissionManager = { StartMission, FailMission, CompleteMission, GetCurrentMission, GetMissionState }
ObjectiveSystem = { Initialize, HandleEvent, GetProgress, IsComplete, Cleanup }
BossSystem = { SpawnBoss, IsBossActive, GetBoss, HandleBossDefeat }
RewardSystem = { GrantRewards }
UnlockSystem = { ApplyUnlocks }
```

## 17. Authoritative State Machine

```text
Locked → Available → Preparing → Active == BossActive → Completing → Completed
                     ↓  Failed  ↓
                   Available    Failed
```

Invalid transitions rejected: Completed→Active, Failed→Completed, Locked→Active.

## 18. Content Extensibility

No `if missionId == ...` en code central.

Anything new is:

- new map definition
- new mission definition
- new objective definition
- new boss definition
- new reward/unlock config

Central systems stays same.

## 19. Documentation Deliverable

Este doc + tasks/todo.md actualizado.
