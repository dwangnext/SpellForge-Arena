# SpellForge Arena

Godot 4 project — Milestone 9: Professional Polish.

## Controls

- WASD: move
- Mouse: aim
- Left mouse: basic attack
- Right mouse: cast selected spell
- 1–8: select Fireball, Ice Bolt, Lightning, Magic Missile, Tornado, Poison Cloud, Laser Beam, or Meteor
- Space: dash
- Escape: pause

Experience gems now advance player levels. Each level pauses play and presents three weighted, non-duplicate upgrade choices from a data-driven catalog.

Fusion recipes automatically resolve recent spell pairs or spell-plus-upgrade conditions. Cast paired ingredients within five seconds; upgrade-gated fusions activate whenever their base spell is cast.

Bosses spawn automatically during a run. Each has three health-driven phases, unique telegraphed attacks, animated placeholder presentation, and a collectible relic reward.

The pause menu now includes a persistent progression vault with permanent upgrades, selectable unlocked characters, spell unlock support, boss relics, achievements, and lifetime statistics. Profile data is versioned and saved under Godot's `user://` storage.

The polish layer adds a title flow, adaptive music, expanded sound design, particles, camera and screen feedback, animated menus, accessibility preferences, controller controls, contextual prompts, and bounded VFX/audio concurrency.

## Netlify multiplayer deployment

Deploy this repository through Netlify's GitHub integration. The checked-in `outputs/netlify` folder contains the playable browser export, while `netlify/functions/lobby.mjs` runs the shared three-player lobby and host-authoritative arena synchronization.

Do not upload only the contents of `outputs/netlify` with Netlify Drop: that publishes the game files but omits the lobby function, so each browser will fall back to a separate game. For a working co-op deployment, connect the GitHub repository in Netlify and use the included `netlify.toml` settings.
