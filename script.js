(function () {
  var hasStoredSession = false;

  try {
    hasStoredSession = Boolean(window.localStorage.getItem('token') && window.localStorage.getItem('user'));
  } catch (_error) {
    hasStoredSession = false;
  }

  if (hasStoredSession) {
    var loader = document.querySelector('.loader');
    if (loader) loader.classList.add('is-visible');
    window.setTimeout(function () {
      window.location.replace('/inbox');
    }, 520);
    return;
  }

  var revealItems = Array.prototype.slice.call(document.querySelectorAll('.reveal'));
  var supportsObserver = 'IntersectionObserver' in window;
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  if (!supportsObserver || reduceMotion) {
    revealItems.forEach(function (item) {
      item.classList.add('is-visible');
    });
  } else {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.22, rootMargin: '0px 0px -8% 0px' }
    );

    revealItems.forEach(function (item) {
      observer.observe(item);
    });
  }

  var heroScene = document.querySelector('.hero__scene');
  var ticking = false;

  function updateHero() {
    ticking = false;
    if (!heroScene || reduceMotion) return;

    var progress = Math.min(window.scrollY / Math.max(window.innerHeight, 1), 1);
    heroScene.style.setProperty('--hero-shift', progress * -92 + 'px');
    heroScene.style.setProperty('--hero-scale', 1 + progress * 0.08);
    heroScene.style.setProperty('--hero-opacity', 1 - progress * 0.46);
  }

  function onScroll() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(updateHero);
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  updateHero();
})();
