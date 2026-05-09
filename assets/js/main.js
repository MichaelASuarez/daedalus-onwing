/* Daedalus onWing — main.js */

// Nav scroll glass effect
const nav = document.getElementById('nav');
if (nav) {
  const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 60);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll(); // set initial state
}

// Mobile hamburger toggle
const hamburger = document.querySelector('.nav-hamburger');
if (hamburger && nav) {
  hamburger.addEventListener('click', () => {
    const open = nav.classList.toggle('mobile-open');
    hamburger.setAttribute('aria-expanded', open);
  });

  // Close drawer when a mobile link is tapped
  document.querySelectorAll('.nav-mobile-link').forEach(link => {
    link.addEventListener('click', () => {
      nav.classList.remove('mobile-open');
      hamburger.setAttribute('aria-expanded', 'false');
    });
  });

  // Close drawer on outside click
  document.addEventListener('click', (e) => {
    if (nav.classList.contains('mobile-open') && !nav.contains(e.target)) {
      nav.classList.remove('mobile-open');
      hamburger.setAttribute('aria-expanded', 'false');
    }
  });
}

// Scroll-in animations via IntersectionObserver
const animObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      animObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

document.querySelectorAll('.animate-in').forEach(el => animObserver.observe(el));

// Active nav link highlighting
const currentPath = window.location.pathname.replace(/\/$/, '') || '/';
document.querySelectorAll('.nav-link[href]').forEach(link => {
  const href = link.getAttribute('href').replace(/\/$/, '') || '/';
  if (currentPath === href || currentPath.startsWith(href) && href !== '/') {
    link.classList.add('active');
  }
});
