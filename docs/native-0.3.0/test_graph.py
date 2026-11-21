"""Run with python3 -B docs/native-0.3.0/test_graph.py."""

from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

import board
import graph


def command(path, *args):
    output = StringIO()
    with patch.object(graph, "GRAPH_FILE", path), patch("sys.argv", ["graph.py", *args]), redirect_stdout(output):
        if graph.main() != 0:
            raise AssertionError(f"command failed: {args}")
    return output.getvalue()


class GraphToolTests(unittest.TestCase):
    rows = {
        "B01": ("", "checkout"), "A01": ("B01", "editor"),
        "A02": ("B01", "editor"), "A03": ("B01", "phone"),
        "A04": ("B01", "review"), "Q99": ("A01,A02,A03,A04", "signoff"),
    }

    def fixture(self, **changed):
        tmp = TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        path = Path(tmp.name) / "tasks.tsv"
        lines = ["\t".join(graph.HEADER)]
        for key, (deps, locks) in {**self.rows, **changed}.items():
            lines.append("\t".join((key, "core", deps, locks, key + " work", "accept", "source", "receipt")))
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def test_invalid_edges(self):
        for change, reason in [(("Q99", "editor"), "cycle"), (("missing", "editor"), "unknown tasks")]:
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, reason):
                graph.read_graph(self.fixture(A01=change))

    def test_show(self):
        display = command(self.fixture(), "show", "A01")
        for line in ("requires: B01", "locks: editor", "task: A01 work", "direct dependents: Q99"):
            self.assertIn(line, display.splitlines())

    def test_resource_outage_with_an_active_worker(self):
        display = command(self.fixture(), "ready", "--done", "B01", "--active", "A01",
                          "--unavailable-locks", "phone", "--slots", "2")
        self.assertEqual([line.strip() for line in display.splitlines() if line.startswith("  ")], ["A04  A04 work"])
        self.assertIn("Ready, waiting for a slot or lock: A02", display)
        self.assertIn("Waiting for unavailable locks: A03 [phone]", display)

    def test_longest_chain_breaks_competition_for_one_slot(self):
        display = command(self.fixture(A03=("A02", "phone")), "ready", "--done", "B01", "--slots", "1")
        selected = [line.strip() for line in display.splitlines() if line.startswith("  ")]
        self.assertEqual(selected, ["A02  A02 work"])

    def test_invalid_active_status(self):
        tasks = graph.read_graph(self.fixture())
        for active, slots, message in [({"A01", "A02"}, 2, "conflicts on editor"),
                                       ({"A01", "A03"}, 1, "exceed 1 slots")]:
            with self.subTest(active=active), self.assertRaisesRegex(ValueError, message):
                graph.fleet_status(tasks, {"B01"}, active, set(), slots)

    def test_board_joins_execution_by_id_without_changing_plan(self):
        path = self.fixture()
        original = board.graph_data(path)
        self.assertTrue(all(row["execution"] is None for row in original))
        # Partial ledger, arbitrary status and HTML-like receipt from a source file.
        record = ["A02", "externally-reviewed", "abc1234", "test fixture", "</script>", "device receipt"]
        path.with_name("execution.tsv").write_text("\t".join(board.LEDGER_FIELDS) + "\n" +
                                                  "\t".join(record) + "\n", encoding="utf-8")
        joined = board.graph_data(path)
        for before, after in zip(original, joined, strict=True):
            expected = dict(zip(board.LEDGER_FIELDS[1:], record[1:])) if before["id"] == "A02" else None
            self.assertEqual(after, {**before, "execution": expected})
        self.assertIn(r"\u003c/script\u003e", board.render(path))

    def test_board_rejects_ambiguous_execution_records(self):
        path = self.fixture()
        header = "\t".join(board.LEDGER_FIELDS) + "\n"
        record = "A02\tblocked\tabc1234\ttest fixture\tobservation\tdevice receipt\n"
        for rows, reason in [(record * 2, "duplicate task A02"),
                             (record.replace("A02", "U00"), "unknown or duplicate task U00"),
                             ("A02\tblocked\n", "incomplete execution record")]:
            with self.subTest(reason=reason), self.assertRaisesRegex(ValueError, reason):
                path.with_name("execution.tsv").write_text(header + rows, encoding="utf-8")
                board.graph_data(path)


class ReleaseGraphTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tasks = graph.read_graph(graph.GRAPH_FILE)

    def test_candidate_sequence(self):
        for prior, later in [("Q02", "Q10"), ("Q09", "Q11"), ("Q23", "XQ10"),
                             ("X12", "X13"), ("XQ15", "X13")]:
            with self.subTest(prior=prior, later=later):
                self.assertIn(prior, graph.closure(self.tasks, later))

    def test_independent_targets(self):
        source = graph.closure(self.tasks, "A01")
        self.assertFalse(any("phone" in self.tasks[key].locks for key in source))
        core = graph.closure(self.tasks, "Q99")
        self.assertEqual(core, {key for key in self.tasks if not key.startswith("X")})

    def test_waves_respect_resources_and_prerequisites(self):
        output = command(graph.GRAPH_FILE, "waves", "--target", "X99", "--slots", "4")
        finished = set()
        for line in output.splitlines()[1:]:
            wave = line.split()[1:]
            self.assertLessEqual(len(wave), 4)
            self.assertEqual(len(set(wave)), len(wave))
            self.assertTrue(finished.isdisjoint(wave))
            locks = set()
            for key in wave:
                task = self.tasks[key]
                self.assertTrue(task.requires <= finished, key)
                self.assertTrue(locks.isdisjoint(task.locks), key)
                locks.update(task.locks)
            finished.update(wave)
        self.assertEqual(finished, graph.closure(self.tasks, "X99"))


if __name__ == "__main__":
    unittest.main()
