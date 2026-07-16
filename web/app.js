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
  writable: false,
  drawerEvent: null,
  closingEvent: false,
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
  const clean = str.replace(/~~/g, '').replace(/^~/, '').trim();
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

function getNextWeekRange(fromDate = new Date()) {
  const today = startOfDay(fromDate);
  const nextWeekStart = addDays(startOfWeek(today), 7);
  const nextWeekEnd = addDays(nextWeekStart, 6);
  return { start: nextWeekStart, end: nextWeekEnd };
}

function isInDateRange(date, start, end) {
  const d = startOfDay(date);
  return d >= startOfDay(start) && d <= startOfDay(end);
}

function formatWeekRange(start, end) {
  const sameMonth = start.getMonth() === end.getMonth();
  if (sameMonth) {
    return `${start.getDate()}–${end.getDate()} ${MONTHS[end.getMonth()]}`;
  }
  return `${start.getDate()} ${MONTHS[start.getMonth()]} – ${end.getDate()} ${MONTHS[end.getMonth()]}`;
}

function getNextWeekMeetings(data, q) {
  const { start, end } = getNextWeekRange(new Date());
  return filterBySearch(
    data.events
      .map((e) => ({ ...e, _d: parseRuDate(e.date) }))
      .filter((e) => e._d && isInDateRange(e._d, start, end))
      .sort((a, b) => a._d - b._d || (a.time || '').localeCompare(b.time || '')),
    q,
    ['client', 'title', 'type']
  );
}

function renderMeetingCard(e) {
  const closed = isEventClosed(e);
  const title = eventTitle(e);
  const day = parseRuDate(e.date);
  const domainCls = e.domain?.toLowerCase() === 'provance' ? 'meeting-card--provance' : 'meeting-card--3d';
  return `
    <article class="meeting-card ${domainCls} ${closed ? 'is-closed' : ''}" data-event-id="${esc(e.id)}" role="button" tabindex="0">
      <div class="meeting-card__time">${e.time ? esc(e.time) : 'весь день'}</div>
      <div class="meeting-card__body">
        <p class="meeting-card__title">${esc(title)}</p>
        <div class="meeting-card__meta">
          <span>${esc(e.client)}</span>
          ${closed ? '<span class="badge badge--low">Выполнено</span>' : `<span>${esc(e.type || 'Встреча')}</span>`}
        </div>
      </div>
      <div class="meeting-card__date">${day ? `${DOW[day.getDay()]}, ${day.getDate()} ${MONTHS[day.getMonth()]}` : esc(e.date)}</div>
    </article>`;
}

function renderNextWeekMeetingsBlock(meetings, range) {
  const rangeLabel = formatWeekRange(range.start, range.end);

  if (!meetings.length) {
    return `
      <div class="card card--week-meetings">
        <div class="card__header">
          <div>
            <h2 class="card__title">Встречи на следующую неделю</h2>
            <p class="card__subtitle">${rangeLabel}</p>
          </div>
          <span class="badge badge--lavender">0</span>
        </div>
        <div class="week-meetings week-meetings--empty">
          <p>На следующую неделю встреч не запланировано</p>
        </div>
      </div>`;
  }

  const byDay = {};
  meetings.forEach((e) => {
    const key = e.date;
    (byDay[key] = byDay[key] || []).push(e);
  });

  const dayGroups = Object.keys(byDay)
    .sort((a, b) => (parseRuDate(a) || 0) - (parseRuDate(b) || 0))
    .map((dateKey) => {
      const d = parseRuDate(dateKey);
      const label = d
        ? `${DOW_FULL[d.getDay()]}, ${d.getDate()} ${MONTHS[d.getMonth()]}`
        : dateKey;
      return `
        <section class="week-meetings__day">
          <h3 class="week-meetings__day-title">${esc(label)}</h3>
          <div class="week-meetings__list">
            ${byDay[dateKey].map(renderMeetingCard).join('')}
          </div>
        </section>`;
    }).join('');

  return `
    <div class="card card--week-meetings">
      <div class="card__header">
        <div>
          <h2 class="card__title">Встречи на следующую неделю</h2>
          <p class="card__subtitle">${rangeLabel}</p>
        </div>
        <span class="badge badge--lavender">${meetings.length}</span>
      </div>
      <div class="week-meetings">
        ${dayGroups}
      </div>
    </div>`;
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

  let evtIdx = 0;
  let dlIdx = 0;
  for (const cal of raw.calendars || []) {
    for (const e of cal.events || []) {
      if (isTemplateEvent(e)) continue;
      events.push({
        ...e,
        id: `evt-${evtIdx++}`,
        key: e.key || null,
        closed: !!e.closed,
        domain: cal.domain,
        source: 'event',
      });
    }
    for (const d of cal.deadlines || []) {
      deadlines.push({
        ...d,
        id: `dl-${dlIdx++}`,
        key: d.key || null,
        closed: !!d.closed,
        domain: cal.domain,
        source: 'deadline',
      });
    }
  }

  const clients = (raw.clients || []).map((c) => ({
    ...c,
    name: c.name || c.id,
    tasks: c.tasks || [],
    contacts: c.contacts || {},
    project_status: c.project_status || c.status || null,
    deal_stage: c.deal_stage || null,
    profile: normalizeClientProfile(c.profile),
    status: c.project_status || c.status || null,
    path: c.path || '',
    highCount: (c.tasks || []).filter((t) => /высок/i.test(t.priority)).length,
    activeCount: (c.tasks || []).filter((t) => /выполнению|в работе/i.test(t.status)).length,
    doneCount: (c.tasks || []).filter((t) => /выполн|закрыт|готов/i.test(t.status)).length,
  }));

  const hasFullProfiles = !!raw.has_full_profiles;
  return {
    ...raw,
    events,
    deadlines,
    clients,
    sync_report: hasFullProfiles ? raw.sync_report : null,
    isPublic: detectPublicMode(raw),
    hasFullProfiles,
  };
}

function allTasks(data) {
  return data.clients.flatMap((c) =>
    (c.tasks || []).map((t) => ({
      ...t, clientName: c.name || c.id, domain: c.domain, clientPath: c.path || '',
    }))
  );
}

const PROJECT_STATUS_ORDER = [
  'Сотрудничаем',
  'Переговоры',
  'Коммерческое предложение',
  'Пауза',
  'Отказ',
  'Без статуса',
];

function projectStatus(client) {
  return client.project_status || client.status || 'Без статуса';
}

function statusBadgeClass(status) {
  const s = (status || '').toLowerCase();
  if (s.includes('сотруднич')) return 'badge--sage';
  if (s.includes('переговор')) return 'badge--lavender';
  if (s.includes('коммерч') || s.includes('кп')) return 'badge--sky';
  if (s.includes('пауз')) return 'badge--mid';
  if (s.includes('отказ')) return 'badge--overdue';
  return 'badge--event';
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
  const clickable = !state.data?.isPublic && opts.clickable !== false;
  return `
    <li class="list-item${clickable ? '' : ' list-item--static'}"${clickable ? ` data-client="${esc(task.clientName)}" role="button" tabindex="0"` : ''}>
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

function findEventById(id) {
  if (!state.data || !id) return null;
  return state.data.events.find((e) => e.id === id)
    || state.data.deadlines.find((d) => d.id === id);
}

function findEventByKey(key) {
  if (!state.data || !key) return null;
  return state.data.events.find((e) => e.key === key)
    || state.data.deadlines.find((d) => d.key === key);
}

function isEventClosed(item) {
  if (!item) return false;
  if (item.closed) return true;
  return /выполн|закрыт/i.test(item.status || '');
}

function findClientByName(name) {
  if (!state.data || !name || name === '—') return null;
  return state.data.clients.find((c) => c.name === name)
    || state.data.clients.find((c) => name.includes(c.name) || c.name.includes(name));
}

function eventTitle(item) {
  return item.title || item.event || item.type || 'Событие';
}

function renderEventItem(e) {
  const isReminder = /напомин/i.test(e.type);
  const closed = isEventClosed(e);
  const chipClass = [
    e.source === 'deadline' ? 'event-chip--deadline' : '',
    isReminder ? 'event-chip--reminder' : '',
    closed ? 'is-closed' : '',
  ].filter(Boolean).join(' ');
  const title = eventTitle(e);
  return `
    <div class="event-chip ${chipClass}" data-event-id="${esc(e.id)}" role="button" tabindex="0" title="${esc(title)}">
      <div class="event-chip__client">${esc(e.client)}${e.time ? ` · ${esc(e.time)}` : ''}</div>
      <div class="event-chip__title">${esc(title)}</div>
    </div>`;
}

function renderEventListItem(e, stripe = 'stripe--lavender') {
  const closed = isEventClosed(e);
  const title = eventTitle(e);
  return `
    <li class="list-item ${closed ? 'is-closed' : ''}" data-event-id="${esc(e.id)}" role="button" tabindex="0">
      <div class="list-item__stripe ${stripe}"></div>
      <div class="list-item__main">
        <p class="list-item__title">${esc(title)}</p>
        <div class="list-item__meta">
          <span class="badge ${closed ? 'badge--low' : 'badge--event'}">${esc(closed ? 'Выполнено' : (e.type || 'Событие'))}</span>
          <span>${esc(e.client)}</span>
          ${e.time ? `<span>${esc(e.time)}</span>` : ''}
        </div>
      </div>
      <div class="list-item__aside">${esc(e.date)}</div>
    </li>`;
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

  const nextWeekRange = getNextWeekRange(today);
  const nextWeekMeetings = getNextWeekMeetings(data, q);

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
          <div class="stat-pill__value">${nextWeekMeetings.length}</div>
          <div class="stat-pill__label">на след. неделе</div>
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
                  ? todayEvents.map((e) => renderEventListItem(e, 'stripe--lavender')).join('')
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
                  ? upcomingEvents.map((e) => renderEventListItem(e, 'stripe--peach')).join('')
                  : '<li class="empty">Нет запланированных событий</li>'}
              </ul>
            </div>
          </div>
        </div>

        <div class="stack">
          ${renderNextWeekMeetingsBlock(nextWeekMeetings, nextWeekRange)}

          ${overdue.length ? `
          <div class="card">
            <div class="card__header">
              <h2 class="card__title">Просроченные дедлайны</h2>
            </div>
            <div class="card__body--flush">
              <ul class="list">
                ${overdue.map((d) => renderEventListItem({ ...d, title: d.event, type: 'Дедлайн', source: 'deadline' }, 'stripe--peach')).join('')}
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
        const dayEvents = data.events.filter((e) => {
          const d = parseRuDate(e.date);
          return d && sameDay(d, date);
        });
        const dayDeadlines = data.deadlines.filter((d) => {
          const dt = parseRuDate(d.date);
          return dt && sameDay(dt, date);
        });
        const items = [
          ...dayEvents.map((e) => ({ ...e, _kind: 'event' })),
          ...dayDeadlines.map((d) => ({ ...d, title: d.event, source: 'deadline', _kind: 'deadline' })),
        ];
        const maxShow = 3;
        const shown = items.slice(0, maxShow);
        const more = items.length - shown.length;
        const chips = shown.map((item) => {
          const closed = isEventClosed(item);
          const label = item.client || eventTitle(item);
          const cls = item._kind === 'deadline' ? 'month-chip--deadline' : 'month-chip--event';
          return `<div class="month-chip ${cls} ${closed ? 'is-closed' : ''}" title="${esc(eventTitle(item))}">${esc(label)}</div>`;
        }).join('');
        return `
          <div class="month-cell ${sameDay(date, today) ? 'is-today' : ''} ${other ? 'is-other' : ''} ${items.length ? 'has-items' : ''}"
               data-date="${formatRuDate(date)}" role="button" tabindex="0">
            <div class="month-cell__num">${date.getDate()}</div>
            <div class="month-cell__items">
              ${chips}
              ${more > 0 ? `<div class="month-chip month-chip--more">+${more}</div>` : ''}
            </div>
          </div>`;
      }).join('')}
    </div>`;
}

function renderProjects(data) {
  const q = state.search;
  const f = state.projectFilter;

  let clients = [...data.clients];
  clients = filterBySearch(clients, q, ['name', 'project_status', (c) => c.tasks.map((t) => t.title).join(' ')]);

  if (f !== 'all') {
    clients = clients.filter((c) => projectStatus(c) === f);
  }

  const statusList = [...new Set(data.clients.map(projectStatus))];
  const orderedStatuses = [
    ...PROJECT_STATUS_ORDER.filter((s) => statusList.includes(s)),
    ...statusList.filter((s) => !PROJECT_STATUS_ORDER.includes(s)).sort(),
  ];

  const filters = [
    ['all', 'Все'],
    ...orderedStatuses.map((s) => [s, s]),
  ];

  const groups = {};
  clients.forEach((c) => {
    const s = projectStatus(c);
    (groups[s] = groups[s] || []).push(c);
  });

  const renderCard = (c) => {
    const total = c.task_count ?? c.tasks?.length ?? 0;
    const progress = total ? Math.round((c.doneCount / total) * 100) : 0;
    const ps = projectStatus(c);
    const clickable = !data.isPublic;
    return `
      <article class="project-card${clickable ? '' : ' project-card--static'}"${clickable ? ` data-client="${esc(c.name || c.id)}" role="button" tabindex="0"` : ''}>
        <div class="project-card__top">
          <h3 class="project-card__name">${esc(c.name || c.id)}</h3>
          <span class="badge ${statusBadgeClass(ps)}">${esc(ps)}</span>
        </div>
        <div class="project-card__meta">${domainBadge(c.domain)}</div>
        <div class="project-card__counts">
          <span><strong>${total}</strong>задач</span>
          <span><strong>${c.highCount}</strong>высокий</span>
          <span><strong>${c.activeCount}</strong>в работе</span>
        </div>
        <div class="progress-bar" title="${progress}% выполнено">
          <div class="progress-bar__fill" style="width:${progress}%"></div>
        </div>
      </article>`;
  };

  const sections = (f === 'all' ? orderedStatuses : [f])
    .filter((s) => groups[s]?.length)
    .map((status) => `
      <section class="status-section">
        <header class="status-section__head">
          <h2 class="status-section__title">${esc(status)}</h2>
          <span class="status-section__count">${groups[status].length}</span>
        </header>
        <div class="project-grid">
          ${groups[status].sort((a, b) => b.highCount - a.highCount).map(renderCard).join('')}
        </div>
      </section>`).join('');

  return `
    <div class="filters" id="project-filters">
      ${filters.map(([id, label]) => `
        <button type="button" class="filter-btn ${f === id ? 'is-active' : ''}" data-filter="${esc(id)}">${esc(label)}</button>
      `).join('')}
    </div>
    ${data.isPublic ? '<p class="drawer__hint drawer__hint--top">Полные карточки клиентов доступны только в локальной версии.</p>' : ''}
    <div class="status-sections">
      ${sections || '<p class="empty">Ничего не найдено</p>'}
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

function renderEventDrawer(item) {
  if (!item) return;
  state.drawerEvent = item;

  const isDeadline = item.source === 'deadline';
  const title = eventTitle(item);
  const typeLabel = isDeadline ? 'Дедлайн' : (item.type || 'Событие');
  const closed = isEventClosed(item);
  const statusClass = closed ? 'badge--low'
    : /просроч/i.test(item.status) ? 'badge--overdue' : 'badge--event';

  $('#drawer-header').innerHTML = `
    <h2 class="${closed ? 'is-closed' : ''}">${esc(title)}</h2>
    <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
      <span class="badge ${statusClass}">${esc(closed ? 'Выполнено' : (item.status || '—'))}</span>
      <span class="badge badge--reminder">${esc(typeLabel)}</span>
      ${domainBadge(item.domain)}
    </div>
  `;

  const rows = [
    ['Дата', item.date],
    ['Время', item.time || '—'],
    ['Клиент', item.client || '—'],
    ['Тип', typeLabel],
    ['Статус', closed ? 'Выполнено' : (item.status || '—')],
  ];

  const client = findClientByName(item.client);
  const canClose = canCloseEvent(item);

  $('#drawer-body').innerHTML = `
    <div class="drawer__section">
      <h3>Информация о событии</h3>
      <dl class="detail-list">
        ${rows.map(([k, v]) => `
          <div class="detail-list__row ${closed ? 'is-closed' : ''}">
            <dt>${esc(k)}</dt>
            <dd>${esc(v)}</dd>
          </div>`).join('')}
      </dl>
    </div>
    ${canClose && state.writable ? `
    <div class="drawer__section">
      <button type="button" class="btn-done-event" id="btn-done-event" ${state.closingEvent ? 'disabled' : ''}>
        ${state.closingEvent ? 'Сохраняем…' : 'Завершить'}
      </button>
      <p class="drawer__hint">Закроет событие в КАЛЕНДАРЬ.md и зачеркнёт после синхронизации.</p>
    </div>` : ''}
    ${!closed && isLocalHost() && !item.key ? `
    <div class="drawer__section">
      <p class="drawer__hint">У события нет ключа — выполните <code>scripts/sync_data.ps1</code> и обновите страницу.</p>
    </div>` : ''}
    ${!closed && isLocalHost() && item.key && !state.writable ? `
    <div class="drawer__section">
      <p class="drawer__hint">Для кнопки «Завершить» запустите <code>scripts/serve.ps1</code> (не простой static server).</p>
    </div>` : ''}
    ${client ? `
    <div class="drawer__section">
      <button type="button" class="drawer-link" id="drawer-open-client">
        Открыть карточку клиента: ${esc(client.name)}
      </button>
    </div>` : ''}
  `;

  $('#drawer-open-client')?.addEventListener('click', () => openClientDrawer(client));
  $('#btn-done-event')?.addEventListener('click', () => closeEvent(item));
}

function isLocalHost() {
  const h = location.hostname;
  return h === 'localhost' || h === '127.0.0.1';
}

function isHostedPublicSite() {
  const h = location.hostname;
  return h.includes('github.io') || h.includes('githubusercontent.com');
}

function detectPublicMode(raw = {}) {
  if (raw.has_full_profiles) return false;
  if (raw.privacy === 'public') return true;
  if (isHostedPublicSite()) return true;
  return !isLocalHost();
}

function canCloseEvent(item) {
  return !!state.writable && !isEventClosed(item) && !!item.key;
}

function normalizeKvItems(block) {
  if (block.items?.length) return block.items;
  const rows = block.rows || [];
  if (rows.length === 2 && typeof rows[0] === 'string' && typeof rows[1] === 'string') {
    return [{ label: rows[0], value: rows[1] }];
  }
  return rows.map((row) => {
    if (row?.label) return row;
    if (Array.isArray(row) && row.length >= 2) return { label: row[0], value: row[1] };
    return null;
  }).filter(Boolean);
}

function normalizeTableRows(block) {
  let rows = block.rows || [];
  if (rows && !Array.isArray(rows)) rows = Object.values(rows);
  return rows.map((row) => {
    if (row?.cells) return row.cells;
    if (Array.isArray(row)) return row;
    return null;
  }).filter((r) => Array.isArray(r) && r.length && !/^(—|-)+$/.test(r.join('')));
}

function normalizeProfileBlock(block) {
  if (!block) return null;
  if (block.kind === 'text') {
    const text = (block.text || '').trim();
    if (!text || /^\|?\s*---/.test(text)) return null;
    return block;
  }
  if (block.kind === 'key_value') {
    const items = normalizeKvItems(block);
    return items.length ? { kind: 'key_value', items } : null;
  }
  if (block.kind === 'table') {
    const rows = normalizeTableRows(block);
    return rows.length ? { kind: 'table', headers: block.headers || [], rows } : null;
  }
  return block;
}

function normalizeClientProfile(profile) {
  if (!profile) return null;
  const sections = (profile.sections || []).map((sec) => ({
    title: sec.title,
    blocks: (sec.blocks || []).map(normalizeProfileBlock).filter(Boolean),
  })).filter((sec) => sec.blocks.length > 0);
  return { updated_note: profile.updated_note || null, sections };
}

function renderInlineText(text) {
  if (!text) return '';
  return esc(text)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>');
}

function renderProfileText(text) {
  return text.split('\n').map((line) => {
    const t = line.trim();
    if (!t) return '';
    if (t.startsWith('### ')) {
      return `<h4 class="profile-text__sub">${renderInlineText(t.slice(4))}</h4>`;
    }
    if (t.startsWith('- ')) {
      return `<p class="profile-text__bullet">${renderInlineText(t)}</p>`;
    }
    return `<p class="profile-text__p">${renderInlineText(t)}</p>`;
  }).join('');
}

function renderProfileBlock(block) {
  if (!block) return '';
  switch (block.kind) {
    case 'key_value':
      return `
        <dl class="profile-kv">
          ${normalizeKvItems(block).map((item) => `
            <div class="profile-kv__row">
              <dt>${esc(item.label)}</dt>
              <dd>${renderInlineText(item.value)}</dd>
            </div>`).join('')}
        </dl>`;
    case 'table':
      return `
        <div class="table-wrap profile-table-wrap">
          <table class="profile-table">
            <thead><tr>${(block.headers || []).map((h) => `<th>${esc(h)}</th>`).join('')}</tr></thead>
            <tbody>
              ${normalizeTableRows(block).map((row) => `
                <tr>${row.map((cell) => `<td>${renderInlineText(cell)}</td>`).join('')}</tr>
              `).join('')}
            </tbody>
          </table>
        </div>`;
    case 'checklist':
      return `
        <ul class="profile-checklist">
          ${(block.items || []).map((item) => `
            <li><span class="profile-checklist__box" aria-hidden="true"></span>${renderInlineText(item)}</li>
          `).join('')}
        </ul>`;
    case 'code':
      return `<pre class="profile-code">${esc(block.text || '')}</pre>`;
    case 'text':
    default:
      return `<div class="profile-text">${renderProfileText(block.text || '')}</div>`;
  }
}

function renderFullClientDrawer(client) {
  const profile = client.profile || {};
  const sections = client.profile?.sections || [];
  const tasks = client.tasks || [];

  $('#drawer-header').innerHTML = `
    <div class="client-hero">
      <p class="client-hero__eyebrow">${esc(client.domain || '3D')} · полная карточка</p>
      <h2>${esc(client.name)}</h2>
      <div class="client-hero__badges">
        ${domainBadge(client.domain)}
        ${client.project_status ? `<span class="badge ${statusBadgeClass(client.project_status)}">${esc(client.project_status)}</span>` : ''}
        ${client.deal_stage ? `<span class="badge badge--event">${esc(client.deal_stage)}</span>` : ''}
      </div>
      ${profile.updated_note ? `<p class="client-hero__note">${renderInlineText(profile.updated_note)}</p>` : ''}
    </div>
  `;

  $('#drawer-body').innerHTML = `
    <div class="client-profile">
      ${sections.map((sec) => `
        <section class="profile-section">
          <h3 class="profile-section__title">${esc(sec.title)}</h3>
          <div class="profile-section__body">
            ${(sec.blocks || []).map(renderProfileBlock).join('')}
          </div>
        </section>
      `).join('')}
      <section class="profile-section profile-section--tasks">
        <h3 class="profile-section__title">Задачи (${tasks.length})</h3>
        <div class="profile-section__body">
          ${tasks.length ? `
            <div class="table-wrap">
              <table class="profile-table">
                <thead>
                  <tr><th>ID</th><th>Задача</th><th>Приоритет</th><th>Статус</th><th>Срок</th><th>Ответственный</th></tr>
                </thead>
                <tbody>
                  ${tasks.map((t) => `
                    <tr>
                      <td>${esc(t.id)}</td>
                      <td>${esc(t.title)}</td>
                      <td>${priorityBadge(t.priority)}</td>
                      <td>${esc(t.status)}</td>
                      <td>${esc(t.due || '—')}</td>
                      <td>${esc(t.assignee || '—')}</td>
                    </tr>`).join('')}
                </tbody>
              </table>
            </div>` : '<p class="empty">Задач нет</p>'}
        </div>
      </section>
      ${client.path ? `
      <section class="profile-section profile-section--meta">
        <h3 class="profile-section__title">Источник</h3>
        <div class="profile-section__body">
          <div class="drawer__path">${esc(client.path)}</div>
        </div>
      </section>` : ''}
    </div>
  `;
}

function renderBasicClientDrawer(client) {
  const tasks = client.tasks || [];
  const contacts = client.contacts || {};
  const hidePhone = state.data?.isPublic;
  const contactRows = Object.entries(contacts)
    .filter(([k]) => hidePhone ? k !== 'Телефон' : true)
    .map(([k, v]) => `<tr><td>${esc(k)}</td><td>${esc(v)}</td></tr>`)
    .join('');

  $('#drawer-header').innerHTML = `
    <h2>${esc(client.name)}</h2>
    <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
      ${domainBadge(client.domain)}
      ${client.project_status ? `<span class="badge ${statusBadgeClass(client.project_status)}">${esc(client.project_status)}</span>` : ''}
      ${client.deal_stage ? `<span class="badge badge--event">${esc(client.deal_stage)}</span>` : ''}
    </div>
    ${state.data?.isPublic ? '<p class="drawer__hint drawer__hint--top">Краткая карточка. Полные справки и вводные — в локальной версии.</p>' : ''}
  `;

  $('#drawer-body').innerHTML = `
    ${contactRows ? `
    <div class="drawer__section">
      <h3>Контакты</h3>
      <div class="table-wrap">
        <table>
          <tbody>${contactRows}</tbody>
        </table>
      </div>
    </div>` : ''}
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
    ${client.path ? `
    <div class="drawer__section">
      <h3>Исходный файл</h3>
      <div class="drawer__path">${esc(client.path)}</div>
    </div>` : ''}
  `;
}

function renderDrawer(client) {
  if (!client) return;
  if (state.data?.hasFullProfiles && client.profile) {
    renderFullClientDrawer(client);
  } else {
    renderBasicClientDrawer(client);
  }
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
  renderSyncPanel(data);
}

function formatSyncTime(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('ru-RU', {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
  });
}

function deltaClass(value) {
  if (value === 'new' || (typeof value === 'string' && value.startsWith('+'))) return 'is-up';
  if (typeof value === 'string' && value.startsWith('-')) return 'is-down';
  return 'is-same';
}

function renderSyncPanel(data) {
  const r = data.sync_report;
  const syncBtn = $('#sync-time');
  const panel = $('#sidebar-sync');

  if (data.isPublic) {
    if (syncBtn) {
      syncBtn.textContent = `Обновлено ${formatSyncTime(data.generated_at)}`;
      syncBtn.classList.remove('is-ok');
      syncBtn.hidden = true;
    }
    if (panel) {
      panel.hidden = true;
      panel.innerHTML = '';
    }
    return;
  }

  if (syncBtn) syncBtn.hidden = false;

  if (!r) {
    syncBtn.textContent = `Обновлено ${formatSyncTime(data.generated_at)}`;
    syncBtn.classList.remove('is-ok');
    panel.hidden = true;
    return;
  }

  syncBtn.textContent = `Синхронизация OK · ${formatSyncTime(r.generated_at)}`;
  syncBtn.classList.add('is-ok');
  panel.hidden = false;

  const t = r.transferred || {};
  const changes = r.changes || {};
  const sources = r.sources || {};
  const statuses = t.project_status || {};
  const statusRows = Object.entries(statuses)
    .sort((a, b) => b[1] - a[1])
    .map(([name, count]) => `<li><span>${esc(name)}</span><strong>${count}</strong></li>`)
    .join('');

  const changeRows = [
    ['Клиенты', changes.clients],
    ['Задачи', changes.tasks],
    ['События', changes.events],
    ['Дедлайны', changes.deadlines],
  ].map(([label, value]) => `
    <li>
      <span>${esc(label)}</span>
      <span class="sync-panel__delta ${deltaClass(value)}">${esc(String(value ?? '0'))}</span>
    </li>`).join('');

  panel.innerHTML = `
    <div class="sync-panel__head">
      <span class="sync-panel__status" aria-hidden="true"></span>
      <h3 class="sync-panel__title">Передано в систему</h3>
    </div>
    <div class="sync-panel__grid">
      <div class="sync-panel__metric"><strong>${t.clients ?? 0}</strong><span>клиентов</span></div>
      <div class="sync-panel__metric"><strong>${t.tasks ?? 0}</strong><span>задач</span></div>
      <div class="sync-panel__metric"><strong>${t.events ?? 0}</strong><span>событий</span></div>
      <div class="sync-panel__metric"><strong>${t.deadlines ?? 0}</strong><span>дедлайнов</span></div>
    </div>
    <p class="sync-panel__sources">
      Источники: ${sources.backlog_files ?? 0} BACKLOG.md,
      ${sources.calendar_files ?? 0} календарь
      ${sources.domains?.length ? ` · ${esc(sources.domains.join(', '))}` : ''}
    </p>
    <div class="sync-panel__section">
      <h4>Изменения с прошлой выгрузки</h4>
      <ul class="sync-panel__list">${changeRows}</ul>
    </div>
    ${statusRows ? `
    <div class="sync-panel__section">
      <h4>Статусы проектов</h4>
      <ul class="sync-panel__list">${statusRows}</ul>
    </div>` : ''}
    ${r.previous_sync_at ? `<p class="sync-panel__sources">Прошлая выгрузка: ${formatSyncTime(r.previous_sync_at)}</p>` : ''}
  `;
}

function updateSyncUi(data) {
  renderSyncPanel(data);
}

function initQuickLinks() {
  const host = location.hostname;
  const isLocal = host === 'localhost' || host === '127.0.0.1';
  $$('[data-quick]').forEach((el) => {
    el.classList.toggle('is-active', (el.dataset.quick === 'local' && isLocal)
      || (el.dataset.quick === 'public' && !isLocal));
  });
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

  // Open event drawer (calendar chips, today lists)
  $$('[data-event-id]').forEach((el) => {
    const open = (e) => {
      e?.stopPropagation?.();
      const item = findEventById(el.dataset.eventId);
      if (item) openEventDrawer(item);
    };
    el.addEventListener('click', open);
    el.addEventListener('keydown', (e) => { if (e.key === 'Enter') open(e); });
  });

  // Open client drawer (projects, tasks)
  $$('[data-client]').forEach((el) => {
    if (el.dataset.eventId) return;
    const open = () => {
      const client = findClientByName(el.dataset.client);
      if (client) openClientDrawer(client);
    };
    el.addEventListener('click', open);
    el.addEventListener('keydown', (e) => { if (e.key === 'Enter') open(); });
  });

  // Month cell: one event -> drawer; many -> day list; none -> week view
  $$('.month-cell[data-date]').forEach((cell) => {
    cell.addEventListener('click', () => {
      const d = parseRuDate(cell.dataset.date);
      if (!d) return;
      const dayItems = [
        ...state.data.events.filter((e) => { const dt = parseRuDate(e.date); return dt && sameDay(dt, d); }),
        ...state.data.deadlines.filter((e) => { const dt = parseRuDate(e.date); return dt && sameDay(dt, d); }),
      ];
      if (dayItems.length === 1) {
        openEventDrawer(dayItems[0]);
        return;
      }
      if (dayItems.length > 1) {
        openDayDrawer(d, dayItems);
        return;
      }
      state.calAnchor = d;
      state.calMode = 'week';
      render();
    });
  });
}

function openDayDrawer(date, items) {
  $('#drawer-header').innerHTML = `
    <h2>${formatRuDate(date)}</h2>
    <p style="margin:8px 0 0;color:var(--text-muted);font-size:0.85rem">${items.length} событий</p>
  `;
  $('#drawer-body').innerHTML = `<ul class="list">${items.map((e) => renderEventListItem(e)).join('')}</ul>`;
  showDrawer();
  $$('#drawer-body [data-event-id]').forEach((el) => {
    el.addEventListener('click', (ev) => {
      ev.stopPropagation();
      const item = findEventById(el.dataset.eventId);
      if (item) openEventDrawer(item);
    });
  });
}

function showDrawer() {
  $('#overlay').hidden = false;
  requestAnimationFrame(() => $('#overlay').classList.add('is-visible'));
  $('#drawer').classList.add('is-open');
  $('#drawer').setAttribute('aria-hidden', 'false');
}

function openClientDrawer(client) {
  if (state.data?.isPublic) return;
  renderDrawer(client);
  const wide = !!(state.data?.hasFullProfiles && client?.profile);
  $('#drawer').classList.toggle('drawer--wide', wide);
  showDrawer();
}

function openEventDrawer(item) {
  renderEventDrawer(item);
  showDrawer();
}

function openDrawer(client) {
  openClientDrawer(client);
}

function closeDrawer() {
  $('#overlay').classList.remove('is-visible');
  $('#drawer').classList.remove('is-open', 'drawer--wide');
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

async function checkWritable() {
  try {
    const res = await fetch('/api/health');
    if (!res.ok) return false;
    const data = await res.json();
    return !!data.writable;
  } catch {
    return false;
  }
}

async function closeEvent(item) {
  if (!item?.key || state.closingEvent || !canCloseEvent(item)) return;
  state.closingEvent = true;
  renderEventDrawer(item);

  try {
    const res = await fetch('/api/close-event', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key: item.key }),
    });
    const payload = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(payload.error || `HTTP ${res.status}`);

    state.data = await loadData(true);
    renderSidebarStats(state.data);
    render();

    const updated = findEventByKey(item.key);
    if (updated) openEventDrawer(updated);
    else closeDrawer();
  } catch (e) {
    alert(`Не удалось закрыть событие: ${e.message || e}`);
  } finally {
    state.closingEvent = false;
    if (state.drawerEvent?.key === item.key || state.drawerEvent?.id === item.id) {
      const updated = findEventByKey(item.key) || item;
      renderEventDrawer(updated);
    }
  }
}

async function loadData(preferFull = false) {
  const useLocal = preferFull && isLocalHost();
  const paths = useLocal
    ? [
      'data/planner.local.json',
      '../data/planner.local.json',
      'data/planner.json',
      '../data/planner.json',
    ]
    : [
      'data/planner.json',
      '../data/planner.json',
    ];
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
  initQuickLinks();

  try {
    state.writable = await checkWritable();
    state.data = await loadData(state.writable || isLocalHost());
    const brandSub = document.querySelector('.brand-sub');
    if (brandSub) {
      brandSub.textContent = state.data.hasFullProfiles
        ? 'CURSOR · полные карточки'
        : state.writable
        ? 'CURSOR · локальная запись'
        : (state.data.isPublic ? 'CURSOR · публичный снимок' : 'CURSOR · только чтение');
    }
    if (state.data.isPublic || state.data.hasFullProfiles) {
      const banner = document.createElement('p');
      banner.className = 'privacy-banner';
      banner.textContent = state.data.hasFullProfiles
        ? 'Локальная версия: полные карточки клиентов из BACKLOG.md (телефоны, суммы, справки).'
        : 'Единый снимок с GitHub: те же клиенты, задачи и календарь. Телефоны и суммы скрыты.';
      document.querySelector('.content')?.prepend(banner);
    }
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

  $('#sync-time')?.addEventListener('click', () => {
    const panel = $('#sidebar-sync');
    if (!panel || panel.hidden) return;
    panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    $('.sidebar')?.classList.add('is-open');
  });

  // Mobile menu
  $('#menu-toggle')?.addEventListener('click', () => {
    $('.sidebar').classList.toggle('is-open');
  });
}

init();
