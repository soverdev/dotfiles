/* Last working version: Mozilla Firefox 152.0 */
const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
const io = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
const ds = Cc["@mozilla.org/file/directory_service;1"].getService(Ci.nsIProperties);
const timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);

const chromeFile  = ds.get("UChrm", Ci.nsIFile);
chromeFile.append("user-chrome.css");

const contentFile = ds.get("UChrm", Ci.nsIFile);
contentFile.append("user-content.css");

const chromeURI   = io.newFileURI(chromeFile);
const contentURI  = io.newFileURI(contentFile);

const reloadSignal = ds.get("UChrm", Ci.nsIFile);
reloadSignal.append("reload-signal");

function reloadSheet(sheetURI) {
	if (sss.sheetRegistered(sheetURI,  sss.USER_SHEET))
		sss.unregisterSheet(sheetURI,  sss.USER_SHEET);

	sss.loadAndRegisterSheet(sheetURI,  sss.USER_SHEET);
}

function reloadTheme() {
	try {
		if (!reloadSignal.exists())
			return;

		reloadSignal.remove(false);

		reloadSheet(chromeURI);
		reloadSheet(contentURI);
	} catch (e) {}
}

/* Initial theme load */
try {
	reloadSheet(chromeURI);
	reloadSheet(contentURI);
} catch (e) {}

/* Check every 200ms if theme needs to be reloaded */
timer.initWithCallback(reloadTheme, 200, Ci.nsITimer.TYPE_REPEATING_SLACK);

