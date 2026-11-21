#!/usr/bin/env python3
"""Inspect the adjacent 0.3.0 task graph. Requires Python 3.9 or later."""

import argparse
from dataclasses import dataclass
from graphlib import CycleError, TopologicalSorter
from pathlib import Path
import sys


HEADER = "id lane requires locks task acceptance area evidence".split()
GRAPH_FILE = Path(__file__).with_name("tasks.tsv")
DEFAULT_SLOTS = 6


@dataclass(frozen=True)
class Task:
    id: str
    lane: str
    requires: frozenset
    locks: frozenset
    task: str
    acceptance: str
    area: str
    evidence: str


def tokens(value, label):
    if not value:
        return frozenset()
    items = [item.strip() for item in value.split(",")]
    if any(not item or item == "-" for item in items):
        raise ValueError(f"{label} contains an empty item or placeholder")
    if len(set(items)) != len(items):
        raise ValueError(f"{label} contains a duplicate item")
    return frozenset(items)


def listed(items):
    return ", ".join(sorted(items)) or "(none)"


def closure(tasks, target):
    if target not in tasks:
        raise ValueError(f"unknown target {target}")
    ancestors = set()
    remaining = [target]
    while remaining:
        key = remaining.pop()
        if key not in ancestors:
            ancestors.add(key)
            remaining.extend(tasks[key].requires)
    return ancestors


def read_graph(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].split("\t") != HEADER:
        raise ValueError(f"expected tab-separated header {' '.join(HEADER)}")
    tasks = {}
    for number, line in enumerate(lines[1:], start=2):
        cells = [cell.strip() for cell in line.split("\t")]
        if len(cells) != len(HEADER):
            raise ValueError(f"line {number} has {len(cells)} columns, expected {len(HEADER)}")
        key, lane, requires, locks, title, acceptance, area, evidence = cells
        for field, value in zip(HEADER, cells):
            if (not value and field != "requires") or value == "-":
                raise ValueError(f"line {number} has an empty or placeholder {field}")
        if "," in key or any(char.isspace() for char in key):
            raise ValueError(f"line {number} has invalid task ID {key!r}")
        if key in tasks:
            raise ValueError(f"duplicate task ID {key} on line {number}")
        tasks[key] = Task(key, lane, tokens(requires, f"{key} requires"),
                          tokens(locks, f"{key} locks"), title, acceptance, area, evidence)

    for task in tasks.values():
        missing = task.requires - tasks.keys()
        if missing:
            raise ValueError(f"{task.id} requires unknown tasks {listed(missing)}")
    try:
        tuple(TopologicalSorter({key: row.requires for key, row in tasks.items()}).static_order())
    except CycleError as error:
        raise ValueError("dependency cycle " + " -> ".join(error.args[1])) from error

    core = closure(tasks, "Q99")
    optional = {key for key in tasks if key.startswith("X")}
    if core & optional:
        raise ValueError(f"Q99 depends on optional tasks {listed(core & optional)}")
    orphans = tasks.keys() - optional - core
    if orphans:
        raise ValueError(f"tasks outside the Q99 dependency chain {listed(orphans)}")
    if optional:
        orphans = optional - closure(tasks, "X99")
        if orphans:
            raise ValueError(f"optional tasks outside the X99 dependency chain {listed(orphans)}")
    return tasks


def positive(raw):
    count = int(raw)
    if count < 1:
        raise argparse.ArgumentTypeError("slots must be a positive integer")
    return count


def fleet_status(tasks, done, active, blocked, slots):
    for label, keys in (("done", done), ("active", active), ("blocked", blocked)):
        unknown = keys - tasks.keys()
        if unknown:
            raise ValueError(f"unknown {label} tasks {listed(unknown)}")
    overlap = (done & active) | (done & blocked) | (active & blocked)
    if overlap:
        raise ValueError(f"conflicting statuses for {listed(overlap)}")
    for key in sorted(done | active):
        missing = tasks[key].requires - done
        if missing:
            raise ValueError(f"{key} needs completed prerequisites {listed(missing)}")
    if len(active) > slots:
        raise ValueError(f"{len(active)} active tasks exceed {slots} slots")
    used = set()
    for key in sorted(active):
        collisions = tasks[key].locks & used
        if collisions:
            raise ValueError(f"active task {key} conflicts on {listed(collisions)}")
        used.update(tasks[key].locks)
    return used


def distances_to_target(tasks, target):
    """Count edges on each task's longest path to the selected target."""
    edges = {key: tasks[key].requires for key in target}
    distances = dict.fromkeys(target, 0)
    for key in reversed(tuple(TopologicalSorter(edges).static_order())):
        for dep in edges[key]:
            distances[dep] = max(distances[dep], distances[key] + 1)
    return distances


def batch(tasks, candidates, used, slots, distances):
    occupied = set(used)
    chosen = []
    for key in sorted(candidates, key=lambda key: (-distances[key], key)):
        if len(chosen) == slots:
            break
        if tasks[key].locks.isdisjoint(occupied):
            chosen.append(key)
            occupied.update(tasks[key].locks)
    return chosen


def ready(tasks, args):
    target = closure(tasks, args.target)
    done, active, blocked = (tokens(getattr(args, label), label) for label in ("done", "active", "blocked"))
    used = fleet_status(tasks, done, active, blocked, args.slots)
    pending = target - done - active
    stalled = {key for key in pending - blocked if closure(tasks, key) & blocked}
    candidates = {key for key in pending - blocked - stalled if tasks[key].requires <= done}
    unavailable = tokens(args.unavailable_locks, "unavailable locks")
    known_locks = {lock for task in tasks.values() for lock in task.locks}
    if unavailable - known_locks:
        raise ValueError(f"unknown unavailable locks {listed(unavailable - known_locks)}")
    unavailable_tasks = {key for key in candidates if tasks[key].locks & unavailable}
    eligible = candidates - unavailable_tasks
    chosen = batch(tasks, eligible, used, args.slots - len(active), distances_to_target(tasks, target))
    print(f"Target {args.target} | {len(done & target)}/{len(target)} complete | "
          f"{len(active)}/{args.slots} slots active")
    print("Startable batch (longest remaining chain by dependency count, then ID):")
    for key in chosen:
        print(f"  {key}  {tasks[key].task}")
    if not chosen:
        print("  (none)")
    print(f"Active across graph: {listed(active)}")
    print(f"Ready, waiting for a slot or lock: {listed(eligible - set(chosen))}")
    print("Waiting for unavailable locks: " + (", ".join(
        f"{key} [{listed(tasks[key].locks & unavailable)}]" for key in sorted(unavailable_tasks)
    ) or "(none)"))
    print(f"Blocked directly in target: {listed(pending & blocked)}")
    print(f"Waiting on a blocked prerequisite: {listed(stalled)}")
    print(f"Waiting on other prerequisites: {listed(pending - blocked - stalled - candidates)}")


def waves(tasks, args):
    target = closure(tasks, args.target)
    distances = distances_to_target(tasks, target)
    done = set()
    wave = 0
    print(f"Target {args.target} | up to {args.slots} workers | longest remaining chain by dependency count, then ID")
    while done != target:
        candidates = {key for key in target - done if tasks[key].requires <= done}
        chosen = batch(tasks, candidates, set(), args.slots, distances)
        wave += 1
        print(f"{wave:02}  {' '.join(chosen)}")
        done.update(chosen)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command")
    sub.add_parser("check", help="validate dependencies, exclusive locks and release targets (default)")
    show = sub.add_parser("show", help="show a task, its prerequisites, locks and evidence")
    show.add_argument("id", metavar="ID")
    select = sub.add_parser("ready", help="select a conflict-free batch using supplied task status")
    for label in ("done", "active", "blocked"):
        select.add_argument("--" + label, default="", metavar="IDS", help=f"comma-separated {label} IDs")
    select.add_argument("--unavailable-locks", default="", metavar="LOCKS",
                        help="comma-separated resources unavailable for new work, e.g. mac-native,phone")
    simulate = sub.add_parser("waves", help="simulate batches from an empty status")
    for action in (select, simulate):
        action.add_argument("--target", default="Q99", metavar="ID", help="target ID (default Q99)")
        action.add_argument("--slots", type=positive, default=DEFAULT_SLOTS, metavar="N",
                            help=f"total worker slots including active tasks (default {DEFAULT_SLOTS})")
    args = parser.parse_args()
    try:
        tasks = read_graph(GRAPH_FILE)
        if args.command in (None, "check"):
            print(f"Valid graph: {len(tasks)} tasks, {len(closure(tasks, 'Q99'))} in core target Q99")
        elif args.command == "show":
            if args.id not in tasks:
                raise ValueError(f"unknown task {args.id}")
            task = tasks[args.id]
            for field in HEADER:
                value = getattr(task, field)
                print(f"{field}: {listed(value) if isinstance(value, frozenset) else value}")
            print(f"direct dependents: {listed(key for key, row in tasks.items() if task.id in row.requires)}")
        elif args.command == "ready":
            ready(tasks, args)
        else:
            waves(tasks, args)
    except (OSError, ValueError) as error:
        print(f"graph: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
