#!/usr/bin/env python3
"""Build local, dependency-free policy/support pages. Publishing is a separate step."""
from pathlib import Path
import html
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/release/site'
STYLE = '''body{margin:0;background:#111;color:#f5f5f5;font:18px/1.8 system-ui,sans-serif}main{max-width:720px;margin:auto;padding:32px 24px 64px}a{color:#ffb347;text-underline-offset:4px}nav{display:flex;flex-wrap:wrap;gap:24px;margin-bottom:32px}h1{font-size:2rem;line-height:1.3}h2{font-size:1.25rem;margin-top:2.5rem;line-height:1.5}li{margin:12px 0}small{color:#bbb}*:focus-visible{outline:3px solid #ffb347;outline-offset:4px}@media(prefers-color-scheme:light){body{background:#fff;color:#222}a{color:#8c4700}small{color:#555}}'''


def inline(text):
    text = html.escape(text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)


def markdown(text):
    output = []
    for block in text.strip().split('\n\n'):
        block = block.strip()
        if block.startswith('### '):
            output.append('<h2>' + inline(block[4:]) + '</h2>')
        elif block.startswith('## '):
            output.append('<h2>' + inline(block[3:]) + '</h2>')
        elif block.startswith('# '):
            output.append('<h1>' + inline(block[2:]) + '</h1>')
        elif block.startswith('- '):
            output.append('<ul>' + ''.join('<li>' + inline(line[2:]) + '</li>' for line in block.splitlines()) + '</ul>')
        else:
            output.append('<p>' + inline(block.replace('\n', ' ')) + '</p>')
    return '\n'.join(output)


for lang in ['ko', 'en']:
    folder = OUT / lang
    folder.mkdir(parents=True, exist_ok=True)
    policy = (ROOT / f'NextSet/NextSet/{lang}.lproj/PrivacyPolicy.txt').read_text()
    support = (ROOT / ('docs/release/SUPPORT.md' if lang == 'ko' else 'docs/release/SUPPORT.en.md')).read_text()
    title = '개인정보 처리방침' if lang == 'ko' else 'Privacy Policy'
    policy = f'# {title}\n\n' + ('최종 수정: 2026-09-22' if lang == 'ko' else 'Last updated: September 22, 2026') + '\n\n' + policy
    for filename, body, page_title in [('privacy.html', policy, title), ('support.html', support, '지원' if lang == 'ko' else 'Support')]:
        body = body.replace('(PRIVACY.md)', '(privacy.html)')
        nav = '<a href="support.html">' + ('지원' if lang == 'ko' else 'Support') + '</a> <a href="privacy.html">' + title + '</a>'
        other = 'en' if lang == 'ko' else 'ko'
        nav += f' <a href="../{other}/{filename}" lang="{other}">' + ('English' if lang == 'ko' else '한국어') + '</a>'
        page = f'<!doctype html>\n<html lang="{lang}"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{page_title} · NextSet</title><style>{STYLE}</style><main><nav aria-label="Navigation">{nav}</nav>{markdown(body)}</main></html>\n'
        (folder / filename).write_text(page)
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'index.html').write_text('<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>NextSet</title><main><h1>NextSet · 다음세트</h1><p><a href="ko/support.html">한국어 지원</a></p><p><a href="en/support.html">English Support</a></p></main></html>\n')
print('Generated', OUT)
