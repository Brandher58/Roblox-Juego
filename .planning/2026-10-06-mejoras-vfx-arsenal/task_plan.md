# Task Plan: Mejoras VFX del arsenal (Orbit, Chain, Bomb, Nova)

## Goal

El arsenal del vertical slice se lee sin esfuerzo desde la cámara top-down: cuchillas visibles con corte legible y bob, rayo de cadena dibujado con Beam que siempre se ve (primer salto corregido) con fade y burst, bombas que lobean de verdad con trail + rotación y explosión más grande, y Nova con anillo expansivo.

## Next Step

Verificación visual con el usuario y commit.

## Current Phase

Phase 5 (Delivery)

## Phases

### Phase 1: Requirements & Discovery

- [x] Understand user intent
- [x] Identify constraints and requirements
- [x] Document findings in findings.md
- **Status:** complete

### Phase 2: Planning & Structure

- [x] Define technical approach
- [x] Create project structure if needed
- [x] Document decisions with rationale
- **Status:** complete

### Phase 3: Implementation

- [x] Orbit: cuchillas más visibles, slash feedback, bob vertical
- [x] Chain: Beam + Attachments, primer salto con offset Y, fade-out y burst
- [x] Bomb: lob visible, trail + rotación en vuelo, explosión más visible
- [x] Nova: anillo de expansión (shockwave) sobre el burst
- **Status:** complete

### Phase 4: Testing & Verification

- [x] Gates: stylua --check, selene, lune headless, rojo build
- [x] Playtest en Studio vía MCP + captura de evidencia
- [x] Fix any issues found
- **Status:** complete

### Phase 5: Delivery

- [ ] Update progress.md / findings.md
- [ ] Commit pronto y pequeño
- [ ] Deliver to user
- **Status:** pending

## Key Questions

1. ¿Cuál es el origen del primer segmento del rayo? → El arma del jugador con offset Y (siempre dibujable). Resuelto.
2. ¿Cómo hacer el anillo de Nova sin assets nuevos? → Cilindro delgado neon que se escala y se funde en cliente. Resuelto.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Beams con Attachment0/1 en un anchor pooled, fade manual en RenderStepped | Tween no soporta NumberSequence; el pool ya tiene un tick |
| Primer segmento del rayo desde el arma del jugador (offset Y FloorY+1) | Garantiza longitud > 0 → "siempre se dibuja el rayo" |
| Bomba: velocidad absoluta con v²=2gh y h escala con distancia | Lobeo real y calculable; se alcanza al objetivo antes de caer |
| Trail + spines solo en proyectiles explosivos | Los bullets conservan su comportamiento y coste |
| Ring = cilindro delgado expandido en XZ | Sin assets; se lee como onda desde la cámara top-down |
| Slash = beam corto y fino + burst en el punto de corte | Feedback legible sin instancias nuevas |

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| | 1 | |

## Notes

- Pools: beams (12), rings (6). Todo reciclado con reloj, sin crear instancias por evento.
- `CombatEffect` es UnreliableRemoteEvent: el cliente decide cómo se ve cada `kind`.
- Gates headless no tocan VFX; cubren lógica pura (se mantienen verdes).