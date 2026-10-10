### 2.2.7

- feat(i18n): register new languages in guide and detect Traditional Chinese locales
- feat(i18n): add Hindi translation
- feat(i18n): add Persian translation
- feat(i18n): add Dutch translation
- feat(i18n): add Indonesian translation
- feat(i18n): add Turkish translation
- feat(i18n): add Polish translation
- feat(i18n): add Traditional Chinese translation
- feat(i18n): add Simplified Chinese translation
- feat(i18n): add Japanese translation
- fix(dock): eliminate hover gaps between apps and allow unclipped hover scaling
- feat(i18n): add French translation and language option in guide
- feat(lyrics): add free scrolling, click-to-seek, and word-scoped dragging
- perf(wallpaper): selectively preload picker in main and optimize filter lifecycle
- feat: add Arabic translation and full RTL layout support
- style: make floating panel background fully opaque
- fix: correct tab name orientation when floating panel is at bottom
- fix(audio): resolve cava watchdog deadlock, process signals and stream filtering
- fix: optimize cava lifecycle with pipewire stream detection and resolve binding loop
- perf(niri): share one event-stream between workspaces, dock and keyboard modules (#419)
- fix(screenshot): explicitly grab keyboard focus when overlay is activated
- fix(floating): switch keyboard focus to on-demand to prevent starving exclusive overlays
- fix(input): hide typing pop animation overlay on text removal in multiline input
- perf(music): watch the equalizer state file instead of polling equalizer.sh (#418)
- perf(sysdata): keep fetcher state on tmpfs instead of ~/.cache (#417)
- feat(osd): add value readout for volume and brightness sliders
- fix(clipboard): prevent image preview flicker during expansion animation
- feat: add reverse exit animations for all window registry components
- chore: flake update
- fix(screenshot): toggle audio mute on right click instead of closing overlay
- feat: default idle actions to media inhibit and increase expanded header spacing
- feat(screenshot): toggle audio sliders on click and merge audio tracks into single stream
- fix(guide): prevent wallpaper preview flicker in matugen theme card
- fix(notes): fix invalid anchors on header drag area
- fix(notes): select content input on first click anywhere in bottom area
- fix(quickactions): release keyboard focus in collapsed state and avoid forcing focus

### 2.2.6

- fix(bar): stop the battery wave when no charge is flowing (#416)
- feat(quickactions): add pinned notes sections and wrap note editor in card
- fix(sysnotif): prevent reload and duplicate full battery notifications
- fix(quickactions): manage keyboard focus and shortcut isolation during input editing
- feat(i18n): add translations for notes pinning and selection
- feat(inputs): add releaseFocus method to Input component
- fix: align topbar modules dynamically next to system panel edge
- feat: enhance notes expanding animations and floating quickaction tab pills
- fix(widgets): resolve ReferenceError when removing widget in WidgetRedactor
- fix: correct filled content box height in SystemUsageCard
- fix(audio): resolve binding loops in audio device and stream cache
- fix(audio): tag and filter out serpantinum sfx streams from volume stream list
- fix(workspaces): fix active and occupied state tracking on niri dynamic workspaces
- fix(bar): show all running timers in info faces simultaneously
- feat(bar): add text style for battery module
- feat(bar): add style and icon toggle settings for keyboard module
- fix(main): prevent monitor scale from double scaling popup dimensions
- fix(clock): use mod() in lumen dial shader to fix GLSL ES memory leak
- feat(bar): add style and visibility settings for network, bluetooth, and volume modules
- perf(guide): optimize popup loading, tab transitions, and background initialization
- perf(sysdata): stream system stats from one long-running fetcher (#414)
- perf(lock): eliminate redundant clock timer and bind directly to DateTime
- fix(lock): keep lockscreen clock synchronized and updating

### 2.2.5-1

- fix: ensure i18n translation readiness before notification dispatch
- fix: resolve missing isCharging property and wave animation scope in battery faces
- fix: manage popup visibility lifecycle to eliminate background render loops
- perf: replace bar battery pill 2D canvas with FluidWave shader
- perf: eliminate redundant shell process forks on startup and settings reload
- fix: remove redundant pause logic on volume wave animation
- perf: pause volume wave animation and unpause on hover
- fix: eliminate lumen clock periodic stall with continuous sweep tracking
- perf: pause system usage and battery waves in idle and animate on value change
- perf: throttle keyboard lock polling fallback and fix watcher path
- perf: eliminate sys_fetcher blocking sleep and optimize sensor parsing
- perf: implement lazy instantiation on first open for popup widgets
- perf: optimize lumen clock with smooth sweep animation and visibility guard
- refactor: replace Shape corners with corner_cutout shader in SideMusicPopout
- refactor: replace figure-stacked Shape corners with corner_cutout shader across popouts and overlays

### 2.2.5

- fix(bar): preserve module text opacity when adjusting bar opacity
- fix(musicpopup): remove the unused offsetY for the music play button
- perf(wallpaper): replace CPU mask geometry transitions with shader math
- fix(idle): serve org.freedesktop.ScreenSaver so games can keep the screen from locking (#409)
- fix(kb): stop restarting a running waiter to break the respawn loop (fixes #411) (#412)
- fix(qml): remove invalid method calls in SystemPanel and ThemeTab
- perf: replace canvas animations with compiled shaders
- perf(music): draw the wavy seek bar with a shader (#410)
- perf(widgets): draw the selection outline with a shader (#408)
- fix(draw): resolve canvas image export and clipboard copy (fixes #406)
- perf: eliminate wallpaper animation lag during on-the-fly matugen generation
- fix(sysnotif): deduplicate battery notifications and eliminate redundant startup check
- perf(music): draw the cover ring visualizers with the shared bars shader (#400)
- perf(visualizer): draw bar, music and lock visualizers with the shared shaders (#399)
- docs: add contributors wall to credits in README
- fix(widgets): use int helpers for min/max/clamp in visualizer shaders (NVIDIA) (#398)
- perf(widgets): draw the visualizer widgets with shaders (#396)
- fix(install): change the telegram channel link
- fix(music): prevent assigning undefined to currentLivePosition double
- fix(focus): ignore unfocused window title events in sway (fixing the same issue for Sway as in #390)
- perf(focus): eliminate reload lag and optimize active window tracking
- perf(bar): skip visualizer level processing in hidden or unused modes (#395)
- fix(wallpaper): persist search state in cache json instead of QSettings serpantinum.conf
- fix(inputs): persist password reveal via Config singleton
- fix(widgets): properly remove deleted widgets from model and tear down faces
- fix(inputs): restore persistent reveal state with explicit settings location
- fix(lock): fix non-bindable transform warning and use onVisibleChanged on surface
- fix(widgets): subscribe music visualizer faces to Cava only once (#393)
- fix(sysnotif): ensure i18n is ready when sysnotif dispatches battery check notifications on laptops
- fix(focus): track WindowOpenedOrChanged events for focused windows in niri
- fix(nix): fix version.txt file not being deleted
- fix(wallpaper): add ffmpeg fallback to convert WebP images to JPEG in ddg_search
- fix(wellbeing): prevent invalid image request when selectedAppIcon is empty
- fix(guide/display): guard wallpaper source and monitor name in SavePresetPopup
- fix(caching): initialize state files and symlink version.txt to prevent FileView read errors
- fix(bar/vis): guard barWindow connections in Vis face to avoid assigning JS object to QObject
- fix(screenshot): call text() in audioPrefsFile onLoaded handler
- fix(bar/sysmon): prevent undefined assignment to boolean property in SysMon face
- fix(launcher): remove invalid onCountChanged handler in DesktopEntries connections
- fix(settings): replace uninitialized QSettings with QtObject and regular properties
- fix(widgets): use QtObject in WidgetSync to avoid duplicate signal overrides
- perf(focus): deduplicate title change events and bound tmpfs log growth
- perf(wellbeing): use zero-fork lockfile check and cache config mtime
- perf(datetime): optimize clock timer and decouple date string re-evaluations
- perf(clipboard): optimize image memory with bounded size and lazy loading
- fix(install): add lsp-plugins-lv2 so the easyeffects equalizer works (#388)
- fix(lyrics): fix word spacing for non-Latin characters in karaoke mode (#387)
- fix(weather): show offline instead of a stale forecast when updates keep failing (#386)
- perf(osd): keep lock LED files open in the kb_locks polling fallback (#384)
- fix(imagebox): don't play GIFs while hidden (#382)
- fix(notifications): instantiate SysNotif so battery notifications work (#379)
- fix(bluetooth): track async adapter initialization in NetworkPopup and SystemPanel (#376)
- fix(lyrics): support compound artist-title formats and audio extensions in lyrics search (#375)
- fix(main): hide popup stage after the close animation (#371)
- perf(media): optimize marquee in MediaFace and stop when not playing
- fix(guide): keep bar module previews inactive while hidden (#369)
- perf(lock): eliminate high-frequency timers, remove 60fps animations, and optimize focus retention
- fix(bar): subscribe sysmon to SysData only once (#366)
- fix(media): constrain WavySeekBar mouse area height to prevent accidental seeking
- fix(syspanel): use ThemeBackend.iconFont and refine action icon sizes
- fix(bar): the bat face widgets not adapting to a desktop variant
- style(systemusagecard): return wave animations
- feat(bar): add battery module styles and visibility settings
- fix(i18n): proofread German translation (capitalization, spelling, terminology) (#360)
- feat(launcher): use itemCount setting to configure emoji view rows
- feat(launcher): add emoji picker with navigatable grid
- style(media): reduce the blur for art thumbnails in the musicpopup
- fix(widgets): fix misaligned buttons
- feat(bar): add configurable settings for the sysmon face module

### 2.2.4

- feat(bar): add configurable visualizer widget
- fix(bar): fix spacing and overlay of grouped modules in sidebar
- chore: remove a comment
- style: change the theme icon in the desktopmenu
- refactor: migrate bar modules to face-based BarModule with central registry
- fix: fix the icon alignment in the sidetopwidget
- fix: fix icon alignment for widgets
- fix: add a global iconfont to fix icon discrepancy
- refactor: reorginize widget faces into specific folders
- perf/fix: fixes #350, redisign of the sysmon widget
- perf: remove a continous wave animation from the system usage card to improve performance. Animate only on change
- fix: scale wallpaper and lock screen sourceSize by devicePixelRatio (#351)
- chore: update the lockfile
- feat: add a lockscreen icon button to the desktop menu when clicked on desktop
- chore: remove a console log of the search indexes in the guidepopup
- fix: remove duplication by ensuring DEduplication in the setting row in the search bar in the guide popup
- fix/feat: fix a misalignment of the corner, fixes #349, add an animation for the hidden -> collapsed state for the floating bar, add animation for moving across the same side of the screen on cursor position change
- style: add a shadow to the seek bar handle
- style: improve the wavy seek bar style by decreasing the peaks and smoothing out the curves
- fix: fix the alignment drift in the music face widget and make sure all of the elements are equally spaced out for readability and style
- fix: whenever Input would loose focus, launcher and clipboard would loose arrow and mouse control. Add focus regaining mechanism and fix the input.qml
- fix: prevent lyrics view from a long scroll animation on creation
- style: improve the visuals of the wavyseekbar in the musicpopup and musicface widget
- perf: optimize the current focus script
- style: change the highlight selection in the redactor a sine-wave shape
- feat: make widgets on the desktop have a selection highlight when using the desktopmenu to select them
- style: add hover and click effects for batwidget and sidebatwidget
- fix: fix redundant flag in the equalizer
- feat: add osd and notifications into the search
- fix: fix themetab elements collapsing into a column
- fix: fix equalizer not executing
- fix: #348. Remove the wave animation from the battery to prevent power drain
- feat: add the idle tab to the search
- style: add a shadow to the clock minimal widget
- fix: force focus on the input when the search is open in the settings
- fix: fixes #346 when input takes focus
- feat: add barmodulestab modules to the search
- i18n: add missing translation for the search in the guidepopup

### 2.2.3

- feat: add arrow navigation to the guidepopup search
- fix: don't unregister setting rows from other tabs
- fix: add a themetab non setting row settings into the search in the guidepopup
- fix: add translations for the search
- fix: fix the icon on the about tab
- fix: improve the search bar
- fix: add a nothing is playing string to the musicface lyrics simple
- fix: fix the issue with the numberanimation paused property not being set when not running
- Merge remote-tracking branch 'origin/master'
- feat(i18n): fall back to the system language when none is set (#343)
- feat: add search for settings in the guide popup, implement settingsgroups in bargeneraltab, docktab

### 2.2.2

- fix: ensure easyeffects isn't dying with the ssystem restart
- fix: update the missing properties in the widgetsync
- chore: update qmldir file
- perf: replace the hardcoded lyrics with a lyricsview in the musicpopup
- feat: add support for custom propertes to the widget redactor
- feat: new face lyrics simple widget for music, with configurable size and layout
- fix: make sure lyrics don't stale and update properly on lyrics change
- fix: make input.qml lose focus when clicked outside
- refactor: separate the wavy seek bar and the lyrics view into reusables
- fix: make the hashes for song previews unique to prevent different players to cache wrong thumbnails to a song
- fix(equalizer): write the preset where EasyEffects 8 reads it, atomically (#338)
- perf: optimize the canvas animation in the musicpopup
- style: make sure the handle doesn't faint in the musicpopup

### 2.2.1

- feat: add a on-hover caffein duration in the systempanel
- feat: add lyrics singleton, add lyrics to the music popup, rework the progress bar style
- fix: fix the path for refactor of the notificationbox
- fix: fix a path bug after the refactor of notificationbox
- chore: change file permittions after a merge
- feat: add option to hide empty workspace indicators (#333)
- refactor: replace all hardcoded settings in the guide popup tabs with the settingsrow reusable
- refactor: separate all reusables into folders for proper structure, add a new settingsrow reusable
- fix: fix a typo in the math for widget redactor
- style: remove the border from the github face widget

### 2.2.0

- fix: add a debounce timer for a reload action in the desktopmenu
- feat: add a redactor opening script
- fix: replace the widget redactor ipc calls with a script call
- feat: add a desktop menu popup to get activated on a right click on desktop and widgets for quick access to functionality
- fix: make sure widgetredactor doesn't talk over ipc calls with the loader but uses widgetsync singleton instead
- style: redesign the pacman face for the workspaceswidget
- feat: make the widget redactor a separate scope window to activate on an ipc call to speed up and improve the redactor
- feat: add a new github face widget
- fix: fixes #328
- fix: improve the readability of the lyrics
- style: add lyrics caching to the lyrics widget
- style: improve the animations and the visuals of the lyrics widget
- fix: remove the black background box that reduced performance from the lockscreen
- style: instead of truncating a lyric, move it to the next line in the music lyric widget
- style: make the font size of lyrics change with widget scale
- style: increase the dimming in the clockview in the lockscreen

### 2.1.10

- fix: switch the power performance profile position in the systempanel with the power saver profile for a more logical positioning from left to right
- feat: add support for local lrc files for a lyrics widget
- feat: add a new lyrics widget
- chore: update flake.lock
- fix: add all of the new missing setting fields into the settings-options.nix
- style: improve the blur effect on the lockscreen and decrease the dimming
- fix: remove the stutter of the second circle on the  clock widget material analog style
- style: change the dropdown glyph animation with the one similar to the flipicon animation
- feat: make the clock face material analog widget have a second morphing indicator circle
- style: remove the border for switch
- style: change the settings iconbutton for a flipicon for expandable actions, restyle the coloring of input fields, remove the icon for custom idle actions, increase the width of the custom action name input field
- style: remove the border for numberselector
- fix: wrap the osd tab settings text so long translations don't overflow (#310)
- added the Ukrainian language option (#315)
- chore: update flake.lock
- fix: make batteryface inner wave fill correctly follow the themebackend border radius

### 2.1.9

- feat: add a file browser in the launcher to open files with the default application configured for it
- fix: rework the way the switch options sizes change on the length of the text inside. Removed premature size change
- feat: add a new Lumen material-analog clock widget variant
- fix: restyle numbers 8, 5 and 9 in the material clock style
- style: improve the numbers look for the clock material
- feat: add material analog and material clock styles to widgets
- style: make the switch option expand its width when the size doesn't fit
- fix: make the wallpaper loading asynchronious to optimize the lockscreen
- fix: make sure lock doesn't have a delay on startup due to screen variables being empty
- fix: remove sidebar settings to keep it all on bar settings
- fix: make autohide timeout not apply to smart-autohide on workspace changed hiding state
- fix: remove the border for the input

### 2.1.8

- feat: add time-setting styling, move the time string setting into modules, merge the modules and sidemodules subtabs under the bar tab
- fix: increase the ddc timeout for monitors. Fixes #305
- style: add a border outline to the input.qml to improve visibility
- feat: add a smart-hide feature for the dock, hide on active workspaces
- fix: remove the border on the centered launcher
- fix: resolve a binding loop of a workspacecount property
- fix: launcher animation desynchronization
- style: change the hover cursor for workspaceswidget to pointing hand cursor
- fix: fix workspaces not working due to a hyprland lua error
- fix: remove a reupdate animation for workspacewidget on changing to workspaces out of the visible workspacecount, make it smooth
- fix: don't prevent qs manager from switching workspaces when the workspace count is low, and allow workspacewidgets to extend beyond the configured amount - the workspacecount is now purely visual

### 2.1.7

- feat: add module settings tab, introduce workspace widget styling
- fix: don't pacman -Syyu on updates or reinstalls, only on migration or fresh installs
- style: change the default iconbutton accentcolor
- style: recolor the delete button for a more minimal look
- fix: fix launcher selection computing its own position which resulted in data-desync
- chore: update the lockfile
- fix: force a fade animation if the transition animation is interrupted
- fix: remove full screen expand button for all widgets except for the visualizer
- feat: add a swipe and a diagonal swipe animation to the wallpaperengine
- style: animation of the sidepanel to slide out from the sides
- style: improve the search animation in the launcher after removing it
- fix: a bug with launcher selected element being incorrectly changing the text color and improve animations for the launcher
- style: remove opacity changes for the viniette in the wallpaper engine animations
- style: improve the search animation in the launcher
- feat: add a width limit for bar's focus widget to prevent overflowing
- fix: fix the bug with the launcher items being offset wrongly during search, clipboard image attirbute fixes
- refactor: remove logging in the widgetsync
- fix: follow bigdatacloud's redirect when reverse-geocoding manual location (#288)
- nix: update flake.lock
- fix: improve scrolling animation for the launcher and the clipboard and make them smooth without wrong y-animation
- style: move the dock applications list to the top
- feat: add 4 more wallpaper changing animations
- animations: improve the entrance animation for the networkpopup
- animations: add tab entrance animation for the guidepopup
- fix: fix an offset bug for widget presets and fix the media widget preset

### 2.1.6

- fix: make sure the bar doesn't stay moved to the side on-logout
- feat: add widget presets, add custom widget presets, add 3 default presets
- refactor: split the usage widget into 4 separate widgets and remove the network widget
- style: make the border radius of the systemusagecards clamped
- style: change the background color of the themeeditor to match the guidepopup
- feat: make the settings window in main.qml freely draggable on the screen
- fix: make sure config.qml prevents staggering writes but emits the settingsloaded signal correctly
- fix: Dock elements having no animation when isSameSideAsBar was true
- fix: unblock orbit view refreshes and handle locked-state/update sync issues
- fix: prevent orbit repeater crash on bluetooth connect/disconnect. fixes #251 (#286)
- fix: make config writes atomic and prevent file corruption
- feat: add a dock setting that allows to place on top or below application windows
- fix: make numlock, capslock state detection work on niri and sway. remove unnecessary timers
- fix: dock animating through a whole screen on workspace change
- docs: move a pull request template into another folder
- style: make sure the lockbox around passwordinput is always seen on the lockscreen
- style: offset the icon glyph in welcometab iconbutton in guidepopup by 1px to center it
- fix: config breaking and now allowing writes for the configuration
- fix: make sure sddm isn't reinstalled on updates
- style: remove border for themes, move the + button for theme creation next to the search field, make sure theme names don't get truncated

### 2.1.5

- feat: 2 new widgets, a battery widget and a system usage widget
- style: reduce transparency
- refactor: make the systemusage liquid fill box a reusable
- feat: add a vertical slider for dropdown reusable
- style: make tab icons in settings be iconbuttons instead of plain icons
- feat: add a test notification button in the notification tab
- fix: osd not showing up in vertical mode
- i18n: add Azerbaijani language support to avoid merge conflict with #268
- fix: make brightness watcher a singleton to stop leaking inotifywait processes (#274)
- i18n: full portugese translation
- i18n: add Portuguese (pt) translation, part 1 (core UI + selector registration) (#270)
- fix: wifi widgets being off at startup after suspend
- style: add container boxes to notification and display tab, make the progress sliders in the wellbeing tab thicker and increase the size of the time box on the right
- fix: Config file tmp race conditions and add a file-write debounce
- fix: make bluetooth widgets in the bar not fall back to enabled state when device is connected at shell startup
- fix: make the systemusage dick tracker display a whole disk and not only one partition. Solves #269
- feat: add exclusion mode toggle to the dock
- feat: add scale effect to the dock
- fix: make Lock have an on-demand network scanning button
- style: two minor changes
- feat: add autohide toggle keybindings (#254)
- fix: a translation bug and add a box outline of the subsettings

### 2.1.4

- style: add icons to each setting in the guidepopup, change margins, rework the wellbeing tab
- increase the padding for grouped elements in the bar
- feat: add new notification sounds
- fix: dock having an element cut off on position change and disconnect the dock when the bar is in modular mode
- fix: launcher having a bad corner at the bottom
- fix: dock evaluation warning
- fix: Dock taking up mouse area clicking when in hidden mode
- fix a local function call bug in serpantinumd
- fix: make all dock settings hide when dock is disabled

### 2.1.3

- feat: add a dock functionality: dock.qml, dock settings
- feat: make clicking on a random area in the screenposition selector not relocate the item for usability
- flake.lock update
- fix: detach OSD from the bar in autohide mode
- fix: make sure the bar doesn't disappear on startup
- fix: a bug with duplicated bar modules
- fix: make the launcher remove the bar offset when in full-screen or autohide mode
- fix repositioning bug with the notifications
- fix: make the screenselector not offset its coordinates due to the bar
- style: make the temp in calendarpopup have 1 number after the dot instead of integer rounded

### 2.1.2

- style: tune down the scale effect for clickbutton
- feat: create a on-screen position configuration for notifications and osd. New reusable - screen selector
- style: make all of the settings have separate configuration boxes
- fix: wallpaper picker recent wallpaper animation fixed
- fix wallpaper dir not being properly set on install
- fix: serpantinum not cleanly killing the quickshell process
- fix: a right corner in clipboard having a wrong target coordinate
- fix sounds not having access to the config
- Remove duplicate no-op lines in QR polygon parser (#253)
- Fix QR marker vertical position (#252)
- refactor: remove all fauly singleton imports, categorize singletons
- fix faulty pull request
- style: overhaul the systempanel colors
- fix: add previous/next media key bindings (#247)
- fix(current_focus): exit after SIGTERM cleanup instead of resuming loop (#245)
- really minor change (#242)
- fix a singleton bug
- i18n: add missing translations for new widgets

### 2.1.1

- feat/refactor: add a user widget and relocate sysinfo singletons
- fix: prevent location from auto-updating on re-boots or updates
- fix: fix inotifywait processes not being killed and being left as orphans
- style: change the toggle style in the launchertab
- feat: add a toggle to show the bar in the widget redactor
- fix: fix resize clamping bug in a widgetredactor
- fix: duplication bug in the wallpaperpicker
- style: change the cava template background color to surface
- i18n: add languages for the new capture setting
- feat(screenshot): optionally capture the region on mouse release (#239)
- style: make the visualizer widgets smoothly zero-out on the edges
- replace widget ipc calls with faster and immidiate singleton calls
- fix: fix jitter by removing continous background wifi-scanning
- feat: switch close-window keybind from Alt+f4 to Super + Q, and switch a music keybind to Super+M instead of Super + Q
- fix: a typo in matugen static config. Replace fastfetch with config
- feat: make the widgets in the redactor shrink if they become too big after rotation to prevent inaccassible states
- fix: fix the bug where the redactor toolbar for widgets wouldn't disappear
- fix: remove automatic network scanning to prevent jitter

### 2.1.0

- feat: add rotation iconbutton into the widget toolbar, allow to rotate widgets by 90 degrees
- feat: add a new visualizer widget
- fix: make sure the first launch applies the wallpaper through the wallpaper singleton
- fix: prevent crashes in the networkpopup widget. fixes #229
- feat: switch the wallpaperengine to use the singleton for communicating with the wallpaperpicker
- fix: battery widgets not following theme's borderradius
- style: make the draggable handle size bigger in the osd to match the syspanel
- feat: add a distinctPills setting for the solid and fill styles of the bar
- feat: optimize the opening sequence for the systempanel
- fix: make sure Main.qml specified the monitor the widget is open on
- feat/fix: add a distinctPills support for the topbar and sidebar, fix the topbar sliding out on all monitors when syspanel was open
- fix: make sure the visualizer widgets zero-out when nothing is playing
- feat: add a search animation for the clipboard
- feat: add a search animation for the launcher, add a center position
- i18n: add new keys for distinctPills setting for the bar and launcher center position
- style: implement a distinctPills property for pill-like look for all of the widgets. Change the paddings and adjust the sizes or all widgets for better look
- fix: eliminate the race condition of the displaywidgettab when only the last connected monitor was correctly reporting the existing desktop widgets
- feat: add Korean language support (#233)
- fix: show system monitor on the correct screen - #221
- style: increase the widget width and change alignment of icon glyps in the weatherfaceround
- style: change the harcoded JetBrains Font in dropdowns and switches to the fontfamily
- fix: prevent duplicate lockscreen cava subscriptions (#219)

### 2.0.7

- feat: a series of optimizations tied to visibility of widgets
- docs: add an update note. Solves #218
- fix: fix a duplication of modules bug
- make sure first launch correctly applies the wallpaper
- feat: a series of performance optimizations for components
- feat: make the first launch script a singleton instead
- fix a bug where location.sh was replaced by a single function
- i18n: add a missing translation for workspaces.desc
- feat: make the Sidebar able to change its height from the bartab settings like the topbar
- style: make the osd capslock, numlock and airplane mode display in the bottom center when the bar is on the side
- fix: clipboard search bar getting swallowed on the sides
- fix: make the order of calendar words depend on the language
- fix: change fullDate property to use toLocaleDateString (#214)
- fix: update targetMonthName formatting to use locale (#213)
- Fix installation script URL formatting in README (#215)
- fix: prevent niri workspaces variation from infinite looping

### 2.0.6-1

- Fix disc to desc typo and general improvements (#210)
- fix: delete lock and pid files for exiting
- fix: make bluelight enable correctly on startup
- feat: allow to shrink the topbar size up to 5%
- style: replace the on/off toggle in osd for capslock, numlock and airplane mode with a clickbutton, optimize it, and remove it for niri and sway
- fix: record selected monitor (#207)
- feat(osd): add CapsLock, NumLock and Airplane mode indicator support (#203)

### 2.0.6

- fix: make bluelight correctly and immidiatly follow the automated schedule. Add a city description
- add FUNDING.yml
- fix: blue_light_filter auto-location improved and fixed, also creating a flock for a single wl-gammarelay-rs instance
- feat(osd): add microphone OSD support and volume controls (#201)
- style: tune down the scale effect on hover for musicwdiget to prevent the thumbnail from sticking out on the left
- fix: loop property canExpand in quickshell
- style: change the volume of the whoosh sound in the MusicPopup equalizer
- feat: BlueLight singleton to ensure that bluelight applies on shell startup
- fix: stale thumbnails in the music player due to asynchronious loading
- fix: serpantinum --version flag to display version correctly on nix
- fix: make sure focus_daemon.py doesn't self-duplicate on reload and doesn't inflate the usage time
- feat: change the default icon in grouped notificatoins in the NotificationBox to use the icon of the grouped notifications that it contains
- fix(nix): add a ... to declare rev from flake.nix
- fix: return the expand functionality for the clipboard
- feat(i18n): add vietnamese translation
- fix: fix the FontAwesome icons being loaded in the widget redactor and making all of the icon glyps offset to the side
- fix: Weather location doesn't expire after 24h if manually set and doesn't get overwrriten on generaltab changes. fixes #195
- Fix switch.qml option text being outside of bounds on some translations
- docs: add autostart instructions for nix and the instructions on how to update for nixos
- fix(nix): make the version file help the Updater.qml display the correct version for about tab in the settings
- fix(i18n): fix the translation having a wrong key for widget tab
- fix: reroute lockscreen calls from systemctl to scripts that fix non-working buttons for niri or systems not on systemd
- nix: update the lockfile
- feat: add DDC brightness fallback (#193)

### 2.0.5

- fix: crucial bug where people couldn't use the config
- feat: make the musicpopup match the theme more by making the dim on the art in the background have the base theme color instead of black
- fix: make external kitty/fatfetch/cava configs not reinstall itself on update, and make location not re-evaluate itself on updates
- feat(i18n): add Armenian translation (#191)

### 2.0.4

- replace hardcoded delete buttons with a reusable
- Fix the calendar popup nodes having wrong scaling behavior breaking the 3d illusion
- feat: add a new reusable icon button instance for "delete button" implementation
- fix: prevent color theme reloads when the theme didn't actually change
- feat: add sub-nested tabs in the displaytab and split the widgets tab in the displaytab
- feat: make the launcher change its size based on the amount of elements and move the input to the bottom when attached to the bottom side of the screen
- feat: make the clipboard change its size based on the amount of elements and move the input to the bottom when attached to the bottom side of the screen
- docs: add a PR template
- Italian Translation fixes (#186)
- feat: make the Sddm theme have a better typing animation
- fix: remove sddm on-screen keyboard for some users
- fix: make config.sh not merge it on update

### 2.0.3

- fix: system options in the systempanel not being adapted to different init systems and different compositors
- feat: allow the launcher and the clipboard to close by clicking outside of their area- fix: make the draggable for changing sfx volume in the generaltab change the sound volume immidiatly on drag to allow the user to listen to how loud the sfx is directly
- Remove update notifications in the abouttab for nixos as redundant and disable updater singleton for nixos
- style: improve the appearing and disappearing animation for a volume/brightness osd when not attached to a bar)
- feat(notifications): add toggle for empty center graphic
- fix: make i18n fallback to english if a language misses a key, and only then fallback to a key
- feat(i18n): Add Italian localization
