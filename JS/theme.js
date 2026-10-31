(function () {
  const root = document.documentElement;
  const toggle = document.querySelector('.theme-toggle');
  const icon = document.getElementById('theme-icon');

  function readSavedTheme() {
    try {
      return localStorage.getItem('theme') === 'dark' ? 'dark' : 'light';
    } catch (e) {
      return null;
    }
  }

  function saveTheme(theme) {
    try {
      localStorage.setItem('theme', theme);
    } catch (e) {
      // Storage unavailable: the choice applies to this page only.
    }
  }

  function applyTheme(theme) {
    root.setAttribute('data-theme', theme);
    if (!toggle || !icon) return;

    // The button names the action it offers, not the current state.
    const toDark = theme !== 'dark';
    const label = toDark ? 'Switch to dark theme' : 'Switch to light theme';
    icon.textContent = toDark ? '🌙' : '🌞';
    toggle.setAttribute('aria-label', label);
    toggle.setAttribute('title', label);
  }

  function syncWithStorage() {
    const saved = readSavedTheme();
    if (saved) applyTheme(saved);
  }

  applyTheme(root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light');

  if (toggle) {
    toggle.addEventListener('click', () => {
      const next = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      applyTheme(next);
      saveTheme(next);
    });
  }

  // A page restored from the back/forward cache, or another open tab, may hold an older choice.
  window.addEventListener('pageshow', (event) => {
    if (event.persisted) syncWithStorage();
  });
  window.addEventListener('storage', (event) => {
    if (event.key === 'theme') syncWithStorage();
  });
})();
