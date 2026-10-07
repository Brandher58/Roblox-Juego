# Findings: Tienda de mejoras permanentes

Descubrimiento realizado el 2026-10-06 para que la implementación futura no
tenga que re-explorar. Todo lo siguiente está verificado sobre el código actual.

## Economía hoy (contexto)

- `RewardSystem.grant` → `Profile.addCurrency(player, rewards.Currency)`.
  Recompensas en `src/shared/Definitions/Missions.luau`: misión 01=+100, 02=+200,
  03=+250, boss=+500 monedas.
- La moneda se guarda en DataStore `MissionProgress`/`v1` (campos `currency`,
  `missions`, `maps`, `completed`), cargada al entrar (sanitizada y clampada a 1e9),
  escrituras diferidas 4 s + PlayerRemoving + BindToClose. Verificado en sesión
  anterior (1150 monedas persistidas entre reinicios).
- **No hay ningún gasto de moneda en el juego** (sink ausente). Las mejoras de
  partida se compran con nivel en el flujo LevelUp, no con moneda.

## Punto de integración de stats (la pieza clave)

- `src/server/Stats.luau` es el único dueño de los modificadores por jugador:
  - `Stats.get(player)` → `StatMath.resolve(Config.PlayerBaseStats, modifiers)`, con caché.
  - `Stats.add(modifier)`, `Stats.removeSource(source)`, `Stats.clear(player)`.
  - `StatModifier = { stat: StatKey, kind: "Add" | "Multiply", value: number, source: string, duration?: number }`
    (`StatMath.apply`: Add suma, Multiply multiplica).
- `Config.PlayerBaseStats`: `MaxHealth = 100`, `MoveSpeed = 16`, `Damage = 1` (global
  multiplier), `CriticalDamage = 1.5`.
- `src/server/PlayerAvatar.luau` (líneas 43-50): aplica `stats.MaxHealth` →
  `humanoid.MaxHealth` (subiendo la vida actual en la diferencia) y
  `stats.MoveSpeed` → `humanoid.WalkSpeed`.
- `src/server/Combat/WeaponRuntime.luau` (`statsFor`): `StatMath.weapon(definition, level,
  upgradeModifiers(player, weaponId), Stats.get(player))` — los stats del jugador entran
  en el daño de cada arma. Por eso un modificador permanente de `Damage` (Multiply)
  escala todas las armas sin tocar nada más.
- Ejemplo existente de activa similar: `Upgrades/Vitality.luau` →
  `{ stat = "MaxHealth", kind = "Add", value = 25, source = "vitality" }`. Las mejoras
  permanentes siguen exactamente esa forma con `source = "meta.<id>"`.

## Persistencia (`src/server/Data/Profile.luau`)

- Tipo `Profile` actual: `Currency`, `UnlockedMissions`, `UnlockedMaps`, `CompletedMissions`.
- `encode()` → JSON `{ v=1, currency, missions[], maps[], completed[] }`; `load()` →
  `GetAsync(tostring(UserId))` → sanitiza contra `Registry.Missions`/`Registry.Maps`.
- API a respetar: `get`, `load`, `save`, `markDirty`, `onLoaded`, `release`,
  `isMissionUnlocked`, `unlockMission`, `unlockMap`, `completeMission`, `addCurrency`.
- Tolera saves antiguos: `sanitizeCurrency`/`sanitizeIds` devuelven defaults. Un campo
  `upgrades` nuevo ausente en saves v1 no rompe nada.

## Red (patrón a seguir)

- `default.project.json`: cada RemoteEvent declarado UNA vez bajo
  `ReplicatedStorage.Remotes` (hubo un bug de duplicados que rompía la entrega).
- `src/shared/Remotes.luau`: `remote(name, className)` con WaitForChild + contrato
  documentado por remote.
- `Main.server.luau`: listener de `ClientReady` reenvía estado (sendTo/sendList/
  sendUpdate); `Profile.onLoaded` reenvía la lista de misiones. El `MetaUpdate` debe
  seguir el mismo patrón.

## UI (presentación pura)

- `MissionPanel.luau`: layout en píxeles fila a fila (ver cabecera del fichero), sin
  procentajes dentro de tarjetas. Botón "TIENDA" iría en la cabecera del panel sin
  tocar el layout de filas.
- `UIKit.luau`: `screen/frame/label/stroke/corner` (patrones usados por todos los paneles).
- `AdminMenu.luau`: ejemplo de botones accionables + lista desplazable.
- La compra siempre `FireServer`, y el coste/saldo que se muestra en cliente es solo
  presentación; la decisión (precio, deducción) la toma el servidor.

## Validación disponible

- `lune run src/tests/headless.luau` (2109/2109), `stylua src`, `selene src`, `rojo build`.
- Playtest Studio + MCP (eval_server_runtime / eval_client_runtime) usado en sesiones
  anteriores para verificación end-to-end.