#!/usr/bin/env python3
"""Claude Code effectiveness analyzer. Task-based quality metrics + coaching data."""

import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path

HISTORY = Path.home() / ".claude" / "history.jsonl"

REACTIVE_EXACT = frozenset({
    "yes", "ye", "y", "yep", "yup", "sure", "ok", "okay", "go", "go ahead",
    "do it", "continue", "add", "sounds good", "looks good", "lgtm",
    "skip it", "nvm", "nevermind", "try now", "run it",
})

CORRECTION_STARTERS = [
    "no,", "wrong", "not that", "stop", "instead", "actually,", "wait,",
    "nope", "revert", "roll back", "rollback", "scrap", "still no",
    "still fail", "still broken", "not working", "it fails", "it broke",
    "that broke", "not correct", "not right", "that's wrong", "that's not",
    "didn't work", "doesn't work", "i reverted", "let's scrap",
]

TDD_PHRASES = [
    "test first", "write a test", "write test", "make a test", "failing test",
    "see it fail", "red green", "tdd", "/tdd", "/bug",
]

SPEC_PHRASES = [
    "should", "must", "expect", "acceptance", "requirement", "criteria",
    "definition of done", "given ", "when ", "then ",
]

FILE_PATH_RE = re.compile(r"(?:[~/.][\w.-]*/)+[\w.-]+\.\w+|@[\w./]+")
CODE_BLOCK_RE = re.compile(r"```")

# Operational tasks: git ops, PRs, staging, simple housekeeping — don't need specs
OPERATIONAL_PATTERNS = re.compile(
    r"^(stage|commit|push|pull|merge|stash|cherry.pick|rebase|checkout|"
    r"make a pr|create a pr|create pr|open a pr|open pr|"
    r"describe.pr|update.pr|pr description|"
    r"add to.*(git|staged)|git add|"
    r"rename|move|delete|remove|copy|"
    r"run (tests|lint|build|ci)|"
    r"deploy|release|tag)",
    re.I,
)

# Exploration: questions/feasibility — context comes from conversation, don't need specs
EXPLORATION_START = re.compile(
    r"^(where|what|how|why|which|is there|does|can you (find|show|explain|check|look))",
    re.I,
)
EXPLORATION_CONTAINS = re.compile(
    r"is it possible|can (we|I|you|claude)|do we (need|have)|are there|"
    r"does (it|this|that)|what happens|how does|how do|"
    r"I (wonder|think|guess|believe|want to understand|want to know|need to understand)",
    re.I,
)


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


def classify_prompt(text):
    """Classify prompt as 'command', 'reactive', 'correction', or 'directive'."""
    if text.startswith("/"):
        return "command"
    normalized = text.strip().lower().rstrip(".,!?")
    if normalized in REACTIVE_EXACT:
        return "reactive"
    if any(text.lower().startswith(c) for c in CORRECTION_STARTERS):
        return "correction"
    return "directive"


METHOD_REF_RE = re.compile(
    r"[A-Z]\w+::\w+|[A-Z]\w+:\d+|"          # Class::method or Class:line
    r"\b\w+\(\)|"                              # function()
    r"`[A-Z]\w+`|`\$\w+->\w+`"                # `ClassName` or `$obj->method`
)
TEST_REF_RE = re.compile(
    r"test[_/]|_test\.|\.test\.|spec[_/]|_spec\.|\.spec\.",
    re.I,
)


def score_prompt(text, has_pasted):
    """Score task-initiating prompt for specificity (0-11)."""
    score = 0
    signals = []
    if len(text) > 100:
        score += 1
        signals.append("length>100")
    if len(text) > 300:
        score += 1
        signals.append("length>300")
    if FILE_PATH_RE.search(text):
        score += 1
        signals.append("file_paths")
    if has_pasted:
        score += 1
        signals.append("pasted_content")
    if "\n\n" in text or re.search(r"^\s*[\d]+\.", text, re.M):
        score += 1
        signals.append("structure")
    if re.search(r"^\s*[-*] ", text, re.M):
        score += 1
        signals.append("bullet_list")
    if any(p in text.lower() for p in SPEC_PHRASES[:4]):
        score += 1
        signals.append("acceptance_criteria")
    if any(w in text.lower() for w in ["don't", "avoid", "without", "only if", "never"]):
        score += 1
        signals.append("constraints")
    if CODE_BLOCK_RE.search(text):
        score += 1
        signals.append("code_blocks")
    if METHOD_REF_RE.search(text):
        score += 1
        signals.append("method_reference")
    if TEST_REF_RE.search(text):
        score += 1
        signals.append("test_reference")
    return score, signals


def specificity_bucket(score):
    if score <= 1:
        return "vague"
    if score <= 3:
        return "moderate"
    if score <= 5:
        return "specific"
    return "exemplary"  # 6+ signals


def classify_task_type(text):
    """Classify task as 'operational', 'exploration', or 'implementation'."""
    if OPERATIONAL_PATTERNS.search(text):
        return "operational"
    if EXPLORATION_START.search(text) or EXPLORATION_CONTAINS.search(text):
        return "exploration"
    return "implementation"


def segment_tasks(entries):
    """Split entries into tasks. Task = prompts between commit boundaries within a session."""
    sessions = defaultdict(list)
    for e in entries:
        sessions[e["sessionId"]].append(e)

    tasks = []
    for sid, prompts in sessions.items():
        prompts.sort(key=lambda x: x["timestamp"])
        current_task = []
        is_first_task = True
        session_has_reviewed = False  # carries forward within session
        for p in prompts:
            current_task.append(p)
            if p["display"].startswith("/commit"):
                task = _build_task(
                    current_task, ended_with_commit=True,
                    is_cold_start=is_first_task)
                # Carry forward: if prior segment in this session had review, inherit
                if session_has_reviewed and not task["had_code_review"]:
                    task["had_code_review"] = True
                    task["session_carry_review"] = True
                if task["had_code_review"]:
                    session_has_reviewed = True
                tasks.append(task)
                current_task = []
                is_first_task = False
        if current_task:
            has_directives = any(
                classify_prompt(pp["display"]) == "directive" for pp in current_task
            )
            if has_directives:
                task = _build_task(
                    current_task, ended_with_commit=False,
                    is_cold_start=is_first_task)
                if session_has_reviewed and not task["had_code_review"]:
                    task["had_code_review"] = True
                    task["session_carry_review"] = True
                tasks.append(task)
    return tasks


def _build_task(prompts, ended_with_commit, is_cold_start=True):
    """Build task dict from prompt list."""
    classified = [(p, classify_prompt(p["display"])) for p in prompts]

    # Find initiating prompt: first directive, or first non-command
    initiating = None
    for p, cls in classified:
        if cls == "directive":
            initiating = p
            break
    if not initiating:
        for p, cls in classified:
            if cls != "command":
                initiating = p
                break

    directives = [p for p, c in classified if c == "directive"]
    reactives = [p for p, c in classified if c == "reactive"]
    corrections = [p for p, c in classified if c == "correction"]
    commands = [p for p, c in classified if c == "command"]
    cmd_names = [p["display"].split()[0] for p in commands if p["display"].startswith("/")]

    has_pasted = bool(initiating and initiating.get("pastedContents")
                      and len(initiating["pastedContents"]) > 0)
    init_text = initiating["display"] if initiating else ""
    task_type = classify_task_type(init_text)
    spec_score, spec_signals = score_prompt(init_text, has_pasted) if initiating else (0, [])

    return {
        "initiating_prompt": init_text,
        "initiating_prompt_pasted": has_pasted,
        "task_type": task_type,
        "is_cold_start": is_cold_start,
        "specificity_score": spec_score,
        "specificity_signals": spec_signals,
        "specificity_bucket": specificity_bucket(spec_score),
        "prompt_count": len([p for p, c in classified if c != "command"]),
        "directive_count": len(directives),
        "reactive_count": len(reactives),
        "correction_count": len(corrections),
        "ended_with_commit": ended_with_commit,
        "had_code_review": (
            any(c in cmd_names for c in
                ["/code-review", "/comment", "/code-review-pr",
                 "/code-review-pr-inline", "/review-pr"])
            or any(
                ".dk-notes/reviews/" in p["display"]
                or ".ai-artifacts/review_" in p["display"]
                or ".reviews/" in p["display"]
                for p, c in classified if c == "directive"
            )
        ),
        "had_tdd": any(
            any(phrase in p["display"].lower() for phrase in TDD_PHRASES)
            for p, c in classified if c in ("directive", "command")
        ),
        "had_spec_language": any(
            phrase in init_text.lower() for phrase in SPEC_PHRASES[:4]
        ) if initiating else False,
        "project": prompts[0].get("project", "?").split("/")[-1],
        "session_id": prompts[0].get("sessionId", ""),
        "ts_start": prompts[0]["timestamp"],
        "ts_end": prompts[-1]["timestamp"],
        "correction_texts": [p["display"][:200] for p in corrections],
    }


def generate_recommendations(metrics):
    """Generate dynamic recommendations based on detected patterns."""
    recs = []

    if metrics["methodology"]["spec_driven_rate"] < 30:
        recs.append({
            "type": "concept", "title": "Spec-Driven Development",
            "data_trigger": f"spec_driven_rate: {metrics['methodology']['spec_driven_rate']}%",
            "impact": 9,
        })
    if metrics["methodology"]["tdd_adherence_rate"] < 30:
        recs.append({
            "type": "command", "title": "/bug and /tdd commands",
            "data_trigger": f"tdd_adherence_rate: {metrics['methodology']['tdd_adherence_rate']}%",
            "impact": 8,
        })
    if metrics["methodology"]["review_discipline_rate"] < 70:
        recs.append({
            "type": "workflow", "title": "Review-before-commit pipeline",
            "data_trigger": f"review_discipline_rate: {metrics['methodology']['review_discipline_rate']}%",
            "impact": 7,
        })
    if metrics["task_effectiveness"]["correction_density"] > 0.5:
        recs.append({
            "type": "concept", "title": "Front-loading context",
            "data_trigger": f"correction_density: {metrics['task_effectiveness']['correction_density']}",
            "impact": 9,
        })
    if metrics["prompt_quality"]["context_provision_score"] < 40:
        recs.append({
            "type": "concept", "title": "Context-rich prompts",
            "data_trigger": f"context_provision_score: {metrics['prompt_quality']['context_provision_score']}%",
            "impact": 8,
        })
    if metrics["task_effectiveness"]["back_and_forth_ratio"] > 0.25:
        recs.append({
            "type": "concept", "title": "Directive prompting",
            "data_trigger": f"back_and_forth_ratio: {metrics['task_effectiveness']['back_and_forth_ratio']}",
            "impact": 7,
        })

    # Command-specific: check if command exists but unused
    cmd_breakdown = metrics.get("slash_commands", {}).get("breakdown", {})
    unused_cmds = {
        "/test-cover": ("command", "Add tests before refactoring", 6),
        "/refactor": ("command", "Safe refactoring with test validation", 6),
        "/describe-pr": ("command", "Auto-generate PR descriptions", 5),
        "/explain": ("command", "Visual HTML explanations for complex code", 5),
        "/bug": ("command", "TDD bug-fix workflow", 7),
        "/stash": ("command", "Save WIP with conventional naming", 4),
    }
    for cmd, (typ, title, impact) in unused_cmds.items():
        if cmd_breakdown.get(cmd, 0) <= 1:
            recs.append({
                "type": typ, "title": f"{cmd} — {title}",
                "data_trigger": f"{cmd} used {cmd_breakdown.get(cmd, 0)} times",
                "impact": impact,
            })

    recs.sort(key=lambda r: r["impact"], reverse=True)
    return recs[:5]


def _per_project_stats(tasks, committed_tasks):
    """Per-project effectiveness breakdown."""
    proj_tasks = defaultdict(list)
    proj_committed = defaultdict(list)
    for t in tasks:
        if t["task_type"] == "implementation":
            proj_tasks[t["project"]].append(t)
    for t in committed_tasks:
        proj_committed[t["project"]].append(t)

    result = {}
    for proj, ptasks in proj_tasks.items():
        ct = proj_committed.get(proj, [])
        ct_count = len(ct) or 1
        pt_count = len(ptasks) or 1
        spec_dist = Counter(t["specificity_bucket"] for t in ptasks)
        result[proj] = {
            "impl_tasks": len(ptasks),
            "commits": len(ct),
            "vague_pct": round(spec_dist.get("vague", 0) / pt_count * 100),
            "avg_specificity": round(
                sum(t["specificity_score"] for t in ptasks) / pt_count, 1),
            "one_shot_rate": round(
                sum(1 for t in ct
                    if t["directive_count"] <= 1 and t["correction_count"] == 0)
                / ct_count * 100, 1) if ct else None,
            "review_rate": round(
                sum(1 for t in ct if t["had_code_review"])
                / ct_count * 100, 1) if ct else None,
        }
    return result


def _period_halves(entries, tasks, committed_tasks, dates):
    """Split period in half for within-period trend analysis."""
    if len(dates) < 2:
        return None
    midpoint = min(dates) + (max(dates) - min(dates)) / 2
    mid_ts = midpoint.timestamp() * 1000

    def half_metrics(half_entries, half_tasks, half_committed):
        ht_count = len(half_tasks) or 1
        hc_count = len(half_committed) or 1
        impl = [t for t in half_tasks if t["task_type"] == "implementation"]
        impl_count = len(impl) or 1
        return {
            "prompts": len(half_entries),
            "tasks": len(half_tasks),
            "commits": len(half_committed),
            "one_shot_rate": round(
                sum(1 for t in half_committed
                    if t["directive_count"] <= 1 and t["correction_count"] == 0)
                / hc_count * 100, 1),
            "avg_specificity": round(
                sum(t["specificity_score"] for t in impl) / impl_count, 1),
            "review_rate": round(
                sum(1 for t in half_committed if t["had_code_review"])
                / hc_count * 100, 1),
        }

    # Split entries by midpoint, re-segment each half independently
    e1 = [e for e in entries if e["timestamp"] < mid_ts]
    e2 = [e for e in entries if e["timestamp"] >= mid_ts]
    t1 = segment_tasks(e1) if e1 else []
    t2 = segment_tasks(e2) if e2 else []
    c1 = [t for t in t1 if t["ended_with_commit"]]
    c2 = [t for t in t2 if t["ended_with_commit"]]

    return {
        "midpoint": midpoint.strftime("%Y-%m-%d"),
        "first_half": half_metrics(e1, t1, c1),
        "second_half": half_metrics(e2, t2, c2),
    }


def analyze(entries):
    if not entries:
        return {"error": "No entries to analyze."}
    dates = [datetime.fromtimestamp(e["timestamp"] / 1000) for e in entries]
    projects = Counter(e.get("project", "?").split("/")[-1] for e in entries)
    day_counts = Counter(d.strftime("%Y-%m-%d") for d in dates)

    # Slash commands
    slash = [e for e in entries if e["display"].startswith("/")]
    cmd_counts = Counter(e["display"].split()[0] for e in slash)

    # Per-project commands
    proj_cmds = defaultdict(Counter)
    for e in entries:
        proj = e.get("project", "?").split("/")[-1]
        if e["display"].startswith("/"):
            proj_cmds[proj][e["display"].split()[0]] += 1

    # Task analysis
    tasks = segment_tasks(entries)
    committed_tasks = [t for t in tasks if t["ended_with_commit"]]
    total_non_cmd = sum(t["prompt_count"] for t in tasks)
    total_reactive = sum(t["reactive_count"] for t in tasks)
    total_corrections = sum(t["correction_count"] for t in tasks)

    # Cross-session review detection: for commits without in-segment review,
    # check if another session for same project has review activity on the same day
    # (user keeps separate impl + review sessions open per project)
    review_tasks_by_proj_day = defaultdict(set)
    for t in tasks:
        if t["had_code_review"]:
            day = datetime.fromtimestamp(t["ts_start"] / 1000).strftime("%Y-%m-%d")
            review_tasks_by_proj_day[(t["project"], day)].add(t["session_id"])

    for ct in committed_tasks:
        if not ct["had_code_review"]:
            day = datetime.fromtimestamp(ct["ts_start"] / 1000).strftime("%Y-%m-%d")
            review_sids = review_tasks_by_proj_day.get((ct["project"], day), set())
            if review_sids - {ct["session_id"]}:
                ct["had_code_review"] = True
                ct["cross_session_review"] = True

    # One-shot: 1 directive + 0 corrections + any reactives
    one_shot = [t for t in committed_tasks
                if t["directive_count"] <= 1 and t["correction_count"] == 0]

    # Filter: only implementation tasks count for specificity scoring
    impl_tasks = [t for t in tasks if t["task_type"] == "implementation"]
    impl_committed = [t for t in committed_tasks if t["task_type"] == "implementation"]

    # Task type distribution
    type_dist = Counter(t["task_type"] for t in tasks)

    # Specificity distribution (implementation only — operational/exploration excluded)
    spec_dist = Counter(t["specificity_bucket"] for t in impl_tasks)

    # Context provision (implementation only)
    impl_count = len(impl_tasks) or 1
    context_prompts = [t for t in impl_tasks if (
        "file_paths" in t["specificity_signals"]
        or t["initiating_prompt_pasted"]
        or "code_blocks" in t["specificity_signals"]
    )]

    # Best/worst prompts (implementation tasks only, skip follow-ups for worst)
    scoreable = [t for t in impl_committed
                 if t["initiating_prompt"] and len(t["initiating_prompt"]) > 20]

    def quality_rank(t):
        outcome = max(0, 3 - t["correction_count"]) + max(0, 3 - t["prompt_count"])
        return t["specificity_score"] * 2 + outcome * 3

    scoreable.sort(key=quality_rank, reverse=True)
    best = scoreable[:5] if scoreable else []
    scoreable.sort(key=quality_rank)
    # For worst: prefer cold-start impl tasks. Fall back to non-cold-start if needed,
    # but flag them — mid-session prompts may be contextually appropriate.
    cold_worst = [t for t in scoreable
                  if t["specificity_score"] <= 2 and t["is_cold_start"]]
    warm_worst = [t for t in scoreable
                  if t["specificity_score"] <= 1 and not t["is_cold_start"]]
    worst = (cold_worst + warm_worst)[:5]

    # Anti-patterns (implementation tasks only)
    anti_patterns = {
        "vague_initiator": sum(1 for t in impl_tasks
                               if t["specificity_bucket"] == "vague"),
        "missing_file_context": sum(1 for t in impl_tasks
                                    if "file_paths" not in t["specificity_signals"]
                                    and len(t["initiating_prompt"]) > 30),
        "missing_acceptance_criteria": sum(1 for t in impl_tasks
                                          if "acceptance_criteria" not in t["specificity_signals"]
                                          and len(t["initiating_prompt"]) > 30),
        "reactive_chain": sum(1 for t in tasks if t["reactive_count"] >= 3),
        "no_review_before_commit": sum(1 for t in committed_tasks if not t["had_code_review"]),
    }

    # Build metrics dict (needed by recommendations)
    committed_count = len(committed_tasks) or 1
    tasks_count = len(tasks) or 1

    metrics = {
        "overview": {
            "period_start": min(dates).strftime("%Y-%m-%d"),
            "period_end": max(dates).strftime("%Y-%m-%d"),
            "total_prompts": len(entries),
            "total_tasks": len(tasks),
            "committed_tasks": len(committed_tasks),
            "total_commits": len(committed_tasks),
            "active_days": len(day_counts),
        },
        "task_effectiveness": {
            "one_shot_rate": round(len(one_shot) / committed_count * 100, 1),
            "correction_density": round(total_corrections / tasks_count, 2),
            "avg_prompts_per_task": round(total_non_cmd / tasks_count, 1),
            "median_prompts_per_task": sorted(
                [t["prompt_count"] for t in tasks]
            )[len(tasks) // 2] if tasks else 0,
            "efficiency_ratio": round(len(committed_tasks) / max(total_non_cmd, 1) * 10, 2),
            "back_and_forth_ratio": round(total_reactive / max(total_non_cmd, 1), 2),
            "tasks_by_prompt_count": {
                "1": sum(1 for t in tasks if t["prompt_count"] == 1),
                "2-3": sum(1 for t in tasks if 2 <= t["prompt_count"] <= 3),
                "4-6": sum(1 for t in tasks if 4 <= t["prompt_count"] <= 6),
                "7-10": sum(1 for t in tasks if 7 <= t["prompt_count"] <= 10),
                "10+": sum(1 for t in tasks if t["prompt_count"] > 10),
            },
        },
        "prompt_quality": {
            "context_provision_score": round(
                len(context_prompts) / impl_count * 100, 1),
            "structure_score": round(
                sum(1 for t in impl_tasks
                    if "structure" in t["specificity_signals"]
                    or "bullet_list" in t["specificity_signals"])
                / impl_count * 100, 1),
            "specificity_distribution": {
                "vague": spec_dist.get("vague", 0),
                "moderate": spec_dist.get("moderate", 0),
                "specific": spec_dist.get("specific", 0),
                "exemplary": spec_dist.get("exemplary", 0),
            },
            "avg_initiating_prompt_length": round(
                sum(len(t["initiating_prompt"]) for t in impl_tasks)
                / impl_count
            ),
            "impl_tasks": len(impl_tasks),
            "task_type_distribution": dict(type_dist),
        },
        "methodology": {
            "tdd_adherence_rate": round(
                sum(1 for t in tasks if t["had_tdd"]) / tasks_count * 100, 1),
            "review_discipline_rate": round(
                sum(1 for t in committed_tasks if t["had_code_review"])
                / committed_count * 100, 1),
            "spec_driven_rate": round(
                sum(1 for t in tasks if t["had_spec_language"])
                / tasks_count * 100, 1),
        },
        "prompt_exemplars": {
            "best": [{
                "prompt": t["initiating_prompt"][:500],
                "specificity_score": t["specificity_score"],
                "specificity_signals": t["specificity_signals"],
                "bucket": t["specificity_bucket"],
                "task_type": t["task_type"],
                "prompt_count": t["prompt_count"],
                "corrections": t["correction_count"],
                "project": t["project"],
            } for t in best],
            "worst": [{
                "prompt": t["initiating_prompt"][:500],
                "specificity_score": t["specificity_score"],
                "specificity_signals": t["specificity_signals"],
                "missing_signals": [s for s in
                                    ["file_paths", "acceptance_criteria", "constraints",
                                     "structure", "pasted_content"]
                                    if s not in t["specificity_signals"]],
                "bucket": t["specificity_bucket"],
                "task_type": t["task_type"],
                "is_cold_start": t["is_cold_start"],
                "prompt_count": t["prompt_count"],
                "corrections": t["correction_count"],
                "correction_texts": t["correction_texts"][:3],
                "project": t["project"],
            } for t in worst],
        },
        "anti_patterns": anti_patterns,
        "slash_commands": {
            "total": len(slash),
            "pct_of_prompts": round(len(slash) / len(entries) * 100, 1),
            "breakdown": dict(cmd_counts.most_common()),
        },
        "commands_per_project": {
            proj: dict(proj_cmds[proj].most_common(5))
            for proj in sorted(proj_cmds)
        },
        "projects": dict(projects.most_common()),
        "per_project": _per_project_stats(tasks, committed_tasks),
        "period_halves": _period_halves(entries, tasks, committed_tasks, dates),
        "trends_data": {
            "one_shot_rate": round(len(one_shot) / committed_count * 100, 1),
            "correction_density": round(total_corrections / tasks_count, 2),
            "context_provision_score": round(
                len(context_prompts) / impl_count * 100, 1),
            "structure_score": round(
                sum(1 for t in impl_tasks
                    if "structure" in t["specificity_signals"]
                    or "bullet_list" in t["specificity_signals"])
                / impl_count * 100, 1),
            "tdd_adherence_rate": round(
                sum(1 for t in tasks if t["had_tdd"]) / tasks_count * 100, 1),
            "review_discipline_rate": round(
                sum(1 for t in committed_tasks if t["had_code_review"])
                / committed_count * 100, 1),
            "spec_driven_rate": round(
                sum(1 for t in tasks if t["had_spec_language"])
                / tasks_count * 100, 1),
            "efficiency_ratio": round(len(committed_tasks) / max(total_non_cmd, 1) * 10, 2),
            "avg_initiating_prompt_length": round(
                sum(len(t["initiating_prompt"]) for t in tasks)
                / tasks_count
            ),
            "back_and_forth_ratio": round(total_reactive / max(total_non_cmd, 1), 2),
        },
    }

    metrics["recommendations"] = generate_recommendations(metrics)
    return metrics


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
