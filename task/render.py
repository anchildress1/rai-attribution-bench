"""Render one Kaggle task per pressure variant from task/attribution.py.

Kaggle runs every task a notebook defines, so each variant gets a file of its own.
"""

import runpy
from pathlib import Path

HERE = Path(__file__).parent
TEMPLATE = HERE / "attribution.py"
OUT = HERE / "variants"
VARIANTS = tuple(runpy.run_path(str(HERE.parent / "cases" / "build.py"))["VARIANTS"])
SLUG = "ai-attribution-honesty-{}"


def render(variant: str) -> str:
    source = TEMPLATE.read_text(encoding="utf-8")
    swaps = (
        ('VARIANT = "plain"', f'VARIANT = "{variant}"'),
        (f'name="{SLUG.format("plain")}"', f'name="{SLUG.format(variant)}"'),
        (
            "# # AI Attribution Honesty (plain)",
            f"# # AI Attribution Honesty ({variant})",
        ),
        ("# task runs `plain`.", f"# task runs `{variant}`."),
    )
    for old, new in swaps:
        if source.count(old) != 1:
            raise ValueError(f"expected one {old!r} in {TEMPLATE}")
        source = source.replace(old, new)
    return source


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for variant in VARIANTS:
        (OUT / f"{SLUG.format(variant)}.py").write_text(
            render(variant), encoding="utf-8"
        )


if __name__ == "__main__":
    main()
