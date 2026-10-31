// Runs before the first paint. Light is the default; only a saved "dark" changes it.
(function () {
  var root = document.documentElement;
  var saved = null;

  root.classList.add('js');

  try {
    saved = localStorage.getItem('theme');
  } catch (e) {
    // Storage unavailable: stay light.
  }

  root.setAttribute('data-theme', saved === 'dark' ? 'dark' : 'light');
})();
