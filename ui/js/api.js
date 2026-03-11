window.SkeinAPI = {
  base: '/apps/skein/api',

  async get(path) {
    const res = await fetch(`${this.base}/${path}`, {
      credentials: 'include',
    });
    if (!res.ok) throw new Error(`GET ${path}: ${res.status}`);
    return res.json();
  },

  async post(action) {
    const res = await fetch(this.base, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(action),
    });
    if (!res.ok) throw new Error(`POST: ${res.status}`);
    return res.json();
  },

  // reads
  getStats()   { return this.get('stats'); },
  getApps()    { return this.get('apps'); },
  getRelays()  { return this.get('relays'); },
  getRoutes()  { return this.get('routes'); },
  getBatch()   { return this.get('batch'); },

  // writes
  discoverRelay(ship) {
    return this.post({ action: 'put-relay', ship });
  },
  dropRelay(relay) {
    return this.post({ action: 'drop-relay', relay });
  },
  clearSeen() {
    return this.post({ action: 'clear-seen' });
  },
  bindApp(app) {
    return this.post({ action: 'bind-app', app });
  },
  unbindApp(app) {
    return this.post({ action: 'unbind-app', app });
  },
};
