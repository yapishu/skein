/* ============================================
   skein -- mixnet operations dashboard
   ============================================ */

const App = {
  state: {
    view: 'dashboard',
    stats: { apps: 0, relays: 0, seen: 0, routes: 0, batch: 0, has_timer: false, ship: '~zod' },
    apps: [],
    relays: [],
    routes: [],
    batch: [],
    batchTimer: null,
    loading: true,
    dialog: null,
  },

  init() {
    window.addEventListener('hashchange', () => this.route());
    this.route();
    this.refresh();
    setInterval(() => this.refresh(), 10000);
  },

  route() {
    const hash = location.hash.slice(1) || 'dashboard';
    this.state.view = hash;
    this.render();
  },

  async refresh() {
    try {
      const [stats, apps, relays, routes, batch] = await Promise.allSettled([
        SkeinAPI.getStats(),
        SkeinAPI.getApps(),
        SkeinAPI.getRelays(),
        SkeinAPI.getRoutes(),
        SkeinAPI.getBatch(),
      ]);
      if (stats.status === 'fulfilled')  this.state.stats = stats.value;
      if (apps.status === 'fulfilled')   this.state.apps = Array.isArray(apps.value) ? apps.value : [];
      if (relays.status === 'fulfilled') this.state.relays = Array.isArray(relays.value) ? relays.value : [];
      if (routes.status === 'fulfilled') this.state.routes = Array.isArray(routes.value) ? routes.value : [];
      if (batch.status === 'fulfilled')  this.state.batch = Array.isArray(batch.value) ? batch.value : [];
    } catch (e) {
      console.error('refresh failed:', e);
    }
    this.state.loading = false;
    this.render();
  },

  toast(msg, type = '') {
    const container = document.querySelector('.toast-container') || (() => {
      const c = document.createElement('div');
      c.className = 'toast-container';
      document.body.appendChild(c);
      return c;
    })();
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = msg;
    container.appendChild(el);
    setTimeout(() => el.remove(), 3500);
  },

  async action(fn) {
    try {
      await fn();
      this.closeDialog();
      this.toast('done', 'success');
      await this.refresh();
    } catch (e) {
      this.toast(e.message, 'error');
    }
  },

  openDialog(name, data = {}) {
    this.state.dialog = { name, data };
    this.render();
  },

  closeDialog() {
    this.state.dialog = null;
    this.render();
  },

  shortId(id) {
    if (!id) return '---';
    const s = String(id);
    return s.length > 20 ? s.slice(0, 10) + '..' + s.slice(-8) : s;
  },

  fmtDate(ts) {
    if (!ts) return '---';
    const d = new Date(ts * 1000);
    return d.toLocaleString(undefined, {
      month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit'
    });
  },

  fmtCountdown(ts) {
    if (!ts) return '---';
    const now = Math.floor(Date.now() / 1000);
    const diff = ts - now;
    if (diff <= 0) return 'now';
    return `${diff}s`;
  },

  // ---- render ----

  render() {
    const app = document.getElementById('app');
    app.innerHTML = `
      ${this.renderSidebar()}
      <div class="main">
        ${this.renderPage()}
      </div>
      ${this.renderDialog()}
    `;
    this.bindEvents();
  },

  renderSidebar() {
    const items = [
      { id: 'dashboard', label: 'Dashboard',  icon: '\u25C9' },
      { id: 'network',   label: 'Network',    icon: '\u2B2A' },
      { id: 'relays',    label: 'Relays',     icon: '\u2B21' },
      { id: 'routes',    label: 'Routes',     icon: '\u2192' },
      { id: 'apps',      label: 'Apps',       icon: '\u25A3' },
      { id: 'batch',     label: 'Batch',      icon: '\u29BF' },
    ];
    return `
      <div class="sidebar">
        <div class="sidebar-brand">
          <h1>skein</h1>
          <div class="brand-sub">mixnet operations</div>
        </div>
        <div class="sidebar-nav">
          <div class="nav-section">navigate</div>
          ${items.map(i => `
            <a href="#${i.id}" class="nav-item ${this.state.view === i.id ? 'active' : ''}">
              <span class="nav-icon">${i.icon}</span>
              <span>${i.label}</span>
            </a>
          `).join('')}
        </div>
        <div class="sidebar-footer">
          <div class="footer-ship">${this.state.stats.ship || '~zod'}</div>
          <div class="footer-label">skein node</div>
        </div>
      </div>
    `;
  },

  renderPage() {
    if (this.state.loading) {
      return '<div class="loading"><div class="spinner"></div> initializing...</div>';
    }
    switch (this.state.view) {
      case 'dashboard': return this.renderDashboard();
      case 'network':   return this.renderNetwork();
      case 'relays':    return this.renderRelays();
      case 'routes':    return this.renderRoutes();
      case 'apps':      return this.renderApps();
      case 'batch':     return this.renderBatch();
      default:          return this.renderDashboard();
    }
  },

  // ---- dashboard ----

  renderDashboard() {
    const s = this.state.stats;
    const timerStatus = s.hasTimer ? 'active' : 'idle';
    const timerClass = s.hasTimer ? 'status-on' : 'status-off';
    return `
      <div class="page-header">
        <h2>Dashboard</h2>
        <div class="page-desc">Mixnet node status overview</div>
      </div>
      <div class="page-content">
        <div class="stat-grid">
          <div class="stat-card stat-cyan">
            <div class="stat-icon">\u25A3</div>
            <div class="stat-body">
              <div class="stat-value">${s.apps || 0}</div>
              <div class="stat-label">Bound Apps</div>
            </div>
          </div>
          <div class="stat-card stat-magenta">
            <div class="stat-icon">\u2B21</div>
            <div class="stat-body">
              <div class="stat-value">${s.relays || 0}</div>
              <div class="stat-label">Relay Descriptors</div>
            </div>
          </div>
          <div class="stat-card stat-green">
            <div class="stat-icon">\u25CE</div>
            <div class="stat-body">
              <div class="stat-value">${s.seen || 0}</div>
              <div class="stat-label">Seen Cache</div>
            </div>
          </div>
          <div class="stat-card stat-amber">
            <div class="stat-icon">\u2192</div>
            <div class="stat-body">
              <div class="stat-value">${s.routes || 0}</div>
              <div class="stat-label">Route Log</div>
            </div>
          </div>
          <div class="stat-card stat-purple">
            <div class="stat-icon">\u29BF</div>
            <div class="stat-body">
              <div class="stat-value">${s.batch || 0}</div>
              <div class="stat-label">Batch Queue</div>
            </div>
          </div>
          <div class="stat-card stat-white">
            <div class="stat-icon">\u25C9</div>
            <div class="stat-body">
              <div class="stat-value"><span class="status-dot ${timerClass}"></span>${timerStatus}</div>
              <div class="stat-label">Epoch Timer</div>
            </div>
          </div>
        </div>

        ${this.renderDashTopo()}

        <div class="security-panel">
          <div class="security-header">
            <span class="security-icon">\u26E8</span>
            <span>Transport Security</span>
          </div>
          <div class="security-grid">
            ${this.secCheck('\u2713', true, 'Asymmetric Headers', 'X25519 DH + AES-SIV per hop')}
            ${this.secCheck('\u2713', true, 'Body Onion Layers', 'Per-hop symmetric re-encryption')}
            ${this.secCheck('\u2713', true, 'Cell ID Rotation', 'Randomized at each relay hop')}
            ${this.secCheck('\u2713', true, 'Contact Bundles', 'Opaque reply-block destinations')}
            ${this.secCheck(s.effectiveMinHops >= 2 ? '\u2713' : '\u26A0', s.effectiveMinHops >= 1, 'Route Diversity', `${s.effectiveMinHops || 0} effective hops \u2014 ${s.effectiveMinHops >= 2 ? 'strong' : s.effectiveMinHops >= 1 ? 'moderate' : 'direct'}`)}
            ${this.secCheck(s.adaptiveHops ? '\u2713' : '\u2014', s.adaptiveHops, 'Adaptive Hops', s.adaptiveHops ? 'auto-scaling with relay pool' : 'manual mode')}
          </div>
        </div>

        <div class="dash-panels">
          <div class="panel">
            <div class="panel-header">
              <span class="panel-title">System Health</span>
            </div>
            <div class="panel-body">
              <div class="health-row">
                <span class="health-label">Node</span>
                <span class="health-value mono">${this.esc(s.ship || '~zod')}</span>
              </div>
              <div class="health-row">
                <span class="health-label">Epoch Timer</span>
                <span class="health-value"><span class="status-dot ${timerClass}"></span>${timerStatus}</span>
              </div>
              <div class="health-row">
                <span class="health-label">Replay Cache</span>
                <span class="health-value">${s.seen || 0} entries (TTL: 1h)
                  ${s.seen > 0 ? `<button class="btn btn-xs btn-ghost" data-action="clear-seen" style="margin-left:8px;">clear</button>` : ''}
                </span>
              </div>
              <div class="health-row">
                <span class="health-label">Route History</span>
                <span class="health-value">${s.routes || 0} / 100 max</span>
              </div>
              <div class="health-row">
                <span class="health-label">Minted Contacts</span>
                <span class="health-value">${s.mintedContacts || 0}</span>
              </div>
            </div>
          </div>

          <div class="panel">
            <div class="panel-header">
              <span class="panel-title">Recent Routes</span>
              <a href="#routes" class="panel-link">view all</a>
            </div>
            <div class="panel-body">
              ${this.renderDashRouteList()}
            </div>
          </div>
        </div>
      </div>
    `;
  },

  renderDashTopo() {
    const { svg, recentRoutes, self } = this.buildTopoSVG(20, 8);
    if (!this.state.relays.length && !recentRoutes.length) return '';
    return `
      <div class="topo-container dash-topo">
        ${svg}
        <div class="topo-legend">
          <span class="topo-legend-item"><span class="topo-legend-dot topo-legend-self"></span>${this.esc(self)}</span>
          <span class="topo-legend-item"><span class="topo-legend-dot topo-legend-relay"></span>Relay</span>
          <span class="topo-legend-item">${recentRoutes.length} active route${recentRoutes.length !== 1 ? 's' : ''}</span>
        </div>
      </div>
    `;
  },

  renderDashRouteList() {
    const routes = this.state.routes;
    if (!routes.length) return '<div class="empty-mini">no routes logged</div>';
    return routes.slice(0, 5).map((r, ri) => `
      <div class="health-row">
        <span class="health-label">
          <span class="route-color-dot" style="background:${this.routeColors[ri % this.routeColors.length]}"></span>
          <span class="mono">${this.shortId(r.cellId)}</span>
        </span>
        <span class="health-value">
          <span class="hop-chain">${r.hops.map(h => `<span class="hop-node">${this.esc(h)}</span>`).join('<span class="hop-arrow">\u2192</span>')}</span>
        </span>
      </div>
    `).join('');
  },

  // ---- network topology ----

  routeColors: [
    '#00e5ff', '#ff00aa', '#00ff88', '#ffaa00',
    '#aa66ff', '#ff3355', '#66ffcc', '#ff6633',
  ],

  buildTopoSVG(maxRoutes = 20, maxPackets = 8) {
    const relays = this.state.relays;
    const routes = this.state.routes;
    const self = this.state.stats.ship || '~zod';

    const nodeSet = new Set([self]);
    relays.forEach(r => nodeSet.add(r.ship));
    routes.forEach(r => r.hops.forEach(h => nodeSet.add(h)));
    const nodes = Array.from(nodeSet);

    const recentRoutes = routes.slice(0, maxRoutes);
    const edges = [];
    recentRoutes.forEach((r, ri) => {
      const chain = [self, ...r.hops];
      for (let i = 0; i < chain.length - 1; i++) {
        edges.push({ from: chain[i], to: chain[i + 1], routeIdx: ri });
      }
    });

    const W = 700, H = 460;
    const cx = W / 2, cy = H / 2;
    const radius = Math.min(W, H) * 0.34;
    const positions = {};
    nodes.forEach((n, i) => {
      const angle = (2 * Math.PI * i / nodes.length) - Math.PI / 2;
      positions[n] = { x: cx + radius * Math.cos(angle), y: cy + radius * Math.sin(angle) };
    });

    const edgeKey = (a, b) => [a, b].sort().join('|');
    const edgeFreq = {};
    edges.forEach(e => {
      const k = edgeKey(e.from, e.to);
      edgeFreq[k] = (edgeFreq[k] || 0) + 1;
    });

    const svgEdges = Object.entries(edgeFreq).map(([key, freq]) => {
      const [a, b] = key.split('|');
      const pa = positions[a], pb = positions[b];
      if (!pa || !pb) return '';
      const opacity = Math.min(0.2 + freq * 0.1, 0.7);
      const sw = Math.min(1 + freq * 0.4, 3);
      return `<line x1="${pa.x}" y1="${pa.y}" x2="${pb.x}" y2="${pb.y}"
                stroke="var(--border-lit)" stroke-width="${sw}" stroke-opacity="${opacity}" />`;
    }).join('');

    const svgPackets = recentRoutes.slice(0, maxPackets).map((r, ri) => {
      const chain = [self, ...r.hops];
      const points = chain.map(n => positions[n]).filter(Boolean);
      if (points.length < 2) return '';
      const d = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ');
      const color = this.routeColors[ri % this.routeColors.length];
      const dur = 2.5 + ri * 0.6;
      const delay = ri * 0.4;
      return `
        <circle r="3.5" fill="${color}" opacity="0.9" class="packet">
          <animateMotion dur="${dur}s" begin="${delay}s" repeatCount="indefinite" path="${d}" />
        </circle>`;
    }).join('');

    const svgNodes = nodes.map(n => {
      const p = positions[n];
      const isSelf = n === self;
      const r = isSelf ? 18 : 12;
      const fill = isSelf ? 'var(--cyan-dim)' : 'var(--bg-surface)';
      const stroke = isSelf ? 'var(--cyan)' : 'var(--border-lit)';
      const textColor = isSelf ? 'var(--cyan)' : 'var(--text)';
      const label = n.length > 8 ? n.slice(0, 7) + '..' : n;
      return `
        <circle cx="${p.x}" cy="${p.y}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="2" class="topo-node ${isSelf ? 'topo-self' : ''}" />
        <text x="${p.x}" y="${p.y + r + 16}" text-anchor="middle" fill="${textColor}" font-size="11" font-family="var(--font-mono)">${this.esc(label)}</text>`;
    }).join('');

    return { svg: `
      <svg viewBox="0 0 ${W} ${H}" class="topo-svg">
        <defs>
          <filter id="glow">
            <feGaussianBlur stdDeviation="3" result="blur" />
            <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
        </defs>
        ${svgEdges}
        ${svgPackets}
        ${svgNodes}
      </svg>`, recentRoutes, nodes, edgeFreq, self };
  },

  renderNetwork() {
    const { svg, recentRoutes, nodes, edgeFreq, self } = this.buildTopoSVG();
    return `
      <div class="page-header">
        <h2>Network</h2>
        <div class="page-desc">Relay topology and active routes</div>
      </div>
      <div class="page-content">
        <div class="topo-container">${svg}</div>
        <div class="topo-legend">
          <span class="topo-legend-item"><span class="topo-legend-dot topo-legend-self"></span> This node (${this.esc(self)})</span>
          <span class="topo-legend-item"><span class="topo-legend-dot topo-legend-relay"></span> Relay</span>
          <span class="topo-legend-item"><span class="topo-legend-dot topo-legend-edge"></span> Active route (${recentRoutes.length} recent)</span>
        </div>
        <div class="dash-panels" style="margin-top:20px;">
          <div class="panel">
            <div class="panel-header"><span class="panel-title">Network Stats</span></div>
            <div class="panel-body">
              <div class="health-row"><span class="health-label">Nodes</span><span class="health-value">${nodes.length}</span></div>
              <div class="health-row"><span class="health-label">Relay Descriptors</span><span class="health-value">${this.state.relays.length}</span></div>
              <div class="health-row"><span class="health-label">Routes Logged</span><span class="health-value">${this.state.routes.length}</span></div>
              <div class="health-row"><span class="health-label">Unique Edges</span><span class="health-value">${Object.keys(edgeFreq).length}</span></div>
            </div>
          </div>
          <div class="panel">
            <div class="panel-header"><span class="panel-title">Recent Activity</span></div>
            <div class="panel-body">
              ${recentRoutes.length ? recentRoutes.slice(0, 5).map((r, ri) => `
                <div class="health-row">
                  <span class="health-label"><span class="route-color-dot" style="background:${this.routeColors[ri % this.routeColors.length]}"></span><span class="mono">${this.shortId(r.cellId)}</span></span>
                  <span class="health-value">
                    <span class="hop-chain">${r.hops.map(h => `<span class="hop-node">${this.esc(h)}</span>`).join('<span class="hop-arrow">\u2192</span>')}</span>
                  </span>
                </div>
              `).join('') : '<div class="empty-mini">no recent routes</div>'}
            </div>
          </div>
        </div>
      </div>
    `;
  },

  // ---- relays ----

  renderRelays() {
    return `
      <div class="page-header">
        <h2>Relays</h2>
        <div class="page-desc">Relay descriptors for anonymous routing</div>
      </div>
      <div class="page-content">
        <div style="margin-bottom:20px;">
          <button class="btn btn-primary" data-action="open-add-relay">+ Add Relay</button>
        </div>
        ${this.state.relays.length ? `
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Relay ID</th>
                  <th>Ship</th>
                  <th>Weight</th>
                  <th>Pub</th>
                  <th>Delay</th>
                  <th>Expiry</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                ${this.state.relays.map(r => `
                  <tr>
                    <td class="mono">${this.esc(r.relay)}</td>
                    <td class="mono">${this.esc(r.ship)}</td>
                    <td>${r.weight}</td>
                    <td><span class="status-dot ${r.hasPub ? 'status-on' : 'status-off'}"></span>${r.hasPub ? 'yes' : 'none'}</td>
                    <td>${r.delay ? r.delay + 's' : '---'}</td>
                    <td>${r.expiry ? this.fmtDate(r.expiry) : 'never'}</td>
                    <td>
                      <button class="btn btn-xs btn-ghost btn-danger" data-action="drop-relay" data-relay="${this.esc(r.relay)}">remove</button>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2B21</div>
            <div class="empty-text">No relay descriptors configured</div>
            <div class="empty-hint">Add relays to enable anonymous multi-hop routing</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- routes ----

  renderRoutes() {
    return `
      <div class="page-header">
        <h2>Routes</h2>
        <div class="page-desc">Recent cell routing decisions</div>
      </div>
      <div class="page-content">
        ${this.state.routes.length ? `
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Cell ID</th>
                  <th>Route ID</th>
                  <th>Target</th>
                  <th>Hop Path</th>
                  <th>Selected At</th>
                </tr>
              </thead>
              <tbody>
                ${this.state.routes.map(r => `
                  <tr>
                    <td class="mono truncate">${this.shortId(r.cellId)}</td>
                    <td class="mono truncate">${this.shortId(r.routeId)}</td>
                    <td class="mono">${this.esc(r.target)}</td>
                    <td class="mono">
                      <div class="hop-chain">
                        ${r.hops.map((h, i) => `<span class="hop-node">${this.esc(h)}</span>${i < r.hops.length - 1 ? '<span class="hop-arrow">\u2192</span>' : ''}`).join('')}
                      </div>
                    </td>
                    <td class="mono">${this.fmtDate(r.selectedAt)}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u2192</div>
            <div class="empty-text">No routes logged yet</div>
            <div class="empty-hint">Routes are logged when cells are sent through the mixnet</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- apps ----

  renderApps() {
    return `
      <div class="page-header">
        <h2>Apps</h2>
        <div class="page-desc">Bound applications receiving messages via the mixnet</div>
      </div>
      <div class="page-content">
        <div style="margin-bottom:20px;">
          <button class="btn btn-primary" data-action="open-bind-app">+ Bind App</button>
        </div>
        ${this.state.apps.length ? `
          <div class="app-grid">
            ${this.state.apps.map(a => `
              <div class="app-card ${a === 'cover' ? 'app-system' : ''}">
                <div class="app-icon">${a === 'cover' ? '\u25C9' : '\u25A3'}</div>
                <div class="app-info">
                  <div class="app-name">${this.esc(a)}</div>
                  <div class="app-type">${a === 'cover' ? 'system / cover traffic' : 'user app'}</div>
                </div>
                <div class="app-actions">
                  ${a === 'cover' ? '<span class="badge badge-system">system</span>' : `
                    <button class="btn btn-xs btn-ghost btn-danger" data-action="unbind-app" data-app="${this.esc(a)}">unbind</button>
                  `}
                </div>
              </div>
            `).join('')}
          </div>
        ` : `
          <div class="empty-state">
            <div class="empty-icon">\u25A3</div>
            <div class="empty-text">No applications bound</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- batch ----

  renderBatch() {
    const timer = this.state.batchTimer;
    return `
      <div class="page-header">
        <h2>Batch</h2>
        <div class="page-desc">Current epoch batch queue -- cells waiting to be forwarded</div>
      </div>
      <div class="page-content">
        <div class="batch-status">
          <div class="batch-timer-card">
            <div class="batch-timer-label">Next Epoch Flush</div>
            <div class="batch-timer-value ${timer ? 'timer-active' : ''}">${timer ? this.fmtCountdown(timer) : 'no timer'}</div>
            <div class="batch-timer-abs">${timer ? this.fmtDate(timer) : '---'}</div>
          </div>
          <div class="batch-count-card">
            <div class="batch-count-label">Queued Cells</div>
            <div class="batch-count-value">${this.state.batch.length}</div>
          </div>
        </div>
        ${this.state.batch.length ? `
          <div class="table-wrap" style="margin-top:20px;">
            <table>
              <thead>
                <tr>
                  <th>Next Ship</th>
                  <th>Cell ID</th>
                </tr>
              </thead>
              <tbody>
                ${this.state.batch.map(b => `
                  <tr>
                    <td class="mono">${this.esc(b.next)}</td>
                    <td class="mono truncate">${this.shortId(b.cellId)}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        ` : `
          <div class="empty-state" style="margin-top:20px;">
            <div class="empty-icon">\u29BF</div>
            <div class="empty-text">Batch is empty</div>
            <div class="empty-hint">Cells accumulate here until the epoch timer fires (~30s)</div>
          </div>
        `}
      </div>
    `;
  },

  // ---- dialogs ----

  renderDialog() {
    if (!this.state.dialog) return '';
    const { name } = this.state.dialog;
    let content = '';

    if (name === 'add-relay') {
      content = `
        <h3>Discover Relay</h3>
        <p style="color:var(--dim);margin-bottom:16px;font-size:13px">Subscribe to a ship to discover its key and relay pool</p>
        <div class="form-group">
          <label>Ship</label>
          <input type="text" id="relay-ship" placeholder="~sampel-palnet" autofocus>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-add-relay">Discover</button>
        </div>
      `;
    }

    if (name === 'bind-app') {
      content = `
        <h3>Bind Application</h3>
        <div class="form-group">
          <label>App Name</label>
          <input type="text" id="bind-app-name" placeholder="my-app" autofocus>
        </div>
        <div class="form-actions">
          <button class="btn" data-action="close-dialog">Cancel</button>
          <button class="btn btn-primary" data-action="submit-bind-app">Bind</button>
        </div>
      `;
    }

    return `
      <div class="dialog-overlay" data-action="close-dialog-bg">
        <div class="dialog" onclick="event.stopPropagation()">
          ${content}
        </div>
      </div>
    `;
  },

  // ---- events ----

  bindEvents() {
    document.querySelectorAll('[data-action]').forEach(el => {
      el.addEventListener('click', (e) => {
        const action = el.dataset.action;
        switch (action) {
          case 'open-add-relay':
            this.openDialog('add-relay');
            break;
          case 'submit-add-relay':
            this.action(() => SkeinAPI.discoverRelay(
              document.getElementById('relay-ship').value,
            ));
            break;
          case 'drop-relay':
            if (confirm('Remove this relay descriptor?')) {
              this.action(() => SkeinAPI.dropRelay(el.dataset.relay));
            }
            break;
          case 'clear-seen':
            this.action(() => SkeinAPI.clearSeen());
            break;
          case 'open-bind-app':
            this.openDialog('bind-app');
            break;
          case 'submit-bind-app':
            this.action(() => SkeinAPI.bindApp(
              document.getElementById('bind-app-name').value,
            ));
            break;
          case 'unbind-app':
            if (confirm(`Unbind ${el.dataset.app}?`)) {
              this.action(() => SkeinAPI.unbindApp(el.dataset.app));
            }
            break;
          case 'close-dialog':
          case 'close-dialog-bg':
            this.closeDialog();
            break;
        }
      });
    });
  },

  secCheck(icon, ok, label, desc) {
    return `
      <div class="sec-item">
        <span class="sec-icon ${ok ? 'sec-on' : 'sec-warn'}">${icon}</span>
        <div class="sec-text">
          <span class="sec-label">${label}</span>
          <span class="sec-desc">${desc}</span>
        </div>
      </div>
    `;
  },

  esc(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },
};

document.addEventListener('DOMContentLoaded', () => App.init());
