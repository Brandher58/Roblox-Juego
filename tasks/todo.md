# Mission System - Task Log

## Completed

- [x] Inspect project structure and architecture
- [x] Determine existing gameplay flow
- [x] Inspect Match, spawners, enemies, XP, combat/loop, UI, networking
- [x] Read relevant roblox-brain skill / roblox-architecture
- [x] Inspection of persistence prep
- [x] List integration points for MissionManager
- [x] Build shared MapDefinitions / MissionDefinitions
- [x] Validate definitions via headless
- [x] Extend enemy definitions with tank/elite/fast/mine_guardian
- [x] Add Difficulty of adapting to mission multipliers
- [x] Document mission execution contract (`docs/MISSION_CONTRACT.md`)
- [x] Update `Match` to use mission definitions / states
- [x] Build client mission select UI + mission HUD
- [x] Build functional `BossSystem`
- [x] Build `ObjectiveSystem` with Survive / KillEnemy / KillElite / DefeatBoss
- [x] Build `RewardSystem` + `UnlockSystem` (server-authoritative)
- [x] Build `MissionManager` and wire `GameLoop`/`Main.server`
- [x] Register + validate Maps and Missions in `Registry`
- [x] Add `AbandonedMine` missions 01/02/03 + boss, and `AbandonedFactory` map
- [x] Integrate via playtest and logs (MCP), local lint + headless tests

## Todo Later

- [ ] Wire `server/Data/Profile.luau` to DataStore (persist progression)
- [ ] Move away from character auto-loads to proper matchmaking
- [ ] Create full Map scene for `AbandonedFactory`
- [ ] Add true random maps
- [ ] Add multiple healthbars for boss, maybe.
- [ ] Verify co-op flow once the match architecture supports multiple players

## Decisions Made

- Adopt Mission definitions as data in `src/shared/Definitions`
- A Mission is independent of a map; it references one `MapId`
- Use existing Spawner and Enemy Registry; the Mission runtime passes spawner configs
- The main loop stays as `Match.State`; a Mission is a runtime requested when match state transitions
- Client only does requests; server governs
- No DataStore wiring yet; keep current progression `Profile` interface

## Done

Full lobby → mission select → missions 01/02/03 → boss → reward → next-map
unlock flow verified in Roblox Studio via MCP, plus `stylua`, `selene`, and
`lune run src/tests/headless.luau` (2108/2108).
