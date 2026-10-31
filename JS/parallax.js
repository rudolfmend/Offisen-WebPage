(() => {
  'use strict';
  const scene = document.querySelector('.reveal-scene');
  if (!scene) return;
  const image = scene.querySelector('.reveal-image');
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const desktop = matchMedia('(min-width: 1000px)');
  let frame = 0;
  const clamp = (v, min, max) => Math.min(max, Math.max(min, v));
  function render() {
    frame = 0;
    const enabled = desktop.matches && !motion.matches;
    scene.classList.toggle('is-animated', enabled);
    if (!enabled) {
      image.style.opacity = '';
      image.style.transform = '';
      return;
    }
    const rect = scene.getBoundingClientRect();
    const top = rect.top + window.scrollY;
    const start = Math.max(0, top - window.innerHeight * 0.65);
    const end = Math.max(start + 1, top - window.innerHeight * 0.12);
    const progress = clamp((window.scrollY - start) / (end - start), 0, 1);
    image.style.opacity = String(progress * progress * (3 - 2 * progress));
    image.style.transform = `translateY(${clamp(-rect.top * 0.18, -90, 90)}px)`;
  }
  function schedule() { if (!frame) frame = requestAnimationFrame(render); }
  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);
  window.addEventListener('pageshow', schedule);
  motion.addEventListener('change', schedule);
  desktop.addEventListener('change', schedule);
  render();
})();
