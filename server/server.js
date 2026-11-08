import express from 'express';
import http from 'http';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { WebSocketServer } from 'ws';

const DEVICE  = process.env.DEVICE_TOKEN  || 'CHANGE_ME';
const VIEWER  = process.env.VIEWER_TOKEN  || 'CHANGE_ME_VIEWER';
const CONTROL = process.env.CONTROL_TOKEN || VIEWER;
const NTFY    = process.env.NTFY || '';
const HOST    = process.env.HOST || '0.0.0.0';
const PORT    = Number(process.env.PORT || 8080);

const MASTER = crypto.createHash('sha256').update(DEVICE).digest();
const CLIP_DIR = 'clips';
fs.mkdirSync(CLIP_DIR, { recursive: true });

const app = express();
app.use(express.static('public'));
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

let device = null;
const viewers = new Set();
const state = { photo: null, gps: null, keys: [], alerts: [], clips: [], settings: {}, online: false };
const last = [0n, 0n, 0n, 0n];
let downCount = 0n;

const bearer = (req) => (req.get('authorization') || '').replace(/^Bearer\s+/i, '');

const derive = (dir, n) => {
  const salt = Buffer.alloc(9);
  salt[0] = dir;
  salt.writeBigUInt64BE(BigInt(n), 1);
  return Buffer.from(crypto.hkdfSync('sha256', MASTER, salt, 'l360.v2', 32));
};

const dec = (s) => {
  try {
    const b = Buffer.from(s, 'base64');
    if (b.length < 37) return null;
    const dir = b[0];
    if (dir > 3) return null;
    const n = b.readBigUInt64BE(1);
    if (n <= last[dir] && last[dir] - n < 1000000000n) return null;
    const iv = b.subarray(9, 21), tag = b.subarray(b.length - 16), ct = b.subarray(21, b.length - 16);
    const d = crypto.createDecipheriv('aes-256-gcm', derive(dir, Number(n)), iv);
    d.setAuthTag(tag);
    const json = JSON.parse(Buffer.concat([d.update(ct), d.final()]).toString());
    last[dir] = n;
    return { dir, json };
  } catch { return null; }
};

const enc = (o) => {
  downCount += 1n;
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', derive(1, Number(downCount)), iv);
  const ct = Buffer.concat([c.update(JSON.stringify(o)), c.final()]);
  const head = Buffer.alloc(9); head[0] = 1; head.writeBigUInt64BE(downCount, 1);
  return Buffer.concat([head, iv, ct, c.getAuthTag()]).toString('base64');
};

const clipKey = (name) =>
  Buffer.from(crypto.hkdfSync('sha256', MASTER, Buffer.from('clip:' + name), 'l360.clip', 32));

function push(title, body, prio = 'default') {
  if (!NTFY) return;
  fetch(NTFY, { method: 'POST', headers: { Title: title, Priority: prio, Tags: 'eyes' }, body }).catch(() => {});
}

app.post('/upload', express.raw({ type: '*/*', limit: '20mb' }), (req, res) => {
  if (bearer(req) !== DEVICE) return res.status(403).end();
  const name = path.basename(String(req.query.name || `clip-${Date.now()}.wav`));
  try {
    const b = req.body;
    const iv = b.subarray(0, 12), tag = b.subarray(b.length - 16), ct = b.subarray(12, b.length - 16);
    const d = crypto.createDecipheriv('aes-256-gcm', clipKey(name), iv);
    d.setAuthTag(tag);
    const plain = Buffer.concat([d.update(ct), d.final()]);
    fs.writeFileSync(path.join(CLIP_DIR, name), plain);
    const clip = { type: 'clip', name, seconds: Number(req.query.seconds) || 0,
                   session: String(req.query.session || '-'), bytes: plain.length, at: Date.now(),
                   url: `/clips/${encodeURIComponent(name)}?t=${VIEWER}` };
    state.clips.unshift(clip);
    state.clips = state.clips.slice(0, 500);
    viewers.forEach(v => v.readyState === 1 && v.send(JSON.stringify(clip)));
    res.status(200).end();
  } catch { res.status(400).end(); }
});

app.get('/clips/:name', (req, res) => {
  const t = bearer(req) || String(req.query.t || '');
  if (![VIEWER, CONTROL, DEVICE].includes(t)) return res.status(403).end();
  const p = path.join(CLIP_DIR, path.basename(req.params.name));
  if (!fs.existsSync(p)) return res.status(404).end();
  res.type('audio/wav').send(fs.readFileSync(p));
});

wss.on('connection', (ws, req) => {
  const tok = bearer(req);
  const isDevice = tok === DEVICE;
  const canControl = isDevice || tok === CONTROL;
  if (!isDevice && tok !== VIEWER && tok !== CONTROL) return ws.close();

  if (isDevice) {
    device = ws; state.online = true;
    const bools = {}, scalars = {};
    for (const [k, v] of Object.entries(state.settings)) {
      if (typeof v === 'boolean') bools[k] = v; else scalars[k] = v;
    }
    ws.send(enc({ type: 'settings', values: bools, ...scalars }));
    ws.on('close', () => { if (device === ws) { device = null; state.online = false; } });
  } else {
    viewers.add(ws);
    ws.on('close', () => viewers.delete(ws));
    ws.send(JSON.stringify({ type: 'snapshot', ...state }));
  }

  ws.on('message', (data, isBinary) => {
    if (isDevice) {
      if (isBinary) { viewers.forEach(v => v.readyState === 1 && v.send(data)); return; }
      const r = dec(data.toString());
      if (!r) return;
      const m = r.json;
      if (m.type === 'photo') state.photo = m.b64;
      if (m.type === 'gps') state.gps = m;
      if (m.type === 'keys') state.keys = m.lines;
      if (m.type === 'settings') Object.assign(state.settings, m.values || {});
      if (m.type === 'alert') {
        state.alerts.unshift(m);
        state.alerts = state.alerts.slice(0, 200);
        push(m.title || 'Alert', `${m.feature || ''} - ${m.reason || ''}`, m.ok === false ? 'high' : 'default');
      }
      viewers.forEach(v => v.readyState === 1 && v.send(JSON.stringify(m)));
      return;
    }
    if (!canControl) return;
    let m; try { m = JSON.parse(data.toString()); } catch { return; }
    if (m.type === 'settings') {
      Object.assign(state.settings, m.values || {});
      for (const [k, v] of Object.entries(m)) if (k !== 'type' && k !== 'values') state.settings[k] = v;
    }
    if (device && device.readyState === 1) device.send(enc(m));
    viewers.forEach(v => v.readyState === 1 && v.send(JSON.stringify(m)));
  });
});

setInterval(() => {
  const days = state.settings.clipRetentionDays || 7;
  const cut = Date.now() - days * 86400000;
  fs.readdir(CLIP_DIR, (_, files) => (files || []).forEach(f => {
    const p = path.join(CLIP_DIR, f);
    fs.stat(p, (_, st) => { if (st && st.mtimeMs < cut) fs.unlink(p, () => {}); });
  }));
  state.clips = state.clips.filter(c => c.at > cut);
}, 3600000);

server.listen(PORT, HOST, () => console.log(`relay on ${HOST}:${PORT}`));
