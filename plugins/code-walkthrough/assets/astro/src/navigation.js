"use strict";
document.documentElement.classList.add("js");
const steps = Array.from(document.querySelectorAll(".step"));
const select = document.getElementById("sections");
const previous = document.getElementById("previous");
const next = document.getElementById("next");
// In pages mode the arrows turn to these pages past the first and last step, and the picker
// holds page URLs instead of section ids.
const pages = document.querySelector(".navigation").dataset;
const book = !select.options[0]?.value.startsWith("section-");
const reduced = matchMedia("(prefers-reduced-motion: reduce)");
let active = null;
let navigating = false;
let navigationTimer;
function threshold()
{
	const header = document.querySelector(".topbar").getBoundingClientRect().height;
	document.documentElement.style.setProperty("--header", `${header}px`);
	const panel = document.querySelector(".code-panel");
	if (!panel) return header + 20;
	const line =
		innerWidth > 650
			? Math.max(header + 20, innerHeight * 0.35)
			: Math.min(innerHeight - 35, header + panel.getBoundingClientRect().height + 30);
	document.documentElement.style.setProperty("--reading-line", `${line}px`);
	return line;
}
function focusCode(step)
{
	const panel = step.closest(".section").querySelector(".code-panel");
	const first = Number(step.dataset.first),
		last = Number(step.dataset.last);
	const rows = Array.from(panel.querySelectorAll(".line"));
	for (const row of rows)
		row.classList.toggle("highlight", Number(row.dataset.line) >= first && Number(row.dataset.line) <= last);
	panel.querySelector(".range").textContent = `Lines ${first}–${last}`;
	if (panel.dataset.follow === "off") return;
	const pre = panel.querySelector("pre"),
		start = rows[first - 1],
		end = rows[last - 1];
	pre.scrollTop = Math.max(
		0,
		start.offsetTop - Math.max(8, (pre.clientHeight - (end.offsetTop + end.offsetHeight - start.offsetTop)) / 2),
	);
}
function activate(step)
{
	if (active !== step)
	{
		active?.classList.remove("is-active");
		active = step;
		active.classList.add("is-active");
	}
	if (!book) select.value = step.closest(".section").id;
	const index = steps.indexOf(step);
	previous.disabled = index === 0 && !pages.pagePrevious;
	next.disabled = index === steps.length - 1 && !pages.pageNext;
	focusCode(step);
}
function update()
{
	const height = document.documentElement.scrollHeight - innerHeight;
	document.querySelector(".progress").style.transform = `scaleX(${height > 0 ? scrollY / height : 0})`;
	if (navigating || !steps.length) return;
	const limit = threshold();
	let candidate = steps[0];
	for (const step of steps)
	{
		if (step.getBoundingClientRect().top <= limit) candidate = step;
		else break;
	}
	if (candidate !== active) activate(candidate);
}
function goTo(step, push = true, behavior = "smooth")
{
	navigating = true;
	clearTimeout(navigationTimer);
	activate(step);
	if (push) history.pushState(null, "", `#${step.id}`);
	window.scrollTo(
		{
			top: scrollY + step.getBoundingClientRect().top - threshold() + 2,
			behavior: reduced.matches ? "instant" : behavior,
		},
	);
	navigationTimer = setTimeout(() =>
	{
		navigating = false;
	}, 600);
}
let scheduled = false;
window.addEventListener(
	"scroll",
	() =>
	{
		if (!scheduled)
		{
			scheduled = true;
			requestAnimationFrame(() =>
			{
				scheduled = false;
				update();
			});
		}
	},
	{
		passive: true,
	},
);
window.addEventListener("resize", () =>
{
	threshold();
	if (active) goTo(active, false, "instant");
});
for (const event of ["wheel", "touchstart"])
	window.addEventListener(
		event,
		() =>
		{
			navigating = false;
			clearTimeout(navigationTimer);
		},
		{
			passive: true,
		},
	);
select.addEventListener("change", () =>
{
	if (book) location.href = select.value;
	else goTo(document.getElementById(select.value).querySelector(".step"));
});
previous.addEventListener("click", () =>
{
	const index = steps.indexOf(active);
	if (index > 0) goTo(steps[index - 1]);
	else if (pages.pagePrevious) location.href = pages.pagePrevious;
});
next.addEventListener("click", () =>
{
	const index = steps.indexOf(active);
	if (index >= 0 && index < steps.length - 1) goTo(steps[index + 1]);
	else if (pages.pageNext) location.href = pages.pageNext;
});
// Keyboard: ← / k and → / j step through explanations (turning pages at the ends), [ and ]
// jump a whole page or section, g goes to the contents, ? lists the shortcuts. Typing in a field, a focused code
// listing (where arrows scroll) and modified keys keep their usual meaning.
function turnSection(direction)
{
	if (book)
	{
		const url = direction < 0 ? pages.pagePrevious : pages.pageNext;
		if (url) location.href = url.split("#")[0];
		return;
	}
	const sections = Array.from(document.querySelectorAll(".section"));
	const current = sections.indexOf(active?.closest(".section"));
	const target = sections[Math.max(0, Math.min(sections.length - 1, current + direction))];
	if (target) goTo(target.querySelector(".step"));
}
const shortcuts = [
	["→ or j", "Next explanation; turns the page after the last one"],
	["← or k", "Previous explanation"],
	["]", book ? "Next page" : "Next section"],
	["[", book ? "Previous page" : "Previous section"],
	["g", book ? "Contents" : "Top of the page"],
	["?", "Show or hide these shortcuts"],
];
let help = null;
function toggleHelp()
{
	if (!help)
	{
		help = document.createElement("dialog");
		help.className = "shortcuts";
		help.setAttribute("aria-label", "Keyboard shortcuts");
		const heading = document.createElement("h2");
		heading.textContent = "Keyboard shortcuts";
		const list = document.createElement("dl");
		for (const [keys, meaning] of shortcuts)
		{
			const term = document.createElement("dt");
			for (const key of keys.split(" or "))
			{
				if (term.childNodes.length) term.append(" or ");
				const kbd = document.createElement("kbd");
				kbd.textContent = key;
				term.append(kbd);
			}
			const description = document.createElement("dd");
			description.textContent = meaning;
			list.append(term, description);
		}
		const close = document.createElement("button");
		close.textContent = "Close";
		close.addEventListener("click", () => help.close());
		help.append(heading, list, close);
		help.addEventListener("click", (event) =>
		{
			if (event.target === help) help.close();
		});
		document.body.append(help);
	}
	if (help.open) help.close();
	else help.showModal();
}
document.addEventListener("keydown", (event) =>
{
	if (
		event.key === "?" &&
		!event.ctrlKey &&
		!event.metaKey &&
		!event.altKey &&
		!event.target.closest?.("input, select, textarea, [contenteditable]")
	)
	{
		event.preventDefault();
		toggleHelp();
		return;
	}
	if (help?.open) return;

	if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return;
	const target = event.target;
	if (target.closest?.("input, select, textarea, [contenteditable], pre")) return;
	const action =
	{
		ArrowLeft: () => previous.click(),
		k: () => previous.click(),
		ArrowRight: () => next.click(),
		j: () => next.click(),
		"[": () => turnSection(-1),
		"]": () => turnSection(1),
		g: () =>
		{
			const home = document.querySelector(".topbar h1 a");
			if (home) location.href = home.href;
			else
				window.scrollTo(
					{
						top: 0,
						behavior: reduced.matches ? "instant" : "smooth",
					},
				);
		},
	}[event.key];
	if (!action) return;
	event.preventDefault();
	action();
});
for (const section of document.querySelectorAll(".section"))
{
	focusCode(section.querySelector(".step"));
	const panel = section.querySelector(".code-panel"),
		button = panel.querySelector(".follow");
	button.addEventListener("click", () =>
	{
		const enabled = panel.dataset.follow === "off";
		panel.dataset.follow = enabled ? "on" : "off";
		button.setAttribute("aria-pressed", String(enabled));
		button.textContent = `Follow scroll: ${enabled ? "on" : "off"}`;
		if (enabled) focusCode(section.querySelector(".is-active") || section.querySelector(".step"));
	});
}
document.addEventListener("click", (event) =>
{
	const link = event.target.closest(".location a");
	if (link)
	{
		event.preventDefault();
		goTo(document.getElementById(link.hash.slice(1)));
	}
});
function fromHash()
{
	const target = document.getElementById(location.hash.slice(1));
	if (target?.classList.contains("step")) goTo(target, false, "instant");
	else update();
}
window.addEventListener("popstate", fromHash);
threshold();
if (steps.length)
{
	activate(steps[0]);
	fromHash();
}
else
{
	previous.disabled = !pages.pagePrevious;
	next.disabled = !pages.pageNext;
}

document.querySelectorAll(".lab canvas").forEach((canvas) =>
{
	const wrapper = document.createElement("div");
	wrapper.className = "diagram-scroll";
	wrapper.tabIndex = 0;
	wrapper.setAttribute("aria-label", canvas.getAttribute("aria-label") + "; scroll horizontally on small screens");
	canvas.before(wrapper);
	wrapper.append(canvas);
});
