'use strict';
document.documentElement.classList.add('js');
const steps = Array.from(document.querySelectorAll('.step'));
const select = document.getElementById('sections');
const previous = document.getElementById('previous');
const next = document.getElementById('next');
const reduced = matchMedia('(prefers-reduced-motion: reduce)');
let active = null;
let navigating = false;
let navigationTimer;
function threshold() {
	const header = document.querySelector('.topbar').getBoundingClientRect().height;
	document.documentElement.style.setProperty('--header', `${header}px`);
	const panel = document.querySelector('.code-panel');
	const line =
		innerWidth > 650
			? Math.max(header + 20, innerHeight * 0.35)
			: Math.min(innerHeight - 35, header + panel.getBoundingClientRect().height + 30);
	document.documentElement.style.setProperty('--reading-line', `${line}px`);
	return line;
}
function focusCode(step) {
	const panel = step.closest('.section').querySelector('.code-panel');
	const first = Number(step.dataset.first),
		last = Number(step.dataset.last);
	const rows = Array.from(panel.querySelectorAll('.line'));
	for (const row of rows)
		row.classList.toggle('highlight', Number(row.dataset.line) >= first && Number(row.dataset.line) <= last);
	panel.querySelector('.range').textContent = `Lines ${first}–${last}`;
	if (panel.dataset.follow === 'off') return;
	const pre = panel.querySelector('pre'),
		start = rows[first - 1],
		end = rows[last - 1];
	pre.scrollTop = Math.max(
		0,
		start.offsetTop - Math.max(8, (pre.clientHeight - (end.offsetTop + end.offsetHeight - start.offsetTop)) / 2),
	);
}
function activate(step) {
	if (active !== step) {
		active?.classList.remove('is-active');
		active = step;
		active.classList.add('is-active');
	}
	select.value = step.closest('.section').id;
	const index = steps.indexOf(step);
	previous.disabled = index === 0;
	next.disabled = index === steps.length - 1;
	focusCode(step);
}
function update() {
	const height = document.documentElement.scrollHeight - innerHeight;
	document.querySelector('.progress').style.transform = `scaleX(${height > 0 ? scrollY / height : 0})`;
	if (navigating) return;
	const limit = threshold();
	let candidate = steps[0];
	for (const step of steps) {
		if (step.getBoundingClientRect().top <= limit) candidate = step;
		else break;
	}
	if (candidate !== active) activate(candidate);
}
function goTo(step, push = true, behavior = 'smooth') {
	navigating = true;
	clearTimeout(navigationTimer);
	activate(step);
	if (push) history.pushState(null, '', `#${step.id}`);
	window.scrollTo({
		top: scrollY + step.getBoundingClientRect().top - threshold() + 2,
		behavior: reduced.matches ? 'instant' : behavior,
	});
	navigationTimer = setTimeout(() => {
		navigating = false;
	}, 600);
}
let scheduled = false;
window.addEventListener(
	'scroll',
	() => {
		if (!scheduled) {
			scheduled = true;
			requestAnimationFrame(() => {
				scheduled = false;
				update();
			});
		}
	},
	{passive: true},
);
window.addEventListener('resize', () => {
	threshold();
	if (active) goTo(active, false, 'instant');
});
for (const event of ['wheel', 'touchstart'])
	window.addEventListener(
		event,
		() => {
			navigating = false;
			clearTimeout(navigationTimer);
		},
		{passive: true},
	);
select.addEventListener('change', () => goTo(document.getElementById(select.value).querySelector('.step')));
previous.addEventListener('click', () => goTo(steps[Math.max(0, steps.indexOf(active) - 1)]));
next.addEventListener('click', () => goTo(steps[Math.min(steps.length - 1, steps.indexOf(active) + 1)]));
for (const section of document.querySelectorAll('.section')) {
	focusCode(section.querySelector('.step'));
	const panel = section.querySelector('.code-panel'),
		button = panel.querySelector('.follow');
	button.addEventListener('click', () => {
		const enabled = panel.dataset.follow === 'off';
		panel.dataset.follow = enabled ? 'on' : 'off';
		button.setAttribute('aria-pressed', String(enabled));
		button.textContent = `Follow scroll: ${enabled ? 'on' : 'off'}`;
		if (enabled) focusCode(section.querySelector('.is-active') || section.querySelector('.step'));
	});
}
document.addEventListener('click', (event) => {
	const link = event.target.closest('.location a');
	if (link) {
		event.preventDefault();
		goTo(document.getElementById(link.hash.slice(1)));
	}
});
function fromHash() {
	const target = document.getElementById(location.hash.slice(1));
	if (target?.classList.contains('step')) goTo(target, false, 'instant');
	else update();
}
window.addEventListener('popstate', fromHash);
threshold();
activate(steps[0]);
fromHash();

document.querySelectorAll('.lab canvas').forEach((canvas) => {
	const wrapper = document.createElement('div');
	wrapper.className = 'diagram-scroll';
	wrapper.tabIndex = 0;
	wrapper.setAttribute('aria-label', canvas.getAttribute('aria-label') + '; scroll horizontally on small screens');
	canvas.before(wrapper);
	wrapper.append(canvas);
});
