#!/usr/bin/env python3
"""
Сканирует папку CURSOR и собирает единый снимок для Ежедневника.
Только чтение исходных markdown — исходники не изменяются.
"""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

# Корень всех проектов
CURSOR_ROOT = Path(__file__).resolve().parent.parent.parent
OUTPUT = Path(__file__).resolve().parent.parent / "data" / "planner.json"


def parse_table_rows(text: str) -> list[list[str]]:
    """Извлекает строки из markdown-таблиц (пропускает разделители ---)."""
    rows: list[list[str]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        if re.match(r"^\|[\s\-:|]+\|$", line):
            continue
        cells = [c.strip().strip("*") for c in line.split("|")[1:-1]]
        if cells:
            rows.append(cells)
    return rows


def domain_from_path(path: Path) -> str:
    parts = path.relative_to(CURSOR_ROOT).parts
    return parts[0] if parts else "unknown"


def parse_backlog(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    client_name = path.parent.name
    result: dict = {
        "name": client_name,
        "path": str(path.relative_to(CURSOR_ROOT)),
        "domain": domain_from_path(path),
        "status": None,
        "contacts": {},
        "tasks": [],
        "meetings": [],
        "open_questions": [],
    }

    # Паспорт клиента
    in_passport = False
    for line in text.splitlines():
        if "## Паспорт клиента" in line:
            in_passport = True
            continue
        if in_passport and line.startswith("## "):
            in_passport = False
        if in_passport and "|" in line and "---" not in line:
            cells = [c.strip() for c in line.split("|")[1:-1]]
            if len(cells) == 2 and cells[0] not in ("Поле", ""):
                key = cells[0].lower()
                if key in ("организация", "контакт", "телефон", "город", "тип"):
                    result["contacts"][cells[0]] = cells[1]

    # Статус сделки
    for row in parse_table_rows(text):
        if len(row) >= 2 and row[0] == "Этап":
            result["status"] = row[1]
            break

    # Backlog задачи
    in_backlog = False
    for line in text.splitlines():
        if line.strip() == "## Backlog":
            in_backlog = True
            continue
        if in_backlog and line.startswith("## "):
            break
        if in_backlog and line.startswith("|") and "---" not in line:
            cells = [c.strip() for c in line.split("|")[1:-1]]
            if len(cells) >= 5 and cells[0] not in ("ID", ""):
                result["tasks"].append({
                    "id": cells[0],
                    "title": cells[1],
                    "priority": cells[2],
                    "status": cells[3],
                    "assignee": cells[4] if len(cells) > 4 else "",
                })

    # Открытые вопросы
    in_questions = False
    for line in text.splitlines():
        if "## Открытые вопросы" in line:
            in_questions = True
            continue
        if in_questions and line.startswith("## "):
            break
        if in_questions and line.strip().startswith("- ["):
            q = re.sub(r"^- \[[ x]\] ", "", line.strip())
            result["open_questions"].append(q)

    return result


def parse_calendar(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    events: list[dict] = []
    deadlines: list[dict] = []
    section = None

    for line in text.splitlines():
        if "## Предстоящие события" in line:
            section = "upcoming"
            continue
        if "## Контрольные даты" in line:
            section = "deadlines"
            continue
        if "## Прошедшие" in line:
            section = "past"
            continue
        if line.startswith("## ") and "Предстоящие" not in line and "Контрольные" not in line and "Прошедшие" not in line:
            if section == "upcoming":
                section = None

        if not line.startswith("|") or "---" in line:
            continue

        cells = [c.strip().strip("*") for c in line.split("|")[1:-1]]
        if not cells or cells[0] in ("Дата", ""):
            continue

        if section == "upcoming" and len(cells) >= 6:
            events.append({
                "date": cells[0],
                "time": cells[1] if cells[1] != "—" else None,
                "client": cells[2],
                "type": cells[3],
                "title": cells[4],
                "status": cells[5],
                "comment": cells[6] if len(cells) > 6 else "",
            })
        elif section == "deadlines" and len(cells) >= 4:
            deadlines.append({
                "date": cells[0],
                "client": cells[1],
                "event": cells[2],
                "status": cells[3],
                "comment": cells[4] if len(cells) > 4 else "",
            })

    return {
        "path": str(path.relative_to(CURSOR_ROOT)),
        "domain": domain_from_path(path),
        "events": events,
        "deadlines": deadlines,
    }


def collect() -> dict:
    clients: list[dict] = []
    calendars: list[dict] = []
    domains: set[str] = set()

    for backlog in CURSOR_ROOT.rglob("BACKLOG.md"):
        if "Ежедневник" in backlog.parts:
            continue
        try:
            client = parse_backlog(backlog)
            clients.append(client)
            domains.add(client["domain"])
        except Exception as e:
            print(f"WARN: {backlog}: {e}")

    for cal in CURSOR_ROOT.rglob("КАЛЕНДАРЬ.md"):
        if "Ежедневник" in cal.parts:
            continue
        try:
            calendars.append(parse_calendar(cal))
            domains.add(domain_from_path(cal))
        except Exception as e:
            print(f"WARN: {cal}: {e}")

    # Сводные метрики
    all_tasks = [t for c in clients for t in c["tasks"]]
    high_priority = [t for t in all_tasks if "высок" in t.get("priority", "").lower()]
    overdue_deadlines = [
        d for cal in calendars for d in cal["deadlines"]
        if "просроч" in d.get("status", "").lower()
    ]

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "cursor_root": str(CURSOR_ROOT),
        "stats": {
            "clients": len(clients),
            "tasks": len(all_tasks),
            "high_priority_tasks": len(high_priority),
            "upcoming_events": sum(len(c["events"]) for c in calendars),
            "overdue_deadlines": len(overdue_deadlines),
        },
        "domains": sorted(domains),
        "clients": sorted(clients, key=lambda x: x["name"]),
        "calendars": calendars,
    }


def main() -> None:
    data = collect()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"OK: {OUTPUT}")
    print(f"  Клиентов: {data['stats']['clients']}")
    print(f"  Задач: {data['stats']['tasks']}")
    print(f"  Событий: {data['stats']['upcoming_events']}")
    print(f"  Просрочено: {data['stats']['overdue_deadlines']}")


if __name__ == "__main__":
    main()
