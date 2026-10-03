#!/usr/bin/env python3
# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Functional regressions through the real source guard in a fresh temporary repository."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RequirementLedgerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="PDFno-Ledger-", dir="/tmp")
        cls.root = Path(cls.temporary.name)
        files = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT)
        for name in set(files.split(b"\0")) - {b""}:
            relative = Path(name.decode())
            if not (ROOT / relative).is_file():
                continue
            target = cls.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        env = {**os.environ, "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}
        subprocess.run(["git", "init", "-q", "--template="], cwd=cls.root, env=env, check=True)
        cls.ledger_path = cls.root / "docs/REQUIREMENTS-LEDGER.json"
        cls.original = cls.ledger_path.read_bytes()
        cls.ledger = json.loads(cls.original)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def guard(self):
        return subprocess.run(["python3", "-B", "scripts/check-native-source.py"], cwd=self.root, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def rejected_file(self, path, data, diagnostic):
        original = path.read_bytes()
        try:
            path.write_bytes(data)
            result = self.guard()
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn(diagnostic, result.stdout)
        finally:
            path.write_bytes(original)

    def rejected_ledger(self, mutate, diagnostic):
        value = copy.deepcopy(self.ledger)
        mutate(value)
        self.rejected_file(self.ledger_path, (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode(), diagnostic)

    def test_original_83_definition_ledger_passes(self):
        result = self.guard()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_existing_row_cannot_be_bound_to_another_id(self):
        def duplicate(value):
            value["items"][1]["specRow"] = value["items"][0]["specRow"]
        def swap(value):
            a, b = value["items"][:2]
            a["specRow"], b["specRow"] = b["specRow"], a["specRow"]
        def change(value):
            value["items"][0]["specRow"] += " changed definition"
        for mutate in [duplicate, swap, change]:
            with self.subTest(mutation=mutate.__name__):
                self.rejected_ledger(mutate, "Requirement ID/definition binding differs")

    def test_category_counts_must_match_the_defined_set(self):
        for mutate in [lambda value: value["categoryCounts"].update(R=16, T=23),
                       lambda value: value["categoryCounts"].update(R="17"),
                       lambda value: value["categoryCounts"].update(R=17.0),
                       lambda value: value["categoryCounts"].pop("J"),
                       lambda value: value.update(formalCount=82),
                       lambda value: value.update(formalCount=83.0)]:
            with self.subTest(mutation=mutate):
                self.rejected_ledger(mutate, "Formal requirement/category counts differ")

    def test_missing_extra_and_duplicate_ledger_ids_are_rejected(self):
        def missing(value):
            value["items"].pop()
        def extra(value):
            item = copy.deepcopy(value["items"][0]); item["id"] = "R18"; value["items"].append(item)
        def duplicate(value):
            value["items"][1]["id"] = value["items"][0]["id"]
        for mutate in [missing, extra, duplicate]:
            with self.subTest(mutation=mutate.__name__):
                self.rejected_ledger(mutate, "Formal requirement ledger differs")

    def test_specification_definition_deletion_addition_change_and_duplicate_are_rejected(self):
        path = self.root / self.ledger["spec"]
        spec, row = path.read_text(), self.ledger["items"][0]["specRow"]
        cases = [(spec.replace(row + "\n", "", 1), "Formal specification differs"),
                 (spec + "\n| R18 | Temporary added definition |\n", "Formal specification differs"),
                 (spec.replace(row, row + " changed definition", 1), "Requirement ID/definition binding differs"),
                 (spec + "\n" + row + "\n", "Duplicate formal specification definition")]
        for changed, diagnostic in cases:
            with self.subTest(diagnostic=diagnostic):
                self.rejected_file(path, changed.encode(), diagnostic)

    def test_definition_line_number_is_bound_to_its_id(self):
        self.rejected_ledger(lambda value: value["items"][1].update(specLine=value["items"][0]["specLine"]),
                             "Requirement definition line differs")

    def test_ledger_cannot_redirect_the_canonical_specification(self):
        self.rejected_ledger(lambda value: value.update(spec="docs/different-specification.md"),
                             "Unexpected canonical specification path")

    def test_existing_mutable_action_rule_remains_effective(self):
        path = self.root / ".github/workflows/checks.yml"
        original = path.read_text()
        changed = original.replace("actions/checkout@11d5960a326750d5838078e36cf38b85af677262", "actions/checkout@v4")
        self.assertNotEqual(original, changed)
        self.rejected_file(path, changed.encode(), "Workflow Action must use a full commit SHA")


if __name__ == "__main__":
    unittest.main()
