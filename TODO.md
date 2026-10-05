# TODO — pendiente después de esta sesión

## Bug pendiente: los enemigos no se ven tras la integración de asset — RESUELTO (2026-10-05)

> **Estado:** fallo causado por `InsertService:LoadAsset(4446576906)` en el servidor, que devuelve `User is not authorized to access Asset`. Ya no ocurre: `Config.luau` ahora comenta `AssetId = 4446576906` y se usa la esfera de reserva. La sección solo queda por si se quiere restaurar el asset de forma autorizada (ver siguiente sección).

Reporte del usuario tras la última actualización de `Default.project.json` (asset 4446576906 en `Config.EnemyVisuals.basic.AssetId`): al hacer Play **no aparece ningún enemigo** en el mundo. Output en Studio:

```
[EnemyRegistry] no se pudo cargar el asset 4446576906: User is not authorized to access Asset.
```

Lo que cambió para causar esto:

- `EnemyRegistry.spawn` hace `model:PivotTo(...)` sobre el asset en vez de colocar `Body`.
- `buildAssetTemplate` crea el `Root` como `PrimaryPart` del modelo y lo renombra a "Root".
- El enemigo usa `IsAsset = true` y en `EnemyAI` se mueve con `PivotTo`.

Al comentar `AssetId` en `Config.luau`, `poolFor` vuelve a servir la pool normal y todo vuelve visible.

Si más adelante se quiere restaurar ese asset, hay que andar con cuidado de:

1. `InsertService:LoadAssetAsync` requiere que el usaurio/grupo del place tenga permiso. El id 4446576906 NO lo tiene por defecto; se tiene que **re-publicar el modelo desde la cuenta del usuario** y usar el id nuevo.
2. Escalado del modelo tras `PivotTo` (aún sin `Model:ScaleTo`).
3. La posición relativa del bounding-box contra `definition.Size`.

## Bug pendiente: las armas nuevas no cambian / no se ven

Reporte del usuario: al tener **Relámpago**, **Pulso Nova**, **Meteorito** y **Cuchillas**
desbloqueadas, no se ve ninguna onda (nova), ninguna bomba caer (meteorito) ni
ningún cuchillo orbitando alrededor. El Relámpago sí parece funcionar.

Lo que se ha comprobado leyendo el código (sin playtest todavía):

- `src/server/Combat/WeaponBehaviors.luau` las registra como `Nova`, `Chain`, `Bomb`, `Orbit`.
- `src/server/Combat/WeaponRuntime.luau` decide cuándo dispara cada arma:
  - Orbit, Nova y Chain tienen target check; Bomb también.
  - Con la nueva regla `RequiresTarget` Orbit salta la búsqueda de objetivo.
- `src/server/Combat/OrbitBlades.luau` crea las cuchillas y las coloca en Y "a altura de enemigos".
- `src/server/Combat/Projectiles.luau` implementa `spawnBomb` y la detonación.
- `src/server/Combat/OrbitBlades.luau` y `src/client/VFX/CombatFeedback.luau` tienen las piezas nuevas.

Pistas para seguir investigando (no resuelto porque aún no se ha hecho Play tras los últimos cambios):

1. Abrir `Juego-Fase1.rbxlx`, conectar el plugin de Rojo o hacer Play y revisar la
   Output: ahí debe aparecer cualquier error de servidor/cliente al lanzar una
   cuchilla / una bomba / una onda.
2. Comprobar en el árbol del juego: `Workspace` debería contener `OrbitBlades` /
   `Projectiles` / `Enemies` / `XPPickups` y que las piezas neon aparezcan.
3. Verificar que al nivel-up sale la carta de desbloqueo de la arma y que al
   elegirla aparece en el HUD de armas (fila derecha). Si no sale, seguro que
   el `Requires` de la mejora deja de ser elegible.

## Asset ID 4446576906

- Ese id en Creator Store es el modelo **"Noob NPC"** (un asset de tipo Model, no una bala ni una cuchilla). Para verlo/abrirlo:
  1. En Studio: `View > Toolbox` — pegar el id 4446576906 en el buscador.
  2. O abrir https://www.roblox.com/library/4446576906.
- Para desbloquear el id 4446576906 hay que re-publicarlo desde la cuenta/grupo del place (Marketplace → “Get Model” → guardar como asset propio) y usar el **nuevo** AssetId. Mientras tanto, `AssetId = 4446576906` está comentado en `Config.luau`.
- Cómo reactivarlo de forma segura, aún sin permiso sobre el asset externo:
  1. Importa el modelo en Studio (Toolbox).
  2. Colócalo bajo `Workspace/EnemyTemplates/basic`.
  3. En `buildAssetTemplate`, en vez de llamar a `InsertService:LoadAsset`, haz `return template:Clone()` de ese modelo.
  4. Añade la escala `Model:ScaleTo(definitionSize)` y la posición con `PivotTo` para que todo encaje.

## Ideas sueltas

- Cuando no se vea ninguna arma nueva, facilitar que el usuario elija con certeza:
  revisar que el HUD de armas muestra todas las armas desbloqueadas (ROWS=12 y clamp 340).
- Para las 4 armas anteriores, el `Chain`/`Bomb` de esta tanda son los encargados de las próximas mejoras "daño en cadena / bombas / constitutivo".
