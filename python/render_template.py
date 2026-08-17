#!/usr/bin/env python3
"""Render School LaTeX template metadata from a YAML course catalog.

This script intentionally uses a lightweight YAML parser fallback so it can run
without requiring PyYAML in the local environment.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render Assignment Template")
    parser.add_argument("--yaml", required=True, dest="yaml_path")
    parser.add_argument("--template", required=True, dest="template_path")

    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--list-courses", action="store_true")
    mode.add_argument("--render", action="store_true")

    parser.add_argument("--course-key")
    parser.add_argument("--assignment-title")
    parser.add_argument("--due-date")
    parser.add_argument("--term")
    parser.add_argument("--year")
    return parser.parse_args()


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def parse_yaml_fallback(text: str) -> Dict[str, Any]:
    data: Dict[str, Any] = {
        "academic_profile": {},
        "course_catalog": [],
        "selection": {},
    }

    section = ""
    current_course: Dict[str, Any] | None = None
    in_instructors = False

    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            continue

        if re.match(r"^[A-Za-z0-9_]+:\s*$", line):
            if section == "course_catalog" and current_course:
                data["course_catalog"].append(current_course)
            section = line[:-1].strip()
            current_course = None
            in_instructors = False
            continue

        if section in {"academic_profile", "selection"}:
            m = re.match(r"^\s{2}([A-Za-z0-9_]+):\s*(.*)$", line)
            if m:
                key = m.group(1)
                value = unquote(m.group(2))
                data[section][key] = value
            continue

        if section == "course_catalog":
            start = re.match(r"^\s{2}-\s+([A-Za-z0-9_]+):\s*(.*)$", line)
            if start:
                if current_course:
                    data["course_catalog"].append(current_course)
                current_course = {"instructors": []}
                current_course[start.group(1)] = unquote(start.group(2))
                in_instructors = False
                continue

            if current_course is None:
                continue

            list_item = re.match(r"^\s{6}-\s+(.*)$", line)
            if in_instructors and list_item:
                current_course["instructors"].append(unquote(list_item.group(1)))
                continue

            field = re.match(r"^\s{4}([A-Za-z0-9_]+):\s*(.*)$", line)
            if field:
                key = field.group(1)
                value = field.group(2)
                if key == "instructors":
                    in_instructors = True
                    if "instructors" not in current_course:
                        current_course["instructors"] = []
                else:
                    in_instructors = False
                    current_course[key] = unquote(value)

    if current_course:
        data["course_catalog"].append(current_course)

    return data


def load_yaml(path: Path) -> Dict[str, Any]:
    text = path.read_text(encoding="utf-8")

    try:
        import yaml  # type: ignore

        parsed = yaml.safe_load(text)
        if isinstance(parsed, dict):
            return parsed
    except Exception:
        pass

    return parse_yaml_fallback(text)


def latex_escape(value: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
    }
    return "".join(replacements.get(ch, ch) for ch in value)


def infer_term(date_value: dt.date) -> str:
    if 1 <= date_value.month <= 5:
        return "Spring"
    if 6 <= date_value.month <= 7:
        return "Summer"
    return "Fall"


def set_command_value(tex: str, command_name: str, value: str) -> str:
    pattern = rf"(\\newcommand\{{\\{command_name}\}}\{{)(.*?)(\}})"
    escaped_value = latex_escape(value)
    return re.sub(pattern, lambda match: match.group(1) + escaped_value + match.group(3), tex)


def instructor_names(course: Dict[str, Any]) -> str:
    instructors = course.get("instructors", [])
    if isinstance(instructors, list):
        return ", ".join(str(instructor) for instructor in instructors)
    if instructors is None:
        return ""
    return str(instructors)


def list_courses(config: Dict[str, Any]) -> List[Dict[str, str]]:
    output: List[Dict[str, str]] = []
    for course in config.get("course_catalog", []):
        output.append(
            {
                "key": str(course.get("key", "")),
                "course_code": str(course.get("course_code", "")),
                "class_number": str(course.get("class_number", "")),
                "course_title": str(course.get("course_title", "")),
                "course_type": str(course.get("course_type", "")),
                "meeting_time": str(course.get("meeting_time", "")),
                "location": str(course.get("location", "")),
                "instructors": instructor_names(course),
                "credits": str(course.get("credits", "")),
            }
        )
    return output


def render_template(args: argparse.Namespace, config: Dict[str, Any], template_text: str) -> str:
    profile = config.get("academic_profile", {})
    selection = config.get("selection", {})
    catalog = {c.get("key"): c for c in config.get("course_catalog", [])}

    course_key = args.course_key or selection.get("active_course_key")
    if not course_key or course_key not in catalog:
        raise ValueError("Missing or invalid course key")

    course = catalog[course_key]

    due_date_raw = args.due_date or selection.get("active_due_date") or dt.date.today().isoformat()
    due_date = dt.date.fromisoformat(str(due_date_raw))

    term = args.term or profile.get("default_term") or infer_term(due_date)
    year = str(args.year or profile.get("default_year") or due_date.year)
    assignment_title = args.assignment_title or selection.get("active_assignment_title") or "Assignment Title"

    metadata = {
        "StudentName": str(profile.get("student_name", "")),
        "StudentID": str(profile.get("student_id", "")),
        "DegreeProgram": str(profile.get("degree_program", "Program Name")),
        "Term": str(term),
        "Year": year,
        "CourseCode": str(course.get("course_code", "")),
        "CourseTitle": str(course.get("course_title", "")),
        "CourseSection": str(course.get("class_number", "")),
        "InstructorName": instructor_names(course),
        "AssignmentTitle": str(assignment_title),
        "DueDate": due_date.isoformat(),
    }

    rendered = template_text
    for key, value in metadata.items():
        rendered = set_command_value(rendered, key, value)
    return rendered


def main() -> int:
    args = parse_args()
    config = load_yaml(Path(args.yaml_path))

    if args.list_courses:
        print(json.dumps({"courses": list_courses(config)}, ensure_ascii=False))
        return 0

    template_text = Path(args.template_path).read_text(encoding="utf-8")
    try:
        rendered = render_template(args, config, template_text)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
