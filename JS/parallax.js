// Image movement per scrolled pixel, shared by both parallax images.
const PARALLAX_RATE = 0.23;

(() => {
  'use strict';
  const scene = document.querySelector('.reveal-scene');
  if (!scene) return;
  const image = scene.querySelector('.reveal-image');
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const desktop = matchMedia('(min-width: 1000px)');
  let frame = 0;
  const clamp = (v, min, max) => Math.min(max, Math.max(min, v));
  // Too late: the CSS fallback has already started showing the image, so it stays static until the next load.
  if (desktop.matches && !motion.matches && getComputedStyle(image).opacity !== '0') {
    const settle = () => scene.classList.add('is-static');
    if (getComputedStyle(image).opacity === '1') {
      settle();
    } else {
      image.addEventListener('animationend', settle, { once: true });
      image.addEventListener('animationcancel', settle, { once: true });
    }
    return;
  }
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
    image.style.transform = `translateY(${clamp(-rect.top * PARALLAX_RATE, -150, 150)}px)`;
  }
  function schedule() { if (!frame) frame = requestAnimationFrame(render); }
  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);
  window.addEventListener('pageshow', schedule);
  motion.addEventListener('change', schedule);
  desktop.addEventListener('change', schedule);
  render();
})();

// Closing call to action: the image is always visible; only its position moves.
(() => {
  'use strict';
  const scene = document.querySelector('.cta-scene');
  if (!scene || !('IntersectionObserver' in window)) return;
  const layer = scene.querySelector('.cta-scene-image');
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const desktop = matchMedia('(min-width: 1000px)');
  const LIMIT = 120; // px either way; keep below the overscan in parallax.css.
  const MARGIN = 100;
  let frame = 0;
  let near = false;
  let preloaded = false;
  let zoneStart = 0;
  let zoneEnd = 0;

  function render() {
    frame = 0;
    if (!desktop.matches || motion.matches) {
      layer.style.transform = '';
      return;
    }
    // Out of range the last position simply stays; it cannot be seen.
    if (!inZone()) return;
    const rect = scene.getBoundingClientRect();
    // The section sits near the page end, so travel finishes where scrolling can actually stop.
    const top = rect.top + window.scrollY;
    const start = top - window.innerHeight;
    const end = Math.min(top + rect.height, document.documentElement.scrollHeight - window.innerHeight);
    // Counted back from that end: if a taller section (enlarged text) needs more than the limit,
    // the image waits while the section is just entering, and the speed stays constant after that.
    const atEnd = Math.min(LIMIT, (end - start) * PARALLAX_RATE / 2);
    const y = Math.min(end, Math.max(start, window.scrollY));
    const offset = Math.max(-LIMIT, atEnd - (end - y) * PARALLAX_RATE);
    layer.style.transform = `translate3d(0, ${offset.toFixed(1)}px, 0)`;
  }
  function schedule() { if (!frame) frame = requestAnimationFrame(render); }

  // Layout is read only when it changes. Each scroll event costs one comparison until the
  // section is close, and the update lands in the same frame even after a long jump.
  function measure() {
    const rect = scene.getBoundingClientRect();
    const top = rect.top + window.scrollY;
    zoneStart = top - window.innerHeight - MARGIN;
    zoneEnd = top + rect.height + MARGIN;
    schedule();
  }
  function inZone() { return window.scrollY >= zoneStart && window.scrollY <= zoneEnd; }
  function onScroll() { if (inZone()) schedule(); }

  // Both variants are ready before arrival, so a theme switch at this section shows no gap.
  function preload() {
    if (preloaded) return;
    preloaded = true;
    scene.querySelectorAll('img').forEach((img) => {
      img.loading = 'eager';
      img.decode().catch(() => {});
    });
  }

  new IntersectionObserver((entries) => {
    const entry = entries[entries.length - 1];
    if (entry.isIntersecting) preload();
  }, { rootMargin: '1000px 0px' }).observe(scene);

  function refresh() {
    scene.classList.toggle('is-near', near && desktop.matches && !motion.matches);
    schedule();
  }

  // The layer is promoted only around the viewport.
  new IntersectionObserver((entries) => {
    near = entries[entries.length - 1].isIntersecting;
    refresh();
  }, { rootMargin: `${MARGIN}px 0px` }).observe(scene);

  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', measure);
  window.addEventListener('pageshow', measure);
  if ('ResizeObserver' in window) new ResizeObserver(measure).observe(document.documentElement);
  measure();
  motion.addEventListener('change', refresh);
  desktop.addEventListener('change', refresh);
})();
