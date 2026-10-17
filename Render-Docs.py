"""Maintainer-only, standard-library Markdown renderer for the offline manual."""
from pathlib import Path
import html
import re

root = Path(__file__).resolve().parent
lines = (root / "README.md").read_text(encoding="utf-8-sig").splitlines()


def inline(s):
    s = html.escape(s)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    return s


content = []
toc = []
i = 0
heading_count = 0
while i < len(lines):
    line = lines[i]
    if not line.strip():
        i += 1
        continue
    heading = re.match(r"^(#{1,3}) (.+)$", line)
    if heading:
        level, text = len(heading[1]), heading[2]
        anchor = f"section-{heading_count}"
        heading_count += 1
        if level == 2:
            toc.append((anchor, text))
        content.append(f'<h{level} id="{anchor}">{inline(text)}</h{level}>')
        i += 1
    elif line.startswith("| "):
        rows = []
        while i < len(lines) and lines[i].startswith("|"):
            cells = [x.strip() for x in lines[i].strip("|").split("|")]
            if not all(re.fullmatch(r":?-+:?", x) for x in cells):
                tag = "th" if not rows else "td"
                rows.append("<tr>" + "".join(f"<{tag}>{inline(c)}</{tag}>" for c in cells) + "</tr>")
            i += 1
        content.append('<div class="table"><table>' + "".join(rows) + "</table></div>")
    elif re.match(r"^\d+\. ", line):
        items = []
        while i < len(lines) and re.match(r"^\d+\. ", lines[i]):
            items.append("<li>" + inline(re.sub(r"^\d+\. ", "", lines[i])) + "</li>")
            i += 1
        content.append("<ol>" + "".join(items) + "</ol>")
    else:
        paragraph = [line]
        i += 1
        while i < len(lines) and lines[i].strip() and not re.match(r"^(#|\||\d+\. )", lines[i]):
            paragraph.append(lines[i])
            i += 1
        content.append("<p>" + inline(" ".join(paragraph)) + "</p>")

page = """<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>鹰角游戏 Steam 图片同步 · 使用说明</title>
<style>
:root{color-scheme:light}*{box-sizing:border-box}body{margin:0;background:#f5f6f8;color:#202936;font:16px/1.85 system-ui,'Microsoft YaHei',sans-serif}
main{max-width:1000px;margin:40px auto;padding:40px 50px;background:white;border:1px solid #e3e8ef;border-radius:16px}
h1{font-size:30px;line-height:1.4;margin-top:0}h2{margin-top:50px;padding-top:15px;border-top:1px solid #e5eaf0;font-size:23px}p{overflow-wrap:anywhere}
nav{padding:18px 24px;background:#eef5fc;border-radius:10px}nav a{display:block;color:#24568a;text-decoration:none;font-size:15px}code{background:#eff2f6;border-radius:4px;padding:2px 5px;font-size:.9em;overflow-wrap:anywhere}
table{width:100%;border-collapse:collapse;margin:16px 0;font-size:14px}th,td{padding:12px;border:1px solid #dce3eb;text-align:left;vertical-align:top}th{background:#f0f5fa}.table{overflow:auto}strong{color:#172f4a}
@media(max-width:700px){main{margin:0;padding:24px 18px;border-radius:0;border:0}h1{font-size:25px}h2{font-size:21px}}
@media print{body{background:white}main{border:0;margin:0;padding:0}nav{display:none}h2{break-after:avoid}tr{break-inside:avoid}}
</style><main>"""
page += content[0] + '<nav aria-label="目录">' + "".join(f'<a href="#{anchor}">{html.escape(text)}</a>' for anchor, text in toc) + "</nav>"
page += "\n".join(content[1:]) + "</main></html>"
(root / "docs" / "使用说明.html").write_text(page, encoding="utf-8")
print("Offline HTML manual generated.")
