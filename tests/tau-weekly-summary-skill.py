"""Check the installed skill's report example and classification contract.

These are source-contract tests, not tests of an LLM's classification behavior.
"""

from pathlib import Path
import re
import sys
import unittest


SKILL = Path(sys.argv.pop(1)).read_text()
EXAMPLE = SKILL.split("```markdown\n", 1)[1].split("\n```", 1)[0]


class WeeklySummarySkillTests(unittest.TestCase):
    def test_each_section_has_all_categories_in_order(self):
        for section in ("Pull requests", "Issues"):
            body = EXAMPLE.split(f"## {section}\n", 1)[1].split("\n## ", 1)[0]
            self.assertEqual(
                re.findall(r"^### (.+)$", body, re.MULTILINE),
                ["done", "updated", "abandoned", "unimportant"],
            )
            for category in ("done", "abandoned", "unimportant"):
                self.assertIn(f"### {category}\n\nNone.", body)

    def test_example_items_are_unique_and_nested_under_updated(self):
        entries = re.findall(r"^#### \[#(\d+)", EXAMPLE, re.MULTILINE)
        self.assertEqual(entries, ["123", "124"])
        self.assertEqual(len(entries), len(set(entries)))
        self.assertNotRegex(EXAMPLE, r"^### \[#")
        for number in entries:
            self.assertIn(f"### updated\n\n#### [#{number}", EXAMPLE)
        self.assertIn("Coverage: 1 issue and 1 PR", EXAMPLE)

    def test_significance_and_outcome_examples(self):
        rows = dict(re.findall(r"^\| (.+) \| (done|updated|abandoned|unimportant) \|$",
                               SKILL, re.MULTILINE))
        self.assertEqual(rows, {
            "Substantive PR fix, now merged": "done",
            "Issue diagnosis, fix verified and issue closed as resolved": "done",
            "PR implementation/review, still open with work remaining": "updated",
            "Issue discussion establishes a reproducer, still open": "updated",
            "Substantive PR proposal, closed unmerged without completion": "abandoned",
            "Meaningful issue investigation, explicitly closed without resolution": "abandoned",
            "Important PR has only a routine rebase this window": "unimportant",
            "Issue has only a routine machine label update this window": "unimportant",
            "Automated PR fixes a substantive regression, now merged": "done",
            "Issue closed as duplicate, linked fix verifies completion": "done",
            "Meaningful work reopened after earlier closure, now incomplete": "updated",
        })

    def test_coverage_and_uncertainty_contract(self):
        for instruction in (
            "Assign every item with observed in-window activity to exactly one subsection",
            "Apply significance before outcome",
            "If completion or closure happened after the window, explicitly distinguish",
            "record the uncertainty and follow the existing incomplete-evidence publication",
            "Keep both sections and all four subsections even when empty",
            "Count unimportant entries in coverage; do not omit or duplicate them",
            "placement per active item, and evidence for each significance/outcome decision",
        ):
            self.assertIn(instruction, SKILL.replace("\n", " "))


unittest.main()
