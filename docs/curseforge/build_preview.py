#!/usr/bin/env python3
"""Regenerate the CurseForge preview and copy pages from description.html and description.md."""

from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FRAGMENT = (ROOT / "description.html").read_text().strip()

PREVIEW = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Goblin Pawn Stars — CurseForge description preview</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; background: #17100a; color: #e6d3a8;
    font-family: "Segoe UI", Helvetica, Arial, sans-serif;
    font-size: 16px; line-height: 1.65;
  }}
  .cf-shell {{ max-width: 836px; margin: 0 auto; padding: 28px 22px 70px; }}
  .cf-note {{
    max-width: 836px; margin: 0 auto; padding: 10px 22px;
    border-bottom: 1px solid #3f2f1a; color: #9c8560;
    font-size: 12px; letter-spacing: .08em; text-transform: uppercase;
  }}
  img {{ max-width: 100%; height: auto; }}
  a {{ color: #d8b25a; }}
  blockquote {{ border-left: 3px solid #c9a24a; margin: 22px 0; padding: 4px 0 4px 18px; color: #d8c39a; font-style: italic; }}
  hr {{ border: 0; border-top: 1px solid #3f2f1a; margin: 34px 0; }}
  h1, h2 {{ line-height: 1.2; }}
  h2 {{ margin-top: 34px; }}
  code {{ background: #24180d; padding: 2px 5px; border-radius: 4px; }}
</style>
</head>
<body>
<div class="cf-note">Local preview · 836 px CurseForge description width</div>
<main class="cf-shell">
{FRAGMENT}
</main>
</body>
</html>
"""

COPY_PAGE = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Copy the Goblin Pawn Stars CurseForge description</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; background: #120b07; color: #e6d3a8; font-family: "Segoe UI", Helvetica, Arial, sans-serif; line-height: 1.55; }}
  main {{ max-width: 1100px; margin: 0 auto; padding: 34px 24px 60px; }}
  h1 {{ color: #e8c25a; margin: 0 0 6px; font-size: 28px; }}
  p {{ color: #c9b68e; }}
  .steps {{ background: #1b120a; border: 1px solid #4a361d; border-radius: 8px; padding: 16px 20px; margin: 20px 0; }}
  .steps ol {{ margin: 8px 0 0; padding-left: 20px; }}
  .steps li {{ margin: 5px 0; }}
  kbd {{ background: #2a1c0e; border: 1px solid #5f4825; border-radius: 4px; padding: 1px 5px; font-size: 12px; }}
  .bar {{ display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin: 18px 0 10px; }}
  button {{ appearance: none; border: 1px solid #c9a24a; border-radius: 6px; background: #c9a24a; color: #17100a; font-weight: 700; padding: 10px 18px; cursor: pointer; font-size: 15px; }}
  button:hover {{ background: #e8c25a; }}
  #status {{ color: #7fd36b; font-size: 14px; }}
  textarea {{ width: 100%; height: 55vh; resize: vertical; background: #0b0704; color: #e6d3a8; border: 1px solid #4a361d; border-radius: 8px; padding: 14px; font: 12px/1.5 Consolas, "Courier New", monospace; }}
</style>
</head>
<body>
<main>
  <h1>Copy the CurseForge description</h1>
  <p>This is the full HTML source, with the eight UI renders already placed between the sections.</p>
  <div class="steps">
    <strong>How to paste it</strong>
    <ol>
      <li>Click <strong>Copy description HTML</strong> below.</li>
      <li>In the CurseForge description editor, choose <strong>WYSIWYG</strong> and open the <strong>HTML/source view</strong> (<kbd>&lt;/&gt;</kbd>).</li>
      <li>Paste the whole block, then switch back to the normal editor view.</li>
      <li>The images load from the public GitHub repository. If CurseForge blocks one, upload that PNG through the editor's image tool and replace its URL.</li>
    </ol>
  </div>
  <div class="bar">
    <button type="button" onclick="copyDescription()">Copy description HTML</button>
    <span id="status" role="status"></span>
  </div>
  <textarea id="source" readonly spellcheck="false">{escape(FRAGMENT)}</textarea>
</main>
<script>
function copyDescription() {{
  const area = document.getElementById('source');
  const status = document.getElementById('status');
  area.focus(); area.select();
  let ok = false;
  try {{ ok = document.execCommand('copy'); }} catch (e) {{ ok = false; }}
  if (navigator.clipboard) {{
    navigator.clipboard.writeText(area.value).then(() => {{
      status.textContent = 'Copied. Paste it into the CurseForge source view.';
    }}).catch(() => {{
      status.textContent = ok ? 'Copied. Paste it into the CurseForge source view.' : 'Select the text and press Ctrl+C / Cmd+C.';
    }});
  }} else {{
    status.textContent = ok ? 'Copied. Paste it into the CurseForge source view.' : 'Select the text and press Ctrl+C / Cmd+C.';
  }}
}}
</script>
</body>
</html>
"""

MARKDOWN = (ROOT / "description.md").read_text().strip()

MD_COPY_PAGE = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Copy the Goblin Pawn Stars CurseForge description (Markdown)</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; background: #120b07; color: #e6d3a8; font-family: "Segoe UI", Helvetica, Arial, sans-serif; line-height: 1.55; }}
  main {{ max-width: 1100px; margin: 0 auto; padding: 34px 24px 60px; }}
  h1 {{ color: #e8c25a; margin: 0 0 6px; font-size: 28px; }}
  p {{ color: #c9b68e; }}
  .steps {{ background: #1b120a; border: 1px solid #4a361d; border-radius: 8px; padding: 16px 20px; margin: 20px 0; }}
  .steps ol {{ margin: 8px 0 0; padding-left: 20px; }}
  .steps li {{ margin: 5px 0; }}
  kbd {{ background: #2a1c0e; border: 1px solid #5f4825; border-radius: 4px; padding: 1px 5px; font-size: 12px; }}
  .bar {{ display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin: 18px 0 10px; }}
  button {{ appearance: none; border: 1px solid #c9a24a; border-radius: 6px; background: #c9a24a; color: #17100a; font-weight: 700; padding: 10px 18px; cursor: pointer; font-size: 15px; }}
  button:hover {{ background: #e8c25a; }}
  #status {{ color: #7fd36b; font-size: 14px; }}
  textarea {{ width: 100%; height: 55vh; resize: vertical; background: #0b0704; color: #e6d3a8; border: 1px solid #4a361d; border-radius: 8px; padding: 14px; font: 12px/1.5 Consolas, "Courier New", monospace; }}
</style>
</head>
<body>
<main>
  <h1>Copy the CurseForge description (Markdown)</h1>
  <p>Use this one when the project's description editor is set to <strong>Markdown</strong>. The HTML file is escaped as text in that editor, which is what a page full of raw &lt;h1&gt; tags means.</p>
  <div class="steps">
    <strong>How to paste it</strong>
    <ol>
      <li>Click <strong>Copy description Markdown</strong> below.</li>
      <li>In the CurseForge editor, open the <strong>Markdown</strong> tab (not the WYSIWYG one).</li>
      <li>Paste the whole block and switch to the preview. Headings, lists, the blockquote and the eight images render; no HTML needed.</li>
    </ol>
  </div>
  <div class="bar">
    <button type="button" onclick="copyDescription()">Copy description Markdown</button>
    <span id="status" role="status"></span>
  </div>
  <textarea id="source" readonly spellcheck="false">{escape(MARKDOWN)}</textarea>
</main>
<script>
function copyDescription() {{
  const area = document.getElementById('source');
  const status = document.getElementById('status');
  area.focus(); area.select();
  let ok = false;
  try {{ ok = document.execCommand('copy'); }} catch (e) {{ ok = false; }}
  if (navigator.clipboard) {{
    navigator.clipboard.writeText(area.value).then(() => {{
      status.textContent = 'Copied. Paste it into the Markdown editor.';
    }}).catch(() => {{
      status.textContent = ok ? 'Copied. Paste it into the Markdown editor.' : 'Select the text and press Ctrl+C / Cmd+C.';
    }});
  }} else {{
    status.textContent = ok ? 'Copied. Paste it into the Markdown editor.' : 'Select the text and press Ctrl+C / Cmd+C.';
  }}
}}
</script>
</body>
</html>
"""

NOTE = '<div class="cf-note">Local preview · 836 px CurseForge description width</div>'
BUTTON = (
    '<div class="cf-note" style="display:flex;justify-content:space-between;gap:16px;'
    'align-items:center;flex-wrap:wrap;">'
    '<span>Local preview · 836 px CurseForge description width</span>'
    '<a href="description-copy.html" style="display:inline-block;background:#c9a24a;'
    'color:#17100a;padding:7px 12px;border-radius:5px;font-weight:700;'
    'text-decoration:none;">Copy description HTML →</a> '
    '<a href="markdown-copy.html" style="display:inline-block;background:#2a1c0e;'
    'color:#e6d3a8;border:1px solid #5f4825;padding:7px 12px;border-radius:5px;'
    'font-weight:700;text-decoration:none;">Copy Markdown →</a>'
    '</div>'
)

(ROOT / "description-preview.html").write_text(PREVIEW)
(ROOT / "description-copy.html").write_text(COPY_PAGE)
(ROOT / "markdown-copy.html").write_text(MD_COPY_PAGE)
(ROOT / "index.html").write_text(PREVIEW.replace(NOTE, BUTTON))
print("wrote description-preview.html, description-copy.html, markdown-copy.html and index.html")
