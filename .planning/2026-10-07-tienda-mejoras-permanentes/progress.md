# Progress: Tienda de mejoras permanentes

## Session: 2026-10-06 (plan creado; no se implementa hoy)

- El usuario preguntó si las monedas se guardan (sí: DataStore, verificado) y para
  qué sirven (hoy no tienen gasto — sin currency sink).
- Decisión del usuario: **tienda de mejoras permanentes** compradas con moneda.
- El usuario indicó que **no lo implementará hoy**: este plan queda commiteado para
  retomarlo en una sesión futura.
- Se eliminó el plan anterior `2026-10-07-mission-progression` (terminado y
  verificado; su trabajo ya estaba commiteado). El plan activo es este.
- Exploración completa de puntos de integración (ver findings.md): sistema de stats
  (`Stats`/`StatMath`), `PlayerAvatar` (MaxHealth/MoveSpeed), `WeaponRuntime`
  (daño), `Profile` (datastore), patrón de remotes y UI.

## Test Results

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| (ninguno — esta sesión solo documenta el plan) | — | — | ⏸ pendiente |

## Error Log

| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-10-06 | (ninguno) | 1 | — |

## Next actions (para la sesión que retome)

1. Ejecutar Fase 1 del task_plan: tipo `MetaUpgradeDefinition`, catálogo de 4
   mejoras, `Registry.MetaUpgrades` y tests headless.
2. Seguir con Fases 2-6 (persistencia, efectos, red, UI, verificación).
4. Al terminar: actualizar este fichero con resultados y hacer commit/push.