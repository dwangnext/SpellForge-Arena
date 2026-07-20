const MAX_PLAYERS = 3;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "content-type",
  "access-control-allow-methods": "GET, POST, OPTIONS",
};

const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers: JSON_HEADERS });
const cleanCode = (value) => String(value ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
const cleanName = (value, fallback) => String(value ?? fallback).replace(/[^a-zA-Z0-9 _-]/g, "").trim().slice(0, 24) || fallback;
const cleanPlayerCode = (value) => /^\d{4,6}$/.test(String(value ?? "")) ? String(value) : "------";
const safeNumber = (value, fallback = 0, limit = 100000) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(-limit, Math.min(limit, parsed)) : fallback;
};
const publicMembers = (members, revealCodes = false) => members.map((member) => ({
  peer_id: member.peer_id,
  name: member.name,
  ...(revealCodes ? { player_code: member.player_code } : {}),
}));

function createCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (byte) => CODE_CHARS[byte % CODE_CHARS.length]).join("");
}

function lobbyStub(env, code) {
  return env.LOBBIES.get(env.LOBBIES.idFromName(code));
}

async function callLobby(env, code, action, body = {}) {
  const response = await lobbyStub(env, code).fetch("https://lobby.internal/action", {
    method: "POST",
    headers: { "content-type": "application/json", "x-spellforge-action": action },
    body: JSON.stringify({ ...body, code }),
  });
  return new Response(response.body, { status: response.status, headers: JSON_HEADERS });
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return json({ ok: true });
    const url = new URL(request.url);

    const socketMatch = url.pathname.match(/^\/lobby\/([A-Z0-9]{6})\/ws$/i);
    if (socketMatch) {
      const code = cleanCode(socketMatch[1]);
      return lobbyStub(env, code).fetch(request);
    }

    if (url.pathname !== "/api/lobby") return json({ ok: false, error: "Not found." }, 404);
    try {
      if (request.method === "GET") {
        const action = String(url.searchParams.get("action") ?? "");
        const code = cleanCode(url.searchParams.get("code"));
        if (!code) return json({ ok: false, error: "A six-character lobby code is required." }, 400);
        return callLobby(env, code, action, Object.fromEntries(url.searchParams));
      }
      if (request.method !== "POST") return json({ ok: false, error: "Method not allowed." }, 405);
      const body = await request.json();
      if (JSON.stringify(body).length > 160_000) return json({ ok: false, error: "Request too large." }, 413);
      const action = String(body.action ?? "");
      if (action === "create") {
        for (let attempt = 0; attempt < 8; attempt += 1) {
          const code = createCode();
          const response = await callLobby(env, code, "create", body);
          if (response.status !== 409) return response;
        }
        return json({ ok: false, error: "Could not reserve a lobby code. Try again." }, 503);
      }
      const code = cleanCode(body.code);
      if (!code) return json({ ok: false, error: "A six-character lobby code is required." }, 400);
      return callLobby(env, code, action, body);
    } catch (error) {
      console.error("SpellForge Worker error", error);
      return json({ ok: false, error: "The multiplayer service hit an unexpected error." }, 500);
    }
  },
};

export class Lobby {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.runtimeWorld = null;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (request.headers.get("Upgrade")?.toLowerCase() === "websocket") {
      return this.connectSocket(url);
    }
    const action = request.headers.get("x-spellforge-action") ?? "";
    const body = await request.json();
    switch (action) {
      case "create": return this.create(body);
      case "join": return this.join(body);
      case "start": return this.start(body);
      case "status": return this.status(body);
      case "leave": return this.leave(body);
      default: return json({ ok: false, error: "Unknown lobby action." }, 400);
    }
  }

  async getLobby() {
    return await this.state.storage.get("lobby") ?? null;
  }

  async saveLobby(lobby) {
    lobby.updated_at = Date.now();
    await this.state.storage.put("lobby", lobby);
  }

  async create(body) {
    if (await this.getLobby()) return json({ ok: false, error: "Lobby code already exists." }, 409);
    const hostToken = crypto.randomUUID();
    const peerToken = crypto.randomUUID();
    const lobby = {
      code: cleanCode(body.code),
      host_token: hostToken,
      started: false,
      members: [{
        peer_id: 1,
        peer_token: peerToken,
        name: cleanName(body.name, "Host Wizard"),
        player_code: cleanPlayerCode(body.player_code),
      }],
    };
    await this.saveLobby(lobby);
    return json({ ok: true, code: lobby.code, peer_id: 1, host_token: hostToken, peer_token: peerToken, members: publicMembers(lobby.members) });
  }

  async join(body) {
    const lobby = await this.getLobby();
    if (!lobby) return json({ ok: false, error: "Lobby not found." }, 404);
    if (lobby.started) return json({ ok: false, error: "That run has already started." }, 409);
    if (lobby.members.length >= MAX_PLAYERS) return json({ ok: false, error: "That lobby already has 3 players." }, 409);
    const used = new Set(lobby.members.map((member) => member.peer_id));
    const peerId = [2, 3].find((candidate) => !used.has(candidate));
    const peerToken = crypto.randomUUID();
    lobby.members.push({
      peer_id: peerId,
      peer_token: peerToken,
      name: cleanName(body.name, `Wizard ${peerId}`),
      player_code: cleanPlayerCode(body.player_code),
    });
    await this.saveLobby(lobby);
    this.broadcast({ type: "members", members: publicMembers(lobby.members) });
    return json({ ok: true, code: lobby.code, peer_id: peerId, peer_token: peerToken, members: publicMembers(lobby.members) });
  }

  async start(body) {
    const lobby = await this.getLobby();
    if (!lobby) return json({ ok: false, error: "Lobby not found." }, 404);
    if (!body.host_token || body.host_token !== lobby.host_token) return json({ ok: false, error: "Only the host can start." }, 403);
    lobby.started = true;
    await this.saveLobby(lobby);
    this.broadcast({ type: "started" });
    return json({ ok: true, started: true });
  }

  async status(body) {
    const lobby = await this.getLobby();
    if (!lobby) return json({ ok: false, error: "Lobby not found." }, 404);
    const reveal = body.owner_code === "609618" && body.host_token === lobby.host_token;
    return json({ ok: true, members: publicMembers(lobby.members, reveal), started: lobby.started });
  }

  async leave(body) {
    const lobby = await this.getLobby();
    if (!lobby) return json({ ok: true });
    const peerId = Number(body.peer_id);
    if (peerId === 1) {
      this.broadcast({ type: "closed", message: "The host closed the lobby." });
      await this.state.storage.deleteAll();
    } else {
      lobby.members = lobby.members.filter((member) => member.peer_id !== peerId);
      await this.saveLobby(lobby);
      this.broadcast({ type: "members", members: publicMembers(lobby.members) });
    }
    return json({ ok: true });
  }

  async connectSocket(url) {
    const lobby = await this.getLobby();
    const peerId = Number(url.searchParams.get("peer_id"));
    const peerToken = String(url.searchParams.get("peer_token") ?? "");
    const member = lobby?.members.find((candidate) => candidate.peer_id === peerId && candidate.peer_token === peerToken);
    if (!member) return json({ ok: false, error: "Invalid lobby player." }, 403);
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    this.state.acceptWebSocket(server);
    server.serializeAttachment({ peerId });
    server.send(JSON.stringify({
      type: "welcome",
      peer_id: peerId,
      members: publicMembers(lobby.members),
      started: lobby.started,
      ...(this.runtimeWorld ? { world: this.runtimeWorld } : {}),
    }));
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(socket, message) {
    if (typeof message !== "string" || message.length > 160_000) return;
    let payload;
    try { payload = JSON.parse(message); } catch { return; }
    if (payload.type !== "sync") return;
    const peerId = Number(socket.deserializeAttachment()?.peerId ?? 0);
    if (peerId < 1 || peerId > MAX_PLAYERS) return;
    const outgoing = {
      type: "sync",
      peer_id: peerId,
      state: this.cleanState(payload.state ?? {}),
      casts: this.cleanCasts(payload.casts),
    };
    if (peerId === 1 && payload.world && typeof payload.world === "object") {
      this.runtimeWorld = payload.world;
      outgoing.world = payload.world;
    }
    this.broadcast(outgoing, peerId);
  }

  webSocketClose() {}
  webSocketError() {}

  cleanState(state) {
    return {
      x: safeNumber(state.x), y: safeNumber(state.y), rotation: safeNumber(state.rotation, 0, 1000),
      vx: safeNumber(state.vx, 0, 5000), vy: safeNumber(state.vy, 0, 5000),
      weapon_id: ["wand", "revolver", "gauntlet", "spawner"].includes(state.weapon_id) ? state.weapon_id : "wand",
      maximum_health: Math.max(1, safeNumber(state.maximum_health, 100, 100000)),
      revive_target: Math.max(0, Math.min(MAX_PLAYERS, Math.trunc(safeNumber(state.revive_target, 0, MAX_PLAYERS)))),
      camp_upgrade_id: String(state.camp_upgrade_id ?? "").replace(/[^a-zA-Z0-9-]/g, "").slice(0, 80),
      camp_upgrade_choice: ["odyssey", "aries"].includes(state.camp_upgrade_choice) ? state.camp_upgrade_choice : "",
      camp_upgrade_request: String(state.camp_upgrade_request ?? "").replace(/[^a-zA-Z0-9-]/g, "").slice(0, 80),
    };
  }

  cleanCasts(casts) {
    if (!Array.isArray(casts)) return [];
    return casts.slice(0, 16).map((cast) => ({
      id: String(cast.id ?? "").replace(/[^a-zA-Z0-9-]/g, "").slice(0, 72),
      spell_id: String(cast.spell_id ?? "").replace(/[^a-zA-Z0-9_]/g, "").slice(0, 64),
      ox: safeNumber(cast.ox), oy: safeNumber(cast.oy), tx: safeNumber(cast.tx), ty: safeNumber(cast.ty),
      modifiers: cast.modifiers && typeof cast.modifiers === "object" ? cast.modifiers : {},
    })).filter((cast) => cast.id && cast.spell_id);
  }

  broadcast(payload, excludedPeerId = 0) {
    const encoded = JSON.stringify(payload);
    for (const socket of this.state.getWebSockets()) {
      const peerId = Number(socket.deserializeAttachment()?.peerId ?? 0);
      if (peerId === excludedPeerId) continue;
      try { socket.send(encoded); } catch {}
    }
  }
}
