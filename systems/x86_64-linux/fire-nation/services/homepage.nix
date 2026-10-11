# Homepage, with its whole config declared here and mounted read-only at /app/config.
# Widget API keys come from sops: each is mounted as a file and referenced in the YAML
# as {{HOMEPAGE_FILE_<NAME>}}. Status dots use siteMonitor, so no container socket is needed.
{ pkgs, ... }:
let
  # Secret name -> sops key. The container gets /run/secrets/homepage_<name> and
  # HOMEPAGE_FILE_<NAME> pointing at it.
  secretKeys = {
    plex = "homepage/plex-token";
    jellyfin = "homepage/jellyfin-api-key";
    audiobookshelf = "homepage/audiobookshelf-api-key";
    overseerr = "homepage/overseerr-api-key";
    qbittorrent_user = "homepage/qbittorrent-username";
    qbittorrent_pass = "homepage/qbittorrent-password";
    sabnzbd = "homepage/sabnzbd-api-key";
    sonarr = "homepage/sonarr-api-key";
    radarr = "homepage/radarr-api-key";
    lidarr = "homepage/lidarr-api-key";
    bazarr = "homepage/bazarr-api-key";
    prowlarr = "homepage/prowlarr-api-key";
  };

  secretPath = name: "/run/secrets/homepage_${name}";
  ref = name: "{{HOMEPAGE_FILE_${pkgs.lib.toUpper name}}}";

  # One entry: href is where the tile links, url is how Homepage reaches the container.
  entry =
    {
      name,
      icon,
      description,
      href,
      url,
      monitor ? url,
      widget ? null,
    }:
    {
      ${name} = {
        inherit icon description href;
        siteMonitor = monitor;
      }
      // pkgs.lib.optionalAttrs (widget != null) { widget = widget // { inherit url; }; };
    };

  site = host: "https://${host}.firenation.app";

  services = [
    {
      "Media Servers" = [
        (entry {
          name = "Plex";
          icon = "plex.png";
          description = "Media server";
          href = "http://fire-nation:32400/web";
          url = "http://plex:32400";
          monitor = "http://plex:32400/identity";
          widget = {
            type = "plex";
            key = ref "plex";
          };
        })
        (entry {
          name = "Jellyfin";
          icon = "jellyfin.png";
          description = "Media server";
          href = site "jelly";
          url = "http://jellyfin:8096";
          widget = {
            type = "jellyfin";
            version = 2;
            key = ref "jellyfin";
            enableNowPlaying = true;
          };
        })
      ];
    }
    {
      "Books" = [
        (entry {
          name = "Audiobookshelf";
          icon = "audiobookshelf.png";
          description = "Audiobooks";
          href = site "bookshelf";
          url = "http://audiobookshelf:80";
          widget = {
            type = "audiobookshelf";
            key = ref "audiobookshelf";
          };
        })
        (entry {
          name = "Grimmory";
          icon = "book-lore.png";
          description = "E-book manager";
          href = site "grimmory";
          url = "http://grimmory:6060";
        })
        (entry {
          name = "Shelfmark";
          icon = "booklogr-light.png";
          description = "E-book downloader";
          href = site "shelfmark";
          url = "http://shelfmark:8084";
        })
      ];
    }
    {
      "Analytics & Requests" = [
        (entry {
          name = "Seerr";
          icon = "overseerr.png";
          description = "Request manager";
          href = site "overseerr";
          url = "http://overseerr:5055";
          widget = {
            type = "overseerr";
            key = ref "overseerr";
          };
        })
        (entry {
          name = "Tautulli";
          icon = "tautulli.png";
          description = "Plex metrics";
          href = site "tautulli";
          url = "http://tautulli:8181";
        })
      ];
    }
    {
      "Downloads" = [
        (entry {
          name = "qBittorrent";
          icon = "qbittorrent.png";
          description = "Torrent downloader";
          href = site "qbittorrent";
          # Shares the wireguard container's network, so it answers on that name.
          url = "http://wireguard:9090";
          widget = {
            type = "qbittorrent";
            username = ref "qbittorrent_user";
            password = ref "qbittorrent_pass";
            enableLeechProgress = true;
            enableLeechSize = true;
          };
        })
        (entry {
          name = "SABnzbd";
          icon = "sabnzbd.png";
          description = "Usenet downloader";
          href = site "sabnzbd";
          url = "http://sabnzbd:8080";
          widget = {
            type = "sabnzbd";
            key = ref "sabnzbd";
          };
        })
      ];
    }
    {
      "Servarr" = [
        (entry {
          name = "Sonarr";
          icon = "sonarr.png";
          description = "Series";
          href = site "sonarr";
          url = "http://sonarr:8989";
          monitor = "http://sonarr:8989/ping";
          widget = {
            type = "sonarr";
            key = ref "sonarr";
          };
        })
        (entry {
          name = "Radarr";
          icon = "radarr.png";
          description = "Movies";
          href = site "radarr";
          url = "http://radarr:7878";
          monitor = "http://radarr:7878/ping";
          widget = {
            type = "radarr";
            key = ref "radarr";
          };
        })
        (entry {
          name = "Lidarr";
          icon = "lidarr.png";
          description = "Music";
          href = site "lidarr";
          url = "http://lidarr:8686";
          monitor = "http://lidarr:8686/ping";
          widget = {
            type = "lidarr";
            key = ref "lidarr";
          };
        })
        (entry {
          name = "Bazarr";
          icon = "bazarr.png";
          description = "Subtitles";
          href = site "bazarr";
          url = "http://bazarr:6767";
          widget = {
            type = "bazarr";
            key = ref "bazarr";
          };
        })
        (entry {
          name = "Prowlarr";
          icon = "prowlarr.png";
          description = "Indexers";
          href = site "prowlarr";
          url = "http://prowlarr:9696";
          monitor = "http://prowlarr:9696/ping";
          widget = {
            type = "prowlarr";
            key = ref "prowlarr";
          };
        })
        (entry {
          name = "Tdarr";
          icon = "tdarr.png";
          description = "Video re-encoder";
          href = site "tdarr";
          # The UI is on 8265; the API the widget reads is on 8266.
          url = "http://tdarr:8266";
          monitor = "http://tdarr:8265";
          widget.type = "tdarr";
        })
      ];
    }
    {
      "Identity" = [
        (entry {
          name = "Pocket ID";
          icon = "pocket-id.png";
          description = "Single sign-on";
          href = "https://firenation.app";
          url = "http://pocket-id:1411";
        })
        (entry {
          name = "tinyauth";
          icon = "tinyauth.png";
          description = "Forward auth";
          href = site "tinyauth";
          url = "http://tinyauth:3003";
        })
      ];
    }
    {
      "Automation" = [
        {
          HomeAssistant = {
            icon = "homeassistant.png";
            description = "Home automation";
            # Host-networked and rootful, so it isn't reachable by name from here.
            href = "http://fire-nation:8123";
          };
        }
      ];
    }
  ];

  settings = {
    title = "FireNation";
    theme = "dark";
    color = "zinc";
    headerStyle = "boxedWidgets";
    # Docker-only displays; there is no container integration any more.
    showStatus = false;
    showStats = false;
    iconStyle = "theme";
    favicon = "/images/favicon.ico";
    background = {
      image = "/images/wall.png";
      blur = "sm";
      brightness = 50;
    };
    layout = {
      "Media Servers" = {
        icon = "mdi-multicast";
        tab = "Content";
        columns = 2;
      };
      "Analytics & Requests" = {
        icon = "mdi-google-analytics";
        tab = "Content";
        columns = 2;
      };
      "Books" = {
        icon = "mdi-bookshelf";
        tab = "Content";
        columns = 3;
      };
      "Downloads" = {
        icon = "mdi-download";
        tab = "Content";
        columns = 2;
      };
      "Servarr" = {
        icon = "mdi-server";
        tab = "Content";
        style = "row";
        columns = 3;
      };
      "Identity" = {
        icon = "mdi-shield-account";
        tab = "Management";
        columns = 2;
      };
      "Automation" = {
        icon = "mdi-home-assistant";
        tab = "Automations";
        columns = 4;
      };
    };
    quicklaunch = {
      searchDescriptions = true;
      hideInternetSearch = true;
      showSearchSuggestions = true;
      hideVisitURL = true;
      provider = "duckduckgo";
    };
  };

  widgets = [
    {
      resources = {
        label = "System";
        cpu = true;
        cputemp = true;
        memory = true;
        uptime = true;
        disk = "/";
      };
    }
    {
      resources = {
        label = "Media";
        disk = "/mnt/data";
      };
    }
    {
      resources = {
        label = "Cache";
        disk = "/mnt/cache";
      };
    }
    {
      resources = {
        label = "Home";
        disk = "/mnt/home";
      };
    }
    {
      search = {
        provider = "duckduckgo";
        target = "_blank";
      };
    }
  ];

  bookmarks = [
    {
      Developer = [
        {
          Github = [
            {
              abbr = "GH";
              href = "https://github.com/r0adkll";
            }
          ];
        }
        {
          dotfiles = [
            {
              abbr = "DF";
              href = "https://github.com/r0adkll/dotfiles";
            }
          ];
        }
      ];
    }
    {
      Social = [
        {
          Reddit = [
            {
              abbr = "RDDT";
              href = "https://reddit.com/u/R0ADKLL";
            }
          ];
        }
      ];
    }
  ];

  # JSON is valid YAML, so toJSON is enough. The files are copied, not linked: the mount
  # only sees this directory, so symlinks into other store paths would dangle. Homepage
  # copies a skeleton for any file it doesn't find, which fails on a read-only mount, so
  # every file it knows about is present.
  configFiles = {
    "services.yaml" = builtins.toJSON services;
    "settings.yaml" = builtins.toJSON settings;
    "widgets.yaml" = builtins.toJSON widgets;
    "bookmarks.yaml" = builtins.toJSON bookmarks;
    "docker.yaml" = "{}";
    "kubernetes.yaml" = "{}";
    "proxmox.yaml" = "{}";
    "custom.css" = "";
    "custom.js" = "";
  };
  configDir = pkgs.runCommand "homepage-config" { } (
    "mkdir $out\n"
    + pkgs.lib.concatStrings (
      pkgs.lib.mapAttrsToList (
        name: text: "cp ${pkgs.writeText name text} $out/${name}\n"
      ) configFiles
    )
  );
in
{
  firenation.services.homepage = {
    image = "ghcr.io/gethomepage/homepage:latest";
    uid = 1017;
    port = 3000;
    # LAN devices without Tailscale still reach http://fire-nation:3000
    lanPorts = [ "3000:3000" ];
    access = "private";
    subdomain = "homepage";
    state.images = "/app/public/images";
    volumes = [
      "${configDir}:/app/config:ro"
      # read-only views for its disk widgets
      "/mnt/data:/mnt/data:ro"
      "/mnt/cache:/mnt/cache:ro"
      "/mnt/home:/mnt/home:ro"
    ];
    environment = {
      LOG_TARGETS = "stdout";
      HOMEPAGE_ALLOWED_HOSTS = "fire-nation:3000,homepage.firenation.app";
    }
    // pkgs.lib.mapAttrs' (
      name: _: pkgs.lib.nameValuePair "HOMEPAGE_FILE_${pkgs.lib.toUpper name}" (secretPath name)
    ) secretKeys;
    secrets.files = pkgs.lib.mapAttrs' (
      name: key: pkgs.lib.nameValuePair (secretPath name) key
    ) secretKeys;
  };
}
