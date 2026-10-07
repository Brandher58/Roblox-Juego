# Task Plan: Tienda de mejoras permanentes (currency sink)

Plan creado el 2026-10-06. El usuario NO implementará hoy: este plan queda
documentado y commiteado para retomarlo en una sesión futura.

## Goal

Añadir una tienda entre partidas donde la moneda acumulada (hoy sin gasto) compra
mejoras permanentes —daño, vida máxima, velocidad, crítico— que persisten en DataStore
y se aplican de forma autoritativa en el servidor a través del sistema de stats
(`Stats`/`StatMath`) del proyecto.

## Next Step

Cuando se retome: implementar la Fase 1 — definir el tipo `MetaUpgradeDefinition`,
el catálogo de mejoras y `Registry.MetaUpgrades`, con sus tests headless.

## Current Phase

Phase 1 (requisitos y descubrimiento ya documentados en findings.md; la implementación está pendiente).

## Phases

### Phase 1: Tipos + catálogo de mejoras (base de datos de contenido)

- [ ] `src/shared/Types.luau`: añadir `export type MetaUpgradeDefinition`:
      `{ Id, Name, Description, Stat: StatKey, Kind: "Add" | "Multiply", PerLevel: number,
         MaxLevel: number, BaseCost: number, CostGrowth: number }`.
- [ ] `src/shared/Definitions/MetaUpgrades/`: un fichero por mejora (patrón de armas/upgrades),
      catálogo inicial de 4:
      - `damage`: `Stat="Damage"`, `Kind="Multiply"`, `PerLevel=1.08`, `MaxLevel=8`, costo 120, ×1.7.
      - `max_health`: `Stat="MaxHealth"`, `Kind="Add"`, `PerLevel=25`, `MaxLevel=5`, costo 150, ×1.8.
      - `move_speed`: `Stat="MoveSpeed"`, `Kind="Add"`, `PerLevel=0.8`, `MaxLevel=4`, costo 100, ×1.6.
      - `crit_damage`: `Stat="CriticalDamage"`, `Kind="Add"`, `PerLevel=0.15`, `MaxLevel=4`, costo 140, ×1.7.
- [ ] `src/shared/Registry.luau`: `Registry.MetaUpgrades` (índice por id, validación de id
      único y de campos, al estilo `indexById`/`validateModifiers` ya existentes).
- [ ] Tests headless: costos por nivel (costo = floor(BaseCost × Growth^nivel), nivel 1..Max),
      nivel 0 = sin bonus, validación de campos del catálogo.
- **Status:** in_progress

### Phase 2: Persistencia en `Profile` (DataStore)

- [ ] `Profile.luau`: campo `PermanentUpgrades: { [string]: number }` (nivel por id) en el tipo
      y en los defaults de sesión (`{}`).
- [ ] `encode`: añadir `upgrades = { id = nivel, ... }`. `load`: saneamiento de claves contra
      `Registry.MetaUpgrades` y clamp de nivel `0..MaxLevel` (floor). Saves viejos sin el campo
      → `{}` (retrocompatible, sin bumpar `v`).
- [ ] Nuevas APIs de `Profile`:
      - `getUpgradeLevel(player, id): number`
      - `upgradeCost(id, level): number?` — nil si el id no existe o nivel ≥ Max.
      - `purchaseUpgrade(player, id): (boolean, string?)` — valida existencia, nivel < Max,
        moneda suficiente; descuenta `addCurrency(player, -costo)`, sube nivel, `markDirty`.
- [ ] Tests headless: carga de save viejo sin `upgrades`, saneamiento de ids/niveles inválidos,
      compra correcta/insuficiente/máximo.
- **Status:** pending

### Phase 3: Aplicación de los efectos (servidor, autoritativo)

- [ ] Nuevo `src/server/Meta/MetaBonuses.luau`:
      - `modifiersFor(player): { StatModifier }` — por cada mejora comprada, un `StatModifier`
        con `source = "meta.<id>"`, `kind` y `PerLevel × nivel`.
      - `apply(player)`: `Stats.clear?` no — al inicio de run se hace `Stats.add` de cada
        modificador; refresca `PlayerAvatar` (MaxHealth/MoveSpeed) si aplica.
- [ ] Hook de inicio de run: en `Match.startRun` (tras el `Stats.clear` del reset), llamar
      `MetaBonuses.apply(player)` para todos los jugadores.
- [ ] Compra en vivo: tras una compra válida, re-aplicar la mejora afectada con
      `Stats.removeSource` + `Stats.add` (el daño se recalcula solo vía `Stats.get`); si es
      MaxHealth/MoveSpeed, refrescar también el `Humanoid` (mismo camino que PlayerAvatar).
- [ ] Punto de entrada stateless confirmado: `PlayerAvatar.luau` (43-50) aplica
      `stats.MaxHealth`→`humanoid.MaxHealth` y `stats.MoveSpeed`→`humanoid.WalkSpeed`;
      `WeaponRuntime.statsFor` provee `Stats.get(player)` a `StatMath.weapon` (el Damage del
      jugador es global multiplier base 1, así que el bonus % escala todas las armas).
- **Status:** pending

### Phase 4: Red y handler de compra

- [ ] `default.project.json`: remotes `PurchaseUpgrade` (RemoteEvent) y `MetaUpdate` (RemoteEvent),
      UNO cada uno (recordar el bug de duplicados).
- [ ] `src/shared/Remotes.luau`: contrato documentado:
      `PurchaseUpgrade` (cliente→servidor, string id) y
      `MetaUpdate` (servidor→cliente: `{ Balance: number, Upgrades: { [string]: number } }`).
- [ ] Nuevo `src/server/Meta/ShopServer.luau` (o handler en Main.server):
      valida `typeof(id)=="string"` breve, `Registry.MetaUpgrades[id]`, estado
      `MissionSelect`/`Lobby` (NO comprar en partida), `Profile.purchaseUpgrade`; si ok →
      `MetaBonuses` recalculada y `Remotes.MetaUpdate:FireClient(player, payload)`.
- [ ] `Main.server`: conectar el handler; enviar `MetaUpdate` de arranque dentro del flujo
      `ClientReady` y de nuevo en `Profile.onLoaded` (igual que la lista de misiones).
- **Status:** pending

### Phase 5: UI de tienda (presentación pura)

- [ ] `src/client/UI/ShopPanel.luau` (patrón de MissionPanel/AdminMenu, UIKit, DisplayOrder 26,
      ResetOnSpawn=false): cabecera con saldo, lista desplazable de mejoras (nombre, nivel
      actual `Lv X/Max`, efecto siguiente, coste), botón COMPRAR, deshabilitado si no alcanza
      (pista "Faltan X") y botón/sello "MÁXIMO" en nivel máximo.
- [ ] `MissionPanel.luau`: botón "TIENDA" en la barra superior (respetando el layout en píxeles);
      al pulsarlo abre ShopPanel con el saldo.
- [ ] `Main.client`: listener de `MetaUpdate` → actualizar saldo + niveles en ShopPanel
      (y saldo en MissionPanel si se decide); botón COMPRAR → `PurchaseUpgrade:FireServer(id)`.
- [ ] `MissionPanel`/shop: filtrar mejoras propias de presentación; nunca calcular precios ni
      descuentos en cliente (el coste se muestra, la decisión es del servidor).
- **Status:** pending

### Phase 6: Verificación y entrega

- [ ] `stylua src`, `selene src`, `lune run src/tests/headless.luau`, `rojo build`.
- [ ] Playtest en Studio (MCP): saldo visible, comprar daño → `Stats.get(player).Damage` sube,
      vida máxima sube tras comprar `max_health`, DataStore guarda niveles, reiniciar servidor →
      niveles cargados, bloqueo a nivel máximo, compra rechazada en partida y con moneda
      insuficiente; sin remotes duplicados.
- [ ] Documentar resultados en progress.md; commit + push (flujo verificar → commit → push).
- **Status:** pending

## Key Questions

- ¿Cómo entran las mejoras permanentes al sistema de stats? → Resuelto: `StatModifier` con
  `source="meta.<id>"` vía `Stats.add`; resolución en `Stats.get`; daño multiplicador porque
  `Damage` del jugador es global multiplier.
- ¿Puede comprarse en mitad de una run? → No: solo `MissionSelect`/`Lobby` (autoridad servidor).
- ¿El save viejo sigue valiendo? → Sí: campo nuevo `upgrades` ausente en saves v1 → `{}`.
- ¿Cuántas mejoras en v1? → 4 (damage, max_health, move_speed, crit_damage). Expandibles.
- ¿Repetir misiones sigue dando moneda? → Sí (commit f2949cf): alimenta el sink nuevo.
- ¿Mostrar saldo también en MissionPanel? → Abierto: mínimo en ShopPanel; opcional cabecera.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Mejoras expresadas como `StatModifier` con `source="meta.<id>"` | Reutiliza `Stats`/`StatMath` y `StatMath.weapon`; cero bifurcaciones por arma/misión. |
| `Damage` permanente usa `Kind="Multiply"` (PerLevel 1.08) | El `Damage` del jugador es global multiplier base 1 en `Config.PlayerBaseStats`; escala todas las armas vía stats del jugador. |
| Compras solo en MissionSelect/Lobby | Evita comprar a mitad de run y desincronizar la partida. |
| Coste por nivel `floor(BaseCost × Growth^(nivel actual))`, servidor decide | Precios nunca del cliente; crecimiento clásico de tienda. |
| DataStore sigue en `v1` y se amplía el JSON con `upgrades` | Retrocompatible; loads viejos robustos por saneamiento (sin bumpar versión). |
| Tienda como panel propio (28–360) abierto desde MissionPanel | Sigue el patrón de paneles existentes y el layout en píxeles sin solaparse. |
| `MetaUpdate` reenvía saldo+niveles (server→client) tras carga y compra | Mismo patrón que `MissionList`/`Profile.onLoaded`. |
| El usuario retoma esto en otro día | Plan commiteado para ejecución futura; no implementar hoy. |

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| (ninguno aún — plan nuevo) | 1 | — |

## Notes

- Recordar el bug previo de remotes duplicados: cada RemoteEvent debe declararse UNA sola vez.
- Comprobar `StatMath.apply/resolve` (Add/Multiply) antes de escribir el catálogo (ver findings).
- `MetaData.luau` es placeholder; si esta tienda crece (personajes/armas), migrar su plantilla
  al nuevo módulo de meta en vez de tocarlo a medias.
- Update phase status as work progresses: `pending` to `in_progress` to `complete`.