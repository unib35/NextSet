#!/usr/bin/env python3
"""Build the public site (GitHub Pages) from Markdown sources. Layout: Claude Design "NextSet Website".

Sources: docs/release/SUPPORT*.md, docs/release/CHANGELOG*.md, the app's <lang>.lproj/PrivacyPolicy.txt.
Static files (CSS, JS, screenshots) are in tools/release-site/static and copied to <site>/assets.
URLs stay as before: <lang>/support.html, <lang>/privacy.html, plus <lang>/index.html and <lang>/changelog.html.
"""
from pathlib import Path
import html
import json
import re
import shutil
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/release/site'
STATIC = Path(__file__).resolve().parent / 'static'
EMAIL = 'jm.jongminlee@gmail.com'
STORE = 'https://apps.apple.com/app/id6814582323'
FONT = 'https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css'
FAVICON = ("data:image/svg+xml," + quote('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="14" fill="#FF9500"/>'
           '<text x="-3" y="70" font-family="-apple-system,Helvetica,Arial" font-size="74" font-weight="800" letter-spacing="-4" fill="#000">30</text></svg>'))
CHECK = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#FF9500" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
CHEVRON = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>'
SHOTS = ['01', '02', '03', '04', '09', '06', '07']

T = {
    'ko': dict(
        brand='다음세트', foot_brand='다음세트 · NextSet', tagline='운동 세트 사이 휴식 시간을 빠르게 재는 타이머',
        support='지원', changelog='업데이트 내역', privacy='개인정보', privacy_full='개인정보 처리방침', lang_aria='Switch to English',
        download='App Store에서 다운로드', devices='iPhone · iPad · Apple Watch', requires='iOS·iPadOS 18 · watchOS 11 이상',
        hero='탭 한 번,<br>나머진 운동만', try_aria='휴식 타이머 체험',
        hints=dict(idle='탭해서 휴식 시작', running='탭해서 일시정지', paused='일시정지됨 · 탭해서 재개', done='휴식 끝 · 다음 세트!'),
        news_pending='무엇이 바뀌나요 →', news_released='무엇이 바뀌었나요 →', news_label='{v} 업데이트',
        shots_title='숫자 하나만 보면 됩니다', shots_lead='운동 세트 사이 휴식 시간을 빠르게 재는 타이머입니다. 화면을 넘겨 보세요.',
        shots_alt=['휴식 중 화면', '시간 선택 화면', '마지막 3초 화면', '잠금화면 Live Activity', '무음 모드 알람', '홈 화면 위젯', 'Apple Watch'],
        feats_title='쉬는 동안 필요한 것만',
        feats=[('10<span aria-hidden="true" style="margin:0 .1em">–</span>300<small>초</small>', '프리셋 줄을 넘겨 고르기', '10초부터 5분까지 탭 한 번으로 고릅니다. 휴식 중에도 설정을 열 수 있고, 바꾼 기본 휴식은 다음 휴식부터 적용돼요.'),
               ('3·2·1', '마지막 3초는 손끝으로', '앱을 보고 있으면 소리와 햅틱으로 알려요. 화면 밖에서는 알림으로, iOS 26 이상에서는 무음·집중 모드에서도 울리는 알람으로 알려요.'),
               ('+30', '조금 더 쉬고 싶을 때', '휴식 중에는 −10 · +10 · +30으로 바로 조절하고, 알람이 울리면 ‘+30초 더 쉬기’ 한 번이면 됩니다.'),
               ('0', '회원가입도, 서버 전송도 없이', '타이머와 최근 운동 30회 요약은 기기에만 저장돼요. 광고·추적·외부 분석 SDK를 쓰지 않습니다.')],
        privacy_more='개인정보 처리방침 →',
        end_title='어디서 시작해도 같은 숫자', end_text='iPhone, iPad, Apple Watch는 물론 잠금화면 · Dynamic Island · 위젯 · 제어 센터에서도 같은 휴식을 보고 조작해요.',
        support_title='다음세트 지원', all='전체', contact='문의', send='이메일 보내기', copy='복사', copied='복사됨', include='함께 알려 주세요',
        include_items=['iPhone · Apple Watch 모델', 'iOS · watchOS 버전', '앱 버전', '문제가 발생한 순서'],
        include_note='이메일 보내기를 누르면 위 항목이 본문에 미리 채워집니다. 비밀번호나 Apple 계정 인증 코드는 보내지 마세요.',
        mail_subject='[다음세트] 문의', mail_body='기기 모델:\niOS / watchOS 버전:\n앱 버전:\n문제가 발생한 순서:\n1. \n',
        changelog_title='무엇이 바뀌었나요',
        policy_title='기록은 기기에만 남습니다', checks=['회원가입 없음', '개발자 서버 전송 없음', '광고·추적 SDK 없음'], updated='최종 수정 2026-09-22',
        description='운동 세트 사이 휴식 시간을 빠르게 재는 타이머. iPhone, iPad, Apple Watch.',
    ),
    'en': dict(
        brand='NextSet', foot_brand='NextSet · 다음세트', tagline='A workout rest timer for iPhone, iPad, and Apple Watch',
        support='Support', changelog='What’s New', privacy='Privacy', privacy_full='Privacy Policy', lang_aria='한국어로 보기',
        download='Download on the App Store', devices='iPhone · iPad · Apple Watch', requires='iOS and iPadOS 18 · watchOS 11 or later',
        hero='One tap.<br>The rest is lifting.', try_aria='Try the rest timer',
        hints=dict(idle='Tap to start rest', running='Tap to pause', paused='Paused · tap to resume', done='Rest over · next set!'),
        news_pending='What’s new →', news_released='What’s new →', news_label='New in {v}',
        shots_title='One number. That’s it.', shots_lead='A workout rest timer for iPhone, iPad, and Apple Watch. Swipe through the screens.',
        shots_alt=['Resting', 'Choosing a rest', 'Final 3 seconds', 'Lock Screen Live Activity', 'Alarm in Silent mode', 'Home Screen widget', 'Apple Watch'],
        feats_title='Only what you need between sets',
        feats=[('10<span aria-hidden="true" style="margin:0 .1em">–</span>300<small>sec</small>', 'Swipe the preset row', 'Pick anything from 10 seconds to 5 minutes in one tap. You can open Settings during rest too; a new default applies from your next rest.'),
               ('3·2·1', 'Feel the final 3 seconds', 'Sound and haptics count you down while the app is open. Outside the app you get a notification — and on iOS 26 or later, an alarm that rings even in Silent mode or a Focus.'),
               ('+30', 'Need a little longer?', 'Adjust with −10 · +10 · +30 during rest. When the alarm rings, just tap “+30 sec”.'),
               ('0', 'No account. No uploads.', 'Your timer and last 30 workout summaries stay on your device. No advertising, tracking, or third-party analytics SDKs.')],
        privacy_more='Privacy Policy →',
        end_title='The same number, everywhere', end_text='See and control the same rest on iPhone, iPad, and Apple Watch — plus the Lock Screen, Dynamic Island, widgets, and Control Center.',
        support_title='NextSet Support', all='All', contact='Contact', send='Send email', copy='Copy', copied='Copied', include='Please include',
        include_items=['iPhone and Apple Watch model', 'iOS and watchOS version', 'App version', 'Steps that led to the issue'],
        include_note='Send email pre-fills these fields. Do not send passwords or Apple Account verification codes.',
        mail_subject='[NextSet] Support', mail_body='Device model:\niOS / watchOS version:\nApp version:\nSteps that led to the issue:\n1. \n',
        changelog_title='What’s changed',
        policy_title='Your records stay on your device', checks=['No account', 'No developer server', 'No ads or tracking SDKs'], updated='Last updated September 22, 2026',
        description='A workout rest timer for the time between sets. iPhone, iPad, and Apple Watch.',
    ),
}


def esc(text):
    return html.escape(text, quote=True)


def inline(text):
    text = esc(text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)


def blocks(path):
    return [b.strip() for b in path.read_text().strip().split('\n\n') if b.strip()]


def is_date(label):
    return re.search(r'\d{4}', label) is not None


def read_changelog(lang):
    releases = []
    for block in blocks(ROOT / ('docs/release/CHANGELOG.md' if lang == 'ko' else 'docs/release/CHANGELOG.en.md')):
        if block.startswith('# '):
            continue
        if block.startswith('## '):
            version, _, label = block[3:].partition(' — ')
            releases.append(dict(version=version.strip(), label=label.strip(), note='', items=[]))
        elif block.startswith('- '):
            releases[-1]['items'] += [line[2:] for line in block.splitlines()]
        else:
            releases[-1]['note'] = block.rstrip('.')
    return releases


def read_support(lang):
    intro, cats = '', []
    for block in blocks(ROOT / ('docs/release/SUPPORT.md' if lang == 'ko' else 'docs/release/SUPPORT.en.md')):
        block = block.replace('\n', ' ')
        if block.startswith('# '):
            continue
        if block.startswith('## '):
            cats.append(dict(label=block[3:], qs=[]))
        elif block.startswith('### '):
            cats[-1]['qs'].append(dict(q=block[4:], ps=[], cards=[], after=[]))
        elif not cats:
            intro = block
        elif block.startswith('> '):
            tag, title, body = re.match(r'> \*\*(.+?)\*\* (.+?) — (.+)', block).groups()
            cats[-1]['qs'][-1]['cards'].append((tag, title, body))
        else:
            q = cats[-1]['qs'][-1]
            (q['after'] if q['cards'] else q['ps']).append(block)
    return intro, cats


def read_policy(lang):
    intro, sections = '', []
    for block in blocks(ROOT / f'NextSet/NextSet/{lang}.lproj/PrivacyPolicy.txt'):
        if block.startswith('## '):
            number, _, title = block[3:].partition('. ')
            sections.append(dict(number=number, title=title, parts=[]))
        elif not sections:
            intro = block.replace('**', '')
        else:
            sections[-1]['parts'].append(block)
    return intro, sections


def page(lang, name, title, body, current=None):
    t = T[lang]
    other = 'en' if lang == 'ko' else 'ko'
    tab = lambda key, href: f'<a class="tab" href="{href}"' + (' aria-current="page"' if current == key else '') + f'>{t[key]}</a>'
    on = lambda code: ' class="on"' if code == lang else ''
    return f'''<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
<meta name="description" content="{esc(t['description'])}">
<meta name="theme-color" content="#000000">
<link rel="icon" href="{FAVICON}">
<link rel="alternate" hreflang="{other}" href="../{other}/{name}">
<link rel="stylesheet" href="{FONT}">
<link rel="stylesheet" href="../assets/site.css">
</head>
<body>
<header class="top"><div class="wrap">
<a class="brand" href="index.html"><span class="mark" aria-hidden="true"><span>30</span></span>{t['brand']}</a>
<nav class="nav" aria-label="{t['brand']}">
{tab('support', 'support.html')}
{tab('changelog', 'changelog.html')}
{tab('privacy', 'privacy.html')}
<a class="lang" href="../{other}/{name}" hreflang="{other}" aria-label="{t['lang_aria']}"><span{on('ko')}>KO</span><span{on('en')}>EN</span></a>
</nav>
</div></header>
{body}
<footer class="foot"><div class="wrap">
<div class="id"><div class="name"><span class="mark sm" aria-hidden="true"><span>30</span></span>{t['foot_brand']}</div><span class="tagline">{t['tagline']}</span></div>
<div class="links"><a href="support.html">{t['support']}</a><a href="changelog.html">{t['changelog']}</a><a href="privacy.html">{t['privacy_full']}</a><a href="mailto:{EMAIL}">{EMAIL}</a></div>
</div></footer>
<script src="../assets/site.js" defer></script>
</body>
</html>
'''


def home(lang, releases):
    t = T[lang]
    latest = releases[0]
    if is_date(latest['label']):
        news = f'{esc(t["news_label"].format(v=latest["version"]))}<span>{t["news_released"]}</span>'
    else:
        news = f'{esc(latest["version"] + " " + latest["label"])}<span>{t["news_pending"]}</span>'
    presets = ''.join(f'<button type="button" data-s="{s}" aria-pressed="{str(s == 60).lower()}">{s if s <= 60 else f"{s // 60}:{s % 60:02d}"}</button>'
                      for s in [10, 30, 60, 90, 120])
    shots = '\n'.join(f'<img src="../assets/shots/{lang}/{n}.jpg" alt="{esc(alt)}" width="264" height="574" loading="lazy" decoding="async">'
                      for n, alt in zip(SHOTS, t['shots_alt']))
    feats = '\n'.join(f'<div class="feat"><div class="n">{n}</div><div class="d"><h3>{esc(h)}</h3><p>{esc(p)}</p>'
                      + (f'<a class="more" href="privacy.html">{t["privacy_more"]}</a>' if i == 3 else '') + '</div></div>'
                      for i, (n, h, p) in enumerate(t['feats']))
    body = f'''<main>
<section class="hero" id="hero" data-hints="{esc(json.dumps(t['hints'], ensure_ascii=False))}"><div class="wrap">
<a class="news" href="changelog.html">{news}</a>
<h1>{t['hero']}</h1>
<button type="button" class="timer" aria-label="{t['try_aria']}"><span class="num">60</span><span class="hint" aria-live="polite">{t['hints']['idle']}</span></button>
<div class="track" aria-hidden="true"><i></i></div>
<div class="presets">{presets}</div>
<div class="cta"><a class="btn white" href="{STORE}">{t['download']}</a><span class="sub">{t['devices']}</span></div>
</div></section>

<section class="sec">
<div class="wrap"><h2 class="big">{t['shots_title']}</h2><p class="lead">{t['shots_lead']}</p></div>
<div class="shots" tabindex="0">
{shots}
</div>
<div class="wrap bar" aria-hidden="true"><div><i></i></div></div>
</section>

<section class="sec pad"><div class="feats">
<h2 class="big">{t['feats_title']}</h2>
{feats}
</div></section>

<section class="end"><div class="in">
<h2 class="big">{t['end_title']}</h2>
<p>{t['end_text']}</p>
<a class="btn orange" href="{STORE}">{t['download']}</a>
<span class="sub">{t['requires']}</span>
</div></section>
</main>'''
    return page(lang, 'index.html', f'{t["brand"]} — {t["tagline"]}', body)


def support(lang):
    t = T[lang]
    intro, cats = read_support(lang)
    chips = f'<button type="button" data-cat="all" aria-pressed="true">{t["all"]}</button>' + ''.join(
        f'<button type="button" data-cat="c{i}" aria-pressed="false">{esc(c["label"])}</button>' for i, c in enumerate(cats))
    items = []
    for i, c in enumerate(cats):
        for q in c['qs']:
            answer = ''.join(f'<p>{inline(p)}</p>' for p in q['ps'])
            if q['cards']:
                answer += '<div class="split">' + ''.join(
                    f'<div class="card"><span class="tag{" hot" if j == 0 else ""}">{inline(tag)}</span><strong>{inline(title)}</strong><span class="body">{inline(body)}</span></div>'
                    for j, (tag, title, body) in enumerate(q['cards'])) + '</div>'
            answer += ''.join(f'<p class="after">{inline(p)}</p>' for p in q['after'])
            items.append(f'<details data-cat="c{i}"{" open" if q["cards"] else ""}><summary><span class="qt"><span class="cat">{esc(c["label"])}</span>'
                         f'<span class="q">{inline(q["q"])}</span></span><span class="chev">{CHEVRON}</span></summary><div class="ans">{answer}</div></details>')
    mail = f'mailto:{EMAIL}?subject={quote(t["mail_subject"])}&amp;body={quote(t["mail_body"])}'
    body = f'''<main class="page">
<div class="eyebrow">{t['support']}</div>
<h1 class="title">{t['support_title']}</h1>
<p class="intro">{inline(intro)}</p>
<div class="cols">
<div class="colmain">
<div class="chips">{chips}</div>
<div class="faq">
{chr(10).join(items)}
</div>
</div>
<aside class="contact">
<div class="label">{t['contact']}</div>
<a class="mail" href="{mail}">{EMAIL}</a>
<div class="acts"><a class="send" href="{mail}">{t['send']}</a><button type="button" class="copy" data-mail="{EMAIL}" data-label="{t['copy']}" data-done="{t['copied']}">{t['copy']}</button></div>
<hr>
<div class="h">{t['include']}</div>
<ol>{''.join(f'<li>{esc(x)}</li>' for x in t['include_items'])}</ol>
<p class="note">{t['include_note']}</p>
</aside>
</div>
</main>'''
    return page(lang, 'support.html', f'{t["support"]} · {t["brand"]}', body, 'support')


def changelog(lang, releases):
    t = T[lang]
    articles = []
    for i, r in enumerate(releases):
        if is_date(r['label']):
            meta = (f'<span class="kind">{esc(r["note"])}</span>' if r['note'] else '') + f'<span class="date">{esc(r["label"])}</span>'
        else:
            meta = f'<span class="status">{esc(r["label"])}</span>'
        items = ''.join(f'<li><span>{inline(x)}</span></li>' for x in r['items'])
        articles.append(f'<article class="rel{" latest" if i == 0 else ""}"><div class="v"><div class="ver">{esc(r["version"])}</div><div class="meta">{meta}</div></div><ul>{items}</ul></article>')
    body = f'''<main class="page">
<div class="eyebrow">{t['changelog']}</div>
<h1 class="title">{t['changelog_title']}</h1>
<div class="changes">
{chr(10).join(articles)}
</div>
</main>'''
    return page(lang, 'changelog.html', f'{t["changelog"]} · {t["brand"]}', body, 'changelog')


def policy_part(block):
    if block.startswith('- '):
        lines = [line[2:] for line in block.splitlines()]
        if all(re.match(r'\*\*.+?:\*\*', line) for line in lines):
            rows = [re.match(r'\*\*(.+?):\*\*\s*(.+)', line).groups() for line in lines]
            return ''.join(f'<div class="row"><span>{inline(k)}</span><span>{inline(v)}</span></div>' for k, v in rows)
        return '<div class="dots">' + ''.join(f'<div class="dot"><span>{inline(line)}</span></div>' for line in lines) + '</div>'
    mail = re.fullmatch(r'\[(.+?)\]\((mailto:.+?)\)', block)
    if mail:
        return f'<a class="mail" href="{mail.group(2)}">{esc(mail.group(1))}</a>'
    return f'<p>{inline(block)}</p>'


def privacy(lang):
    t = T[lang]
    intro, sections = read_policy(lang)
    toc = ''.join(f'<a href="#p{s["number"]}"><b>{s["number"]}</b>{esc(s["title"])}</a>' for s in sections)
    secs = '\n'.join(f'<section id="p{s["number"]}"><h2><b>{s["number"]}</b>{esc(s["title"])}</h2>{"".join(policy_part(p) for p in s["parts"])}</section>'
                     for s in sections)
    body = f'''<main class="page">
<div class="eyebrow">{t['privacy_full']}</div>
<h1 class="title">{t['policy_title']}</h1>
<p class="summary">{esc(intro)}</p>
<div class="checks">{''.join(f'<span>{CHECK}{esc(c)}</span>' for c in t['checks'])}</div>
<div class="updated">{t['updated']}</div>
<div class="cols policy">
<nav class="toc" aria-label="{t['privacy_full']}">{toc}</nav>
<div class="pol">
{secs}
</div>
</div>
</main>'''
    return page(lang, 'privacy.html', f'{t["privacy_full"]} · {t["brand"]}', body, 'privacy')


if OUT.exists():
    shutil.rmtree(OUT)
shutil.copytree(STATIC, OUT / 'assets')
for lang in ['ko', 'en']:
    folder = OUT / lang
    folder.mkdir(parents=True, exist_ok=True)
    releases = read_changelog(lang)
    (folder / 'index.html').write_text(home(lang, releases))
    (folder / 'support.html').write_text(support(lang))
    (folder / 'changelog.html').write_text(changelog(lang, releases))
    (folder / 'privacy.html').write_text(privacy(lang))
# 루트는 언어를 골라 보낸다. 한국어(또는 판단 불가)는 ko, 그 밖은 en.
(OUT / 'index.html').write_text('''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>다음세트 · NextSet</title>
<meta http-equiv="refresh" content="0; url=ko/">
<script>try{var l=(navigator.languages&&navigator.languages[0])||navigator.language||'ko';location.replace(/^ko/i.test(l)?'ko/':'en/')}catch(e){}</script>
</head><body style="background:#000"><a href="ko/" style="color:#FF9500">다음세트</a> · <a href="en/" style="color:#FF9500">NextSet</a></body></html>
''')
print('Generated', OUT)
