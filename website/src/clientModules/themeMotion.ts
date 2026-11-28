import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment';

const HERO_ROUTES = new Set(['/', '/getting-started']);

function syncChromeState() {
  const root = document.documentElement;
  const path = window.location.pathname.replace(/\/+$/, '') || '/';
  if (HERO_ROUTES.has(path)) {
    root.setAttribute('data-hero-page', 'true');
  } else {
    root.removeAttribute('data-hero-page');
  }

  if (window.scrollY > 16) {
    root.setAttribute('data-scrolled', 'true');
  } else {
    root.removeAttribute('data-scrolled');
  }
}

if (ExecutionEnvironment.canUseDOM) {
  syncChromeState();

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      document.documentElement.setAttribute('data-theme-ready', 'true');
    });
  });

  window.addEventListener(
    'scroll',
    () => {
      if (window.scrollY > 16) {
        document.documentElement.setAttribute('data-scrolled', 'true');
      } else {
        document.documentElement.removeAttribute('data-scrolled');
      }
    },
    {passive: true},
  );
}

export function onRouteDidUpdate() {
  if (ExecutionEnvironment.canUseDOM) {
    syncChromeState();
  }
}
