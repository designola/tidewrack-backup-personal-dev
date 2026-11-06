# Journal/save audit and Sprint 29 acceptance

Baseline: main at 8c9b1e407afe178a6287c6646705185d2e356e3c.

## What the baseline actually restores

Pause > Save records `scene_file_path`, then writes version 1, scene, and the
entire flags dictionary to user://save.json. Main Menu > Continue checks file
existence, calls load_game, then changes to the saved scene. No autosave exists.
New Game clears memory but does not delete or overwrite the previous save.

| State | Baseline save/Continue behavior |
| --- | --- |
| Story flags | All JSON-compatible keys/values survive, including false |
| Scene | Saved scene reloads from its beginning |
| Journal | Never serialized; not registered as an autoload; no discovery callers |
| Player position | Reset to scene spawn |
| Dialogue position | Not serialized; dialogue restarts on interaction |
| Pause/UI state | Not serialized |

The keeper choices set skeptic/believer, trusted_edith, and radioed_tom. The
lamp_relit flag is read by the lamp-room scaffold. This change does not change
any flag name, value, choice, or existing set_flag behavior. The ground-floor
stair still only plays dialogue; it does not transition to the lamp room.

## Implemented contract

GameState owns ordered journal IDs; Journal is a registered facade. Reading the
logbook records keeper_log on entering its first node. Discovery rejects blank
IDs and duplicates, and entries() returns a copy. Unknown nonempty IDs remain
valid so content changes do not silently delete discoveries. IDs are exact and
case-sensitive. A reader UI and content catalog remain separate work.

Version 2 adds journal_entries. Version 1 and unversioned saves retain flags and
start with an empty journal (we do not infer discoveries from ambiguous story
flags). Missing scene/flags retain legacy defaults; missing v2 journal defaults
to empty. Malformed fields and unsupported versions reject the whole load before
mutation. Duplicate IDs normalize in first-discovery order. Load/reset refresh
readers without replaying entry_added toasts. entries_changed currently also
fires for story-flag changes; consumers should simply refresh their view.

Saves stage to a sibling .tmp file, flush/check the write, then rename over the
save. Failures return false and do not intentionally truncate the old save.
Temporary files are never Continue candidates. This is not a backup/recovery
system or a guarantee against power-loss/filesystem failures. New Game still
leaves the prior on-disk save until the player explicitly saves again.

## Verification and remaining acceptance gates

Run `python3 tests/validate_dialogue.py` and, with Godot 4.3+ installed,
`godot --headless --path . --script tests/test_save.gd`.
The engine suite uses a separate test filename, never user://save.json.

The suite covers ordered round trips, false/nested/unknown flags, both resume
scenes, v1/unversioned migrations and resave, stale-state replacement, duplicate
and unknown IDs, snapshot isolation, reset, discovery notifications, malformed
payloads, future versions, missing files, and failed staging writes.

Before calling this done, run these in the shipping engine/export:

- Fresh process: read log, choose each branch, Save, exit, Continue. Verify IDs,
  flags, spawn reset, and no repeated discovery toast. Repeat Continue twice.
- Real legacy save fixtures from each shipped build: load, inspect flags, save
  as v2, restart, and compare. The repo contains no historical save fixtures.
- Truncated/invalid JSON, unreadable file, invalid scene, future version: show
  failure on the menu without changing active state or rewriting the save.
- Disk full and rename denied: report Save failed; previous save still loads.
  Kill the process during staging and replacement; test target OS filesystems.
- Save repeatedly over an existing file in Windows/Linux/Steam exports. Confirm
  replacement semantics and temp cleanup. A staging-write failure is automated;
  rename failure and power interruption require platform testing.
- New Game after Continue clears journal and flags; returning to menu without
  saving still permits Continue of the prior disk save. Confirm this UX is desired.
- Keyboard/controller menu navigation and long failure label layout; reader UI
  remains absent, so journal visibility is not launch-complete.

Godot was unavailable in the implementation environment. The engine suite and
manual acceptance gates must pass before release sign-off; static inspection
and the Python dialogue validator alone cannot establish runtime correctness.
