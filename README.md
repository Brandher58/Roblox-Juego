# Roblox-Juego

Vertical slice (Fase 1) de un roguelite de supervivencia tipo *Survivor* en Roblox: te
matan enemigos, subes de nivel, eliges una mejora, la build cambia, aparecen más
enemigos y la partida termina cuando caes o cuando aguantas el objetivo de tiempo.

## Cómo ejecutarlo

El bucle fiable es **generar el lugar y abrirlo**, sin depender del plugin:

```bash
rojo build --output "Juego-Fase1.rbxlx"
```

Abre `Juego-Fase1.rbxlx` en Roblox Studio y pulsa Play. El build es determinista: el
árbol que hay en el fichero es exactamente el que produce `default.project.json`, sin
parcheos acumulados.

Para iterar rápido con sincronización en vivo:

```bash
rojo serve                 # servidor Rojo en 127.0.0.1:34872
```

Abre **un solo** lugar, conecta el plugin de Rojo **antes** de pulsar Play y déjalo
conectado. Desconecta antes de cerrar Studio, no después.

### Dos trampas de Rojo que ya han costado tiempo

1. **El punto de entrada no se llama `init.*`.** El del servidor es
   `src/server/Main.server.luau` y el del cliente `src/client/Main.client.luau`. Rojo
   convierte cualquier carpeta mapeada que contenga un `init.*` en un Script con el
   nombre de la carpeta, y entonces `script.Parent` deja de ser la carpeta: los módulos
   quedan como hermanos sueltos en el padre y los `require(script.Parent.X)` fallan con
   "X is not a valid member of ...".

2. **`rojo serve` en vivo no sobrevive a cambios estructurales.** Cuando Rojo tiene que
   pasar de un Script a una carpeta (o mover un módulo de un sitio a otro), el plugin
   destruye y recrea instancias. Si hay un `serve` corriendo mientras se renombran o se
   mueven archivos, el árbol del lugar queda a medias y aparecen errores como
   "SpatialGrid is not a valid member of ...EnemyRegistry" aunque el proyecto esté
   bien. Es exactamente lo que pasó al pasar de `init.server.luau` a
   `Main.server.luau` con el serve activo.

Regla: si un `require` de un hermano falla de forma absurda, el lugar está desincronizado,
no el código. Para confirmarlo, pega esto en View → Command Bar:

```lua
local s = game:GetService("ServerScriptService"):FindFirstChild("Server")
local c = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client")
print("Server:", s and s.ClassName, s and #s:GetChildren())
print("Client:", c and c.ClassName, c and #c:GetChildren())
-- esperado: Folder 13 y Folder 8. Si pone Script o 0, el lugar está mal sincronizado.
```

Y para ver el subárbol concreto que falla:

```lua
for _, c in game:GetService("ServerScriptService").Server.Enemies:GetChildren() do
    print(c.Name, c.ClassName)
end
```

### Comprobaciones automáticas

```bash
stylua src                       # formatea (column_width 110, tabs)
stylua --check src               # falla si algo está sin formatear
selene src                       # lint (0 errores, 0 warnings)
lune run src/tests/headless.luau # 1912 comprobaciones de la lógica pura
```

`src/tests/headless.luau` prueba sin Roblox la curva de XP, la curva de rareza con
`Luck`, el orden de los modificadores de estadísticas, las garantías del sorteo de cartas
y **las rutas de todos los `require` relativos**. Los módulos puros resuelven sus
imports con `script and script.Parent.X or "./X"`: en Roblox gana la ruta del ModuleScript
y fuera de Studio la relativa, que es lo que permite correrlos en Lune.

Esa última comprobación existe por una razón concreta: dentro de un ModuleScript,
`script` **es el propio módulo**, así que `require(script.SpatialGrid)` busca un *hijo*
del módulo y no un hermano, y revienta con
"SpatialGrid is not a valid member of ModuleScript ...EnemyRegistry" — un mensaje que
parece un fallo de sincronización de Rojo pero es del código. Desde una subcarpeta hace
falta además un `Parent` por cada nivel. Ni `selene` ni `rojo build` lo detectan porque
ninguno toca el DataModel; el test resuelve cada `require(script.X)` contra el árbol real
de ficheros:

```
FAIL: require(script.SpatialGrid) en src/server/Enemies/EnemyRegistry.luau:
      no existe src/server/Enemies/EnemyRegistry/SpatialGrid
FAIL: require(script.Parent.Stats) en src/server/Combat/WeaponRuntime.luau:
      no existe src/server/Combat/Stats
```

`src/tests/headless.luau` prueba sin Roblox la curva de XP, la curva de rareza con
`Luck`, el orden de los modificadores de estadísticas y las garantías del sorteo de
cartas. Los módulos puros resuelven sus imports con `script and script.Parent.X or
"./X"`: en Roblox gana la ruta del ModuleScript y fuera de Studio la relativa, que es
lo que permite correrlos en Lune.

## Arquitectura

Tres capas, con una regla por capa: **el servidor es dueño de la verdad, el cliente es
dueño de la presentación, y `shared` no toca la API de Roblox.**

```
src/shared/     Types, Config, Remotes, StatMath, Rarity, Progression, UpgradeOffers,
                Registry (validación de contenido) + Definitions/ (datos)
src/server/     Main.server (punto de entrada), Match, GameLoop, Run, Stats,
                PlayerAvatar,
                Enemies/ (SpatialGrid, EnemyRegistry, EnemyAI),
                Spawning/ (Difficulty, EnemySpawner),
                Combat/ (Projectiles, WeaponBehaviors, WeaponRuntime),
                Pickups/ (XPPickups), Progression/ (LevelUp),
                Utility/ (Pool), Data/ (MetaData, stub)
src/client/     Main.client (punto de entrada), Camera/ (TopDownCamera),
                Input/ (RunInput),
                UI/ (UIKit, Hud, LevelUpPanel, ResultPanel), VFX/ (CombatFeedback)
src/tests/      Pruebas headless (Lune). No se mapea al DataModel.
```

### Quién manda

| Dato | Dueño | Por qué |
| --- | --- | --- |
| Vida, daño, XP, enemigos, drops, estadísticas, progreso | Servidor | El cliente solo pide; nunca concede |
| Carta elegida | Cliente (id) → servidor (aplicar) | Se valida contra las ofertas pendientes y se consume una vez |
| Cámara, input, HUD, VFX | Cliente | Cero autoridad, cero objetos creados por frame en el servidor |

El único `OnServerEvent` del juego está en `src/server/Main.server.luau`
(`RequestUpgrade` y `ClientReady`). No existe ningún remote de "maté a un enemigo",
"gané XP" o "compré mejora": esas cosas solo ocurren en el servidor.

### Estados de partida

`Lobby → Playing → LevelUp → … → Victory | Defeat`, con `Starting`, `Event` y `Boss`
reservados. `Match.isSimulating()` decide si el bucle corre: en `LevelUp` se congela
todo, incluido el reloj, y hay autoelección a los 15 s para que nadie deje la partida
bloqueada. El fin de partida reinicia solo tras `DefeatDuration`.

En la Fase 1 el final es "aguantar `Config.Run.TargetDuration`" (6 min). Ese mismo reloj
es el punto donde entrará el jefe en la Fase 2.

### Datos, no código

- **Armas**: `shared/Definitions/Weapons/*.luau` (stats base + `Scaling` por nivel +
  `Behavior`). Añadir un arma con el mismo patrón de disparo = un archivo y una línea
  en `Registry`. Un patrón nuevo = una entrada en `Combat/WeaponBehaviors.luau`.
- **Mejoras**: `shared/Definitions/Upgrades/*.luau` (modificadores genéricos
  `Add`/`Multiply` + `Requires`, el punto de extensión para evoluciones).
- **Enemigos**: `shared/Definitions/Enemies/*.luau`. El spawner tiene una tabla
  `GROUPS` data-driven; no hay `if enemy == ...` en ningún sitio.
- **Dificultad**: `server/Spawning/Difficulty.luau`, función pura del tiempo jugado
  (vida, velocidad, intervalo, tamaño de tanda, tope de vivos, élite).
- **Números**: todo sale de `shared/Config.luau`, deep-frozen.

### Estadísticas

```
arma   = stats base + Scaling(nivel) + mejoras del arma × multiplicadores del jugador
jugador= Config.PlayerBaseStats + modificadores Add × modificadores Multiply
```

`StatMath.resolve` aplica primero los `Add` y luego los `Multiply`, así que el resultado
no depende del orden en que se registraron. Nadie muta el bloque base: `Stats` es el
único que escribe modificadores y los recomputa solo cuando cambian o vence un buff.

### Rarity sin tirar el dado a ciegas

Pesos base 55/27/12/5/1 y `Luck` como exponente del índice de rareza. Encima hay dos
garantías en `UpgradeOffers.generate`, comprobadas por las pruebas:

1. Con una sola arma, siempre se ofrece un arma nueva.
2. Siempre hay una mejora de un arma que ya llevas.

Si no queda ninguna mejora elegible, se devuelven 0 cartas en lugar de fallar.

## Rendimiento

Un solo `Heartbeat` (`GameLoop`) con el orden explícito de sistemas. Enemigos, pickups y
proyectiles salen de pools con token de leasing (`Utility/Pool`), así que un impacto no
crea ni destruye instancias. La IA refresca objetivos por tandas de 8 con cursor
giratorio, y las consultas de cercanía (objetivo más cercano, separación, impactos) van
contra un hash espacial de celdas numéricas. Las gotas de XP se funden entre sí a partir
de `Config.Pickups.MaxActive`, así que el número de instancias en el suelo está acotado
sin perder recompensa.

## Qué NO está en la Fase 1

- Sin jefe (solo la arquitectura de estados y el reloj que lo disparará).
- Sin persistencia: `Data/MetaData.luau` solo marca la frontera Run/Meta y documenta el
  plan de `UpdateAsync` con bloqueo de sesión.
- Sin monetización, sin lobby jugable, sin `StreamingEnabled` (la arena es de 220×220).
- Sin buffs temporales en el contenido: la fila de buffs del HUD y
  `Stats.add/removeSource` ya existen para que los powerups de la Fase 2 no toquen la UI.

## Contenido de la Fase 1

2 armas (`gun`, `shotgun`), 1 enemigo (`basic`), 5 mejoras (2 de arma, 1 desbloqueo,
1 de arma shotgun, 1 pasiva de vida), 5 estados usados de 8, 4-5 minutos de partida.