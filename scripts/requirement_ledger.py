# Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
"""Validate one-to-one formal ID/definition bindings, without changing requirements."""
import re

CATEGORY_COUNTS = {"R": 17, "T": 22, "U": 13, "S": 8, "J": 8, "UAT": 15}
EXPECTED_IDS = {f"{category}{index:02d}" for category, count in CATEGORY_COUNTS.items() for index in range(1, count + 1)}
SPEC_PATH = "docs/PDFno_AI_Development_Spec_v0.3_Native.md"
ROW_ID = re.compile(r"^\|\s*((?:R|T|U|S|J|UAT)\d{2})(?:\s+[^|]*)?\s*\|")


def validate_requirement_ledger(ledger, spec):
    failures = []
    rows = {}
    for number, line in enumerate(spec.splitlines(), 1):
        match = ROW_ID.match(line)
        if not match:
            continue
        identifier = match.group(1)
        if identifier in rows:
            failures.append("Duplicate formal specification definition: " + identifier)
        rows[identifier] = (number, line)
    if set(rows) != EXPECTED_IDS:
        failures.append("Formal specification differs from the 83 preserved IDs")
    if not isinstance(ledger, dict):
        return failures + ["Invalid requirement ledger"]
    if ledger.get("spec") != SPEC_PATH:
        failures.append("Unexpected canonical specification path")
    counts = ledger.get("categoryCounts")
    if (type(ledger.get("formalCount")) is not int or ledger["formalCount"] != len(EXPECTED_IDS)
            or not isinstance(counts, dict) or counts != CATEGORY_COUNTS
            or any(type(value) is not int for value in counts.values())):
        failures.append("Formal requirement/category counts differ from the preserved definitions")
    items = ledger.get("items")
    if not isinstance(items, list) or any(not isinstance(item, dict) or not isinstance(item.get("id"), str) for item in items):
        return failures + ["Invalid formal requirement items"]
    identifiers = [item["id"] for item in items]
    if len(identifiers) != len(EXPECTED_IDS) or len(set(identifiers)) != len(identifiers) or set(identifiers) != EXPECTED_IDS:
        failures.append("Formal requirement ledger differs from the 83 preserved IDs")
    seen_rows = set()
    for item in items:
        identifier = item["id"]
        definition = item.get("specRow")
        expected = rows.get(identifier)
        if expected is None or definition != expected[1]:
            failures.append("Requirement ID/definition binding differs: " + identifier)
        if expected is None or type(item.get("specLine")) is not int or item["specLine"] != expected[0]:
            failures.append("Requirement definition line differs: " + identifier)
        if not isinstance(definition, str) or definition in seen_rows:
            failures.append("Duplicate or invalid ledger definition: " + identifier)
        else:
            seen_rows.add(definition)
    return failures
