import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../"
import "PetArt.js" as Art

PanelWindow {
    id: win

    property var settings: ({})

    function num(v, d) {
        let n = Number(v);
        return (v === undefined || v === null || v === "" || isNaN(n)) ? d : n;
    }

    readonly property int pxScale: Math.max(2, Math.min(6, Math.round(num(settings.scale, 3))))
    readonly property bool musicReactive: settings.musicReactive !== false
    readonly property int idleTimeout: Math.max(15, Math.round(num(settings.idleTimeout, 120)))
    readonly property real hotTemp: num(settings.hotTemp, 80)
    readonly property real busyCpu: num(settings.busyCpu, 90)
    readonly property real lowBattery: num(settings.lowBattery, 15)
    readonly property real floorOffset: num(settings.floorOffset, 6)

    readonly property string cursorScript: Qt.resolvedUrl("pet_cursor.py").toString().replace("file://", "")

    // ------------------------------------------------------------------ window

    property var petScreen: null
    screen: petScreen

    color: "transparent"
    WlrLayershell.namespace: "qs-pet"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: (present || anyTreat) && !fullscreenUp && !locked

    mask: Region {
        item: hitbox
        Region { item: treat0.active ? treat0 : null }
        Region { item: treat1.active ? treat1 : null }
        Region { item: treat2.active ? treat2 : null }
    }

    function pickScreen() {
        let screens = Quickshell.screens;
        try {
            if (Hyprland.focusedMonitor) {
                for (let i = 0; i < screens.length; i++) {
                    if (screens[i] && screens[i].name === Hyprland.focusedMonitor.name) return screens[i];
                }
            }
        } catch (e) {}
        return screens.length > 0 ? screens[0] : null;
    }

    // ------------------------------------------------------------------ geometry

    readonly property real s: pxScale
    readonly property real worldW: win.screen ? win.screen.width : 1920
    readonly property real worldH: win.screen ? win.screen.height : 1080
    readonly property real floorY: worldH - floorOffset
    readonly property real spriteW: Art.CW * s
    readonly property real spriteH: Art.CH * s
    readonly property real gravity: 2600
    readonly property int dangleHeadTop: 18

    // ------------------------------------------------------------------ state

    property bool started: false
    property bool present: false
    property string mode: "ground"
    property string act: "sit"
    property real actUntil: 0
    property real animStart: 0
    property string goal: ""
    property real px: worldW / 2
    property real py: floorY
    property real vx: 0
    property real vy: 0
    property real slideV: 0
    property int facing: 1
    property real targetX: px
    property real moveSpeed: 55
    property int zoomLegs: 0
    property real nextBlink: 0
    property real blinkUntil: 0
    property string lookFace: "side"
    property int bounces: 0
    property bool sleptFromIdle: false
    property bool pendingDismiss: false
    property var particles: []
    property real lastTick: 0
    property real nextSpawn: 0
    property bool zAlt: false
    property bool umbrellaUp: false
    property real nextRain: 0
    property real visibleSince: 0
    property bool typingPaused: false
    property real typingNextChange: 0
    property real tilt: 0
    property real squash: 1.0
    property var sc: null
    property string scKey: ""
    property var events: []

    function logEvent(name) {
        let list = events.slice();
        list.push(new Date().toTimeString().substring(0, 8) + " " + name);
        while (list.length > 24) list.shift();
        events = list;
    }

    property bool chasing: false
    property real chaseStart: 0
    property int chaseCatches: 0
    property real cursorX: -1
    property real cursorY: -1
    property real nextPounce: 0
    property bool caughtThisJump: false

    property string scriptEnd: ""
    property real scriptT: 0
    property real scriptDur: 0
    property real scriptX0: 0
    property real scriptY0: 0
    property real scriptVX: 0
    property real scriptVY: 0
    property point bedTarget: Qt.point(0, 0)

    property var eatingTreat: null
    property var heldTreat: null
    property var barTreat: null
    property bool refusedTreat: false
    property real nextChomp: 0
    readonly property var treatSlots: [treat0, treat1, treat2]
    readonly property bool anyTreat: treat0.active || treat1.active || treat2.active
    readonly property bool treatsFalling: (treat0.active && treat0.phase === "fall")
        || (treat1.active && treat1.phase === "fall")
        || (treat2.active && treat2.phase === "fall")
    readonly property var fishSc: Art.fishScene()

    property bool musicOn: false
    property bool coding: false
    property bool hot: false
    property real hotSince: 0
    property real coolSince: 0
    property bool locked: false
    property int lastWs: -999

    readonly property bool userIdle: idleMon.isIdle
    readonly property bool lowBat: UPower.displayDevice.ready
        && UPower.displayDevice.isLaptopBattery
        && UPower.displayDevice.state === UPowerDeviceState.Discharging
        && UPower.displayDevice.percentage * 100 <= lowBattery
    readonly property bool raining: {
        let ic = Weather.currentIcon || "";
        if (ic.length === 0) return false;
        let cp = ic.codePointAt(0);
        return cp === 0xF0597 || cp === 0xF0E7;
    }
    readonly property bool fullscreenUp: {
        let t = ToplevelManager.activeToplevel;
        if (!t || !t.fullscreen) return false;
        if (t.screens && t.screens.length > 0 && win.screen) return t.screens.indexOf(win.screen) !== -1;
        return true;
    }

    readonly property var transientActs: ["alert", "stumble", "meow", "purr", "dizzy", "stretch", "land", "notice", "greet", "eat", "caught", "tired", "refuse"]

    function isTransient(a) {
        return transientActs.indexOf(a) !== -1;
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function clampX(x) {
        let m = 14 * s;
        return clamp(x, m, worldW - m);
    }

    function setAct(name, duration) {
        let now = Date.now();
        act = name;
        animStart = now;
        actUntil = duration > 0 ? now + duration : 0;
    }

    function sfx(name, vol, minGap) {
        PetState.sfx(name, vol, minGap);
    }

    function matchesCoding(cls) {
        if (!cls) return false;
        let c = String(cls).toLowerCase();
        let apps = PetState.codingApps;
        for (let i = 0; i < apps.length; i++) {
            let p = String(apps[i] || "").toLowerCase();
            if (p === "") continue;
            if (p.indexOf("*") !== -1) {
                let re = new RegExp("^" + p.split("*").map(x => x.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*") + "$");
                if (re.test(c)) return true;
            } else if (p === c) {
                return true;
            }
        }
        return false;
    }

    // ------------------------------------------------------------------ particles

    function spawn(g, dx, dy, pvx, pvy, life) {
        let list = particles.slice();
        list.push({ g: g, dx: dx, dy: dy, vx: pvx, vy: pvy, born: Date.now(), life: life });
        while (list.length > 14) list.shift();
        particles = list;
    }

    function spawnHearts(n) {
        for (let i = 0; i < n; i++) {
            spawn("heart", -5 + Math.random() * 10, -2 - i * 3, -1.5 + Math.random() * 3, -7 - Math.random() * 2, 1300 + i * 150);
        }
    }

    function updateParticles(now, dt) {
        if (particles.length === 0) return;
        let keep = [];
        for (let i = 0; i < particles.length; i++) {
            let p = particles[i];
            if (now - p.born > p.life) continue;
            p.dx += p.vx * dt;
            p.dy += p.vy * dt;
            if (p.g === "drop" || p.g === "crumb") p.vy += 30 * dt;
            keep.push(p);
        }
        particles = keep;
    }

    // ------------------------------------------------------------------ rendering

    function bassLevel() {
        let lv = Cava.barLevels;
        if (!lv || lv.length < 8) return 0;
        let sum = 0;
        for (let i = 0; i < 8; i++) sum += lv[i];
        return sum / 8;
    }

    function visualState(now) {
        let st = { pose: "sit", frame: 0, face: "normal", facing: facing, fx: [] };
        let t = now - animStart;
        switch (act) {
        case "walk":
            st.pose = "walk"; st.frame = Math.floor(now / 130) % 4; break;
        case "run":
        case "zoom":
            st.pose = "run"; st.frame = Math.floor(now / 85) % 2; break;
        case "stand":
            st.pose = "stand"; st.frame = Math.floor(now / 900) % 2; break;
        case "sleep":
        case "nap":
            st.pose = "loaf"; st.frame = Math.floor(now / 1100) % 2; st.face = "sleep"; break;
        case "flop":
            st.pose = "flop"; st.face = (Math.floor(now / 2600) % 3 === 0) ? "pant" : "tired"; break;
        case "pant":
        case "tired":
            st.pose = "sit"; st.face = "pant"; st.frame = Math.floor(now / 420) % 2; st.sweat = (act === "pant"); break;
        case "type":
            st.pose = "type"; st.frame = typingPaused ? 0 : Math.floor(now / 150) % 2;
            st.face = typingPaused ? "side" : "normal"; st.glasses = true; break;
        case "dance": {
            st.pose = "dance";
            let b = musicReactive ? bassLevel() : ((Math.floor(now / 260) % 2) ? 0.6 : 0.1);
            st.bob = b > 0.55 ? 2 : (b > 0.28 ? 1 : 0);
            st.frame = Math.floor(now / 500) % 2;
            st.face = st.bob === 2 ? "happy" : "normal";
            break;
        }
        case "groom":
            st.pose = "groom"; st.frame = Math.floor(now / 320) % 2; st.face = st.frame === 0 ? "blink" : "happy"; break;
        case "look":
            st.face = lookFace; break;
        case "alert":
            st.face = t < 250 ? "normal" : "alert";
            if (t > 180) st.fx.push({ g: "bang", dx: raining ? 11 : 7, dy: (raining ? -6 : -9) - (Math.floor(t / 400) % 2) });
            break;
        case "stumble":
            st.pose = "stumble"; st.face = "alert"; break;
        case "meow":
            st.face = t < 550 ? "meow" : "happy"; break;
        case "purr":
            st.face = "love"; break;
        case "dizzy": {
            st.face = "dizzy";
            let a = now / 220;
            for (let i = 0; i < 3; i++) {
                let ang = a + i * 2.094;
                st.fx.push({ g: "star", dx: Math.round(Math.cos(ang) * 8), dy: Math.round(-3 + Math.sin(ang) * 2) });
            }
            break;
        }
        case "stretch":
            st.pose = t < 1000 ? "stretch" : "sit"; st.face = t < 900 ? "yawn" : "blink"; break;
        case "land":
            st.pose = "crouch"; break;
        case "notice": {
            st.face = "up";
            let k = Math.floor(now / 240) % 3;
            let spots = [[-8, -3], [8, -6], [-3, -10]];
            st.fx.push({ g: "sparkle", dx: spots[k][0], dy: spots[k][1] });
            break;
        }
        case "greet":
            st.face = "happy"; break;
        case "refuse":
            st.face = "side"; break;
        case "caught":
            st.pose = "crouch"; st.face = "happy"; break;
        case "crouch":
            st.pose = "crouch"; st.face = "side"; st.frame = Math.floor(now / 140) % 2; break;
        case "lookup":
            st.face = "up"; st.frame = Math.floor(now / 700) % 2; break;
        case "eat":
            st.pose = "eat"; st.face = (Math.floor(now / 190) % 2 === 0) ? "chew" : "chew2"; break;
        case "held":
            st.pose = "dangle"; st.face = Math.abs(tilt) > 9 ? "alert" : "normal"; st.frame = Math.floor(now / 300) % 2; break;
        case "air":
            st.pose = "leap"; st.face = (Math.abs(vx) + Math.abs(vy) > 1600) ? "alert" : "happy"; break;
        default:
            st.frame = Math.floor(now / 1600) % 2; break;
        }

        if (st.face === "normal" && now < blinkUntil) st.face = "blink";

        let noAcc = st.pose === "loaf" || st.pose === "flop" || st.pose === "dangle" || st.pose === "leap" || st.pose === "eat" || st.pose === "stretch";
        if (musicOn && !noAcc) st.phones = true;
        if (raining && !noAcc) st.umbrella = true;
        if (hot && !noAcc) st.sweat = true;

        for (let i = 0; i < particles.length; i++) {
            let p = particles[i];
            st.fx.push({ g: p.g, dx: Math.round(p.dx), dy: Math.round(p.dy) });
        }
        return st;
    }

    function render(now) {
        let st = visualState(now);
        umbrellaUp = !!st.umbrella;
        let key = JSON.stringify(st);
        if (key !== scKey) {
            scKey = key;
            sc = Art.scene(st);
        }
    }

    // ------------------------------------------------------------------ brain

    readonly property int tickInterval: {
        if (goal !== "" || act === "walk" || act === "run" || act === "zoom" || chasing) return 40;
        if (act === "dance") return 66;
        if (act === "sleep" || act === "nap" || act === "flop") return 300;
        return 100;
    }

    Timer {
        id: brain
        interval: win.tickInterval
        repeat: true
        running: win.visible && win.present && win.mode === "ground"
        onTriggered: win.tick()
    }

    FrameAnimation {
        id: physics
        running: win.visible && win.present && (win.mode === "air" || win.mode === "script")
        onTriggered: win.physicsStep(Math.min(frameTime, 0.034))
    }

    function tick() {
        let now = Date.now();
        let dt = lastTick > 0 ? Math.min(0.25, (now - lastTick) / 1000) : 0.1;
        lastTick = now;
        updateHot(now);
        updateBlink(now);
        groundTick(now, dt);
        if (umbrellaUp && now >= nextRain) {
            spawn("drop", (Math.random() < 0.5 ? -1 : 1) * (8 + Math.random() * 2), -6, 0, 16, 650);
            nextRain = now + 280 + Math.random() * 200;
        }
        updateParticles(now, dt);
        render(now);
    }

    function updateHot(now) {
        let temp = Number(SysData.temp) || 0;
        let cpu = Number(SysData.cpu) || 0;
        if (temp >= hotTemp || cpu >= busyCpu) {
            coolSince = 0;
            if (!hotSince) hotSince = now;
            if (!hot && now - hotSince > 8000) hot = true;
        } else {
            hotSince = 0;
            if (temp < hotTemp - 4 && cpu < busyCpu - 12) {
                if (!coolSince) coolSince = now;
                if (hot && now - coolSince > 10000) hot = false;
            }
        }
    }

    function updateBlink(now) {
        if (now >= nextBlink) {
            blinkUntil = now + 140;
            nextBlink = now + 2500 + Math.random() * 3500;
        }
    }

    function desired() {
        if (userIdle) return "sleep";
        if (lowBat) return "flop";
        if (hot) return "pant";
        if (coding) return "type";
        if (musicOn) return "dance";
        return "";
    }

    function stepToward(dt) {
        let dx = targetX - px;
        let step = moveSpeed * dt;
        if (Math.abs(dx) <= step + 0.5) {
            px = targetX;
            return true;
        }
        facing = dx > 0 ? 1 : -1;
        px += facing * step;
        return false;
    }

    function walkTo(x, kind) {
        targetX = x;
        act = kind;
        animStart = Date.now();
        actUntil = 0;
        moveSpeed = kind === "zoom" ? 380 : (kind === "run" ? 280 : 55);
    }

    function groundTick(now, dt) {
        if (Math.abs(slideV) > 4) {
            px = clampX(px + slideV * dt);
            slideV *= Math.pow(0.03, dt);
        } else {
            slideV = 0;
        }

        if (goal === "exit" || goal === "enter") {
            if (stepToward(dt)) {
                if (goal === "exit") finishExit();
                else finishEnter();
            }
            return;
        }

        if (goal === "bed") {
            if (now >= actUntil) launchToBed();
            return;
        }

        if (isTransient(act)) {
            if (now < actUntil) {
                transientTick(now);
                return;
            }
            if (act === "eat") {
                finishEat();
                return;
            }
            act = "";
        }

        if (chasing) {
            chaseTick(now, dt);
            return;
        }

        let tr = userIdle ? null : restingTreat();
        if (goal === "treat" && !tr) goal = "";
        if (tr) {
            if (!PetState.isFull()) {
                seekTreat(tr, dt);
                return;
            }
            if (!refusedTreat) {
                refusedTreat = true;
                logEvent("too full for a treat");
                setAct("refuse", 1600);
                return;
            }
        }

        let want = desired();
        if (want === "sleep") {
            if (act !== "sleep") {
                goal = "";
                setAct("sleep", 0);
                sleptFromIdle = true;
            }
            sleepTick(now);
            return;
        }
        if (sleptFromIdle) {
            sleptFromIdle = false;
            wake();
            return;
        }
        if (want === "flop") {
            if (act !== "flop") { goal = ""; setAct("flop", 0); }
            return;
        }
        if (want === "pant") {
            if (act !== "pant") { goal = ""; setAct("pant", 0); }
            return;
        }
        if (want === "type") {
            typeTick(now, dt);
            return;
        }
        if (want === "dance") {
            if (act !== "dance") { goal = ""; setAct("dance", 0); }
            danceTick(now);
            return;
        }

        if (goal === "type" || act === "type" || act === "dance" || act === "pant" || act === "flop") {
            goal = "";
            setAct("stand", 900);
            return;
        }
        wanderTick(now, dt);
    }

    function transientTick(now) {
        if (act === "purr" && now >= nextSpawn) {
            spawnHearts(1);
            nextSpawn = now + 450;
        } else if (act === "greet" && now >= nextSpawn) {
            spawnHearts(1);
            nextSpawn = now + 600;
        } else if (act === "eat") {
            if (now >= nextChomp) {
                sfx("chomp", 0.6);
                nextChomp = now + 1100;
            }
            if (now >= nextSpawn) {
                spawn("crumb", 8 + Math.random() * 3, 9, (Math.random() - 0.5) * 8, -6, 600);
                nextSpawn = now + 260;
            }
        }
    }

    function wanderTick(now, dt) {
        if (act === "walk" || act === "run" || act === "zoom") {
            if (stepToward(dt)) {
                if (act === "zoom" && zoomLegs > 0) {
                    zoomLegs--;
                    walkTo(px < worldW / 2 ? clampX(worldW * (0.6 + Math.random() * 0.3)) : clampX(worldW * (0.1 + Math.random() * 0.3)), "zoom");
                    return;
                }
                setAct("sit", 2500 + Math.random() * 5000);
            }
            return;
        }
        if (act === "nap") {
            sleepTick(now);
            if (now >= actUntil) wake();
            return;
        }
        if (act === "" || act === "sleep" || (actUntil > 0 && now >= actUntil)) chooseIdle(now);
    }

    function chooseIdle(now) {
        let hour = new Date().getHours();
        let night = hour >= 0 && hour < 5;
        let r = Math.random();
        if (r < 0.38) {
            let dist = 120 + Math.random() * 420;
            let dir = Math.random() < 0.5 ? -1 : 1;
            let tx = clampX(px + dir * dist);
            if (Math.abs(tx - px) < 80) tx = clampX(px - dir * dist);
            walkTo(tx, "walk");
        } else if (r < 0.60) {
            setAct("sit", 3500 + Math.random() * 6000);
        } else if (r < 0.71) {
            setAct("groom", 2000 + Math.random() * 2000);
        } else if (r < 0.80) {
            lookFace = Math.random() < 0.5 ? "up" : "side";
            setAct("look", 1500 + Math.random() * 1500);
        } else if (r < 0.86 && PetState.happiness > 0.55 && !night) {
            zoomLegs = 1 + Math.floor(Math.random() * 2);
            walkTo(px < worldW / 2 ? clampX(worldW * 0.85) : clampX(worldW * 0.15), "zoom");
        } else if (r < (night ? 0.80 : 0.95)) {
            setAct("stand", 1500 + Math.random() * 2000);
        } else {
            setAct("nap", 25000 + Math.random() * 35000);
        }
    }

    function sleepTick(now) {
        if (now >= nextSpawn) {
            spawn(zAlt ? "z2" : "z1", 6, 1, 2.2, -2.6, 2600);
            zAlt = !zAlt;
            nextSpawn = now + 1400;
        }
    }

    function wake() {
        setAct("stretch", 1400);
        particles = [];
        sfx("mrrp", 0.5, 4000);
    }

    function cornerX() {
        let m = 18 + 14 * s;
        let left = m;
        let right = worldW - m;
        return (Math.abs(px - left) <= Math.abs(px - right)) ? left : right;
    }

    function typeTick(now, dt) {
        if (act !== "type") {
            let cx = cornerX();
            if (goal !== "type") {
                goal = "type";
                walkTo(cx, Math.abs(px - cx) > 500 ? "run" : "walk");
            }
            if (stepToward(dt)) {
                goal = "";
                setAct("type", 0);
                facing = cx < worldW / 2 ? 1 : -1;
                typingNextChange = now + 3000;
            }
            return;
        }
        if (now >= typingNextChange) {
            typingPaused = !typingPaused && Math.random() < 0.35;
            typingNextChange = now + (typingPaused ? 1200 + Math.random() * 1500 : 2500 + Math.random() * 4500);
        }
        if (!typingPaused && now >= nextSpawn) {
            spawn(Math.random() < 0.5 ? "bit0" : "bit1", -5 + Math.random() * 10, 8, 0, -6, 1400);
            nextSpawn = now + 900 + Math.random() * 1500;
        }
    }

    function danceTick(now) {
        if (now >= nextSpawn) {
            spawn("note", 11 + Math.random() * 3, -4, 2.5, -5, 1700);
            nextSpawn = now + 1300 + Math.random() * 900;
        }
    }

    function react(kind, arg) {
        if (!present || mode !== "ground" || goal === "exit" || goal === "enter") return;
        logEvent("react " + kind + (arg ? " " + arg : "") + " (act " + act + ")");
        let now = Date.now();
        let asleep = act === "sleep" || act === "nap";
        switch (kind) {
        case "alert":
            if (asleep || act === "flop") return;
            if (arg) facing = arg;
            setAct("alert", 2600);
            break;
        case "stumble":
            if (asleep || act === "flop") return;
            setAct("stumble", 650);
            slideV = (arg || 1) * 260;
            break;
        case "meow":
            if (asleep) { sleptFromIdle = false; wake(); return; }
            setAct("meow", 800);
            sfx(Math.random() < 0.5 ? "meow" : "mew", 0.9);
            break;
        case "purr":
            if (asleep) return;
            if (act !== "purr") {
                PetState.pettedTotal++;
                nextSpawn = 0;
            }
            setAct("purr", 1600);
            sfx("purr", 0.8, 1500);
            break;
        case "dizzy":
            setAct("dizzy", 2600);
            break;
        case "notice":
            if (asleep) return;
            setAct("notice", 1600);
            break;
        case "greet":
            setAct("greet", 1500);
            spawnHearts(2);
            nextSpawn = now + 600;
            sfx("mrrp", 0.6, 3000);
            break;
        case "stretch":
            wake();
            break;
        case "sleep":
            setAct("nap", 30000);
            break;
        }
    }

    // ------------------------------------------------------------------ summon / dismiss

    function applyLoaded() {
        if (started || !PetState.loaded) return;
        started = true;
        petScreen = pickScreen();
        if (PetState.out) {
            present = true;
            visibleSince = Date.now();
            px = worldW * (0.3 + Math.random() * 0.4);
            py = floorY;
            mode = "ground";
            setAct("stretch", 1400);
        }
        restoreLooseTreats();
        if (PetState.pendingSummon) {
            PetState.pendingSummon = false;
            if (!present) Qt.callLater(() => win.summon(null));
        }
    }

    function bedPoint(bed) {
        if (!bed || !bed.isUsable || typeof bed.seatPoint !== "function") return null;
        if (win.screen && bed.screenName && bed.screenName !== win.screen.name) return null;
        let p = bed.seatPoint();
        if (!p || isNaN(p.x) || isNaN(p.y)) return null;
        return p;
    }

    function startScript(x1, y1, dur, endKind) {
        scriptX0 = px;
        scriptY0 = py;
        scriptT = 0;
        scriptDur = dur;
        scriptEnd = endKind;
        scriptVX = (x1 - px) / dur;
        scriptVY = (y1 - py) / dur - 0.5 * gravity * dur;
        if (Math.abs(scriptVX) > 20) facing = scriptVX > 0 ? 1 : -1;
        mode = "script";
        act = "air";
    }

    function scriptStep(dt) {
        scriptT = Math.min(scriptDur, scriptT + dt);
        let t = scriptT;
        px = scriptX0 + scriptVX * t;
        py = scriptY0 + scriptVY * t + 0.5 * gravity * t * t;
        vy = scriptVY + gravity * t;
        if (scriptT >= scriptDur) {
            let kind = scriptEnd;
            scriptEnd = "";
            vx = 0;
            vy = 0;
            if (kind === "bed") {
                mode = "ground";
                arriveBed();
            } else {
                land("soft");
                react("greet");
            }
        }
    }

    function launchToBed() {
        goal = "";
        let tx = bedTarget.x;
        let ty = bedTarget.y + 7 * s;
        let dist = Math.hypot(tx - px, ty - py);
        startScript(tx, ty, clamp(0.55 + dist / 2800, 0.6, 1.0), "bed");
        sfx("mrrp", 0.45, 2000);
    }

    function arriveBed() {
        logEvent("in bed");
        present = false;
        PetState.out = false;
        particles = [];
        act = "sit";
        sfx("pop", 0.45);
        PetState.bedArrived();
    }

    function summon(bed) {
        if (present && goal !== "exit") return;
        logEvent("summon");
        petScreen = pickScreen();
        let now = Date.now();
        let wasExiting = goal === "exit";
        present = true;
        PetState.out = true;
        visibleSince = now;
        mode = "ground";
        vx = 0; vy = 0; slideV = 0;
        particles = [];
        let p = wasExiting ? null : bedPoint(bed || PetState.bedFor(petScreen ? petScreen.name : ""));
        if (p) {
            goal = "";
            px = p.x;
            py = p.y + 7 * s;
            let dir = p.x < worldW / 2 ? 1 : -1;
            startScript(clampX(p.x + dir * (140 + Math.random() * 220)), floorY, 0.9, "floor");
            sfx("mrrp", 0.5, 2000);
            return;
        }
        let fromLeft = goal === "exit" ? (px < worldW / 2) : (Math.random() < 0.5);
        if (goal !== "exit") px = fromLeft ? -16 * s : worldW + 16 * s;
        py = floorY;
        goal = "enter";
        walkTo(fromLeft ? worldW * (0.12 + Math.random() * 0.2) : worldW * (0.68 + Math.random() * 0.2), "walk");
        moveSpeed = 120;
    }

    function finishEnter() {
        goal = "";
        react("greet");
    }

    function dismiss() {
        if (!present || goal === "exit" || goal === "bed" || mode === "script") return;
        logEvent("dismiss");
        if (chasing) stopChase(false);
        if (mode !== "ground") {
            pendingDismiss = true;
            return;
        }
        let p = bedPoint(PetState.bedFor(win.screen ? win.screen.name : ""));
        if (p) {
            goal = "bed";
            bedTarget = p;
            facing = p.x >= px ? 1 : -1;
            setAct("crouch", 320);
            return;
        }
        goal = "exit";
        walkTo(px < worldW / 2 ? -18 * s : worldW + 18 * s, "run");
    }

    function finishExit() {
        goal = "";
        present = false;
        PetState.out = false;
        particles = [];
        act = "sit";
    }

    // ------------------------------------------------------------------ chase

    function toggleChase() {
        if (chasing) stopChase(false);
        else startChase();
    }

    function startChase() {
        if (!present || mode !== "ground" || goal === "exit" || goal === "enter") return;
        logEvent("chase start");
        goal = "";
        chasing = true;
        chaseStart = Date.now();
        chaseCatches = 0;
        cursorX = -1;
        cursorY = -1;
        nextPounce = 0;
        sfx("mrrp", 0.7);
        setAct("alert", 700);
    }

    function stopChase(tired) {
        logEvent("chase stop" + (tired ? " (tired)" : ""));
        chasing = false;
        cursorX = -1;
        cursorY = -1;
        if (mode !== "ground") return;
        if (tired) setAct("tired", 2600);
        else setAct("sit", 1500);
    }

    function onCursorLine(line) {
        let parts = String(line).trim().split(/\s+/);
        if (parts.length < 2) return;
        let gx = Number(parts[0]), gy = Number(parts[1]);
        if (isNaN(gx) || isNaN(gy)) return;
        let mon = win.screen ? Hyprland.monitorFor(win.screen) : null;
        let lx = gx - (mon ? mon.x : 0);
        let ly = gy - (mon ? mon.y : 0);
        if (lx < 0 || ly < 0 || lx > worldW || ly > worldH) {
            cursorX = -1;
            cursorY = -1;
            return;
        }
        cursorX = lx;
        cursorY = ly;
    }

    function jumpToward(tx, ty, low) {
        let h = low ? 80 : clamp(floorY - ty + 30, 80, 480);
        vy = -Math.sqrt(2 * gravity * h);
        let tUp = -vy / gravity;
        vx = clamp((tx - px) / Math.max(0.2, tUp * (low ? 2.0 : 1.0)), -700, 700);
        if (Math.abs(vx) > 30) facing = vx > 0 ? 1 : -1;
        bounces = 2;
        caughtThisJump = false;
        mode = "air";
        act = "air";
    }

    function chaseTick(now, dt) {
        if (now - chaseStart > 60000 || chaseCatches >= 5) {
            stopChase(true);
            return;
        }
        if (cursorX < 0) {
            if (act !== "lookup") setAct("lookup", 0);
            return;
        }
        let dx = cursorX - px;
        if (Math.abs(dx) > 22) {
            if (act !== "run") walkTo(clampX(cursorX), "run");
            targetX = clampX(cursorX);
            moveSpeed = Math.min(380, 140 + Math.abs(dx) * 0.9);
            stepToward(dt);
            return;
        }
        facing = dx >= 0 ? 1 : -1;
        let high = cursorY < floorY - 120;
        let reachable = floorY - cursorY < 540;
        if (now >= nextPounce && reachable) {
            nextPounce = now + (high ? 1300 + Math.random() * 900 : 900 + Math.random() * 500);
            jumpToward(cursorX, cursorY, !high);
            return;
        }
        let want = high ? "lookup" : "crouch";
        if (act !== want) setAct(want, 0);
    }

    // ------------------------------------------------------------------ physics

    function physicsStep(dt) {
        let now = Date.now();
        if (mode === "script") {
            scriptStep(dt);
            updateParticles(now, dt);
            render(now);
            return;
        }
        vy += gravity * dt;
        px += vx * dt;
        py += vy * dt;
        if (Math.abs(vx) > 40) facing = vx > 0 ? 1 : -1;

        let hw = 11 * s;
        if (px < hw) {
            px = hw;
            if (vx < 0) vx = -vx * 0.55;
        } else if (px > worldW - hw) {
            px = worldW - hw;
            if (vx > 0) vx = -vx * 0.55;
        }
        let top = py - spriteH + 25 * s;
        if (top < 0) {
            py -= top;
            if (vy < 0) vy = -vy * 0.35;
        }

        if (chasing && !caughtThisJump && cursorX >= 0) {
            let hx = px + facing * 5 * s;
            let hy = py - spriteH + 30 * s;
            if (Math.hypot(cursorX - hx, cursorY - hy) < 36) {
                caughtThisJump = true;
                chaseCatches++;
                PetState.caughtTotal++;
                spawnHearts(3);
                sfx("mew", 0.8);
            }
        }

        if (py >= floorY) {
            py = floorY;
            let impact = vy;
            if (impact > 1750) {
                land("dizzy");
            } else if (impact > 700 && bounces < 2) {
                bounces++;
                vy = -impact * 0.3;
                vx *= 0.7;
                sfx("thud", 0.35, 150);
            } else {
                land(impact > 380 ? "hard" : "soft");
            }
        }
        updateParticles(now, dt);
        render(now);
    }

    function land(kind) {
        logEvent("landed " + kind);
        mode = "ground";
        vy = 0;
        slideV = vx * 0.45;
        vx = 0;
        bounces = 0;
        lastTick = Date.now();
        if (kind === "dizzy") {
            setAct("dizzy", 2600);
            sfx("thud", 0.8);
            sfx("mew", 0.6);
            squashAnim.restart();
        } else if (chasing) {
            setAct(caughtThisJump ? "caught" : "land", caughtThisJump ? 1100 : 220);
        } else {
            setAct("land", kind === "hard" ? 320 : 180);
            if (kind === "hard") {
                sfx("thud", 0.5);
                squashAnim.restart();
            }
        }
        caughtThisJump = false;
        if (pendingDismiss) {
            pendingDismiss = false;
            Qt.callLater(win.dismiss);
        }
    }

    SequentialAnimation {
        id: squashAnim
        NumberAnimation { target: win; property: "squash"; to: 0.78; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: win; property: "squash"; to: 1.0; duration: 240; easing.type: Easing.OutBack }
    }

    // ------------------------------------------------------------------ treats

    function freeSlot() {
        for (let i = 0; i < treatSlots.length; i++) {
            if (!treatSlots[i].active) return treatSlots[i];
        }
        return null;
    }

    function spawnTreat(x, y, phase) {
        let sl = freeSlot();
        if (!sl) return null;
        sl.tx = x;
        sl.ty = y;
        sl.tvx = 0;
        sl.tvy = 0;
        sl.phase = phase;
        sl.active = true;
        refusedTreat = false;
        return sl;
    }

    function restoreLooseTreats() {
        let n = PetState.looseTreats;
        for (let i = 0; i < n; i++) {
            if (!present || !spawnTreat(clampX(worldW * (0.2 + Math.random() * 0.6)), floorY, "rest")) {
                PetState.returnLooseTreat();
            }
        }
    }

    function treatAt(x, y) {
        for (let i = 0; i < treatSlots.length; i++) {
            let t = treatSlots[i];
            if (!t.active || t.phase === "eat") continue;
            let pad = 6;
            if (x >= t.x - pad && x <= t.x + t.width + pad && y >= t.y - pad && y <= t.y + t.height + pad) return t;
        }
        return null;
    }

    function restingTreat() {
        let best = null;
        for (let i = 0; i < treatSlots.length; i++) {
            let t = treatSlots[i];
            if (!t.active || t.phase !== "rest") continue;
            if (!best || Math.abs(t.tx - px) < Math.abs(best.tx - px)) best = t;
        }
        return best;
    }

    function treatNearCat(t) {
        let cx = t.tx, cy = t.ty - t.height / 2;
        let pad = 22;
        return cx >= hitbox.x - pad && cx <= hitbox.x + hitbox.width + pad && cy >= hitbox.y - pad && cy <= hitbox.y + hitbox.height + pad;
    }

    function seekTreat(t, dt) {
        let side = t.tx >= px ? 1 : -1;
        let standX = clampX(t.tx - side * 7.5 * s);
        if (Math.abs(px - standX) > 3) {
            if (goal !== "treat" || (act !== "walk" && act !== "run")) {
                goal = "treat";
                walkTo(standX, Math.abs(px - standX) > 300 ? "run" : "walk");
                moveSpeed = Math.max(moveSpeed, 90);
            }
            targetX = standX;
            stepToward(dt);
            return;
        }
        goal = "";
        facing = side;
        startEating(t);
    }

    // anything that interrupts a meal puts the treat back on the floor
    onActChanged: {
        if (act !== "eat" && eatingTreat) {
            if (eatingTreat.active) eatingTreat.phase = "rest";
            eatingTreat = null;
        }
    }

    function startEating(t) {
        logEvent("eating");
        eatingTreat = t;
        t.phase = "eat";
        nextChomp = 0;
        nextSpawn = 0;
        setAct("eat", 2200);
    }

    function finishEat() {
        if (eatingTreat) {
            eatingTreat.active = false;
            eatingTreat.phase = "rest";
            eatingTreat = null;
            PetState.treatEaten();
        }
        setAct("greet", 1200);
        spawnHearts(2);
        nextSpawn = Date.now() + 500;
    }

    function feedFromHand(t) {
        if (PetState.isFull()) {
            t.phase = "fall";
            setAct("refuse", 1600);
            refusedTreat = true;
            logEvent("too full for a treat");
            return;
        }
        if (chasing) stopChase(false);
        goal = "";
        facing = t.tx >= px ? 1 : -1;
        t.tx = px + facing * 7.5 * s;
        t.ty = floorY;
        startEating(t);
    }

    function dropTreat(t, allowFeed) {
        if (allowFeed && present && mode === "ground" && goal !== "bed" && treatNearCat(t)) {
            feedFromHand(t);
            return;
        }
        t.tvx = 0;
        t.tvy = 0;
        t.phase = "fall";
    }

    function treatStep(dt) {
        for (let i = 0; i < treatSlots.length; i++) {
            let t = treatSlots[i];
            if (!t.active || t.phase !== "fall") continue;
            t.tvy += gravity * dt;
            t.tx = clamp(t.tx + t.tvx * dt, t.width / 2, worldW - t.width / 2);
            t.ty += t.tvy * dt;
            if (t.ty >= floorY) {
                t.ty = floorY;
                if (t.tvy > 520) {
                    t.tvy = -t.tvy * 0.3;
                    t.tvx *= 0.6;
                } else {
                    t.tvy = 0;
                    t.tvx = 0;
                    t.phase = "rest";
                    if (present && mode === "ground" && act !== "sleep" && act !== "nap" && !PetState.isFull()) {
                        facing = t.tx >= px ? 1 : -1;
                    }
                }
            }
        }
    }

    function onBarTreatDrag(phase, sx, sy, bed) {
        if (phase === "start") {
            if (!PetState.takeTreat()) return;
            let t = spawnTreat(sx, sy + 8 * s, "held");
            if (!t) {
                PetState.returnLooseTreat();
                return;
            }
            barTreat = t;
            logEvent("treat taken from the bed");
            if (!present) summon(bed);
            return;
        }
        if (!barTreat) return;
        if (phase === "move") {
            barTreat.tx = sx;
            barTreat.ty = sy + barTreat.height / 2;
            return;
        }
        let t = barTreat;
        barTreat = null;
        dropTreat(t, phase === "end");
    }

    function onTreatDrop(bed) {
        if (!PetState.takeTreat()) return;
        let p = bedPoint(bed);
        let t = spawnTreat(p ? p.x : clampX(worldW * (0.3 + Math.random() * 0.4)), p ? p.y + 10 * s : 60, "fall");
        if (!t) {
            PetState.returnLooseTreat();
            return;
        }
        t.tvx = (Math.random() - 0.5) * 260;
        logEvent("treat dropped");
        sfx("pop", 0.5);
        if (!present) summon(bed);
    }

    function onTreatsEarned(n, reason) {
        logEvent("treats +" + n + " (" + reason + ")");
        if (present && mode === "ground" && act !== "sleep" && act !== "nap" && act !== "eat") setAct("notice", 1600);
        sfx("pop", 0.4, 800);
    }

    // ------------------------------------------------------------------ input

    property bool pressed: false
    property bool dragging: false
    property real pressX: 0
    property real pressY: 0
    property var samples: []

    Timer {
        id: clickTimer
        interval: 260
        onTriggered: win.react("meow")
    }

    function onPress(x, y, button) {
        let tr = treatAt(x, y);
        if (tr && button === Qt.LeftButton) {
            heldTreat = tr;
            tr.phase = "held";
            tr.tx = x;
            tr.ty = y + tr.height / 2;
            return;
        }
        if (!present) return;
        if (button === Qt.RightButton) {
            dismiss();
            return;
        }
        pressed = true;
        dragging = false;
        pressX = x;
        pressY = y;
    }

    function onMove(x, y) {
        if (heldTreat) {
            heldTreat.tx = x;
            heldTreat.ty = y + heldTreat.height / 2;
            return;
        }
        if (!pressed) return;
        if (!dragging) {
            if (Math.hypot(x - pressX, y - pressY) < 6) return;
            startHold();
        }
        holdTo(x, y);
    }

    function onRelease(x, y) {
        if (heldTreat) {
            let t = heldTreat;
            heldTreat = null;
            dropTreat(t, true);
            return;
        }
        if (!pressed) return;
        pressed = false;
        if (dragging) {
            release();
            return;
        }
        if (clickTimer.running) {
            clickTimer.stop();
            toggleChase();
        } else {
            clickTimer.restart();
        }
    }

    function startHold() {
        logEvent("picked up");
        dragging = true;
        if (chasing) stopChase(false);
        goal = "";
        mode = "held";
        act = "held";
        slideV = 0;
        samples = [];
        bounces = 0;
        particles = [];
        sfx("mew", 0.6, 1500);
    }

    function holdTo(x, y) {
        let now = Date.now();
        let list = samples.slice();
        list.push({ x: x, y: y, t: now });
        while (list.length > 6) list.shift();
        samples = list;
        let prevX = px;
        px = x;
        py = y + spriteH - (dangleHeadTop - 1) * s;
        tilt = clamp(tilt * 0.6 + (px - prevX) * 0.9, -18, 18);
        render(now);
    }

    function release() {
        dragging = false;
        let now = Date.now();
        let rvx = 0, rvy = 0;
        if (samples.length >= 2) {
            let b = samples[samples.length - 1];
            let a = samples[0];
            for (let i = samples.length - 2; i >= 0; i--) {
                a = samples[i];
                if (b.t - a.t > 90) break;
            }
            let span = Math.max(0.016, (b.t - a.t) / 1000);
            if (now - b.t < 120) {
                rvx = (b.x - a.x) / span;
                rvy = (b.y - a.y) / span;
            }
        }
        vx = clamp(rvx, -4200, 4200);
        vy = clamp(rvy, -4200, 4200);
        tilt = 0;
        if (Math.hypot(vx, vy) > 900) PetState.thrownTotal++;
        mode = "air";
        act = "air";
    }

    function onWheel() {
        if (!present || mode !== "ground") return;
        react("purr");
        PetState.nudgeHappiness(0.004);
    }

    // ------------------------------------------------------------------ scene graph

    PetSprite {
        id: sprite
        px: win.pxScale
        colors: PetState.colors
        scene: win.sc
        visible: win.present
        x: Math.round(win.px - width / 2)
        y: Math.round(win.py - height)
        transform: [
            Rotation {
                origin.x: sprite.width / 2
                origin.y: win.dangleHeadTop * win.s
                angle: win.mode === "held" ? win.tilt : 0
            },
            Scale {
                origin.x: sprite.width / 2
                origin.y: sprite.height
                xScale: 2.0 - win.squash
                yScale: win.squash
            }
        ]
    }

    Item {
        id: hitbox
        readonly property var hit: (win.present && win.sc) ? win.sc.hit : null
        x: hit ? sprite.x + (hit.x - 1) * win.s : -100
        y: hit ? sprite.y + (hit.y - 1) * win.s : -100
        width: hit ? (hit.w + 2) * win.s : 1
        height: hit ? (hit.h + 2) * win.s : 1
    }

    component TreatItem: Item {
        id: treatRoot
        property bool active: false
        property string phase: "rest"
        property real tx: 0
        property real ty: 0
        property real tvx: 0
        property real tvy: 0
        property int pxs: 3
        property var fishScene: null
        visible: active
        width: fish.width
        height: fish.height
        x: Math.round(tx - width / 2)
        y: Math.round(ty - height)

        PetSprite {
            id: fish
            px: treatRoot.pxs
            colors: PetState.colors
            scene: treatRoot.fishScene
            rotation: treatRoot.phase === "held" ? -12 : 0
        }
    }

    TreatItem { id: treat0; pxs: win.pxScale; fishScene: win.fishSc }
    TreatItem { id: treat1; pxs: win.pxScale; fishScene: win.fishSc }
    TreatItem { id: treat2; pxs: win.pxScale; fishScene: win.fishSc }

    FrameAnimation {
        id: treatAnim
        running: win.visible && win.treatsFalling
        onTriggered: win.treatStep(Math.min(frameTime, 0.034))
    }

    MouseArea {
        id: input
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: win.mode === "held" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (m) => win.onPress(m.x, m.y, m.button)
        onPositionChanged: (m) => win.onMove(m.x, m.y)
        onReleased: (m) => win.onRelease(m.x, m.y)
        onCanceled: {
            if (win.heldTreat) {
                win.dropTreat(win.heldTreat, false);
                win.heldTreat = null;
            }
            if (win.dragging) win.release();
            win.pressed = false;
        }
        onWheel: (w) => win.onWheel()
    }

    // ------------------------------------------------------------------ signals from the shell

    IdleMonitor {
        id: idleMon
        enabled: win.present
        timeout: win.idleTimeout
        respectInhibitors: true
    }

    FileView {
        id: lockWatch
        path: Caching.getRunDir("lock") + "/locked"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: win.setLocked(true)
        onLoadFailed: win.setLocked(false)
    }

    function setLocked(v) {
        if (locked === v) return;
        let wasLocked = locked;
        locked = v;
        if (wasLocked && !v && present) {
            lastTick = 0;
            Qt.callLater(() => win.react("greet"));
        }
    }

    Process {
        id: cursorProc
        running: win.chasing && win.visible
        command: ["python3", "-I", win.cursorScript, "0.033"]
        stdout: SplitParser {
            onRead: (data) => win.onCursorLine(data)
        }
    }

    Timer {
        id: musicOffTimer
        interval: 2500
        onTriggered: win.musicOn = false
    }

    function updateMusic() {
        if (MprisController.isPlaying) {
            musicOffTimer.stop();
            musicOn = true;
        } else {
            musicOffTimer.restart();
        }
    }

    Connections {
        target: MprisController
        function onIsPlayingChanged() { win.updateMusic(); }
    }

    Timer {
        id: codingTimer
        interval: 1500
        onTriggered: win.coding = win.matchesCoding(CurrentFocus.appClass)
    }

    Connections {
        target: CurrentFocus
        function onAppClassChanged() { codingTimer.restart(); }
    }


    property bool cavaHeld: false
    readonly property bool wantCava: win.visible && win.musicReactive && win.act === "dance"
    onWantCavaChanged: {
        if (wantCava && !cavaHeld) {
            Cava.registerConsumer();
            cavaHeld = true;
        } else if (!wantCava && cavaHeld) {
            Cava.unregisterConsumer();
            cavaHeld = false;
        }
    }

    Connections {
        target: NotificationManager
        function onPopupAdded(uid, notif) { win.onNotification(); }
    }

    function onNotification() {
        logEvent("notification");
        let ns = Config.getSetting("notifications", {});
        if (ns && ns.dnd) return;
        let pos = String((ns && ns.position) || "top right");
        let side = pos.indexOf("left") !== -1 ? -1 : (pos.indexOf("right") !== -1 ? 1 : (px < worldW / 2 ? 1 : -1));
        react("alert", side);
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { win.onWorkspace(); }
    }

    function onWorkspace() {
        let ws = Hyprland.focusedWorkspace;
        if (!ws) return;
        let id = ws.id;
        let prev = lastWs;
        lastWs = id;
        if (prev === -999 || id <= 0 || prev <= 0 || id === prev) return;
        if (Hyprland.focusedMonitor && win.screen && Hyprland.focusedMonitor.name !== win.screen.name) return;
        react("stumble", id > prev ? -1 : 1);
    }

    Timer {
        id: themeTimer
        interval: 900
        onTriggered: {
            if (win.present && Date.now() - win.visibleSince > 6000) win.react("notice");
        }
    }

    Connections {
        target: ThemeBackend
        function onMauveChanged() { themeTimer.restart(); }
    }

    Connections {
        target: PetState
        function onLoadedChanged() { win.applyLoaded(); }
        function onSummonRequested(bed) { win.summon(bed); }
        function onDismissRequested() { win.dismiss(); }
        function onChaseRequested() { win.toggleChase(); }
        function onReactRequested(kind) { win.react(kind); }
        function onCodingAppsChanged() { codingTimer.restart(); }
        function onTreatDrag(phase, sx, sy, bed) { win.onBarTreatDrag(phase, sx, sy, bed); }
        function onTreatDropRequested(bed) { win.onTreatDrop(bed); }
        function onTreatsEarned(count, reason) { win.onTreatsEarned(count, reason); }
    }

    onVisibleChanged: {
        if (visible) {
            lastTick = 0;
            render(Date.now());
        }
    }

    function status() {
        return {
            present: present, mode: mode, act: act, goal: goal,
            x: Math.round(px), y: Math.round(py), facing: facing,
            music: musicOn, coding: coding, hot: hot, idle: userIdle, lowBattery: lowBat,
            raining: raining, locked: locked, fullscreen: fullscreenUp, chasing: chasing,
            treats: PetState.treats, looseTreats: PetState.looseTreats, happiness: PetState.happiness,
            fullness: Math.round(PetState.currentFullness() * 100) / 100,
            cursor: chasing ? [Math.round(cursorX), Math.round(cursorY)] : null
        };
    }

    Component.onCompleted: {
        petScreen = pickScreen();
        let ws = Hyprland.focusedWorkspace;
        lastWs = ws ? ws.id : -999;
        updateMusic();
        coding = matchesCoding(CurrentFocus.appClass);
        SysData.subscribe();
        render(Date.now());
        applyLoaded();
    }

    Component.onDestruction: {
        SysData.unsubscribe();
        if (cavaHeld) {
            Cava.unregisterConsumer();
            cavaHeld = false;
        }
    }
}
