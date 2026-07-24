#!/usr/bin/env python3
"""
validate_framework.py — DEEPX dx-compiler Agent-Driven Framework Validator

Validates the .deepx/ directory structure, cross-references, domain tags,
and agent routing consistency.

Usage:
    python validate_framework.py [--json] [--verbose] [--deepx-dir PATH]

Categories:
    1. routing_paths    — Agent routing references resolve to existing files
    2. file_tree        — Expected directories and files exist
    3. agent_handoffs   — Agent routes-to targets exist as agent files
    4. skill_sections   — Skills have required sections (phases, gates)
    5. toolset_signatures — Toolsets document required API signatures
    6. memory_domain_tags — Memory entries use valid domain tags
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List


# ── Constants ──────────────────────────────────────────────────────────────

EXPECTED_DIRECTORIES = [
    "agents",
    "skills",
    "instructions",
    "toolsets",
    "memory",
    "scripts",
]

REQUIRED_AGENT_FILES = [
    "dx-compiler-builder.md",
    "dx-model-converter.md",
    "dx-dxnn-compiler.md",
]

REQUIRED_SKILL_FILES = [
    "dx-agent-compiler-convert/SKILL.md",
    "dx-agent-compiler-compile/SKILL.md",
    "dx-agent-compiler-validate/SKILL.md",
]

REQUIRED_INSTRUCTION_FILES = [
    "coding-standards.md",
    "compilation-workflow.md",
]

REQUIRED_TOOLSET_FILES = [
    "dxcom-api.md",
    "dxcom-cli.md",
    "config-schema.md",
]

REQUIRED_MEMORY_FILES = [
    "MEMORY.md",
    "common_pitfalls.md",
]

REQUIRED_SCRIPT_FILES = [
    "validate_framework.py",
]

VALID_DOMAIN_TAGS = {"[UNIVERSAL]", "[DX_COMPILER]", "[QUANTIZATION]"}

PROHIBITED_DOMAIN_TAGS = {"[DX_APP]", "[DX_STREAM]", "[PIPELINE]"}

REQUIRED_SKILL_SECTIONS = [
    "Phase",
    "Validation gate",
]

REQUIRED_TOOLSET_KEYWORDS = {
    "dxcom-api.md": ["compile(", "model", "output_dir", "config"],
    "dxcom-cli.md": ["-m", "-c", "-o", "dxcom"],
    "config-schema.md": ["inputs", "calibration_method", "default_loader"],
}


# ── Data Classes ───────────────────────────────────────────────────────────

@dataclass
class CheckResult:
    """Result of a single validation check."""
    category: str
    check_name: str
    passed: bool
    message: str
    severity: str = "error"  # "error" or "warning"


@dataclass
class FrameworkReport:
    """Aggregate report of all validation checks."""
    results: List[CheckResult] = field(default_factory=list)

    def add(self, result: CheckResult) -> None:
        self.results.append(result)

    @property
    def passed(self) -> int:
        return sum(1 for r in self.results if r.passed)

    @property
    def failed(self) -> int:
        return sum(1 for r in self.results if not r.passed and r.severity == "error")

    @property
    def warnings(self) -> int:
        return sum(1 for r in self.results if not r.passed and r.severity == "warning")

    @property
    def total(self) -> int:
        return len(self.results)

    @property
    def success(self) -> bool:
        return self.failed == 0

    def to_dict(self) -> Dict:
        return {
            "summary": {
                "total": self.total,
                "passed": self.passed,
                "failed": self.failed,
                "warnings": self.warnings,
                "success": self.success,
            },
            "results": [
                {
                    "category": r.category,
                    "check": r.check_name,
                    "passed": r.passed,
                    "message": r.message,
                    "severity": r.severity,
                }
                for r in self.results
            ],
        }

    def print_report(self, verbose: bool = False) -> None:
        print("\n" + "=" * 60)
        print("DEEPX dx-compiler Framework Validation Report")
        print("=" * 60)

        if verbose or not self.success:
            categories: Dict[str, List[CheckResult]] = {}
            for r in self.results:
                categories.setdefault(r.category, []).append(r)

            for cat, checks in sorted(categories.items()):
                print(f"\n── {cat} ──")
                for c in checks:
                    if verbose or not c.passed:
                        icon = "PASS" if c.passed else ("WARN" if c.severity == "warning" else "FAIL")
                        print(f"  [{icon}] {c.check_name}: {c.message}")

        print(f"\n{'=' * 60}")
        status = "PASSED" if self.success else "FAILED"
        print(f"Result: {status}")
        print(f"  Total:    {self.total}")
        print(f"  Passed:   {self.passed}")
        print(f"  Failed:   {self.failed}")
        print(f"  Warnings: {self.warnings}")
        print("=" * 60 + "\n")


# ── Validation Functions ──────────────────────────────────────────────────

def check_file_tree(deepx_dir: Path, report: FrameworkReport) -> None:
    """Category 1: Verify expected directories and files exist."""
    # Check directories
    for dirname in EXPECTED_DIRECTORIES:
        dirpath = deepx_dir / dirname
        report.add(CheckResult(
            category="file_tree",
            check_name=f"directory_{dirname}",
            passed=dirpath.is_dir(),
            message=f"{dirname}/ exists" if dirpath.is_dir() else f"{dirname}/ missing",
        ))

    # Check required files by subdirectory
    file_checks = [
        ("agents", REQUIRED_AGENT_FILES),
        ("skills", REQUIRED_SKILL_FILES),
        ("instructions", REQUIRED_INSTRUCTION_FILES),
        ("toolsets", REQUIRED_TOOLSET_FILES),
        ("memory", REQUIRED_MEMORY_FILES),
        ("scripts", REQUIRED_SCRIPT_FILES),
    ]

    for subdir, files in file_checks:
        for filename in files:
            filepath = deepx_dir / subdir / filename
            report.add(CheckResult(
                category="file_tree",
                check_name=f"file_{subdir}/{filename}",
                passed=filepath.is_file(),
                message=f"{subdir}/{filename} exists" if filepath.is_file() else f"{subdir}/{filename} missing",
            ))

    # Check README.md
    readme = deepx_dir / "README.md"
    report.add(CheckResult(
        category="file_tree",
        check_name="file_README.md",
        passed=readme.is_file(),
        message="README.md exists" if readme.is_file() else "README.md missing",
    ))


def check_routing_paths(deepx_dir: Path, report: FrameworkReport) -> None:
    """Category 2: Verify routing references in README.md resolve to files."""
    readme = deepx_dir / "README.md"
    if not readme.is_file():
        report.add(CheckResult(
            category="routing_paths",
            check_name="readme_exists",
            passed=False,
            message="README.md not found — cannot check routing paths",
        ))
        return

    content = readme.read_text(encoding="utf-8")

    # Find all relative file references (e.g., agents/dx-compiler-builder.md)
    file_refs = re.findall(r'`([a-z]+/[a-zA-Z0-9_-]+\.\w+)`', content)
    for ref in file_refs:
        filepath = deepx_dir / ref
        report.add(CheckResult(
            category="routing_paths",
            check_name=f"route_{ref}",
            passed=filepath.is_file(),
            message=f"Route target {ref} exists" if filepath.is_file() else f"Route target {ref} not found",
        ))


def check_agent_handoffs(deepx_dir: Path, report: FrameworkReport) -> None:
    """Category 3: Verify agent routes-to targets exist as agent files."""
    agents_dir = deepx_dir / "agents"
    if not agents_dir.is_dir():
        report.add(CheckResult(
            category="agent_handoffs",
            check_name="agents_dir",
            passed=False,
            message="agents/ directory not found",
        ))
        return

    for agent_file in agents_dir.glob("*.md"):
        content = agent_file.read_text(encoding="utf-8")

        # Look for routes-to in YAML frontmatter
        routes_match = re.findall(r'routes-to:.*?\n((?:\s+-\s+\S+\n)*)', content, re.DOTALL)
        if routes_match:
            for block in routes_match:
                targets = re.findall(r'-\s+(\S+)', block)
                for target in targets:
                    target_file = agents_dir / f"{target}.md"
                    report.add(CheckResult(
                        category="agent_handoffs",
                        check_name=f"handoff_{agent_file.stem}_to_{target}",
                        passed=target_file.is_file(),
                        message=(
                            f"{agent_file.stem} → {target} valid"
                            if target_file.is_file()
                            else f"{agent_file.stem} → {target} target not found"
                        ),
                    ))

        # Look for @agent references in body
        agent_refs = re.findall(r'@(dx-\w+[-\w]*)', content)
        for ref in agent_refs:
            target_file = agents_dir / f"{ref}.md"
            report.add(CheckResult(
                category="agent_handoffs",
                check_name=f"ref_{agent_file.stem}_to_{ref}",
                passed=target_file.is_file(),
                message=(
                    f"{agent_file.stem} @{ref} valid"
                    if target_file.is_file()
                    else f"{agent_file.stem} @{ref} target not found"
                ),
            ))


def check_skill_sections(deepx_dir: Path, report: FrameworkReport) -> None:
    """Category 5: Verify skills have required sections (phases, validation gates)."""
    skills_dir = deepx_dir / "skills"
    if not skills_dir.is_dir():
        report.add(CheckResult(
            category="skill_sections",
            check_name="skills_dir",
            passed=False,
            message="skills/ directory not found",
        ))
        return

    # Process skills follow their own structure (Gate Function, Iron Law, etc.)
    process_skills = {
        "dx-agent-brainstorm",
        "dx-agent-tdd",
        "dx-agent-verify",
        "dx-swe-debugging",
        "dx-swe-executing-plans",
        "dx-swe-parallel-agents",
        "dx-swe-receiving-review",
        "dx-swe-requesting-review",
        "dx-swe-subagent-dev",
        "dx-swe-writing-plans",
        "dx-skill-router",
        "dx-harness-writing-skills",
    }

    for skill_file in skills_dir.glob("*/SKILL.md"):
        content = skill_file.read_text(encoding="utf-8")
        rel_name = skill_file.parent.name

        if rel_name in process_skills:
            report.add(CheckResult(
                category="skill_sections",
                check_name=f"skill_{rel_name}_process_skill",
                passed=True,
                message=f"{rel_name} is a process skill (own structure)",
            ))
            continue

        for section in REQUIRED_SKILL_SECTIONS:
            found = section.lower() in content.lower()
            report.add(CheckResult(
                category="skill_sections",
                check_name=f"skill_{rel_name}_has_{section.lower().replace(' ', '_')}",
                passed=found,
                message=(
                    f"{rel_name} has '{section}' section"
                    if found
                    else f"{rel_name} missing '{section}' section"
                ),
            ))


def check_toolset_signatures(deepx_dir: Path, report: FrameworkReport) -> None:
    """Category 6: Verify toolsets document required API signatures."""
    toolsets_dir = deepx_dir / "toolsets"
    if not toolsets_dir.is_dir():
        report.add(CheckResult(
            category="toolset_signatures",
            check_name="toolsets_dir",
            passed=False,
            message="toolsets/ directory not found",
        ))
        return

    for filename, keywords in REQUIRED_TOOLSET_KEYWORDS.items():
        filepath = toolsets_dir / filename
        if not filepath.is_file():
            report.add(CheckResult(
                category="toolset_signatures",
                check_name=f"toolset_{filename}_exists",
                passed=False,
                message=f"{filename} not found",
            ))
            continue

        content = filepath.read_text(encoding="utf-8")
        for keyword in keywords:
            found = keyword in content
            report.add(CheckResult(
                category="toolset_signatures",
                check_name=f"toolset_{filename}_has_{keyword.replace(' ', '_')}",
                passed=found,
                message=(
                    f"{filename} documents '{keyword}'"
                    if found
                    else f"{filename} missing documentation for '{keyword}'"
                ),
            ))


def check_memory_domain_tags(deepx_dir: Path, report: FrameworkReport) -> None:
    """Category 7: Verify memory entries use valid domain tags."""
    pitfalls = deepx_dir / "memory" / "common_pitfalls.md"
    if not pitfalls.is_file():
        report.add(CheckResult(
            category="memory_domain_tags",
            check_name="common_pitfalls_exists",
            passed=False,
            message="common_pitfalls.md not found",
        ))
        return

    content = pitfalls.read_text(encoding="utf-8")

    # Build regex from VALID + PROHIBITED tags to avoid false positives from
    # status markers ([PASS], [FAIL], [OK], etc.) while still detecting prohibited
    # tags ([DX_APP], [DX_STREAM], [PIPELINE]) in compiler pitfalls.
    # When adding a new domain tag, update VALID_DOMAIN_TAGS or PROHIBITED_DOMAIN_TAGS.
    _all_known_tag_names = "|".join(
        t.strip("[]") for t in (VALID_DOMAIN_TAGS | PROHIBITED_DOMAIN_TAGS)
    )
    tags_found = re.findall(rf'\[({_all_known_tag_names})\]', content)
    tags_found_formatted = {f"[{t}]" for t in tags_found}

    # Check that all found tags are valid
    for tag in tags_found_formatted:
        is_valid = tag in VALID_DOMAIN_TAGS
        is_prohibited = tag in PROHIBITED_DOMAIN_TAGS

        if is_prohibited:
            report.add(CheckResult(
                category="memory_domain_tags",
                check_name=f"prohibited_tag_{tag}",
                passed=False,
                message=f"Prohibited domain tag {tag} found in common_pitfalls.md",
            ))
        elif not is_valid:
            report.add(CheckResult(
                category="memory_domain_tags",
                check_name=f"unknown_tag_{tag}",
                passed=False,
                message=f"Unknown domain tag {tag} in common_pitfalls.md",
                severity="warning",
            ))
        else:
            report.add(CheckResult(
                category="memory_domain_tags",
                check_name=f"valid_tag_{tag}",
                passed=True,
                message=f"Valid domain tag {tag} used",
            ))

    # Check that at least some valid tags are present
    valid_used = tags_found_formatted & VALID_DOMAIN_TAGS
    report.add(CheckResult(
        category="memory_domain_tags",
        check_name="has_domain_tags",
        passed=len(valid_used) > 0,
        message=(
            f"Found {len(valid_used)} valid domain tags"
            if valid_used
            else "No valid domain tags found in common_pitfalls.md"
        ),
    ))


# ── Main ───────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate DEEPX dx-compiler agent-driven framework (.deepx/ directory)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show all checks, not just failures",
    )
    parser.add_argument(
        "--deepx-dir",
        type=str,
        default=None,
        help="Path to .deepx/ directory (default: auto-detect from script location)",
    )
    args = parser.parse_args()

    # Resolve .deepx/ directory
    if args.deepx_dir:
        deepx_dir = Path(args.deepx_dir).resolve()
    else:
        # Auto-detect: script is in .deepx/scripts/
        deepx_dir = Path(__file__).resolve().parent.parent

    if not deepx_dir.is_dir():
        print(f"ERROR: .deepx/ directory not found at {deepx_dir}", file=sys.stderr)
        return 1

    # Run all validation categories
    report = FrameworkReport()

    check_file_tree(deepx_dir, report)
    check_routing_paths(deepx_dir, report)
    check_agent_handoffs(deepx_dir, report)
    check_skill_sections(deepx_dir, report)
    check_toolset_signatures(deepx_dir, report)
    check_memory_domain_tags(deepx_dir, report)

    # Output results
    if args.json:
        print(json.dumps(report.to_dict(), indent=2))
    else:
        report.print_report(verbose=args.verbose)

    return 0 if report.success else 1


if __name__ == "__main__":
    sys.exit(main())
