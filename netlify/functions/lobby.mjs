import { getStore } from "@netlify/blobs";

const store = getStore("spellforge-coop-lobbies");
const MAX_PLAYERS = 3;
const LOBBY_TTL_MS = 30 * 60 * 1000;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "content-type",
    "access-control-allow-methods": "GET, POST, OPTIONS",
  },
});

const cleanCode = (value) => String(value ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
const cleanName = (value, fallback) => String(value ?? fallback).replace(/[^a-zA-Z0-9 _-]/g, "").trim().slice(0, 24) || fallback;
const cleanPlayerCode = (value) => /^\d{6}$/.test(String(value ?? "")) ? String(value) : "------";
const metaKey = (code) => `lobbies/${code}/meta`;
const stateKey = (code, peerId) => `runtime/${code}/players/${peerId}`;
const worldKey = (code) => `runtime/${code}/world`;
const castPrefix = (code) => `runtime/${code}/casts/`;
const safeNumber = (value, fallback = 0, limit = 100000) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(-limit, Math.min(limit, parsed)) : fallback;
};
const publicMembers = (members, revealCodes = false) => members.map((member) => ({
  peer_id: Number(member.peer_id),
  name: String(member.name),
  ...(revealCodes ? { player_code: cleanPlayerCode(member.player_code) } : {}),
}));

function createCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (byte) => CODE_CHARS[byte % CODE_CHARS.length]).join("");
}

async function getLobby(code) {
  if (code.length !== 6) return null;
  const lobby = await store.get(metaKey(code), { type: "json", consistency: "strong" });
  if (!lobby || Number(lobby.expires_at ?? 0) < Date.now()) return null;
  return lobby;
}

async function saveLobby(lobby) {
  lobby.updated_at = Date.now();
  lobby.expires_at = Date.now() + LOBBY_TTL_MS;
  await store.setJSON(metaKey(lobby.code), lobby);
}

async function createLobby(body) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = createCode();
    const hostToken = crypto.randomUUID();
    const lobby = {
      code,
      host_token: hostToken,
      started: false,
      created_at: Date.now(),
      updated_at: Date.now(),
      expires_at: Date.now() + LOBBY_TTL_MS,
      members: [{ peer_id: 1, name: cleanName(body.name, "Host Wizard"), player_code: cleanPlayerCode(body.player_code) }],
    };
    const result = await store.setJSON(metaKey(code), lobby, { onlyIfNew: true });
    if (result.modified) {
      return json({ ok: true, code, peer_id: 1, host_token: hostToken, members: publicMembers(lobby.members) });
    }
  }
  return json({ ok: false, error: "Could not reserve a join code. Please try again." }, 503);
}

async function joinLobby(body) {
  const code = cleanCode(body.code);
  const lobby = await getLobby(code);
  if (!lobby) return json({ ok: false, error: "Lobby not found or expired." }, 404);
  if (lobby.started) return json({ ok: false, error: "That run has already started." }, 409);
  if (lobby.members.length >= MAX_PLAYERS) return json({ ok: false, error: "That lobby already has 3 players." }, 409);
  const used = new Set(lobby.members.map((member) => Number(member.peer_id)));
  const peerId = [2, 3].find((candidate) => !used.has(candidate));
  if (!peerId) return json({ ok: false, error: "That lobby is full." }, 409);
  lobby.members.push({ peer_id: peerId, name: cleanName(body.name, `Wizard ${peerId}`), player_code: cleanPlayerCode(body.player_code) });
  await saveLobby(lobby);
  return json({ ok: true, code, peer_id: peerId, members: publicMembers(lobby.members) });
}

async function startLobby(body) {
  const code = cleanCode(body.code);
  const lobby = await getLobby(code);
  if (!lobby) return json({ ok: false, error: "Lobby not found or expired." }, 404);
  if (!body.host_token || body.host_token !== lobby.host_token) {
    return json({ ok: false, error: "Only the host can start this run." }, 403);
  }
  lobby.started = true;
  await saveLobby(lobby);
  return json({ ok: true, started: true });
}

async function sendSignal(body) {
  const code = cleanCode(body.code);
  const lobby = await getLobby(code);
  if (!lobby) return json({ ok: false, error: "Lobby not found or expired." }, 404);
  const from = Number(body.from);
  const to = Number(body.to);
  const validIds = new Set(lobby.members.map((member) => Number(member.peer_id)));
  if (!validIds.has(from) || !validIds.has(to) || from === to) {
    return json({ ok: false, error: "Invalid signaling peers." }, 400);
  }
  const id = `${Date.now().toString(36)}-${crypto.randomUUID()}`;
  const message = {
    id,
    from,
    to,
    kind: body.kind === "ice" ? "ice" : "session",
    payload: body.payload ?? {},
    created_at: Date.now(),
  };
  await store.setJSON(`signals/${code}/${to}/${id}`, message);
  return json({ ok: true, id });
}

async function syncLobby(body) {
  const code = cleanCode(body.code);
  const lobby = await getLobby(code);
  if (!lobby || !lobby.started) return json({ ok: false, error: "Run is not active." }, 404);
  const peerId = Number(body.peer_id);
  if (!lobby.members.some((member) => Number(member.peer_id) === peerId)) {
    return json({ ok: false, error: "Player is not in this run." }, 403);
  }

  const state = body.state ?? {};
  await store.setJSON(stateKey(code, peerId), {
    peer_id: peerId,
    x: safeNumber(state.x), y: safeNumber(state.y), rotation: safeNumber(state.rotation, 0, 1000),
    vx: safeNumber(state.vx, 0, 5000), vy: safeNumber(state.vy, 0, 5000),
    weapon_id: ["wand", "revolver", "gauntlet"].includes(state.weapon_id) ? state.weapon_id : "wand",
    maximum_health: Math.max(1, safeNumber(state.maximum_health, 100, 100000)),
    updated_at: Date.now(),
  });

  const casts = Array.isArray(body.casts) ? body.casts.slice(0, 16) : [];
  await Promise.all(casts.map(async (cast) => {
    const castId = String(cast.id ?? "").replace(/[^a-zA-Z0-9-]/g, "").slice(0, 72);
    const spellId = String(cast.spell_id ?? "").replace(/[^a-zA-Z0-9_]/g, "").slice(0, 64);
    if (!castId || !spellId) return;
    await store.setJSON(`${castPrefix(code)}${castId}`, {
      id: castId, peer_id: peerId, spell_id: spellId,
      ox: safeNumber(cast.ox), oy: safeNumber(cast.oy), tx: safeNumber(cast.tx), ty: safeNumber(cast.ty),
      modifiers: cast.modifiers && typeof cast.modifiers === "object" ? cast.modifiers : {},
      created_at: Date.now(),
    });
  }));

  if (peerId === 1 && body.host_token === lobby.host_token && body.world && typeof body.world === "object") {
    await store.setJSON(worldKey(code), { ...body.world, updated_at: Date.now() });
  }

  const playerStates = (await Promise.all(lobby.members.map((member) => store.get(
    stateKey(code, Number(member.peer_id)),
    { type: "json", consistency: "strong" },
  )))).filter((entry) => entry && Date.now() - Number(entry.updated_at ?? 0) < 10000);
  const world = await store.get(worldKey(code), { type: "json", consistency: "strong" }) ?? {};
  const { blobs } = await store.list({ prefix: castPrefix(code) });
  const recentEntries = blobs.sort((a, b) => a.key.localeCompare(b.key)).slice(-128);
  const recentCasts = (await Promise.all(recentEntries.map((entry) => store.get(entry.key, {
    type: "json", consistency: "strong",
  })))).filter((entry) => entry && Date.now() - Number(entry.created_at ?? 0) < 30000);
  return json({ ok: true, players: playerStates, casts: recentCasts, world });
}

async function pollSignals(url) {
  const code = cleanCode(url.searchParams.get("code"));
  const peerId = Number(url.searchParams.get("peer_id"));
  const lobby = await getLobby(code);
  if (!lobby) return json({ ok: false, error: "Lobby not found or expired." }, 404);
  if (!lobby.members.some((member) => Number(member.peer_id) === peerId)) {
    return json({ ok: false, error: "Player is not in this lobby." }, 403);
  }
  const prefix = `signals/${code}/${peerId}/`;
  const { blobs } = await store.list({ prefix });
  const recent = blobs.sort((a, b) => a.key.localeCompare(b.key)).slice(-96);
  const messages = (await Promise.all(recent.map((entry) => store.get(entry.key, {
    type: "json",
    consistency: "strong",
  })))).filter(Boolean);
  return json({ ok: true, messages });
}

async function getStatus(url) {
  const lobby = await getLobby(cleanCode(url.searchParams.get("code")));
  if (!lobby) return json({ ok: false, error: "Lobby not found or expired." }, 404);
  const revealCodes = url.searchParams.get("owner_code") === "609618"
    && url.searchParams.get("host_token") === lobby.host_token;
  return json({ ok: true, members: publicMembers(lobby.members, revealCodes), started: Boolean(lobby.started) });
}

async function leaveLobby(body) {
  const code = cleanCode(body.code);
  const lobby = await getLobby(code);
  if (!lobby) return json({ ok: true });
  const peerId = Number(body.peer_id);
  if (peerId === 1) {
    await store.delete(metaKey(code));
  } else {
    lobby.members = lobby.members.filter((member) => Number(member.peer_id) !== peerId);
    await saveLobby(lobby);
  }
  return json({ ok: true });
}

export default async (request) => {
  if (request.method === "OPTIONS") return json({ ok: true });
  try {
    const url = new URL(request.url);
    if (request.method === "GET") {
      const action = url.searchParams.get("action");
      if (action === "poll") return await pollSignals(url);
      if (action === "status") return await getStatus(url);
      return json({ ok: false, error: "Unknown lobby action." }, 400);
    }
    if (request.method !== "POST") return json({ ok: false, error: "Method not allowed." }, 405);
    const body = await request.json();
    if (JSON.stringify(body).length > 120_000) return json({ ok: false, error: "Request too large." }, 413);
    if (body.action === "create") return await createLobby(body);
    if (body.action === "join") return await joinLobby(body);
    if (body.action === "start") return await startLobby(body);
    if (body.action === "signal") return await sendSignal(body);
    if (body.action === "sync") return await syncLobby(body);
    if (body.action === "leave") return await leaveLobby(body);
    return json({ ok: false, error: "Unknown lobby action." }, 400);
  } catch (error) {
    console.error("SpellForge lobby error", error);
    return json({ ok: false, error: "The lobby service hit an unexpected error." }, 500);
  }
};
