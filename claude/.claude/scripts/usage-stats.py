#!/usr/bin/env python3
"""Claude Code usage stats extractor. Outputs JSON for /usage-report command."""

import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path

HISTORY = Path.home() / ".claude" / "history.jsonl"


def load_history():
    if not HISTORY.exists():
        print(json.dumps({"error": "No history found."}))
        sys.exit(1)
    with open(HISTORY) as f:
        return [json.loads(line) for line in f if line.strip()]


def date_range_filter(entries, days=None):
    if not days:
        return entries
    cutoff = (datetime.now() - timedelta(days=days)).timestamp() * 1000
    return [e for e in entries if e["timestamp"] >= cutoff]


def analyze(entries):
    dates = [datetime.fromtimestamp(e["timestamp"] / 1000) for e in entries]
    projects = Counter(e.get("project", "?").split("/")[-1] for e in entries)
    sessions = Counter(e.get("sessionId", "") for e in entries)
    session_sizes = sorted(sessions.values(), reverse=True)
    non_cmd = [e for e in entries if not e["display"].startswith("/")]
    lengths = [len(e["display"]) for e in non_cmd]

    # Day counts
    day_counts = Counter(d.strftime("%Y-%m-%d") for d in dates)

    # Day of week
    dow = Counter(d.strftime("%A") for d in dates)

    # Hours
    hours = Counter(d.hour for d in dates)

    # Slash commands
    slash = [e for e in entries if e["display"].startswith("/")]
    cmd_counts = Counter(e["display"].split()[0] for e in slash)

    # Per-project commands
    proj_cmds = defaultdict(Counter)
    for e in entries:
        proj = e.get("project", "?").split("/")[-1]
        if e["display"].startswith("/"):
            proj_cmds[proj][e["display"].split()[0]] += 1

    # Short responses
    short_resps = [e for e in non_cmd if len(e["display"]) < 20]
    short_texts = Counter(e["display"].strip().lower() for e in short_resps)

    # Questions
    questions = sum(1 for e in non_cmd if "?" in e["display"])

    # Corrections
    correction_words = ["no,", "wrong", "not that", "don't", "stop", "instead",
                        "actually,", "wait,", "nope", "that's not"]
    corrections = [e for e in non_cmd
                   if any(w in e["display"].lower() for w in correction_words)]

    # Task categories
    categories = Counter()
    for e in non_cmd:
        d = e["display"].lower()
        if any(w in d for w in ["test", "spec", "coverage"]):
            categories["testing"] += 1
        elif any(w in d for w in ["bug", "fix", "error", "issue", "broken", "fail"]):
            categories["debugging"] += 1
        elif any(w in d for w in ["review", "pr ", "pull request"]):
            categories["code review"] += 1
        elif any(w in d for w in ["deploy", "k8s", "kubernetes", "helm", "docker"]):
            categories["infra/deploy"] += 1
        elif any(w in d for w in ["refactor", "clean", "simplify", "extract"]):
            categories["refactoring"] += 1
        elif any(w in d for w in ["add ", "create", "implement", "new ", "feature"]):
            categories["new feature"] += 1
        elif any(w in d for w in ["config", "setting", "setup", "install"]):
            categories["config/setup"] += 1
        elif any(w in d for w in ["explain", "how", "what", "why", "where"]):
            categories["understanding"] += 1
        elif any(w in d for w in ["commit", "push", "merge", "branch"]):
            categories["git ops"] += 1
        elif len(d) < 20:
            categories["short response"] += 1
        else:
            categories["other"] += 1

    # Commit workflow
    sessions_data = defaultdict(list)
    for e in entries:
        sessions_data[e["sessionId"]].append(e)
    commit_distances = []
    for sid, prompts in sessions_data.items():
        for i, p in enumerate(prompts):
            if p["display"].startswith("/commit"):
                prior = [pp for pp in prompts[:i] if not pp["display"].startswith("/")]
                commit_distances.append(len(prior))

    # Pasted content
    pasted = sum(1 for e in entries
                 if e.get("pastedContents") and len(e["pastedContents"]) > 0)

    # Session size brackets
    size_brackets = {
        "1-5": sum(1 for s in session_sizes if s <= 5),
        "6-10": sum(1 for s in session_sizes if 6 <= s <= 10),
        "11-20": sum(1 for s in session_sizes if 11 <= s <= 20),
        "21-50": sum(1 for s in session_sizes if 21 <= s <= 50),
        "50+": sum(1 for s in session_sizes if s > 50),
    }

    active_days = len(day_counts)

    return {
        "overview": {
            "period_start": min(dates).strftime("%Y-%m-%d"),
            "period_end": max(dates).strftime("%Y-%m-%d"),
            "total_prompts": len(entries),
            "sessions": len(sessions),
            "avg_prompts_per_session": round(len(entries) / len(sessions), 1),
            "active_days": active_days,
            "avg_prompts_per_day": round(len(entries) / active_days, 1),
        },
        "daily_activity": {d: day_counts[d] for d in sorted(day_counts)},
        "day_of_week": {d: dow.get(d, 0) for d in
                        ["Monday", "Tuesday", "Wednesday", "Thursday",
                         "Friday", "Saturday", "Sunday"]},
        "peak_hours": {f"{h:02d}:00": c for h, c in hours.most_common(8)},
        "projects": dict(projects.most_common()),
        "session_sizes": size_brackets,
        "largest_session": session_sizes[0],
        "slash_commands": {
            "total": len(slash),
            "pct_of_prompts": round(len(slash) / len(entries) * 100, 1),
            "breakdown": dict(cmd_counts.most_common()),
        },
        "commands_per_project": {
            proj: dict(proj_cmds[proj].most_common(5))
            for proj in sorted(proj_cmds)
        },
        "prompt_characteristics": {
            "non_command_count": len(non_cmd),
            "avg_length": round(sum(lengths) / len(lengths)),
            "median_length": sorted(lengths)[len(lengths) // 2],
            "short_pct": round(sum(1 for l in lengths if l < 50) / len(lengths) * 100),
            "medium_pct": round(sum(1 for l in lengths if 50 <= l < 200) / len(lengths) * 100),
            "long_pct": round(sum(1 for l in lengths if 200 <= l < 500) / len(lengths) * 100),
            "very_long_pct": round(sum(1 for l in lengths if l >= 500) / len(lengths) * 100),
            "pasted_content_count": pasted,
            "pasted_content_pct": round(pasted / len(entries) * 100, 1),
        },
        "interaction_types": {
            "questions_pct": round(questions / len(non_cmd) * 100),
            "short_responses": len(short_resps),
            "top_short": dict(short_texts.most_common(10)),
            "corrections": len(corrections),
            "correction_pct": round(len(corrections) / len(non_cmd) * 100, 1),
        },
        "task_categories": dict(categories.most_common()),
        "commit_workflow": {
            "avg_prompts_before_commit": round(
                sum(commit_distances) / len(commit_distances), 1
            ) if commit_distances else None,
            "min": min(commit_distances) if commit_distances else None,
            "max": max(commit_distances) if commit_distances else None,
        },
    }


def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else None
    entries = load_history()
    if days:
        entries = date_range_filter(entries, days)
        if not entries:
            print(json.dumps({"error": f"No history in last {days} days."}))
            sys.exit(0)
    print(json.dumps(analyze(entries), indent=2))


if __name__ == "__main__":
    main()
