export default {
  defaultBrowser: "Google Chrome",
  options: {
    checkForUpdates: true,
    logRequests: false,
  },
  handlers: [
    {
      // Open any url that includes the string "workplace" in Firefox
      match: [
        "linkedin.com/*", // Match Linked-In
        "*.linkedin.com/*",
        
        "youtube.com/*", // Match Youtube
        "*.youtube.com/*",
        "youtu.be/*",
        
        "steampowered.com/*", // Match Steam
        "*.steampowered.com/*",

        "printables.com/*", // Match Prusa Sites
        "*.printables.com/*",
        "prusa3d.com/*",
        "*.prusa3d.com/*",
        "prusament.com/*",
        "*.prusament.com/*"
      ],
      browser: "Firefox"
    }
  ]
};
