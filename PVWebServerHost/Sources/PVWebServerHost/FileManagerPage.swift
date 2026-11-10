//
//  FileManagerPage.swift
//  PVWebServerHost
//
//  The web file manager served at `GET /`. Self-contained: it reaches the server only
//  through the routes in `PVHostedWebServer+Routes.swift`.
//

import Foundation

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
enum FileManagerPage {

    // swiftlint:disable:next function_body_length
    static func html(defaultUploadPath: String) -> String {
        // Inject the default upload subpath as a JS constant so client-side
        // navigation can target it before any user interaction.
        let jsDefaultPath = defaultUploadPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Provenance — Web File Manager</title>
          <style>
            :root {
              color-scheme: dark;
              --pv-bg: #1a1a2e;
              --pv-surface: #16213e;
              --pv-surface-hover: #1f2f52;
              --pv-border: #2a3a5c;
              --pv-text: #e0e0e0;
              --pv-text-muted: #8899aa;
              --pv-accent: #4a90d9;
              --pv-accent-hover: #5ba3ec;
              --pv-success: #27ae60;
              --pv-danger: #c0392b;
              --pv-warning: #f39c12;
            }
            * { box-sizing: border-box; }
            body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
                   max-width: 1100px; margin: 0 auto; padding: 20px;
                   background: var(--pv-bg); color: var(--pv-text);
                   -webkit-font-smoothing: antialiased; }
            header { display: flex; align-items: center; gap: 16px; padding: 8px 0 16px;
                     border-bottom: 2px solid var(--pv-accent); margin-bottom: 20px; }
            header .logo { font-size: 32px; line-height: 1; }
            header h1 { margin: 0; font-size: 24px; font-weight: 700; letter-spacing: -0.5px; }
            header .sub { margin: 2px 0 0; color: var(--pv-text-muted); font-size: 13px; }

            .card { background: var(--pv-surface); border: 1px solid var(--pv-border);
                    border-radius: 10px; padding: 16px; margin-bottom: 16px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.25); }
            .card h2 { margin: 0 0 12px; font-size: 13px; font-weight: 600;
                       color: var(--pv-text-muted); text-transform: uppercase; letter-spacing: 0.5px; }

            .drop-zone { border: 2px dashed var(--pv-border); border-radius: 10px;
                         padding: 28px 20px; text-align: center; transition: all 0.2s;
                         background-color: rgba(74, 144, 217, 0.03); cursor: pointer; }
            .drop-zone.hover { border-color: var(--pv-accent);
                               background-color: rgba(74, 144, 217, 0.12);
                               box-shadow: 0 0 18px rgba(74, 144, 217, 0.18); }
            .drop-zone p { margin: 6px 0; color: var(--pv-text-muted); font-size: 13px; }
            .drop-zone .lead { color: var(--pv-text); font-weight: 600; font-size: 15px; }
            .btn { display: inline-block; padding: 8px 16px; border-radius: 6px;
                   font-size: 14px; font-weight: 500; cursor: pointer;
                   border: 1px solid transparent; transition: all 0.15s; }
            .btn-primary { background: var(--pv-accent); color: #fff; border-color: var(--pv-accent); }
            .btn-primary:hover { background: var(--pv-accent-hover); border-color: var(--pv-accent-hover); }
            .btn-success { background: var(--pv-success); color: #fff; border-color: var(--pv-success); }
            .btn-success:hover { filter: brightness(1.1); }
            .btn-default { background: var(--pv-surface); color: var(--pv-text); border-color: var(--pv-border); }
            .btn-default:hover { background: var(--pv-surface-hover); border-color: var(--pv-accent); color: #fff; }
            .btn-sm { padding: 4px 10px; font-size: 13px; }
            .btn-icon { padding: 4px 8px; background: none; border: none; color: var(--pv-text-muted);
                        cursor: pointer; border-radius: 4px; font-size: 14px; }
            .btn-icon:hover { background: rgba(255,255,255,0.06); color: #fff; }
            .btn-icon.danger:hover { background: rgba(192,57,43,0.18); color: #e74c3c; }

            .toolbar { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-top: 12px; }
            #progress-bar { width: 100%; height: 6px; background: var(--pv-bg); border-radius: 3px;
                            margin-top: 12px; display: none; overflow: hidden; }
            #progress-fill { height: 100%; background: var(--pv-accent); width: 0%; transition: width 0.2s; }
            #status { margin-top: 8px; font-size: 13px; color: var(--pv-text-muted); }

            .quick-nav { display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
                         margin-bottom: 12px; }
            .quick-nav-label { font-size: 13px; color: var(--pv-text-muted); font-weight: 500; }
            .quick-nav .btn { background: var(--pv-surface); color: var(--pv-text);
                              border: 1px solid var(--pv-border); padding: 4px 12px; font-size: 13px; }
            .quick-nav .btn:hover { background: var(--pv-surface-hover); border-color: var(--pv-accent); color: #fff; }
            .quick-nav .btn.active { background: var(--pv-accent); border-color: var(--pv-accent); color: #fff; }

            .breadcrumb { display: flex; flex-wrap: wrap; gap: 4px; align-items: center;
                          font-size: 13px; color: var(--pv-text-muted); margin-bottom: 10px; }
            .breadcrumb a { color: var(--pv-accent); cursor: pointer; text-decoration: none; }
            .breadcrumb a:hover { text-decoration: underline; color: var(--pv-accent-hover); }
            .breadcrumb .sep { color: var(--pv-text-muted); }

            table { width: 100%; border-collapse: collapse; }
            thead th { text-align: left; padding: 8px 10px; font-size: 12px; font-weight: 600;
                       color: var(--pv-text-muted); text-transform: uppercase; letter-spacing: 0.5px;
                       border-bottom: 1px solid var(--pv-border); }
            tbody tr { border-bottom: 1px solid var(--pv-border); transition: background 0.15s; }
            tbody tr:hover { background: rgba(74,144,217,0.08); }
            tbody td { padding: 10px; font-size: 14px; vertical-align: middle; color: var(--pv-text); }
            .col-name { width: auto; }
            .col-name .clickable { color: var(--pv-text); cursor: pointer; }
            .col-name .clickable:hover { color: #fff; text-decoration: underline; }
            .col-name .dir-icon { color: var(--pv-warning); margin-right: 6px; }
            .col-name .file-icon { color: var(--pv-text-muted); margin-right: 6px; }
            .col-size { width: 110px; text-align: right; color: var(--pv-text-muted);
                        font-variant-numeric: tabular-nums; font-size: 13px; }
            .col-mod { width: 200px; color: var(--pv-text-muted); font-size: 13px; }
            .col-actions { width: 130px; text-align: right; white-space: nowrap; }
            .empty { color: var(--pv-text-muted); text-align: center; padding: 32px 16px; font-size: 14px; }

            .modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.6);
                              display: none; align-items: center; justify-content: center;
                              z-index: 1000; }
            .modal-backdrop.active { display: flex; }
            .modal { background: var(--pv-surface); border: 1px solid var(--pv-border);
                     border-radius: 10px; padding: 20px; min-width: 320px;
                     box-shadow: 0 8px 24px rgba(0,0,0,0.4); }
            .modal h3 { margin: 0 0 12px; font-size: 16px; }
            .modal input { width: 100%; padding: 8px 12px; background: var(--pv-bg);
                           border: 1px solid var(--pv-border); border-radius: 6px;
                           color: var(--pv-text); font-size: 14px; }
            .modal input:focus { border-color: var(--pv-accent); outline: none;
                                 box-shadow: 0 0 0 2px rgba(74,144,217,0.25); }
            .modal-actions { display: flex; gap: 8px; justify-content: flex-end; margin-top: 16px; }

            /* ---------- Dashboard ---------- */
            .dashboard { display: grid; grid-template-columns: 1fr 168px; gap: 20px; align-items: stretch; }
            .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }
            .stat { background: var(--pv-bg); border: 1px solid var(--pv-border); border-radius: 8px;
                    padding: 12px; }
            .stat .label { font-size: 11px; color: var(--pv-text-muted); text-transform: uppercase;
                           letter-spacing: 0.5px; margin-bottom: 4px; }
            .stat .value { font-size: 20px; font-weight: 700; color: #ffffff; font-variant-numeric: tabular-nums; }
            .stat .sub { font-size: 12px; color: var(--pv-text-muted); margin-top: 2px; }
            .disk-bar { margin-top: 10px; height: 6px; background: var(--pv-bg);
                        border: 1px solid var(--pv-border); border-radius: 3px; overflow: hidden; }
            .disk-fill { height: 100%; background: linear-gradient(90deg, var(--pv-accent), var(--pv-success));
                         transition: width 0.4s ease; }
            .qr-block { display: flex; flex-direction: column; align-items: center; gap: 6px;
                        padding: 8px; background: #ffffff; border-radius: 8px; }
            .qr-block img { width: 152px; height: 152px; display: block; image-rendering: pixelated; }
            .qr-block .caption { color: #111; font-size: 11px; font-weight: 600; }
            .server-url-row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap;
                              margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--pv-border);
                              font-size: 13px; }
            .server-url-row code { background: var(--pv-bg); border: 1px solid var(--pv-border);
                                   padding: 4px 8px; border-radius: 4px; color: var(--pv-accent); }
            .copy-btn { padding: 4px 10px; font-size: 12px; }

            /* ---------- Search + select toolbar ---------- */
            .list-toolbar { display: flex; gap: 8px; align-items: center; flex-wrap: wrap;
                            margin-bottom: 10px; }
            .search-input { flex: 1 1 220px; min-width: 160px; padding: 6px 10px;
                            background: var(--pv-bg); border: 1px solid var(--pv-border);
                            border-radius: 6px; color: var(--pv-text); font-size: 13px; }
            .search-input:focus { border-color: var(--pv-accent); outline: none;
                                  box-shadow: 0 0 0 2px rgba(74,144,217,0.25); }
            .selection-pill { display: none; padding: 4px 10px; border-radius: 12px;
                              background: rgba(74,144,217,0.18); color: var(--pv-accent);
                              font-size: 12px; font-weight: 600; }
            .selection-pill.active { display: inline-block; }

            .col-check { width: 32px; text-align: center; }
            .col-check input[type="checkbox"] { accent-color: var(--pv-accent); cursor: pointer;
                                                 width: 14px; height: 14px; }

            /* ---------- Toast notifications ---------- */
            #toast-stack { position: fixed; top: 20px; right: 20px; z-index: 2000;
                           display: flex; flex-direction: column; gap: 8px; max-width: 320px; }
            .toast { background: var(--pv-surface); border: 1px solid var(--pv-border);
                     border-radius: 8px; padding: 10px 14px; font-size: 13px;
                     box-shadow: 0 6px 20px rgba(0,0,0,0.45);
                     animation: toastIn 0.18s ease-out; }
            .toast.success { border-color: var(--pv-success); color: #ffffff; }
            .toast.error   { border-color: var(--pv-danger);  color: #ffffff; }
            .toast.info    { border-color: var(--pv-accent);  color: var(--pv-text); }
            @keyframes toastIn { from { transform: translateY(-8px); opacity: 0; }
                                 to   { transform: translateY(0);    opacity: 1; } }
            .toast.leaving { animation: toastOut 0.18s ease-in forwards; }
            @keyframes toastOut { to { transform: translateY(-8px); opacity: 0; } }

            @media (max-width: 700px) {
              .dashboard { grid-template-columns: 1fr; }
              .qr-block  { align-self: center; }
            }
            @media (max-width: 600px) {
              .col-mod { display: none; }
              .col-size { width: 80px; }
              .col-actions { width: 96px; }
              .col-check { width: 28px; }
            }
          </style>
        </head>
        <body>
          <div id="toast-stack" aria-live="polite"></div>

          <header>
            <div class="logo">🎮</div>
            <div>
              <h1>Provenance Web Uploader</h1>
              <p class="sub">Drag &amp; drop ROMs, BIOS, and save files from any device on your network.</p>
            </div>
          </header>

          <!-- Dashboard: disk stats, uptime, server URL, QR code -->
          <div class="card">
            <h2>Dashboard</h2>
            <div class="dashboard">
              <div>
                <div class="stats-grid">
                  <div class="stat">
                    <div class="label">Disk Used</div>
                    <div class="value" id="stat-disk-used">—</div>
                    <div class="sub" id="stat-disk-sub">of — total</div>
                    <div class="disk-bar"><div class="disk-fill" id="stat-disk-fill" style="width:0%"></div></div>
                  </div>
                  <div class="stat">
                    <div class="label">Library Size</div>
                    <div class="value" id="stat-library-size">—</div>
                    <div class="sub" id="stat-library-count">— files across categories</div>
                  </div>
                  <div class="stat">
                    <div class="label">Server Uptime</div>
                    <div class="value" id="stat-uptime">—</div>
                    <div class="sub" id="stat-version">Provenance —</div>
                  </div>
                </div>
                <div class="server-url-row">
                  <span class="quick-nav-label">Browser and WebDAV:</span>
                  <code id="server-url">—</code>
                  <button class="btn btn-default copy-btn" id="copy-url-btn">📋 Copy</button>
                </div>
              </div>
              <div class="qr-block" id="qr-block" title="Scan to open from your phone">
                <img id="qr-img" alt="QR code for server URL" src="/qr.png">
                <div class="caption">Scan to open</div>
              </div>
            </div>
          </div>

          <div class="card">
            <div class="drop-zone" id="drop-zone">
              <p class="lead">Drop files here to upload</p>
              <p>or</p>
              <div class="toolbar">
                <button class="btn btn-primary" id="upload-btn">⬆ Upload Files</button>
                <button class="btn btn-success" id="newfolder-btn">📁 New Folder</button>
                <button class="btn btn-default" id="refresh-btn">↻ Refresh</button>
                <input type="file" id="file-input" multiple style="display:none">
              </div>
              <div id="progress-bar"><div id="progress-fill"></div></div>
              <div id="status"></div>
            </div>
          </div>

          <div class="card">
            <div class="quick-nav">
              <span class="quick-nav-label">Quick Access:</span>
              <button class="btn btn-sm" data-quick="Imports">Imports</button>
              <button class="btn btn-sm" data-quick="ROMs">ROMs</button>
              <button class="btn btn-sm" data-quick="BIOS">BIOS</button>
              <button class="btn btn-sm" data-quick="Save States">Save States</button>
              <button class="btn btn-sm" data-quick="">All Files</button>
            </div>
            <nav class="breadcrumb" id="breadcrumb"></nav>
            <div class="list-toolbar">
              <input type="search" class="search-input" id="search-input"
                     placeholder="🔍 Filter files in this folder…" autocomplete="off">
              <span class="selection-pill" id="selection-pill">0 selected</span>
              <button class="btn btn-default btn-sm" id="select-all-btn">☑ Select All</button>
              <button class="btn btn-default btn-sm" id="select-none-btn">☐ Clear</button>
              <button class="btn btn-danger btn-sm" id="bulk-delete-btn" disabled
                      style="background:var(--pv-danger);border-color:var(--pv-danger);color:#fff;opacity:0.55">
                🗑 Delete Selected
              </button>
            </div>
            <table>
              <thead><tr>
                <th class="col-check"><input type="checkbox" id="select-all-cb" title="Select all"></th>
                <th class="col-name">Name</th>
                <th class="col-size">Size</th>
                <th class="col-mod">Modified</th>
                <th class="col-actions"></th>
              </tr></thead>
              <tbody id="file-list"><tr><td colspan="5" class="empty">Loading…</td></tr></tbody>
            </table>
          </div>

          <div class="modal-backdrop" id="modal">
            <div class="modal">
              <h3 id="modal-title">New Folder</h3>
              <input type="text" id="modal-input" autocomplete="off">
              <div class="modal-actions">
                <button class="btn btn-default" id="modal-cancel">Cancel</button>
                <button class="btn btn-primary" id="modal-ok">OK</button>
              </div>
            </div>
          </div>

          <script>
            const DEFAULT_UPLOAD_PATH = "\(jsDefaultPath)";
            let currentPath = DEFAULT_UPLOAD_PATH;
            let currentItems = [];          // Cached items for current dir (post-filter rendering)
            const selectedNames = new Set(); // Names of selected items in current dir
            let searchFilter = '';

            // ----- Toasts -----
            function toast(message, type = 'info', durationMs = 3200) {
              const stack = document.getElementById('toast-stack');
              if (!stack) return;
              const el = document.createElement('div');
              el.className = 'toast ' + type;
              el.textContent = message;
              stack.appendChild(el);
              setTimeout(() => {
                el.classList.add('leaving');
                setTimeout(() => el.remove(), 220);
              }, durationMs);
            }

            function esc(s) {
              return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;')
                              .replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#x27;');
            }
            function fmtSize(b) {
              if (!b) return '0 B';
              if (b < 1024) return b + ' B';
              if (b < 1024*1024) return (b/1024).toFixed(1) + ' KB';
              if (b < 1024*1024*1024) return (b/1024/1024).toFixed(1) + ' MB';
              return (b/1024/1024/1024).toFixed(2) + ' GB';
            }
            function fmtUptime(seconds) {
              const d = Math.floor(seconds / 86400);
              const h = Math.floor((seconds % 86400) / 3600);
              const m = Math.floor((seconds % 3600) / 60);
              const s = Math.floor(seconds % 60);
              if (d > 0) return d + 'd ' + h + 'h';
              if (h > 0) return h + 'h ' + m + 'm';
              if (m > 0) return m + 'm ' + s + 's';
              return s + 's';
            }
            function joinPath(a, b) {
              if (!a) return b;
              if (!b) return a;
              return a.replace(/\\/+$/, '') + '/' + b.replace(/^\\/+/, '');
            }
            function parentPath(p) {
              if (!p) return '';
              const trimmed = p.replace(/\\/+$/, '');
              const idx = trimmed.lastIndexOf('/');
              return idx >= 0 ? trimmed.slice(0, idx) : '';
            }

            // ----- Modal helpers -----
            const modal = document.getElementById('modal');
            const modalTitle = document.getElementById('modal-title');
            const modalInput = document.getElementById('modal-input');
            const modalOk = document.getElementById('modal-ok');
            const modalCancel = document.getElementById('modal-cancel');
            let modalResolver = null;
            function promptModal(title, placeholder) {
              modalTitle.textContent = title;
              modalInput.value = placeholder || '';
              modal.classList.add('active');
              modalInput.focus();
              modalInput.select();
              return new Promise(resolve => { modalResolver = resolve; });
            }
            modalOk.addEventListener('click', () => { modal.classList.remove('active');
              const v = modalInput.value.trim(); modalResolver && modalResolver(v || null); });
            modalCancel.addEventListener('click', () => { modal.classList.remove('active');
              modalResolver && modalResolver(null); });
            modalInput.addEventListener('keydown', e => { if (e.key === 'Enter') modalOk.click(); else if (e.key === 'Escape') modalCancel.click(); });

            // ----- Listing + breadcrumb -----
            async function loadFiles(path) {
              const isNavigation = path !== undefined && path !== currentPath;
              currentPath = path === undefined ? currentPath : path;
              if (isNavigation) {
                selectedNames.clear();
                searchFilter = '';
                const search = document.getElementById('search-input');
                if (search) search.value = '';
              }
              renderBreadcrumb();
              updateQuickActive();
              const tbody = document.getElementById('file-list');
              tbody.innerHTML = '<tr><td colspan="5" class="empty">Loading…</td></tr>';
              try {
                const res = await fetch('/files?path=' + encodeURIComponent(currentPath));
                if (!res.ok) {
                  const err = await res.json().catch(() => ({}));
                  tbody.innerHTML = '<tr><td colspan="5" class="empty">' + esc(err.error || 'Failed to load') + '</td></tr>';
                  return;
                }
                const payload = await res.json();
                currentItems = payload.items || [];
                renderFileList();
              } catch (e) {
                tbody.innerHTML = '<tr><td colspan="5" class="empty">' + esc(e.message) + '</td></tr>';
              }
            }

            function renderFileList() {
              const tbody = document.getElementById('file-list');
              const filtered = searchFilter
                ? currentItems.filter(it => it.name.toLowerCase().includes(searchFilter))
                : currentItems;
              // Drop selections that no longer exist after a filter / refresh.
              for (const name of Array.from(selectedNames)) {
                if (!filtered.some(it => it.name === name)) selectedNames.delete(name);
              }
              let html = '';
              if (currentPath) {
                html += '<tr data-up="1"><td class="col-check"></td><td class="col-name"><span class="clickable"><span class="dir-icon">↑</span>..</span></td><td></td><td></td><td></td></tr>';
              }
              if (!filtered.length) {
                const msg = searchFilter
                  ? 'No files match "' + esc(searchFilter) + '".'
                  : (currentPath ? 'This folder is empty.' : 'No files yet — drag and drop above to upload!');
                tbody.innerHTML = html + '<tr><td colspan="5" class="empty">' + msg + '</td></tr>';
                updateSelectionUI();
                return;
              }
              html += filtered.map(it => {
                const icon = it.isDirectory ? '<span class="dir-icon">📁</span>' : '<span class="file-icon">📄</span>';
                const sizeCell = it.isDirectory ? '' : fmtSize(it.size);
                const modCell = it.modified ? new Date(it.modified).toLocaleString() : '';
                const checked = selectedNames.has(it.name) ? ' checked' : '';
                const actions = it.isDirectory
                  ? '<button class="btn-icon" data-action="rename" data-name="' + esc(it.name) + '" title="Rename">✎</button>' +
                    '<button class="btn-icon danger" data-action="delete" data-name="' + esc(it.name) + '" data-is-dir="1" title="Delete">🗑</button>'
                  : '<button class="btn-icon" data-action="download" data-name="' + esc(it.name) + '" title="Download">⬇</button>' +
                    '<button class="btn-icon" data-action="rename" data-name="' + esc(it.name) + '" title="Rename">✎</button>' +
                    '<button class="btn-icon danger" data-action="delete" data-name="' + esc(it.name) + '" title="Delete">🗑</button>';
                return '<tr data-name="' + esc(it.name) + '" data-is-dir="' + (it.isDirectory ? '1' : '0') + '">' +
                       '<td class="col-check"><input type="checkbox" data-select="' + esc(it.name) + '"' + checked + '></td>' +
                       '<td class="col-name"><span class="clickable">' + icon + esc(it.name) + '</span></td>' +
                       '<td class="col-size">' + esc(sizeCell) + '</td>' +
                       '<td class="col-mod">' + esc(modCell) + '</td>' +
                       '<td class="col-actions">' + actions + '</td>' +
                       '</tr>';
              }).join('');
              tbody.innerHTML = html;
              updateSelectionUI();
            }

            function updateSelectionUI() {
              const count = selectedNames.size;
              const pill = document.getElementById('selection-pill');
              const bulkBtn = document.getElementById('bulk-delete-btn');
              const headerCb = document.getElementById('select-all-cb');
              pill.textContent = count + ' selected';
              pill.classList.toggle('active', count > 0);
              bulkBtn.disabled = count === 0;
              bulkBtn.style.opacity = count === 0 ? '0.55' : '1';
              if (headerCb) {
                const total = currentItems.filter(it => !searchFilter || it.name.toLowerCase().includes(searchFilter)).length;
                headerCb.checked = count > 0 && count === total;
                headerCb.indeterminate = count > 0 && count < total;
              }
            }

            function renderBreadcrumb() {
              const crumb = document.getElementById('breadcrumb');
              const parts = currentPath ? currentPath.split('/').filter(Boolean) : [];
              let acc = '';
              let html = '<a data-path="">📂 root</a>';
              parts.forEach((p, i) => {
                acc = acc ? acc + '/' + p : p;
                html += '<span class="sep">/</span>';
                if (i === parts.length - 1) {
                  html += '<span>' + esc(p) + '</span>';
                } else {
                  html += '<a data-path="' + esc(acc) + '">' + esc(p) + '</a>';
                }
              });
              crumb.innerHTML = html;
            }
            function updateQuickActive() {
              document.querySelectorAll('.quick-nav .btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.quick === currentPath);
              });
            }

            // ----- Row actions + selection -----
            document.getElementById('file-list').addEventListener('click', async e => {
              // Checkbox toggles update the selection set without reloading.
              const cb = e.target.closest('input[type="checkbox"][data-select]');
              if (cb) {
                const name = cb.dataset.select;
                if (cb.checked) selectedNames.add(name); else selectedNames.delete(name);
                updateSelectionUI();
                return;
              }
              const upRow = e.target.closest('tr[data-up]');
              if (upRow) { loadFiles(parentPath(currentPath)); return; }
              const actionBtn = e.target.closest('button[data-action]');
              if (actionBtn) {
                const name = actionBtn.dataset.name;
                const action = actionBtn.dataset.action;
                if (action === 'delete') await deletePath(joinPath(currentPath, name), name);
                else if (action === 'rename') await renamePath(name);
                else if (action === 'download') window.location.href = '/download?path=' + encodeURIComponent(joinPath(currentPath, name));
                return;
              }
              const row = e.target.closest('tr[data-name]');
              if (!row) return;
              const nameClick = e.target.closest('.col-name .clickable');
              if (!nameClick) return;
              const name = row.dataset.name;
              if (row.dataset.isDir === '1') loadFiles(joinPath(currentPath, name));
              else window.location.href = '/download?path=' + encodeURIComponent(joinPath(currentPath, name));
            });

            // ----- Search filter -----
            document.getElementById('search-input').addEventListener('input', e => {
              searchFilter = e.target.value.trim().toLowerCase();
              renderFileList();
            });

            // ----- Multi-select toolbar -----
            document.getElementById('select-all-btn').addEventListener('click', () => {
              const filtered = searchFilter
                ? currentItems.filter(it => it.name.toLowerCase().includes(searchFilter))
                : currentItems;
              filtered.forEach(it => selectedNames.add(it.name));
              renderFileList();
            });
            document.getElementById('select-none-btn').addEventListener('click', () => {
              selectedNames.clear();
              renderFileList();
            });
            document.getElementById('select-all-cb').addEventListener('change', e => {
              if (e.target.checked) {
                const filtered = searchFilter
                  ? currentItems.filter(it => it.name.toLowerCase().includes(searchFilter))
                  : currentItems;
                filtered.forEach(it => selectedNames.add(it.name));
              } else {
                selectedNames.clear();
              }
              renderFileList();
            });
            document.getElementById('bulk-delete-btn').addEventListener('click', async () => {
              if (selectedNames.size === 0) return;
              if (!confirm('Delete ' + selectedNames.size + ' item(s)? This cannot be undone.')) return;
              const paths = Array.from(selectedNames).map(n => joinPath(currentPath, n));
              const res = await fetch('/files/batch-delete', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ paths: paths })
              });
              if (!res.ok) { toast('Bulk delete failed', 'error'); return; }
              const j = await res.json().catch(() => ({}));
              const deleted = j.deleted || 0;
              const failedCount = (j.failed || []).length;
              if (failedCount === 0) {
                toast('Deleted ' + deleted + ' item' + (deleted === 1 ? '' : 's'), 'success');
              } else {
                toast('Deleted ' + deleted + ', ' + failedCount + ' failed', 'error');
              }
              selectedNames.clear();
              loadFiles();
              refreshStats();
            });

            async function deletePath(path, label) {
              if (!confirm('Delete "' + label + '"?')) return;
              const res = await fetch('/files?path=' + encodeURIComponent(path), { method: 'DELETE' });
              if (!res.ok) { toast('Delete failed', 'error'); return; }
              toast('Deleted "' + label + '"', 'success');
              loadFiles();
              refreshStats();
            }
            async function renamePath(name) {
              const newName = await promptModal('Rename "' + name + '" to:', name);
              if (!newName || newName === name) return;
              const from = joinPath(currentPath, name);
              const to = joinPath(currentPath, newName);
              const res = await fetch('/files', {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ from: from, to: to })
              });
              if (!res.ok) { toast('Rename failed', 'error'); return; }
              toast('Renamed to "' + newName + '"', 'success');
              loadFiles();
            }

            // ----- Quick nav -----
            document.querySelector('.quick-nav').addEventListener('click', e => {
              const btn = e.target.closest('button[data-quick]');
              if (!btn) return;
              loadFiles(btn.dataset.quick);
            });

            // ----- Breadcrumb nav -----
            document.getElementById('breadcrumb').addEventListener('click', e => {
              const link = e.target.closest('a[data-path]');
              if (!link) return;
              loadFiles(link.dataset.path);
            });

            // ----- New folder -----
            document.getElementById('newfolder-btn').addEventListener('click', async () => {
              const name = await promptModal('New folder name', '');
              if (!name) return;
              const res = await fetch('/folders', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ path: currentPath, name: name })
              });
              if (!res.ok) { alert('Could not create folder'); return; }
              loadFiles();
            });

            // ----- Refresh -----
            document.getElementById('refresh-btn').addEventListener('click', () => loadFiles());

            // ----- Drag & drop / upload -----
            const zone = document.getElementById('drop-zone');
            zone.addEventListener('dragover', e => { e.preventDefault(); zone.classList.add('hover'); });
            zone.addEventListener('dragleave', () => zone.classList.remove('hover'));
            zone.addEventListener('drop', e => {
              e.preventDefault();
              zone.classList.remove('hover');
              uploadFiles(e.dataTransfer.files);
            });
            document.getElementById('upload-btn').addEventListener('click', () => document.getElementById('file-input').click());
            document.getElementById('file-input').addEventListener('change', e => uploadFiles(e.target.files));

            async function uploadFiles(files) {
              enqueueUploads(Array.from(files || []), currentPath || DEFAULT_UPLOAD_PATH);
            }

            const MAX_CONCURRENT_UPLOADS = 3;
            const LIST_REFRESH_MS = 2500;
            let pendingUploads = [];
            let activeUploadCount = 0;
            let uploadBatchTotal = 0;
            let uploadBatchDone = 0;
            let listRefreshTimer = null;

            function scheduleRefreshFileList() {
              const targetPath = currentPath || DEFAULT_UPLOAD_PATH;
              if (listRefreshTimer) clearTimeout(listRefreshTimer);
              listRefreshTimer = setTimeout(() => {
                listRefreshTimer = null;
                loadFiles(targetPath);
              }, LIST_REFRESH_MS);
            }

            function updateUploadProgressUI() {
              const bar = document.getElementById('progress-bar');
              const fill = document.getElementById('progress-fill');
              const status = document.getElementById('status');
              if (!bar || !fill || !status) return;
              const active = activeUploadCount + pendingUploads.length;
              if (active === 0 && uploadBatchTotal === 0) {
                setTimeout(() => {
                  if (activeUploadCount === 0 && pendingUploads.length === 0) {
                    bar.style.display = 'none';
                    fill.style.width = '0%';
                    status.textContent = '';
                  }
                }, 3000);
                return;
              }
              bar.style.display = 'block';
              const pct = uploadBatchTotal > 0 ? (uploadBatchDone / uploadBatchTotal) * 100 : 0;
              fill.style.width = pct + '%';
              status.textContent = 'Uploading… ' + uploadBatchDone + '/' + uploadBatchTotal
                + (pendingUploads.length ? ' (' + pendingUploads.length + ' queued)' : '');
            }

            function enqueueUploads(fileList, targetPath) {
              if (!fileList || !fileList.length) return;
              noteLocalOp();
              for (let i = 0; i < fileList.length; i++) {
                pendingUploads.push({ file: fileList[i], targetPath: targetPath });
              }
              uploadBatchTotal += fileList.length;
              document.getElementById('progress-bar').style.display = 'block';
              updateUploadProgressUI();
              pumpUploadQueue();
            }

            function pumpUploadQueue() {
              while (activeUploadCount < MAX_CONCURRENT_UPLOADS && pendingUploads.length > 0) {
                const job = pendingUploads.shift();
                activeUploadCount++;
                uploadOneFile(job.file, job.targetPath).finally(() => {
                  activeUploadCount--;
                  uploadBatchDone++;
                  updateUploadProgressUI();
                  if ((currentPath || DEFAULT_UPLOAD_PATH) === job.targetPath) {
                    scheduleRefreshFileList();
                  }
                  if (pendingUploads.length === 0 && activeUploadCount === 0) {
                    uploadBatchTotal = 0;
                    uploadBatchDone = 0;
                    loadFiles();
                    refreshStats();
                    toast('Upload batch complete → ' + job.targetPath, 'success');
                  }
                  pumpUploadQueue();
                });
              }
            }

            function uploadOneFile(file, targetPath) {
              return new Promise(resolve => {
                const fd = new FormData();
                fd.append('files[]', file, file.name);
                const xhr = new XMLHttpRequest();
                xhr.onload = () => resolve();
                xhr.onerror = () => resolve();
                xhr.open('POST', '/upload?path=' + encodeURIComponent(targetPath));
                xhr.send(fd);
              });
            }

            // ----- Dashboard stats -----
            async function refreshStats() {
              try {
                const res = await fetch('/stats');
                if (!res.ok) return;
                const s = await res.json();
                document.getElementById('stat-disk-used').textContent = fmtSize(s.usedDiskBytes);
                document.getElementById('stat-disk-sub').textContent =
                  'of ' + fmtSize(s.totalDiskBytes) + ' total · ' + fmtSize(s.freeDiskBytes) + ' free';
                const pct = s.totalDiskBytes > 0
                  ? Math.min(100, (s.usedDiskBytes / s.totalDiskBytes) * 100)
                  : 0;
                document.getElementById('stat-disk-fill').style.width = pct.toFixed(1) + '%';

                let librarySize = 0;
                let libraryCount = 0;
                (s.directories || []).forEach(d => {
                  librarySize += (d.sizeBytes || 0);
                  libraryCount += (d.fileCount || 0);
                });
                document.getElementById('stat-library-size').textContent = fmtSize(librarySize);
                document.getElementById('stat-library-count').textContent =
                  libraryCount + ' file' + (libraryCount === 1 ? '' : 's') + ' across '
                  + (s.directories || []).length + ' categories';

                document.getElementById('stat-uptime').textContent = fmtUptime(s.uptimeSeconds || 0);
                document.getElementById('stat-version').textContent =
                  'Provenance ' + (s.appVersion || '?') + ' (' + (s.buildNumber || '?') + ')';

                const httpURL = s.serverURL || ('http://' + (s.ipAddress || '?') + ':' + s.httpPort + '/');
                document.getElementById('server-url').textContent = httpURL;

                // Refresh QR if the visible URL changed (cache-busts).
                const qr = document.getElementById('qr-img');
                if (qr) qr.src = '/qr.png?text=' + encodeURIComponent(httpURL);
              } catch (e) {
                // Silent — dashboard is non-critical.
                console.warn('stats fetch failed', e);
              }
            }

            document.getElementById('copy-url-btn').addEventListener('click', async () => {
              const text = document.getElementById('server-url').textContent.trim();
              if (!text || text === '—') return;
              try {
                await navigator.clipboard.writeText(text);
                toast('Copied: ' + text, 'success');
              } catch {
                toast('Copy failed — long-press the URL instead', 'error');
              }
            });

            // Periodic dashboard refresh so disk/uptime stay live without page reload.
            setInterval(refreshStats, 15000);
            refreshStats();

            // ----- Server-Sent Events (real-time file activity) -----
            //
            // Every connected browser opens an EventSource on /events. Each
            // mutating route on the server broadcasts a typed event after the
            // op succeeds. We refresh the file listing when the event touches
            // the current folder, refresh the dashboard for any file op, and
            // show a toast when the event came from someone else.
            let liveEventSource = null;
            let lastLocalOp = 0;        // ms timestamp of the most recent local op
            let refreshTimer = null;    // debounce timer for file-list refresh

            function noteLocalOp() { lastLocalOp = Date.now(); }

            // Wrap our own toast-bearing actions so we know not to re-toast
            // events that originated from this browser.
            ['deletePath','renamePath','uploadFiles','bulkDeleteAction'].forEach(fn => {
              if (typeof window[fn] !== 'function') return;
              const orig = window[fn];
              window[fn] = function() { noteLocalOp(); return orig.apply(this, arguments); };
            });

            function scheduleListRefresh() {
              if (refreshTimer) clearTimeout(refreshTimer);
              refreshTimer = setTimeout(() => {
                refreshTimer = null;
                loadFiles();
              }, 250);
            }

            function pathInsideCurrentDir(eventPath) {
              // Server returns paths relative to browseRoot; current dir is
              // also relative. Match dirname == currentPath (or both root).
              const norm = (eventPath || '').replace(/^\\/+/, '').replace(/\\/+$/, '');
              const lastSlash = norm.lastIndexOf('/');
              const parent = lastSlash >= 0 ? norm.slice(0, lastSlash) : '';
              return parent === (currentPath || '');
            }

            function connectLiveEvents() {
              if (typeof EventSource === 'undefined') return;
              try { liveEventSource && liveEventSource.close(); } catch {}
              const es = new EventSource('/events');
              liveEventSource = es;

              const handle = (kind) => (e) => {
                let data = {};
                try { data = JSON.parse(e.data || '{}'); } catch {}
                const isLocal = (Date.now() - lastLocalOp) < 800; // assume our own op

                if (pathInsideCurrentDir(data.path)) {
                  scheduleListRefresh();
                }
                refreshStats();

                if (!isLocal) {
                  const name = data.name || data.path || '';
                  if (kind === 'upload')      toast('📥 New upload: ' + name, 'info', 2400);
                  else if (kind === 'delete') toast('🗑 Removed: ' + name, 'info', 2200);
                  else if (kind === 'rename') toast('✎ Renamed → ' + name, 'info', 2200);
                  else if (kind === 'folder') toast('📁 New folder: ' + name, 'info', 2200);
                }
              };
              es.addEventListener('upload', handle('upload'));
              es.addEventListener('delete', handle('delete'));
              es.addEventListener('rename', handle('rename'));
              es.addEventListener('folder', handle('folder'));
              es.addEventListener('hello',  () => console.log('[SSE] connected'));

              es.onerror = () => {
                // Browser EventSource auto-reconnects per `retry:` hint.
                console.warn('[SSE] dropped; auto-reconnecting…');
              };
            }
            connectLiveEvents();

            // Initial load — start at the default upload path (matches GCDWebUploader behaviour).
            loadFiles(DEFAULT_UPLOAD_PATH);
          </script>
        </body>
        </html>
        """
    }
}
