# Ежедневник

Единый read-only дашборд задач, встреч и клиентов по всем проектам из папки `CURSOR`.

## Быстрый старт

1. **Данные** живут в markdown проектов (`BACKLOG.md`, `КАЛЕНДАРЬ.md`)
2. **Изменения** — через чаты Cursor (субагенты обновляют исходники)
3. **Сборка снимка:** `powershell -File scripts/sync_data.ps1` (или `python scripts/sync_data.py` при установленном Python)
4. **Просмотр:** локальный сервер из папки проекта:
   ```powershell
   powershell -File scripts/serve.ps1
   ```
   Откройте http://localhost:8080

## Документация

- [PROJECT.md](PROJECT.md) — видение, архитектура, облако
- [AGENTS.md](AGENTS.md) — роли субагентов
- [docs/MVP-ROADMAP.md](docs/MVP-ROADMAP.md) — план этапов

## Субагенты (Cursor skills)

| Skill | Роль |
| --- | --- |
| `orchestrator` | Главный, сводки и маршрутизация |
| `design-ux` | Дизайн и юзабилити |
| `calendar-scheduler` | Календарь без пересечений |
| `coder` | Код, сборка, деплой |

В чате: «используй skill calendar-scheduler — поставь встречу…»
