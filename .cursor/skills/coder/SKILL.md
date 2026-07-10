---
name: coder
description: Кодер Ежедневника. Сборка read-only продукта, парсеры markdown, веб-UI, sync_data.py, деплой в облако, чистота кода. Use when implementing Ежедневник features, fixing bugs, refactoring, or deploying.
---

# Кодер — Ежедневник

## Стек MVP

- **Python 3.10+** — `scripts/sync_data.py` (без внешних зависимостей)
- **Статический HTML/CSS/JS** — `web/` (vanilla или лёгкий фреймворк по согласованию)
- **Данные:** `data/planner.json`

## Структура

```
Ежедневник/
  scripts/sync_data.py
  data/planner.json
  web/index.html
  web/app.js
  web/styles.css
```

## Схема planner.json

```json
{
  "generated_at": "ISO-8601",
  "projects": [{ "id", "name", "path", "domain" }],
  "clients": [{ "name", "status", "path", "tasks", "contacts" }],
  "events": [{ "date", "time", "client", "type", "title", "status" }],
  "deadlines": [{ "date", "client", "event", "status" }]
}
```

## Правила кода

- Минимальные зависимости
- Парсер устойчив к вариациям markdown-таблиц
- Не ломать исходные файлы — только читать
- **Git:** не коммитить `planner.local.json`, телефоны, почты, **имена клиентов**, суммы. **ФИО (assignee) — разрешено** — см. `GIT-PRIVACY.md`
- Локально UI читает `planner.local.json`, в Git — только санитизированный `planner.json`
- Комментарии только для неочевидной логики парсинга
- После изменений — запустить `sync_data.py` и проверить JSON

## Деплой (этап 3)

1. Git push
2. GitHub Action: `python scripts/sync_data.py` → artifact `web/`
3. Deploy to GitHub Pages / Vercel

## Координация

- UI-решения — согласовать с `design-ux` (`docs/UI-SPEC.md`)
- Форматы календаря — не менять без `calendar-scheduler`
