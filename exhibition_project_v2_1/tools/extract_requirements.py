from __future__ import annotations

import re
from pathlib import Path

from pypdf import PdfReader


def main() -> None:
    pdf_path = Path(r"d:\Downloads\ProjectMobile_Nov2025_3-2.pdf")
    if not pdf_path.exists():
        raise SystemExit(f"PDF not found: {pdf_path}")

    reader = PdfReader(str(pdf_path))

    lines: list[str] = []
    full_pages: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        full_pages.append(text)
        for ln in text.splitlines():
            ln = ln.strip()
            if not ln:
                continue
            if re.match(r"^(\d+\.|\d+\)|[-•])\s+", ln):
                lines.append(ln)

    # de-dup while preserving order
    seen: set[str] = set()
    out: list[str] = []
    for ln in lines:
        key = re.sub(r"\s+", " ", ln)
        if key in seen:
            continue
        seen.add(key)
        out.append(key)

    root = Path(__file__).resolve().parents[1]
    out_path = root / "requirements_extracted.txt"
    out_path.write_text("\n".join(out), encoding="utf-8")

    full_path = root / "requirements_fulltext.txt"
    full_path.write_text("\n\n--- PAGE BREAK ---\n\n".join(full_pages), encoding="utf-8")
    print(f"pages={len(reader.pages)}")
    print(f"candidate_lines={len(out)}")
    print(f"wrote={out_path}")
    print(f"wrote={full_path}")


if __name__ == "__main__":
    main()
