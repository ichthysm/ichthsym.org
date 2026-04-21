function activateTab(target) {
  const btn = document.querySelector(`.tab-btn[data-target="${target}"]`);
  const panel = document.getElementById(target);
  if (!btn || !panel) return;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
  btn.classList.add('active');
  panel.classList.add('active');
}

document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => activateTab(btn.dataset.target));
});

const hash = window.location.hash.slice(1);
if (hash) activateTab(hash);
