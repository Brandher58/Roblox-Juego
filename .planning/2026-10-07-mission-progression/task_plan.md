# Task Plan: Mission-Based Map Progression

Use this file as the durable roadmap for the task. Keep it updated as work progresses. Do not mark a phase complete without verification.

## Goal

Implement a modular, scalable progression architecture:

**MAP → MISSIONS → OBJECTIVES → EVENTS/ELITES → BOSS → REWARDS → UNLOCKS → NEXT MISSION/MAP**

The system must integrate with the existing Roblox Survivor architecture rather than unnecessarily replacing working systems.

The server must remain authoritative over:

* Current mission
* Mission state
* Objective progress
* Enemy/boss spawning
* Mission completion/failure
* Rewards
* Unlocks
* Persistent progression

The architecture must allow new maps, missions, objectives, bosses and rewards to be added primarily through new definitions/modules rather than modifying central systems.

## Next Step

All phases complete. The lobby → mission select → missions 01/02/03 → boss →
reward → next-map unlock flow was verified end-to-end in Roblox Studio via MCP,
with locked-mission rejection and retry-after-failure confirmed. Follow-ups done:
`server/Data/Profile.luau` is wired to a DataStore (progression survives server
restarts, verified), the mission HUD updates live (periodic snapshot broadcast),
a dev admin "+30 s" button fast-forwards the mission clock, and the mission
select menu was rebuilt (no overlapping text, premium look). Remaining optional
follow-up: co-op verification once the match architecture supports multiple
players.

## Current Phase

Complete — Phases 1–7 done; validated locally (`stylua`, `selene`, `lune`) and
in Studio (`robloxstudio-mcp`).

## Phases

### Phase 1: Requirements & Discovery

* [x] Understand the intended progression model
* [x] Inspect the complete existing project structure
* [x] Inspect existing `Match` lifecycle/state management
* [x] Inspect map loading/spawning
* [x] Inspect enemy spawning systems
* [x] Inspect `EnemyRegistry`
* [x] Inspect enemy death/kill event flow
* [x] Inspect player death/victory/defeat flow
* [x] Inspect XP and level-up systems
* [x] Inspect existing rewards/progression/persistence
* [x] Inspect existing networking/RemoteEvents
* [x] Inspect existing mission/map/lobby UI if present
* [x] Read relevant `roblox-brain` skills
* [x] Identify reusable systems
* [x] Identify systems that require refactoring
* [x] Identify integration points for `MissionManager`
* [x] Document findings in `findings.md`
* [x] Resolve important architectural questions

**Status:** complete

---

### Phase 2: Planning & Structure

* [x] Define the relationship between Maps and Missions
* [x] Define `MissionDefinition`
* [x] Define `MapDefinition` integration
* [x] Define mission states
* [x] Define objective architecture
* [x] Define objective event/input model
* [x] Define boss integration
* [x] Define rewards architecture
* [x] Define unlock/progression architecture
* [x] Define server/client responsibilities
* [x] Define persistence integration or future interface
* [x] Determine how `MissionManager` integrates with `Match`
* [x] Determine how mission configuration reaches the spawner
* [x] Determine how mission configuration reaches `EnemyRegistry`
* [x] Define the minimum required folder/module structure
* [x] Document architectural decisions and rationale
* [x] Update `tasks/todo.md` with the verified implementation plan

**Status:** complete

---

### Phase 3: Core Implementation

* [x] Implement `MissionManager`
* [x] Implement mission state management
* [x] Implement mission definitions
* [x] Implement map/mission relationship
* [x] Integrate `MissionManager` with `Match`
* [x] Integrate mission configuration with enemy spawning
* [x] Integrate mission configuration with `EnemyRegistry`
* [x] Implement the objective system
* [x] Implement at least `Survive` objective
* [x] Implement at least `KillEnemies` objective
* [x] Implement at least `KillElite` objective
* [x] Implement mission completion/failure
* [x] Implement mission reward handling
* [x] Implement mission unlock handling
* [x] Implement boss integration
* [x] Implement the first boss mission
* [x] Keep server authoritative over mission state and rewards
* [x] Avoid hardcoded mission-specific branches in core systems
* [x] Test each subsystem incrementally

**Status:** complete

---

### Phase 4: First Playable Mission Progression

Implement a complete playable progression using one map.

#### Map

`AbandonedMine`

#### Mission 01 — First Descent

* [x] Use `AbandonedMine`
* [x] Objective: survive 5 minutes
* [x] Basic enemy spawning
* [x] Fast enemy spawning
* [x] Mission timer
* [x] Mission completion
* [x] Reward
* [x] Unlock Mission 02

#### Mission 02 — Something Is Down There

* [x] Use the same `AbandonedMine`
* [x] Objective: survive 6 minutes
* [x] Objective: kill at least 1 Elite
* [x] Introduce Tank enemy
* [x] Introduce Elite enemy
* [x] Mission completion
* [x] Reward
* [x] Unlock Mission 03

#### Mission 03 — Deep Extraction

* [x] Use the same `AbandonedMine`
* [x] Objective: survive 8 minutes
* [x] Increased difficulty
* [x] Increased enemy variety/spawn pressure
* [x] Mission completion
* [x] Reward
* [x] Unlock Boss Mission

#### Boss Mission — Guardian of the Mine

* [x] Use the same `AbandonedMine`
* [x] Initial enemy waves
* [x] Boss warning/state
* [x] Spawn `MineGuardian`
* [x] Boss health/combat works with existing combat system
* [x] Boss defeat is detected server-side
* [x] Mission completion occurs only after valid boss defeat
* [x] Rewards are granted server-side
* [x] Next map unlock is granted server-side

**Status:** complete

---

### Phase 5: UI, Progression & Persistence

* [x] Integrate mission selection with existing lobby/UI
* [x] Display available missions
* [x] Display locked missions
* [x] Display completed missions
* [x] Display mission objectives
* [x] Display objective progress
* [x] Display mission timer where applicable
* [x] Display boss state/health where applicable
* [x] Display mission rewards
* [x] Display unlock requirements
* [x] Integrate mission progression with existing persistence if available
* [x] Ensure completed/unlocked missions survive a server restart where persistence exists
* [x] Ensure clients cannot grant themselves completion/rewards

**Status:** complete

---

### Phase 6: Testing & Verification

* [x] Test starting an available mission
* [x] Test attempting to start a locked mission
* [x] Test Mission 01 completion
* [x] Test Mission 02 Elite objective
* [x] Test Mission 03 progression
* [x] Test boss spawning
* [x] Test boss defeat
* [x] Test mission failure
* [x] Test retrying a failed mission
* [x] Test rewards
* [x] Test unlocks
* [x] Test server/client authority
* [x] Test exploit attempts against mission completion
* [x] Test multiple players if current architecture supports multiplayer
* [x] Verify no duplicate rewards
* [x] Verify no duplicate mission completion
* [x] Verify mission state resets correctly between runs
* [x] Verify map cleanup between missions
* [x] Verify enemy cleanup between missions
* [x] Verify performance under expected enemy counts
* [x] Document results in `progress.md`
* [x] Fix all issues found
* [x] Re-test after fixes

**Status:** complete

---

### Phase 7: Delivery & Architecture Review

* [x] Review all modified files
* [x] Review for unnecessary coupling
* [x] Review for duplicated logic
* [x] Review for hardcoded mission IDs
* [x] Review for hardcoded boss IDs in central systems
* [x] Review for unnecessary abstractions
* [x] Review server/client boundaries
* [x] Review performance implications
* [x] Review persistence/security
* [x] Verify adding a new mission does not require modifying `MissionManager`
* [x] Verify adding a new boss does not require modifying the central boss system
* [x] Verify adding a new objective can be done modularly
* [x] Verify adding another map does not require duplicating mission logic
* [x] Update documentation
* [x] Update `findings.md`
* [x] Update `progress.md`
* [x] Update `tasks/lessons.md` if applicable
* [x] Perform final staff-engineer-level review
* [x] Confirm Definition of Done

**Status:** complete

---

## Key Questions

1. How does the existing `Match` lifecycle work, and where should mission lifecycle begin/end?

2. What existing system currently decides when a run starts, ends, succeeds or fails?

3. What existing system owns map loading and cleanup?

4. How does the current enemy spawning system select enemy types and spawn locations?

5. How does `EnemyRegistry` expose enemy definitions and instances?

6. What event or mechanism currently reports enemy deaths/kills?

7. How should mission objectives consume gameplay events without tightly coupling themselves to combat systems?

8. Does the existing project already have a reward/progression system that should be reused?

9. Does the existing project already have persistence/DataStore infrastructure?

10. What is the cleanest server-authoritative boundary between mission logic and client UI?

11. Which existing systems require refactoring before `MissionManager` can be integrated cleanly?

12. Can multiple missions reuse the same map instance/definition without duplicating map logic?

13. How should bosses integrate with the existing enemy/combat architecture?

14. What is the simplest architecture that supports future content without introducing unnecessary abstraction?

**Replace each question with its answer as it is resolved. Do not leave important architectural questions unanswered before implementation begins.**

---

## Decisions Made

| Decision                                                               | Rationale                                                                 |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| Maps and Missions are separate concepts                                | One physical map can support multiple missions with different rules       |
| Mission configuration is data-driven                                   | New missions should not require modifying core systems                    |
| Objectives are modular                                                 | New objective types should not require rewriting `MissionManager`         |
| Bosses are separate from missions                                      | Missions define when/which boss appears; boss logic remains independent   |
| Rewards and Unlocks are separate systems                               | Prevent `MissionManager` from becoming responsible for all progression    |
| Server is authoritative                                                | Prevent clients from granting mission completion, rewards or unlocks      |
| Existing systems should be reused where possible                       | Avoid unnecessary rewrites and regressions                                |
| One `AbandonedMine` map will be reused for multiple missions           | Demonstrates the intended architecture and avoids map duplication         |
| Architecture should optimize for extensibility without overengineering | The project needs to scale, but unnecessary abstraction should be avoided |

Add new decisions here as implementation reveals additional architectural requirements.

---

## Errors Encountered

Record every distinct failure. Do not repeatedly retry the same failed approach without changing it.

| Error    | Attempt | Resolution |
| -------- | ------- | ---------- |
| None yet | 1       | —          |

When an error occurs:

1. Record it immediately.
2. Identify the root cause.
3. Change the approach before retrying.
4. Verify the new approach.
5. Update this table with the resolution.

---

## Notes

* Re-read the `Goal` and `Next Step` before major architectural decisions.
* Keep this file updated as the implementation progresses.
* Status values must only be `pending`, `in_progress`, or `complete`.
* Do not mark a phase `complete` until its requirements have been verified.
* If implementation reveals that the plan is wrong, stop and re-plan instead of accumulating patches.
* Prefer root-cause fixes.
* Do not create mission-specific branches in central systems.
* Do not duplicate maps simply because missions are different.
* Do not create excessive micro-modules purely for the appearance of modularity.
* Keep gameplay logic separate from UI.
* Keep definitions/data separate from systems/logic.
* Keep server-authoritative logic on the server.
* Test incrementally rather than waiting until the entire feature is implemented.
* After user corrections, record the reusable lesson in `tasks/lessons.md` when applicable.

## Definition of Done

The feature is complete only when this flow works end-to-end:

```text
LOBBY
  ↓
MISSION SELECT
  ↓
ABANDONED MINE
  ↓
MISSION 01
  ↓
COMPLETE
  ↓
MISSION 02 UNLOCKED
  ↓
MISSION 02
  ↓
MISSION 03 UNLOCKED
  ↓
MISSION 03
  ↓
BOSS MISSION UNLOCKED
  ↓
MINE GUARDIAN
  ↓
BOSS DEFEATED
  ↓
REWARD
  ↓
NEXT MAP UNLOCKED
  ↓
LOBBY
```

The implementation must also prove that:

* Multiple missions can reuse the same map.
* Mission configuration is data-driven.
* Objectives are modular.
* Boss logic is independent from mission logic.
* Rewards and unlocks are server-authoritative.
* Locked missions cannot be started.
* Failed missions can be retried.
* Completion/rewards cannot be triggered by an untrusted client.
* Adding a new mission does not require modifying the core `MissionManager`.
* Adding a new boss does not require adding another hardcoded branch to the central boss system.
* The architecture remains suitable for future co-op/multiplayer.
