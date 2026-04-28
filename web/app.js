const hostResource = location.hostname.startsWith('cfx-nui-')
  ? location.hostname.replace('cfx-nui-', '')
  : null;
const isNui = typeof GetParentResourceName === 'function' || hostResource !== null;
const isDemo = !isNui && new URLSearchParams(location.search).has('demo');
const resourceName = typeof GetParentResourceName === 'function'
  ? GetParentResourceName()
  : hostResource || 'nd_multijob';
const root = document.getElementById('multijob-root');

document.documentElement.style.background = 'transparent';
document.body.style.background = 'transparent';
document.body.classList.remove('demo');

const mockJobs = [
  { id: 'police', name: 'Los Santos Police', short: 'LSPD', rank: 'Sergeant', grade: 2, salary: 4200, icon: 'shield-halved' },
  { id: 'ambulance', name: 'San Andreas Medical', short: 'EMS', rank: 'Paramedic', grade: 1, salary: 3800, icon: 'truck-medical' },
  { id: 'mechanic', name: 'Hayes Auto', short: 'HAYES', rank: 'Technician', grade: 1, salary: 2600, icon: 'wrench' },
  { id: 'taxi', name: 'Downtown Cab Co.', short: 'TAXI', rank: 'Driver', grade: 0, salary: 1900, icon: 'taxi' },
  { id: 'realestate', name: 'Dynasty 8', short: 'D8', rank: 'Agent', grade: 0, salary: 2100, icon: 'house' }
];

const accents = ['#f2f3f5', '#c8ccd1', '#9aa0a8', '#6b7079', '#d4ccc0', '#b8c2cc'];
const iconStyles = ['none', 'outline', 'initials', 'chevrons', 'number', 'swatch'];

let state = {
  open: false,
  active: 'police',
  onDuty: true,
  current: null,
  confirmingLeave: false,
  jobs: mockJobs,
  maxJobs: 5,
  singleJobMode: false,
  settings: {
    accent: '#c8ccd1',
    radius: 12,
    scale: 0.85,
    iconStyle: 'outline',
    showLeave: true,
    showPay: true
  },
  position: loadDemoPosition()
};

let panel;
let drag;

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  }[char]));
}

function money(value) {
  return `$${Number(value || 0).toLocaleString()}`;
}

function rgba(hex, alpha) {
  const clean = String(hex || '#c8ccd1').replace('#', '');
  const value = clean.length === 3
    ? clean.split('').map(char => char + char).join('')
    : clean.padEnd(6, '0').slice(0, 6);

  const int = Number.parseInt(value, 16);
  const r = (int >> 16) & 255;
  const g = (int >> 8) & 255;
  const b = int & 255;

  return `rgba(${r},${g},${b},${alpha})`;
}

function activeJob() {
  return state.jobs.find(job => job.id === state.active) || state.current || {
    id: 'unemployed',
    name: 'Unemployed',
    short: 'CIV',
    rank: 'Civilian',
    salary: 0,
    icon: 'briefcase'
  };
}

function fa(name) {
  return `<i class="fa-solid fa-${esc(name)}" aria-hidden="true"></i>`;
}

function jobIcon(job, index, large = false) {
  const style = state.settings.iconStyle || 'outline';
  if (style === 'none') return '';

  if (style === 'initials') {
    return `<span class="mj-icon mj-icon-box mj-icon-initials">${esc(job.short || job.id)}</span>`;
  }

  if (style === 'number') {
    return `<span class="mj-icon mj-icon-box mj-icon-number">${String(index + 1).padStart(2, '0')}</span>`;
  }

  if (style === 'swatch') {
    return `<span class="mj-icon mj-icon-box mj-icon-swatch"><span style="background:var(--accent)"></span></span>`;
  }

  if (style === 'chevrons') {
    const count = Math.max(1, Math.min(3, Number(job.grade || 0) + 1));
    return `<span class="mj-icon mj-icon-box"><span class="mj-chevrons">${Array.from({ length: count }, () => fa('chevron-right')).join('')}</span></span>`;
  }

  const sizeClass = large ? ' mj-icon-large' : '';
  return `<span class="mj-icon mj-icon-box${sizeClass}">${fa(job.icon || 'briefcase')}</span>`;
}

function renderJobRow(job, index) {
  return `
    <button class="mj-row" data-switch="${esc(job.id)}">
      ${jobIcon(job, index)}
      <span class="mj-copy">
        <span class="mj-title">${esc(job.name)}</span><span class="mj-sub">${esc(job.rank)}</span>
      </span>
      <span class="mj-chevron">${fa('chevron-right')}</span>
    </button>
  `;
}

function renderPanel() {
  if (isNui && !state.open) {
    panel = null;
    root.innerHTML = '';
    root.style.display = 'none';
    return;
  }

  root.style.display = 'block';

  const active = activeJob();
  const rows = state.jobs.filter(job => job.id !== active.id);
  const settings = state.settings;
  const showSwitch = !state.singleJobMode && state.maxJobs > 1;
  const showLeave = settings.showLeave !== false;
  const showPay = settings.showPay !== false;

  const accent = settings.accent || '#c8ccd1';

  root.style.setProperty('--accent', accent);
  root.style.setProperty('--accent-soft', rgba(accent, 0.14));
  root.style.setProperty('--accent-border', rgba(accent, 0.26));
  root.style.setProperty('--radius', `${Math.max(0, Math.min(20, settings.radius ?? 12))}px`);
  root.style.setProperty('--scale', Math.max(0.5, Math.min(1.2, settings.scale ?? 0.85)));

  root.innerHTML = `
    <section class="mj-panel ${state.open ? 'is-open' : ''}" aria-label="Multijob menu">
      <header class="mj-header">
        <span class="mj-brand">
          <span class="mj-grip">${'<span></span>'.repeat(6)}</span>
          <span class="mj-label">JOBS</span>
        </span>
      </header>

      <div class="mj-active">
        <div class="mj-active-main">
          ${jobIcon(active, 0, true)}
          <div class="mj-copy">
            <div class="mj-eyebrow">Grade: ${esc(active.rank)}</div>
            <div class="mj-title">${esc(active.name)}</div>
          </div>
          ${showPay ? `<div class="mj-pay">${money(active.salary)}</div>` : ''}
        </div>
        <div class="mj-actions">
          <button class="mj-button mj-duty ${state.onDuty ? 'is-on' : ''}" data-duty>
            <span class="mj-duty-dot"></span>
            ${state.onDuty ? 'On Duty' : 'Off Duty'}
          </button>
          ${showLeave ? `<button class="mj-button mj-leave" data-leave title="Leave job" aria-label="Leave job">${fa('right-from-bracket')}</button>` : ''}
        </div>
      </div>

      ${showSwitch ? `<div class="mj-section">
        <div class="mj-section-title">Switch to</div>
        <div class="mj-list">
          ${rows.length ? rows.map(renderJobRow).join('') : '<div class="mj-empty">No other jobs available.</div>'}
        </div>
      </div>` : ''}

      <footer class="mj-footer">
        <span>${state.jobs.length}/${state.maxJobs} jobs</span>
      </footer>
      ${renderConfirm()}
    </section>
    ${renderDevPanel()}
  `;

  panel = root.querySelector('.mj-panel');
  bindPanel();
  applyPosition();
}

function renderConfirm() {
  if (!state.confirmingLeave || state.settings.showLeave === false) return '';
  const active = activeJob();

  return `
    <div class="mj-confirm" role="dialog" aria-modal="true">
      <div class="mj-confirm-card">
        <div class="mj-confirm-title">Leave ${esc(active.name)}?</div>
        <div class="mj-confirm-sub">This removes the job from your list.</div>
        <div class="mj-confirm-actions">
          <button data-confirm-cancel>Cancel</button>
          <button data-confirm-leave>Leave</button>
        </div>
      </div>
    </div>
  `;
}

function renderDevPanel() {
  if (!isDemo) return '';

  return `
    <aside class="mj-dev">
      <label>Open <input type="checkbox" data-dev="open" ${state.open ? 'checked' : ''}></label>
      <label>Icon style
        <select data-dev="iconStyle">${iconStyles.map(value => `<option value="${value}" ${state.settings.iconStyle === value ? 'selected' : ''}>${value}</option>`).join('')}</select>
      </label>
      <label>Radius <input type="range" min="0" max="20" value="${state.settings.radius}" data-dev="radius"></label>
      <label>Scale <input type="range" min="0.5" max="1.2" step="0.01" value="${state.settings.scale}" data-dev="scale"></label>
      <div class="mj-presets">${accents.map(color => `<button class="mj-preset" data-accent="${color}" style="background:${color}" title="${color}"></button>`).join('')}</div>
    </aside>
  `;
}

function bindPanel() {
  const header = root.querySelector('.mj-header');
  header.addEventListener('pointerdown', startDrag);

  root.querySelector('[data-duty]').addEventListener('click', () => {
    if (!isNui) {
      state.onDuty = !state.onDuty;
      renderPanel();
      pulseDuty();
      return;
    }

    pulseDuty();
    post('toggleDuty');
  });

  root.querySelector('[data-leave]')?.addEventListener('click', () => {
    state.confirmingLeave = true;
    renderPanel();
  });

  root.querySelector('[data-confirm-cancel]')?.addEventListener('click', () => {
    state.confirmingLeave = false;
    renderPanel();
  });

  root.querySelector('[data-confirm-leave]')?.addEventListener('click', () => {
    state.confirmingLeave = false;

    if (!isNui) {
      state.jobs = state.jobs.filter(job => job.id !== state.active);
      state.active = state.jobs[0]?.id || 'unemployed';
      renderPanel();
      return;
    }

    post('leaveJob');
    renderPanel();
  });

  root.querySelectorAll('[data-switch]').forEach(button => {
    button.addEventListener('click', () => {
      const id = button.dataset.switch;
      if (!isNui) {
        state.active = id;
        state.onDuty = false;
        renderPanel();
        return;
      }

      post('switchJob', { id });
    });
  });

  root.querySelectorAll('[data-dev]').forEach(input => {
    input.addEventListener('input', () => updateDev(input));
    input.addEventListener('change', () => updateDev(input));
  });

  root.querySelectorAll('[data-accent]').forEach(button => {
    button.addEventListener('click', () => {
      state.settings.accent = button.dataset.accent;
      renderPanel();
    });
  });
}

function pulseDuty() {
  const btn = root.querySelector('[data-duty]');
  if (!btn) return;
  btn.classList.remove('is-pulsing');
  void btn.offsetWidth;
  btn.classList.add('is-pulsing');
}

function updateDev(input) {
  const key = input.dataset.dev;

  if (key === 'open') {
    state.open = input.checked;
  } else if (key === 'iconStyle') {
    state.settings.iconStyle = input.value;
  } else {
    state.settings[key] = Number(input.value);
  }

  renderPanel();
}

function startDrag(event) {
  if (event.button !== 0) return;

  const position = state.position || defaultPosition();
  drag = {
    pointerId: event.pointerId,
    startX: event.clientX,
    startY: event.clientY,
    x: position.x,
    y: position.y
  };

  panel.classList.add('is-dragging');
  event.currentTarget.classList.add('is-dragging');
  event.currentTarget.setPointerCapture(event.pointerId);

  window.addEventListener('pointermove', moveDrag);
  window.addEventListener('pointerup', stopDrag, { once: true });
}

function moveDrag(event) {
  if (!drag) return;

  const rect = root.getBoundingClientRect();
  const zoomX = rect.width / root.offsetWidth || 1;
  const zoomY = rect.height / root.offsetHeight || zoomX;

  const next = clampPosition({
    x: drag.x + (event.clientX - drag.startX) / zoomX,
    y: drag.y + (event.clientY - drag.startY) / zoomY
  });

  state.position = next;
  applyPosition();
}

function stopDrag() {
  drag = null;
  window.removeEventListener('pointermove', moveDrag);
  persistPosition(state.position);
  panel?.classList.remove('is-dragging');
  root.querySelector('.mj-header')?.classList.remove('is-dragging');
}

function defaultPosition() {
  const scale = Number(state.settings.scale || 0.85);
  const height = panel ? panel.offsetHeight * scale : 320;

  return {
    x: 24,
    y: Math.max(24, root.offsetHeight - height - 24)
  };
}

function clampPosition(position) {
  const scale = Number(state.settings.scale || 0.85);
  const width = panel ? panel.offsetWidth * scale : 320 * scale;
  const height = panel ? panel.offsetHeight * scale : 260 * scale;
  const maxX = Math.max(0, root.offsetWidth - width);
  const maxY = Math.max(0, root.offsetHeight - height);

  return {
    x: Math.min(Math.max(0, position.x), maxX),
    y: Math.min(Math.max(0, position.y), maxY)
  };
}

function applyPosition() {
  if (!panel) return;

  if (!state.position) {
    state.position = defaultPosition();
  }

  state.position = clampPosition(state.position);
  panel.style.left = `${state.position.x}px`;
  panel.style.top = `${state.position.y}px`;
}

function loadDemoPosition() {
  if (!isDemo) return null;

  try {
    return JSON.parse(localStorage.getItem('nd_multijob_position'));
  } catch {
    return null;
  }
}

function persistPosition(position) {
  if (!position) return;

  if (isNui) {
    post('savePosition', {
      x: Math.round(position.x),
      y: Math.round(position.y)
    });
    return;
  }

  if (isDemo) {
    localStorage.setItem('nd_multijob_position', JSON.stringify(position));
  }
}

function post(name, data = {}) {
  return fetch(`https://${resourceName}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  }).catch(() => {});
}

function applyPayload(payload) {
  state.jobs = Array.isArray(payload.jobs) ? payload.jobs : [];
  state.active = payload.active || state.jobs[0]?.id || 'unemployed';
  state.onDuty = payload.onDuty === true;
  state.current = payload.current || null;
  state.maxJobs = Number(payload.maxJobs) || state.maxJobs;
  state.singleJobMode = payload.singleJobMode === true || state.maxJobs <= 1;
  state.settings = { ...state.settings, ...(payload.settings || {}) };
  if (state.settings.showLeave === false) {
    state.confirmingLeave = false;
  }
  renderPanel();
}

window.addEventListener('message', event => {
  const data = event.data || {};

  if (data.action === 'setOpen') {
    state.open = data.open === true;
    if (!state.open) state.confirmingLeave = false;
    renderPanel();
  }

  if (data.action === 'setData') {
    applyPayload(data.payload || {});
  }

  if (data.action === 'setPosition') {
    state.position = data.position || null;
    renderPanel();
  }
});

window.addEventListener('keydown', event => {
  if (event.key === 'Escape') {
    if (state.confirmingLeave) {
      state.confirmingLeave = false;
      renderPanel();
      return;
    }
    if (isNui) post('close');
    state.open = false;
    renderPanel();
    return;
  }

  if (event.key === 'F6') {
    if (isNui) {
      post('close');
      state.open = false;
      renderPanel();
    } else if (isDemo) {
      state.open = !state.open;
      renderPanel();
    }
  }
});

window.addEventListener('resize', () => {
  state.position = state.position && clampPosition(state.position);
  renderPanel();
});

if (isDemo) {
  document.body.classList.add('demo');
}

renderPanel();

if (isNui) {
  post('ready');
}
