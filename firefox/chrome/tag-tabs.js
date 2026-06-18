/* Last working version: Mozilla Firefox 152.0 */
const SITES = {
	"https://discord.com":     "discord",
	"https://mail.google.com": "gmail",
	"https://www.youtube.com": "youtube",
	"https://canvas.u":        "canvas",
	"https://github.com":      "github",
};

function tagTab(tab) {
	const url = tab.linkedBrowser?.currentURI?.spec || "";

	for (const pattern in SITES) {
		if (url.includes(pattern)) {
			tab.setAttribute("data-site", SITES[pattern]);
			return;
		}
	}

	tab.removeAttribute("data-site");
}

Services.obs.addObserver(win => {
	win.addEventListener("load", () => {
		if (win.location.href !== "chrome://browser/content/browser.xhtml")
			return;

		win.addEventListener("SSWindowRestored", () => {
			for (const tab of win.gBrowser.tabs)
				tagTab(tab);
		}, { once: true });

		win.gBrowser.addTabsProgressListener({
			onLocationChange(browser) {
				tagTab(win.gBrowser.getTabForBrowser(browser));
			}
		});
	}, { once: true });
}, "domwindowopened");

