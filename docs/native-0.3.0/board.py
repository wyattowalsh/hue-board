#!/usr/bin/env python3
"""Print an offline HTML viewer for the adjacent, validated task graph."""

import json
from pathlib import Path

from graph import closure, read_graph


def graph_data(path):
    tasks = read_graph(path)
    core = closure(tasks, "Q99")
    return [
        {
            "id": row.id, "lane": row.lane, "scope": "Core" if row.id in core else "Optional",
            "requires": sorted(row.requires), "locks": sorted(row.locks), "title": row.task,
            "acceptance": row.acceptance, "area": row.area, "evidence": row.evidence,
        }
        for row in tasks.values()
    ]


PAGE = r'''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Hue Board 0.3.0 · Task graph</title>
<style>
:root { color-scheme:light; --ink:#202a32; --muted:#465664; --line:#c7ced3; --blue:#174c72;
  --surface:#fff; --canvas:#f4f5f2; --active:#e4eff5; font:100%/1.5 "Atkinson Hyperlegible Next",system-ui,sans-serif }
* { box-sizing:border-box }
body { max-width:90rem; margin:auto; padding:clamp(.8rem,3vw,2.5rem); color:var(--ink); background:var(--canvas) }
h1,h2,h3,p,dl,dd { margin:0 }
header { display:flex; align-items:baseline; flex-wrap:wrap; gap:.25rem .9rem; margin-bottom:1.25rem }
h1 { font-size:clamp(1.55rem,3vw,2.15rem); letter-spacing:-.035em }
header p,.meta,.counts,dt,label { color:var(--muted) }
main { display:grid; grid-template-columns:minmax(19rem,26rem) minmax(0,1fr); gap:1.1rem; align-items:start }
nav,article { min-width:0; background:var(--surface); border:1px solid var(--line); border-radius:.65rem }
nav { padding:1rem }
article { padding:clamp(1rem,3vw,2rem); scroll-margin-top:.5rem; overflow-wrap:anywhere }
.filters { display:grid; grid-template-columns:minmax(0,1fr) minmax(0,1fr); gap:.5rem .75rem }
.filters label:first-child { grid-column:1/-1 }
label,dt { font-size:.9rem; font-weight:650 }
input,select,button { font:inherit; color:var(--ink); background:var(--surface); border:1px solid #8796a0; border-radius:.35rem }
input,select { display:block; width:100%; min-height:2.75rem; padding:.4rem .55rem }
button { cursor:pointer; padding:.45rem .7rem }
button:hover,a:hover { background:var(--active) }
:focus-visible { outline:3px solid #6a3682; outline-offset:2px }
.counts { display:flex; justify-content:space-between; align-items:center; margin:.75rem 0; gap:.4rem; font-size:.9rem }
.results { max-height:clamp(18rem,58vh,46rem); overflow:auto; padding:.25rem }
.results a { display:grid; grid-template-columns:4em minmax(0,1fr); gap:.35rem; padding:.55rem .3rem;
  align-items:baseline; border-top:1px solid var(--line); text-decoration:none; color:var(--ink) }
.results a[aria-current] { background:var(--active); box-shadow:inset .19rem 0 var(--blue); padding-left:.5rem }
.key { color:var(--blue); font:600 .86rem/1.5 "IBM Plex Mono",monospace }
.meta { margin-bottom:.4rem }
h2 { font-size:clamp(1.25rem,2.5vw,1.7rem); line-height:1.25; max-width:60ch }
dl { margin-top:1rem }
dt { margin-top:.8rem }
dd { max-width:78ch }
h3 { font-size:1rem; margin-top:1.25rem }
.edges { display:flex; flex-wrap:wrap; align-items:center; gap:.35rem; margin-top:.35rem }
.edges a { color:var(--blue); border:1px solid var(--line); border-radius:.35rem; padding:.35rem .65rem; text-decoration:underline }
@media(max-width:46rem) { main { grid-template-columns:1fr } .results { max-height:12rem } header { margin-bottom:.75rem } }
</style></head>
<body><header><h1>Hue Board 0.3.0</h1><p id="summary">Task graph</p></header>
<main><nav aria-label="Find a task">
<div class="filters">
<label>Search tasks<input type="search" id="query" placeholder="ID, task, file or receipt"></label>
<label>Workstream<select id="lane"><option value="">All workstreams</option></select></label>
<label>Scope<select id="scope"><option value="">Core and optional</option><option>Core</option><option>Optional</option></select></label>
</div>
<div class="counts"><output id="count" aria-live="polite"></output><button type="button" id="clear">Clear filters</button></div>
<div id="results" class="results"></div></nav>
<article aria-labelledby="title"><p id="meta" class="meta"></p><h2 id="title" tabindex="-1"></h2>
<dl><dt>Acceptance</dt><dd id="acceptance"></dd><dt>Evidence to retain</dt><dd id="evidence"></dd>
<dt>Work area</dt><dd id="area"></dd><dt>Exclusive resources</dt><dd id="locks"></dd></dl>
<h3>Direct prerequisites</h3><div id="requires" class="edges"></div>
<h3>Direct dependents</h3><div id="dependents" class="edges"></div></article></main>
<noscript>Enable JavaScript to browse the task graph, or read the adjacent tasks.tsv file.</noscript>
<script type="application/json" id="graph">__GRAPH_JSON__</script>
<script>
"use strict";
const get = id => document.getElementById(id);
const tasks = JSON.parse(get("graph").textContent);
const byId = new Map(tasks.map(task => [task.id, task]));
const dependents = new Map(tasks.map(task => [task.id, []]));
for (const task of tasks) for (const dependency of task.requires) dependents.get(dependency).push(task.id);
const coreCount = tasks.filter(task => task.scope === "Core").length;
get("summary").textContent = `Task graph · ${coreCount} core · ${tasks.length - coreCount} optional`;
const laneTitle = lane => lane.split("-").join(" ");
for (const lane of [...new Set(tasks.map(task => task.lane))].sort()) {
  get("lane").add(new Option(laneTitle(lane), lane));
}
const searchIndex = new Map(tasks.map(task => [
  task.id, Object.values(task).flat().join(" ").toLowerCase()
]));
let selected;

function taskLink(id, full) {
  const task = byId.get(id);
  const link = document.createElement("a");
  link.href = "#task=" + encodeURIComponent(id);
  const key = document.createElement("span");
  key.className = "key";
  key.textContent = id;
  link.append(key);
  if (full) {
    const name = document.createElement("span");
    name.textContent = task.title;
    link.append(name);
    if (id === selected) link.setAttribute("aria-current", "true");
  } else {
    link.setAttribute("aria-label", id + " · " + task.title);
    link.title = task.title;
  }
  return link;
}

function filterTasks() {
  const words = get("query").value.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const lane = get("lane").value;
  const scope = get("scope").value;
  const matches = tasks.filter(task => (!lane || lane === task.lane)
    && (!scope || scope === task.scope) && words.every(word => searchIndex.get(task.id).includes(word)));
  get("count").textContent = matches.length + (matches.length === 1 ? " task" : " tasks");
  const results = get("results");
  results.replaceChildren(...matches.map(task => taskLink(task.id, true)));
  if (!matches.length) results.textContent = "No matching tasks. Try clearing a filter.";
}

function showEdges(element, ids) {
  element.replaceChildren(...ids.map(id => taskLink(id, false)));
  if (!ids.length) element.textContent = "None";
}

function showTask(focus) {
  const id = new URLSearchParams(location.hash.slice(1)).get("task");
  const task = byId.get(id) || tasks[0];
  selected = task.id;
  get("meta").textContent = [selected, laneTitle(task.lane), task.scope].join(" · ");
  get("title").textContent = task.title;
  for (const field of ["acceptance", "area", "evidence"]) get(field).textContent = task[field];
  get("locks").textContent = task.locks.join(", ");
  showEdges(get("requires"), task.requires);
  showEdges(get("dependents"), dependents.get(selected));
  for (const link of get("results").querySelectorAll("a")) {
    if (link.hash === "#task=" + encodeURIComponent(selected)) link.setAttribute("aria-current", "true");
    else link.removeAttribute("aria-current");
  }
  if (focus) get("title").focus();
}

for (const id of ["query", "lane", "scope"]) get(id).addEventListener("input", filterTasks);
get("clear").addEventListener("click", () => {
  for (const id of ["query", "lane", "scope"]) get(id).value = "";
  filterTasks();
  get("query").focus();
});
window.addEventListener("hashchange", () => showTask(true));
document.addEventListener("click", event => {
  const link = event.target.closest("a");
  if (link && link.hash === location.hash) get("title").focus();
});
filterTasks();
showTask(false);
</script></body></html>'''


def render(path):
    # Raw-text script elements cannot contain a literal HTML closing tag, even in JSON strings.
    payload = json.dumps(graph_data(path), ensure_ascii=True, separators=(",", ":"))
    escaped = payload.translate(str.maketrans({"<": r"\u003c", ">": r"\u003e", "&": r"\u0026"}))
    return PAGE.replace("__GRAPH_JSON__", escaped)


if __name__ == "__main__":
    print(render(Path(__file__).with_name("tasks.tsv")))
