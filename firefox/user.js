/* Last working version: Mozilla Firefox 152.0 */

// Enable customization
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("svg.context-properties.content.enabled", true);

user_pref("browser.tabs.tabClipWidth", 83);

// Ask before closing multiple tabs
user_pref("browser.tabs.warnOnClose", true);

// Restore previous session on startup
user_pref("browser.startup.page", 3);

// Disable sponsored stuff
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);

// Disable tab group creation
user_pref("browser.tabs.dragDrop.createGroup.enabled", false);

// Improve search suggestions
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.suggest.trending", false);

// Prefer dark mode
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");

// Disable all "AI enhancements" except translation
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.smartWindow", "blocked");
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.page", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("extensions.ml.enabled", false);
user_pref("pdfjs.enableAltText", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.smartwindow.memories.generateFromConversation", false);
user_pref("browser.smartwindow.memories.generateFromHistory", false);
user_pref("browser.ai.control.translations", "available");

// Remove unnecessary items from toolbar
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"downloads-button\",\"unified-extensions-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"developer-button\",\"screenshot-button\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"PersonalToolbar\",\"toolbar-menubar\",\"TabsToolbar\",\"unified-extensions-area\"],\"currentVersion\":23,\"newElementCount\":3}");
user_pref("extensions.ui.dictionary.hidden", true);
user_pref("extensions.ui.lastCategory", "addons://discover/");
user_pref("extensions.ui.locale.hidden", true);
user_pref("extensions.ui.mlmodel.hidden", true);
user_pref("extensions.ui.sitepermission.hidden", true);
user_pref("extensions.unifiedExtensions.button.always_visible", false);

// Disable data collection and use
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("nimbus.rollouts.enabled", false);

// Security settings
user_pref("dom.security.https_only_mode", true);
user_pref("privacy.globalprivacycontrol.enabled", true);

// Forms
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("signon.autofillForms", false);
user_pref("signon.firefoxRelay.feature", "disabled");
user_pref("signon.generation.enabled", false);

// Disable previous/next page swiping
user_pref("browser.gesture.swipe.left", "");
user_pref("browser.gesture.swipe.right", "");

// Disable weather widget on new tab page
user_pref("browser.newtabpage.activity-stream.widgets.weather.enabled", false);

// Disable bright purple gradient on new private tab
user_pref("browser.privatebrowsing.felt-privacy-v1", false);

