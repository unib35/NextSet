// 시안의 동작: 첫 화면 체험 타이머, 스크린샷 스크롤 막대, 지원 분류 칩, 이메일 복사. 없어도 페이지는 읽힌다.
(() => {
  const hero = document.getElementById('hero');
  if (hero) {
    const num = hero.querySelector('.num'), hint = hero.querySelector('.hint'), fill = hero.querySelector('.track i');
    const presets = [...hero.querySelectorAll('.presets button')], hints = JSON.parse(hero.dataset.hints);
    let secs = 60, rem = 60, phase = 'idle', endAt = 0;
    const render = () => {
      hero.classList.toggle('done', phase === 'done');
      hero.classList.toggle('paused', phase === 'paused');
      num.textContent = phase === 'idle' ? secs : Math.ceil(rem);
      hint.textContent = hints[phase];
      fill.style.width = (phase === 'idle' ? 100 : rem / secs * 100) + '%';
      presets.forEach(b => b.setAttribute('aria-pressed', String(+b.dataset.s === secs)));
    };
    setInterval(() => {
      if (phase !== 'running') return;
      rem = Math.max(0, (endAt - Date.now()) / 1000);
      if (rem <= 0) phase = 'done';
      render();
    }, 100);
    hero.querySelector('.timer').addEventListener('click', () => {
      const now = Date.now();
      if (phase === 'idle') { phase = 'running'; endAt = now + secs * 1000; rem = secs; }
      else if (phase === 'running') { phase = 'paused'; rem = Math.max(0, (endAt - now) / 1000); }
      else if (phase === 'paused') { phase = 'running'; endAt = now + rem * 1000; }
      else { phase = 'idle'; rem = secs; }
      render();
    });
    presets.forEach(b => b.addEventListener('click', () => { secs = rem = +b.dataset.s; phase = 'idle'; render(); }));
    render();
  }

  const shots = document.querySelector('.shots'), thumb = document.querySelector('.bar i');
  if (shots && thumb) {
    const measure = () => {
      const max = shots.scrollWidth - shots.clientWidth, w = Math.min(100, shots.clientWidth / shots.scrollWidth * 100);
      thumb.style.width = w + '%';
      thumb.style.left = (max > 0 ? shots.scrollLeft / max * (100 - w) : 0) + '%';
    };
    shots.addEventListener('scroll', measure, { passive: true });
    addEventListener('resize', measure);
    addEventListener('load', measure);
    measure();
  }

  const chips = [...document.querySelectorAll('.chips button')];
  chips.forEach(chip => chip.addEventListener('click', () => {
    chips.forEach(c => c.setAttribute('aria-pressed', String(c === chip)));
    document.querySelectorAll('.faq details').forEach(d => { d.hidden = chip.dataset.cat !== 'all' && d.dataset.cat !== chip.dataset.cat; });
  }));

  const copy = document.querySelector('.copy');
  if (copy) copy.addEventListener('click', () => {
    try { navigator.clipboard.writeText(copy.dataset.mail).catch(() => {}); } catch (e) {}
    copy.textContent = copy.dataset.done;
    clearTimeout(copy.t);
    copy.t = setTimeout(() => { copy.textContent = copy.dataset.label; }, 1600);
  });
})();
