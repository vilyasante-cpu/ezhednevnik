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
- [docs/MVP-ROADMAP.md](documentation/MVP-ROADMAP.md) — план этапов

## Субагенты (Cursor skills)

| Skill | Роль |
| --- | --- |
| `orchestrator` | Главный, сводки и маршрутизация |
| `design-ux` | Дизайн и юзабилити |
| `calendar-scheduler` | Календарь без пересечений |
| `coder` | Код, сборка, деплой |

В чате: «используй skill calendar-scheduler — поставь встречу…»

## GitHub

Репозиторий: **https://github.com/vilyasante-cpu/ezhednevnik**

Сайт (Pages): **https://vilyasante-cpu.github.io/ezhednevnik/** — только обезличенная статистика.

**Приватность:** см. [GIT-PRIVACY.md](GIT-PRIVACY.md) — в Git: имена и компании ✓, телефоны и суммы ✗.

Деплой: **Deploy from a branch** → `main` → папка `/docs`

## Автосинхронизация

Цепочка: `BACKLOG.md` / `КАЛЕНДАРЬ.md` в CURSOR → `planner.json` → git push → GitHub Pages.

### Разовая синхронизация

```powershell
powershell -File scripts/auto_sync.ps1
```

### Авто каждые 30 минут (Windows)

```powershell
powershell -File scripts/install_autosync_task.ps1
```

### Фоновый watcher (проверка каждую минуту)

```powershell
powershell -File scripts/watch_sync.ps1
```

Удалить задачу: `powershell -File scripts/install_autosync_task.ps1 -Uninstall`
