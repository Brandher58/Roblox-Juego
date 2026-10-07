# Progress

## Phase 1 — Requirements & Discovery (complete)

Mapeado completo del arsenal.

## Phase 2 — Planning & Structure (complete)

Decisiones registradas en `task_plan.md`.

## Phase 3 — Implementation (complete)

| Paso | Archivo | Estado |
|------|---------|--------|
| 3.0 Config: tuning Orbit/Projectile (blade más grande/brillante, bob, trail, lob) | `src/shared/Config.luau` | ✅ |
| 3.1 Bomb: velocidad absoluta v²=2gh, trail (2 attachments X) + spin en vuelo | `Projectiles.luau` + `WeaponBehaviors.luau` | ✅ |
| 3.2 Chain: primer salto desde el arma con offset Y (siempre dibujable) | `WeaponBehaviors.luau` | ✅ |
| 3.3 Orbit: visibilidad, bob vertical, slash feedback | `OrbitBlades.luau` | ✅ |
| 3.4 Cliente: Beam+Attachments, fade-out manual (RenderStepped), ring Nova/explosión, slash | `CombatFeedback.luau` | ✅ |
| 3.5 Admin: remote + servidor (solo Studio) + menú cliente (F2) | `Admin.luau`, `AdminMenu.luau`, `Remotes`, `Main.*` | ✅ |

## Phase 4 — Testing & Verification (complete)

| Check | Result |
|-------|--------|
| `stylua --check .` | ✅ sin output |
| `selene .` | ✅ 0 errores, 0 warnings |
| `lune run src/tests/headless.luau` | ✅ 2056/2056 |
| `rojo build -o out.rbxlx default.project.json` | ✅ |

- Playtest Studio vía MCP: `Playing` en curso, **0 errores** de cliente y servidor.
- Admin menu (F2) **verificado funcional**: el botón "Armas y mejoras al tope" dejó todas las armas en level 8 y "+500 XP" subió de nivel. El bug "no funciona" era `AdminCommand`/`Admin` duplicados por un merge doble de Rojo; se limpiaron con `execute_luau` en la sesión edit y se reinició el playtest.
- Fixes encontrados en playtest:
  - `trail.Length` → propiedad correcta `trail.MaxLength` (error en ~96 partes del pool).
  - `NumberSequence.new(kp, kp)` → forma `NumberSequence.new({kp, kp})`.

## Phase 5 — Delivery (in_progress)

- [ ] Commit pequeño de esta fase
- [ ] Coordinar con el usuario para validar visualmente el VFX (cámara top-down).

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| `Length is not a valid member of Trail` | 1 | usar `trail.MaxLength` |
| `NumberSequence.new(): table of NumberSequenceKeypoints expected` | 1 | pasar tabla `{kp, kp}` |
| Admin menu no hacía nada | 1 | `AdminCommand`/`Admin` duplicados (merge doble de Rojo) → dedupe en sesión + restart playtest |

## 5-Question Reboot Check

| Question | Answer |
|----------|--------|
| Where am I? | Phase 5 — entrega/commit |
| Where am I going? | Coordinar verificación visual |
| What's the goal? | VFX legibles de Orbit/Chain/Bomb/Nova + playtest con menú admin |
| What have I learned? | findings.md |
| What have I done? | Ver tabla de pasos |