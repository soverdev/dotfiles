/* Last working version: Mozilla Firefox 152.0 */
const _ds = Cc["@mozilla.org/file/directory_service;1"].getService(Ci.nsIProperties);
const _io = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);

function loadUserScript(filename) {
	try {
		const file = _ds.get("UChrm", Ci.nsIFile);
		file.append(filename);
		Services.scriptloader.loadSubScript(_io.newFileURI(file).spec);
	} catch (e) {}
}

loadUserScript("theme-reload.js");
loadUserScript("tag-tabs.js");

