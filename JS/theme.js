(function () {
  const root = document.documentElement;
  const toggle = document.querySelector('.theme-toggle');
  const icon = document.getElementById('theme-icon');
  if (!toggle || !icon) return;

  const savedTheme = localStorage.getItem('theme');
  const systemPrefersLight = window.matchMedia('(prefers-color-scheme: light)').matches;

  const initial = savedTheme ?? (systemPrefersLight ? 'light' : 'dark');
  root.setAttribute('data-theme', initial);
  updateIcon();

  toggle.addEventListener('click', () => {
    const next = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
    root.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
    updateIcon();
  });

  function updateIcon() {
    icon.textContent = root.getAttribute('data-theme') === 'light' ? '🌞' : '🌙';
  }
})();
