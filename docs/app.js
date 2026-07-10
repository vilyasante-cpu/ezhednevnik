/**
 * Ежедневник — read-only SPA
 */

const TITLES = {
  today: 'Сегодня',
  calendar: 'Календарь',
  projects: 'Проекты',
  notes: 'Заметки',
};

const DOW = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
const DOW_FULL = ['воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота'];
const MONTHS = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const MONTHS_NOM = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

const state = {
  data: null,
  view: 'today',
  search: '',
  calMode: 'week',
  calAnchor: startOfDay(new Date()),
  projectFilter: 'all',
};

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

/* ── Date helpers ── */

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function parseRuDate(str) {
  if (!str || str.includes('ГГГГ') || str.startsWith('[')) return null;
  const clean = str.replace(/^~/, '').trim();
  const m = clean.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/);
  if (!m) return null;
  return new Date(+m[3], +m[2] - 1, +m[1]);
}

function sameDay(a, b) {
  return a.getFullYear() === b.getFullYear()
    && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate();
}

function addDays(d, n) {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

function startOfWeek(d) {
  const x = startOfDay(d);
  const day = x.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  return addDays(x, diff);
}

function formatRuDate(d) {
  return `${d.getDate().toString().padStart(2, '0')}.${(d.getMonth() + 1).toString().padStart(2, '0')}.${d.getFullYear()}`;
}

function formatPageDate(d) {
  return `${d.getDate()} ${MONTHS[d.getMonth()]}, ${DOW_FULL[d.getDay()]}`;
}

function isTemplateEvent(e) {
  return !e.date || e.date.includes('ГГГГ') || e.client?.startsWith('[');
}

/* ── Data processing ── */

function normalizeData(raw) {
  const events = [];
  const deadlines = [];

  for (const cal of raw.calendars || []) {
    for (const e of cal.events || []) {
      if (isTemplateEvent(e)) continue;
      events.push({ ...e, domain: cal.domain, source: 'event' });
    }
    for (const d of cal.deadlines || []) {
      deadlines.push({ ...d, domain: cal.domain, source: 'deadline' });
    }
  }

  const clients = (raw.clients || []).map((c) => ({
    ...c,
    tasks: c.tasks || [],
    highCount: c.tasks.filter((t) => /высок/i.test(t.priority)).length,
    activeCount: c.tasks.filter((t) => /выполнению|в работе/i.test(t.status)).length,
    doneCount: c.tasks.filter((t) => /выполн|закрыт|готов/i.test(t.status)).length,
  }));

  return { ...raw, events, deadlines, clients };
}

function allTasks(data) {
  return data.clients.flatMap((c) =>
    c.tasks.map((t) => ({ ...t, clientName: c.name, domain: c.domain, clientPath: c.path }))
  );
}

function priorityClass(p) {
  if (/высок/i.test(p)) return 'high';
  if (/низк/i.test(p)) return 'low';
  return 'mid';
}

function domainBadge(domain) {
  const cls = domain?.toLowerCase() === 'provance' ? 'provance' : '3d';
  return `<span class="badge badge--${cls}">${esc(domain || '3D')}</span>`;
}

function priorityBadge(p) {
  const cls = priorityClass(p);
  const labels = { high: 'Высокий', mid: 'Средний', low: 'Низкий' };
  return `<span class="badge badge--${cls}">${labels[cls]}</span>`;
}

function esc(s) {
  const d = document.createElement('div');
  d.textContent = s ?? '';
  return d.innerHTML;
}

function matchesSearch(text, q) {
  return !q || (text || '').toLowerCase().includes(q.toLowerCase());
}

function filterBySearch(items, q, keys) {
  if (!q) return items;
  return items.filter((item) =>
    keys.some((k) => matchesSearch(typeof k === 'function' ? k(item) : item[k], q))
  );
}

/* ── Render helpers ── */

function renderTaskItem(task, opts = {}) {
  const stripe = opts.stripe || `stripe--${task.domain?.toLowerCase() === 'provance' ? 'provance' : '3d'}`;
  return `
    <li class="list-item" data-client="${esc(task.clientName)}" role="button" tabindex="0">
      <div class="list-item__stripe ${stripe}"></div>
      <div class="list-item__main">
        <p class="list-item__title">${esc(task.title)}</p>
        <div class="list-item__meta">
          ${priorityBadge(task.priority)}
          <span>${esc(task.clientName)}</span>
          <span>${esc(task.status)}</span>
          ${task.assignee && task.assignee !== '—' ? `<span>→ ${esc(task.assignee)}</span>` : ''}
        </div>
      </div>
      <div class="list-item__aside">${esc(task.id)}</div>
    </li>`;
}

function renderEventItem(e) {
  const isReminder = /напомин/i.test(e.type);
  const chipClass = e.source === 'deadline' ? 'event-chip--deadline'
    : isReminder ? 'event-chip--reminder' : '';
  const title = e.title || e.event;
  return `
    <div class="event-chip ${chipClass}" data-client="${esc(e.client)}" role="button" tabindex="0">
      <div class="event-chip__client">${esc(e.client)}${e.time ? ` · ${esc(e.time)}` : ''}</div>
      <div class="event-chip__title">${esc(title)}</div>
    </div>`;
}

/* ── Views ── */

function renderToday(data) {
  const today = startOfDay(new Date());
  const q = state.search;

  const todayEvents = filterBySearch(
    data.events.filter((e) => { const d = parseRuDate(e.date); return d && sameDay(d, today); }),
    q, ['client', 'title', 'type']
  );

  const upcomingEvents = filterBySearch(
    data.events
      .map((e) => ({ ...e, _d: parseRuDate(e.date) }))
      .filter((e) => e._d && e._d >= today)
      .sort((a, b) => a._d - b._d),
    q, ['client', 'title']
  ).slice(0, 8);

  const highTasks = filterBySearch(
    allTasks(data).filter((t) => /высок/i.test(t.priority) && !/выполн|закрыт|готов/i.test(t.status)),
    q, ['title', 'clientName', 'id']
  ).slice(0, 12);

  const overdue = filterBySearch(
    data.deadlines.filter((d) => /просроч/i.test(d.status)),
    q, ['client', 'event']
  );

  const activeTasks = allTasks(data).filter((t) => /выполнению|в работе/i.test(t.status)).length;

  return `
    <div class="stack">
      <div class="stat-row">
        <div class="stat-pill stat-pill--lavender">
          <div class="stat-pill__value">${data.stats.clients}</div>
          <div class="stat-pill__label">клиентов</div>
        </div>
        <div class="stat-pill stat-pill--sage">
          <div class="stat-pill__value">${activeTasks}</div>
          <div class="stat-pill__label">в работе</div>
        </div>
        <div class="stat-pill stat-pill--sky">
          <div class="stat-pill__value">${upcomingEvents.length}</div>
          <div class="stat-pill__label">предстоящих</div>
        </div>
        <div class="stat-pill stat-pill--peach">
          <div class="stat-pill__value">${overdue.length}</div>
          <div class="stat-pill__label">просрочено</div>
        </div>
      </div>

      <div class="grid-2">
        <div class="stack">
          <div class="card">
            <div class="card__header">
              <h2 class="card__title">Сегодня</h2>
              <span class="badge badge--event">${formatRuDate(today)}</span>
            </div>
            <div class="card__body--flush">
              <ul class="list">
                ${todayEvents.length
                  ? todayEvents.map((e) => `<li class="list-item" style="cursor:default">
                      <div class="list-item__stripe stripe--lavender"></div>
                      <div class="list-item__main">
                        <p class="list-item__title">${esc(e.title)}</p>
                        <div class="list-item__meta">
                          <span class="badge badge--reminder">${esc(e.type)}</span>
                          <span>${esc(e.client)}</span>
                        </div>
                      </div>
                    </li>`).join('')
                  : '<li class="empty">На сегодня событий нет — день свободен</li>'}
              </ul>
            </div>
          </div>

          <div class="card">
            <div class="card__header">
              <h2 class="card__title">Ближайшие события</h2>
            </div>
            <div class="card__body--flush">
              <ul class="list">
                ${upcomingEvents.length
                  ? upcomingEvents.map((e) => `<li class="list-item" data-client="${esc(e.client)}" role="button" tabindex="0">
                      <div class="list-item__stripe stripe--peach"></div>
                      <div class="list-item__main">
                        <p class="list-item__title">${esc(e.title)}</p>
                        <div class="list-item__meta">
                          <span>${esc(e.date)}</span>
                          <span>${esc(e.client)}</span>
                          ${domainBadge(e.domain)}
                        </div>
                      </div>
                    </li>`).join('')
                  : '<li class="empty">Нет запланированных событий</li>'}
              </ul>
            </div>
          </div>
        </div>

        <div class="stack">
          <div class="card">
            <div class="card__header">
              <h2 class="card__title">Приоритетные задачи</h2>
            </div>
            <div class="card__body--flush">
              <ul class="list" id="priority-list">
                ${highTasks.length
                  ? highTasks.map((t) => renderTaskItem(t)).join('')
                  : '<li class="empty">Нет задач с высоким приоритетом</li>'}
              </ul>
            </div>
          </div>

          ${overdue.length ? `
          <div class="card">
            <div class="card__header">
              <h2 class="card__title">Просроченные дедлайны</h2>
            </div>
            <div class="card__body--flush">
              <ul class="list">
                ${overdue.map((d) => `
                  <li class="list-item" data-client="${esc(d.client)}" role="button" tabindex="0">
                    <div class="list-item__stripe stripe--peach"></div>
                    <div class="list-item__main">
                      <p class="list-item__title">${esc(d.event)}</p>
                      <div class="list-item__meta">
                        <span class="badge badge--overdue">${esc(d.status)}</span>
                        <span>${esc(d.client)}</span>
                        <span>${esc(d.date)}</span>
                      </div>
                    </div>
                  </li>`).join('')}
              </ul>
            </div>
          </div>` : ''}
        </div>
      </div>
    </div>`;
}

function renderCalendar(data) {
  const anchor = state.calAnchor;
  const mode = state.calMode;

  if (mode === 'week') {
    const weekStart = startOfWeek(anchor);
    const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
    const today = startOfDay(new Date());

    const weekEnd = addDays(weekStart, 6);
    const periodLabel = `${weekStart.getDate()}–${weekEnd.getDate()} ${MONTHS[weekEnd.getMonth()]} ${weekEnd.getFullYear()}`;

    return `
      <div class="cal-toolbar">
        <div class="cal-nav">
          <button type="button" id="cal-prev" aria-label="Назад">‹</button>
          <span class="cal-period">${periodLabel}</span>
          <button type="button" id="cal-next" aria-label="Вперёд">›</button>
          <button type="button" id="cal-today" style="margin-left:8px;padding:0 14px;width:auto;font-size:0.82rem">Сегодня</button>
        </div>
        <div class="toggle-group" id="cal-mode-toggle">
          <button type="button" data-mode="week" class="is-active">Неделя</button>
          <button type="button" data-mode="month">Месяц</button>
        </div>
      </div>
      <div class="week-grid">
        ${days.map((day) => {
          const dayEvents = data.events.filter((e) => {
            const d = parseRuDate(e.date);
            return d && sameDay(d, day);
          });
          const dayDeadlines = data.deadlines.filter((d) => {
            const dt = parseRuDate(d.date);
            return dt && sameDay(dt, day);
          });
          const chips = [
            ...dayEvents.map(renderEventItem),
            ...dayDeadlines.map((d) => renderEventItem({ ...d, title: d.event, source: 'deadline' })),
          ].join('');
          return `
            <div class="day-col ${sameDay(day, today) ? 'is-today' : ''}">
              <div class="day-col__head">
                <div class="day-col__dow">${DOW[day.getDay()]}</div>
                <div class="day-col__num">${day.getDate()}</div>
              </div>
              <div class="day-col__body">
                ${chips || '<span style="font-size:0.72rem;color:var(--text-muted);padding:4px">—</span>'}
              </div>
            </div>`;
        }).join('')}
      </div>`;
  }

  // Month view
  const year = anchor.getFullYear();
  const month = anchor.getMonth();
  const first = new Date(year, month, 1);
  const startPad = first.getDay() === 0 ? 6 : first.getDay() - 1;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const today = startOfDay(new Date());

  const cells = [];
  for (let i = 0; i < startPad; i++) {
    const d = addDays(first, -(startPad - i));
    cells.push({ date: d, other: true });
  }
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ date: new Date(year, month, d), other: false });
  }
  while (cells.length % 7 !== 0) {
    const last = cells[cells.length - 1].date;
    cells.push({ date: addDays(last, 1), other: true });
  }

  return `
    <div class="cal-toolbar">
      <div class="cal-nav">
        <button type="button" id="cal-prev" aria-label="Назад">‹</button>
        <span class="cal-period">${MONTHS_NOM[month]} ${year}</span>
        <button type="button" id="cal-next" aria-label="Вперёд">›</button>
        <button type="button" id="cal-today" style="margin-left:8px;padding:0 14px;width:auto;font-size:0.82rem">Сегодня</button>
      </div>
      <div class="toggle-group" id="cal-mode-toggle">
        <button type="button" data-mode="week">Неделя</button>
        <button type="button" data-mode="month" class="is-active">Месяц</button>
      </div>
    </div>
    <div class="month-grid">
      ${['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) => `<div class="month-dow">${d}</div>`).join('')}
      ${cells.map(({ date, other }) => {
        const evCount = data.events.filter((e) => { const d = parseRuDate(e.date); return d && sameDay(d, date); }).length;
        const dlCount = data.deadlines.filter((d) => { const dt = parseRuDate(d.date); return dt && sameDay(dt, date); }).length;
        const dots = [
          ...Array(Math.min(evCount, 3)).fill('<span class="dot dot--event"></span>'),
          ...Array(Math.min(dlCount, 2)).fill('<span class="dot dot--deadline"></span>'),
        ].join('');
        return `
          <div class="month-cell ${sameDay(date, today) ? 'is-today' : ''} ${other ? 'is-other' : ''}"
               data-date="${formatRuDate(date)}" role="button" tabindex="0">
            <div class="month-cell__num">${date.getDate()}</div>
            <div class="month-cell__dots">${dots}</div>
          </div>`;
      }).join('')}
    </div>`;
}

function renderProjects(data) {
  const q = state.search;
  const f = state.projectFilter;

  let clients = [...data.clients];

  if (f === 'high') clients = clients.filter((c) => c.highCount > 0);
  if (f === 'active') clients = clients.filter((c) => c.activeCount > 0);
  if (f === 'many') clients = clients.filter((c) => c.tasks.length >= 4);

  clients = filterBySearch(clients, q, ['name', (c) => c.tasks.map((t) => t.title).join(' ')]);

  clients.sort((a, b) => b.highCount - a.highCount || b.tasks.length - a.tasks.length);

  const filters = [
    ['all', 'Все'],
    ['high', 'С высоким приоритетом'],
    ['active', 'В работе'],
    ['many', 'Много задач'],
  ];

  return `
    <div class="filters" id="project-filters">
      ${filters.map(([id, label]) => `
        <button type="button" class="filter-btn ${f === id ? 'is-active' : ''}" data-filter="${id}">${label}</button>
      `).join('')}
    </div>
    <div class="project-grid">
      ${clients.length ? clients.map((c) => {
        const total = c.tasks.length;
        const progress = total ? Math.round((c.doneCount / total) * 100) : 0;
        return `
          <article class="project-card" data-client="${esc(c.name)}" role="button" tabindex="0">
            <div class="project-card__top">
              <h3 class="project-card__name">${esc(c.name)}</h3>
              ${domainBadge(c.domain)}
            </div>
            <div class="project-card__counts">
              <span><strong>${total}</strong>задач</span>
              <span><strong>${c.highCount}</strong>высокий</span>
              <span><strong>${c.activeCount}</strong>в работе</span>
            </div>
            <div class="progress-bar" title="${progress}% выполнено">
              <div class="progress-bar__fill" style="width:${progress}%"></div>
            </div>
          </article>`;
      }).join('') : '<p class="empty" style="grid-column:1/-1">Ничего не найдено</p>'}
    </div>`;
}

function renderNotes() {
  return `
    <div class="notes-hero">
      <div class="notes-hero__icon">✎</div>
      <h2>Заметки скоро появятся</h2>
      <p>Раздел для быстрых записей в разработке.<br>Пока все изменения — через чаты Cursor.</p>
    </div>`;
}

function renderDrawer(client) {
  if (!client) return;

  const tasks = client.tasks || [];
  $('#drawer-header').innerHTML = `
    <h2>${esc(client.name)}</h2>
    <div style="display:flex;gap:8px;margin-top:8px">${domainBadge(client.domain)}</div>
  `;

  $('#drawer-body').innerHTML = `
    <div class="drawer__section">
      <h3>Задачи (${tasks.length})</h3>
      ${tasks.length ? `
        <div class="table-wrap">
          <table>
            <thead><tr><th>ID</th><th>Задача</th><th>Приоритет</th><th>Статус</th></tr></thead>
            <tbody>
              ${tasks.map((t) => `
                <tr>
                  <td>${esc(t.id)}</td>
                  <td>${esc(t.title)}</td>
                  <td>${priorityBadge(t.priority)}</td>
                  <td>${esc(t.status)}</td>
                </tr>`).join('')}
            </tbody>
          </table>
        </div>` : '<p class="empty">Задач нет</p>'}
    </div>
    <div class="drawer__section">
      <h3>Исходный файл</h3>
      <div class="drawer__path">${esc(client.path)}</div>
    </div>
  `;
}

/* ── App shell ── */

function render() {
  const data = state.data;
  if (!data) return;

  $('#page-title').textContent = TITLES[state.view];
  $('#page-date').textContent = formatPageDate(new Date());

  const views = {
    today: () => renderToday(data),
    calendar: () => renderCalendar(data),
    projects: () => renderProjects(data),
    notes: () => renderNotes(),
  };

  $('#content').innerHTML = views[state.view]();
  bindViewEvents();
}

function renderSidebarStats(data) {
  const active = allTasks(data).filter((t) => /выполнению|в работе/i.test(t.status)).length;
  $('#sidebar-stats').innerHTML = `
    <strong>${active}</strong>
    задач в работе<br>
    ${data.stats.clients} клиентов · ${data.stats.tasks} всего
  `;
}

function bindViewEvents() {
  // Calendar controls
  $('#cal-prev')?.addEventListener('click', () => {
    state.calAnchor = state.calMode === 'week'
      ? addDays(state.calAnchor, -7)
      : new Date(state.calAnchor.getFullYear(), state.calAnchor.getMonth() - 1, 1);
    render();
  });

  $('#cal-next')?.addEventListener('click', () => {
    state.calAnchor = state.calMode === 'week'
      ? addDays(state.calAnchor, 7)
      : new Date(state.calAnchor.getFullYear(), state.calAnchor.getMonth() + 1, 1);
    render();
  });

  $('#cal-today')?.addEventListener('click', () => {
    state.calAnchor = startOfDay(new Date());
    render();
  });

  $$('#cal-mode-toggle button').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.calMode = btn.dataset.mode;
      render();
    });
  });

  // Project filters
  $$('#project-filters .filter-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.projectFilter = btn.dataset.filter;
      render();
    });
  });

  // Open client drawer
  $$('[data-client]').forEach((el) => {
    const open = () => {
      const name = el.dataset.client;
      const client = state.data.clients.find((c) => c.name === name)
        || state.data.clients.find((c) => name.includes(c.name) || c.name.includes(name));
      if (client) openDrawer(client);
    };
    el.addEventListener('click', open);
    el.addEventListener('keydown', (e) => { if (e.key === 'Enter') open(); });
  });

  // Month cell click → week view
  $$('.month-cell[data-date]').forEach((cell) => {
    cell.addEventListener('click', () => {
      const d = parseRuDate(cell.dataset.date);
      if (d) {
        state.calAnchor = d;
        state.calMode = 'week';
        render();
      }
    });
  });
}

function openDrawer(client) {
  renderDrawer(client);
  $('#overlay').hidden = false;
  requestAnimationFrame(() => $('#overlay').classList.add('is-visible'));
  $('#drawer').classList.add('is-open');
  $('#drawer').setAttribute('aria-hidden', 'false');
}

function closeDrawer() {
  $('#overlay').classList.remove('is-visible');
  $('#drawer').classList.remove('is-open');
  $('#drawer').setAttribute('aria-hidden', 'true');
  setTimeout(() => { $('#overlay').hidden = true; }, 350);
}

function setView(view) {
  state.view = view;
  $$('.nav-item, .bottom-nav__item').forEach((el) => {
    el.classList.toggle('is-active', el.dataset.view === view);
  });
  $('.sidebar')?.classList.remove('is-open');
  render();
}

function showError(msg) {
  $('#content').innerHTML = `
    <div class="error-box">
      <h2>Не удалось загрузить данные</h2>
      <p>${esc(msg)}</p>
      <code>cd web\nnpx --yes serve .\n# или: python -m http.server 8080</code>
    </div>`;
}

async function loadData() {
  const paths = ['data/planner.json', '../data/planner.json'];
  let lastErr;

  for (const path of paths) {
    try {
      const res = await fetch(path);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return normalizeData(await res.json());
    } catch (e) {
      lastErr = e;
    }
  }
  throw lastErr;
}

/* ── Init ── */

async function init() {
  $('#page-date').textContent = formatPageDate(new Date());

  try {
    state.data = await loadData();
    const gen = new Date(state.data.generated_at);
    $('#sync-time').textContent = `Обновлено ${gen.toLocaleString('ru-RU', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}`;
    renderSidebarStats(state.data);
    render();
  } catch (e) {
    showError(e.message || 'Запустите локальный сервер из папки web');
  }

  // Navigation
  $$('[data-view]').forEach((el) => {
    el.addEventListener('click', () => setView(el.dataset.view));
  });

  // Search
  let searchTimer;
  $('#search').addEventListener('input', (e) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      state.search = e.target.value.trim();
      render();
    }, 200);
  });

  // Drawer
  $('#drawer-close').addEventListener('click', closeDrawer);
  $('#overlay').addEventListener('click', closeDrawer);
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeDrawer(); });

  // Mobile menu
  $('#menu-toggle')?.addEventListener('click', () => {
    $('.sidebar').classList.toggle('is-open');
  });
}

init();
