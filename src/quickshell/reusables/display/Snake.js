.pragma library

const FIXED_DT = 1 / 60;
const DEFAULT_SEGMENTS = 48;
const MIN_SEGMENTS = 16;
const MAX_SEGMENTS = 96;
const SNAKE_SEG_LEN = 6.8;
const MAX_TURN_PER_SEG = 0.26;
const COS_MAX_TURN = Math.cos(MAX_TURN_PER_SEG);
const SIN_MAX_TURN = Math.sin(MAX_TURN_PER_SEG);
const MIN_TURN_RADIUS = 24;
const EDGE_PAD = 28;
const WALL_MARGIN = 200;
const WEAVE_AMPLITUDE = 9;
const WEAVE_WAVENUMBER = (Math.PI * 2) / 200;
const WEAVE_NECK_SEGMENTS = 12;
const CHUNK_SEGMENTS = 16;
const MAX_CHUNKS = 6;
const BODY_MARGIN = 10;
const HEAD_MARGIN = 30;

function normalizeAngle(angle) {
    let a = angle;
    while (a > Math.PI) a -= Math.PI * 2;
    while (a < -Math.PI) a += Math.PI * 2;
    return a;
}

const simulations = {};

function acquire(key) {
    let entry = simulations[key];
    if (!entry) {
        entry = { refs: 0, sim: createSimulation() };
        simulations[key] = entry;
    }
    entry.refs++;
    return entry.sim;
}

function release(key) {
    const entry = simulations[key];
    if (!entry) return;
    entry.refs--;
    if (entry.refs <= 0) delete simulations[key];
}

function createSimulation() {
    const jointX = new Float32Array(MAX_SEGMENTS);
    const jointY = new Float32Array(MAX_SEGMENTS);
    const bodyX = new Float32Array(MAX_SEGMENTS);
    const bodyY = new Float32Array(MAX_SEGMENTS);
    const chunkRects = new Float32Array(MAX_CHUNKS * 4);
    let chunks = 1;
    let stepVersion = 0;

    let segmentCount = DEFAULT_SEGMENTS;
    let areaWidth = 1920;
    let areaHeight = 1080;

    let headSpeed = 110;
    let headAngle = 0;
    let displayHeadAngle = 0;
    let gaitPhase = 0;
    let tongueTimer = 3.2;
    let tongueProgress = 0;
    let wanderTurn = 0;
    let wanderTarget = 0;
    let wanderTimer = 0;
    let cruiseSpeed = 140;
    let speedTimer = 0;
    let accumulator = 0;
    let lastAdvanceAt = 0;
    let driver = null;
    let initialized = false;

    let headFx = 1;
    let headFy = 0;
    let headNx = 0;
    let headNy = 1;
    let headSnoutX = 0;
    let headSnoutY = 0;
    let tailTipX = 0;
    let tailTipY = 0;

    function init(width, height, segments) {
        initialized = true;
        stepVersion++;
        areaWidth = width;
        areaHeight = height;
        segmentCount = clampSegments(segments);
        const span = (segmentCount - 1) * SNAKE_SEG_LEN;
        const startX = Math.min(width - EDGE_PAD, Math.max(width * 0.28, span + EDGE_PAD));
        const startY = Math.max(90, Math.min(height - 80, height * 0.42));
        for (let i = 0; i < segmentCount; i++) {
            jointX[i] = startX - i * SNAKE_SEG_LEN;
            jointY[i] = startY + Math.sin(i * 0.32) * 14;
        }
    }

    function clampSegments(segments) {
        const n = Math.round(segments || DEFAULT_SEGMENTS);
        return Math.max(MIN_SEGMENTS, Math.min(MAX_SEGMENTS, n));
    }

    function setLength(segments) {
        const n = clampSegments(segments);
        for (let i = segmentCount; i < n; i++) {
            const dx = jointX[i - 1] - jointX[i - 2];
            const dy = jointY[i - 1] - jointY[i - 2];
            const len = Math.sqrt(dx * dx + dy * dy) || 1;
            jointX[i] = jointX[i - 1] + dx / len * SNAKE_SEG_LEN;
            jointY[i] = jointY[i - 1] + dy / len * SNAKE_SEG_LEN;
        }
        segmentCount = n;
        stepVersion++;
    }

    function resize(width, height) {
        areaWidth = width;
        areaHeight = height;
    }

    function edgeWeight(distance, margin) {
        const t = 1 - Math.max(0, distance) / margin;
        return t * t;
    }

    function stepSimulation(dt) {
        wanderTimer -= dt;
        if (wanderTimer <= 0) {
            const magnitude = Math.random() < 0.3 ? Math.random() * 0.15 : 0.25 + Math.random() * 0.5;
            wanderTarget = (Math.random() < 0.5 ? -1 : 1) * magnitude;
            wanderTimer = 1.4 + Math.random() * 2.2;
        }

        speedTimer -= dt;
        if (speedTimer <= 0) {
            cruiseSpeed = Math.random() < 0.2 ? 55 + Math.random() * 35 : 110 + Math.random() * 80;
            speedTimer = 2.5 + Math.random() * 3.5;
        }

        const minX = EDGE_PAD;
        const maxX = Math.max(minX, areaWidth - EDGE_PAD);
        const minY = EDGE_PAD;
        const maxY = Math.max(minY, areaHeight - EDGE_PAD);
        const margin = Math.max(40, Math.min(WALL_MARGIN, 0.25 * Math.min(areaWidth, areaHeight)));
        const hx = jointX[0];
        const hy = jointY[0];

        let pushX = 0;
        let pushY = 0;
        if (hx - minX < margin) pushX += edgeWeight(hx - minX, margin);
        if (maxX - hx < margin) pushX -= edgeWeight(maxX - hx, margin);
        if (hy - minY < margin) pushY += edgeWeight(hy - minY, margin);
        if (maxY - hy < margin) pushY -= edgeWeight(maxY - hy, margin);
        const wallStrength = Math.min(1, Math.sqrt(pushX * pushX + pushY * pushY));

        let avoidTurn = 0;
        if (wallStrength > 0) {
            const steerX = Math.cos(headAngle) + pushX * 2.5;
            const steerY = Math.sin(headAngle) + pushY * 2.5;
            const avoidDiff = normalizeAngle(Math.atan2(steerY, steerX) - headAngle);
            avoidTurn = avoidDiff * 2.4;
            if (wallStrength > 0.25 && avoidDiff * wanderTarget < 0) {
                wanderTarget = -wanderTarget;
            }
        }
        wanderTurn += (wanderTarget - wanderTurn) * (1 - Math.exp(-1.1 * dt));

        const turnLoad = Math.min(1, Math.abs(wanderTurn + avoidTurn) / 1.6);
        const desiredSpeed = cruiseSpeed * (1 - 0.3 * turnLoad);
        headSpeed += (desiredSpeed - headSpeed) * (1 - Math.exp(-(desiredSpeed > headSpeed ? 1.6 : 2.2) * dt));

        const stepDist = headSpeed * dt;
        gaitPhase = (gaitPhase + stepDist * WEAVE_WAVENUMBER) % (Math.PI * 2);

        const dynamicRadius = MIN_TURN_RADIUS + Math.min(34, headSpeed * 0.022);
        const maxTurnRate = headSpeed / dynamicRadius;
        const turnRate = Math.max(-maxTurnRate, Math.min(maxTurnRate, wanderTurn + avoidTurn));
        headAngle = normalizeAngle(headAngle + turnRate * dt);

        jointX[0] = Math.max(minX, Math.min(maxX, hx + Math.cos(headAngle) * stepDist));
        jointY[0] = Math.max(minY, Math.min(maxY, hy + Math.sin(headAngle) * stepDist));

        let prevUx = -Math.cos(headAngle);
        let prevUy = -Math.sin(headAngle);
        for (let i = 1; i < segmentCount; i++) {
            const leadX = jointX[i - 1];
            const leadY = jointY[i - 1];
            const sdx = jointX[i] - leadX;
            const sdy = jointY[i] - leadY;
            const sLen = Math.sqrt(sdx * sdx + sdy * sdy) || 1;
            let ux = sdx / sLen;
            let uy = sdy / sLen;

            const dot = ux * prevUx + uy * prevUy;
            if (dot < COS_MAX_TURN) {
                const cross = prevUx * uy - prevUy * ux;
                const sign = cross >= 0 ? 1 : -1;
                ux = prevUx * COS_MAX_TURN - prevUy * SIN_MAX_TURN * sign;
                uy = prevUx * SIN_MAX_TURN * sign + prevUy * COS_MAX_TURN;
            }

            jointX[i] = leadX + ux * SNAKE_SEG_LEN;
            jointY[i] = leadY + uy * SNAKE_SEG_LEN;
            prevUx = ux;
            prevUy = uy;
        }

        displayHeadAngle = Math.atan2(jointY[0] - jointY[1], jointX[0] - jointX[1]);

        if (tongueProgress > 0) {
            tongueProgress += dt / 0.28;
            if (tongueProgress >= 1) {
                tongueProgress = 0;
                tongueTimer = 4.2 + Math.random() * 4.5;
            }
        } else {
            tongueTimer -= dt;
            if (tongueTimer <= 0) {
                tongueProgress = 0.001;
            }
        }
    }

    function advance(frameTime, owner, speed) {
        const now = Date.now();
        if (driver !== owner && now - lastAdvanceAt < 100) return;
        driver = owner;
        lastAdvanceAt = now;
        const scale = Math.max(0.1, speed || 1);
        accumulator += Math.min(0.05, Math.max(0, frameTime)) * scale;
        const stepDt = FIXED_DT * Math.min(1, scale);
        const maxSteps = Math.ceil(4 * Math.max(1, scale));
        let steps = 0;
        while (accumulator >= stepDt && steps < maxSteps) {
            stepSimulation(stepDt);
            stepVersion++;
            accumulator -= stepDt;
            steps++;
        }
    }

    function prepare() {
        const last = segmentCount - 1;
        for (let i = 0; i < segmentCount; i++) {
            const prev = i === 0 ? 0 : i - 1;
            const next = i === last ? last : i + 1;
            const tx = jointX[prev] - jointX[next];
            const ty = jointY[prev] - jointY[next];
            const len = Math.sqrt(tx * tx + ty * ty) || 1;
            const neck = Math.min(1, i / WEAVE_NECK_SEGMENTS);
            const envelope = WEAVE_AMPLITUDE * neck * neck * (3 - 2 * neck) * (1 - 0.4 * i / last);
            const offset = envelope * Math.sin(gaitPhase - i * SNAKE_SEG_LEN * WEAVE_WAVENUMBER);
            bodyX[i] = jointX[i] - ty / len * offset;
            bodyY[i] = jointY[i] + tx / len * offset;
        }

        headFx = Math.cos(displayHeadAngle);
        headFy = Math.sin(displayHeadAngle);
        headNx = -headFy;
        headNy = headFx;
        headSnoutX = bodyX[0] + headFx * 26.6;
        headSnoutY = bodyY[0] + headFy * 26.6;

        const tailDx = bodyX[last] - bodyX[last - 1];
        const tailDy = bodyY[last] - bodyY[last - 1];
        const tailScale = 4.2 / (Math.sqrt(tailDx * tailDx + tailDy * tailDy) || 1);
        tailTipX = bodyX[last] + tailDx * tailScale;
        tailTipY = bodyY[last] + tailDy * tailScale;

        chunks = Math.max(1, Math.min(MAX_CHUNKS, Math.ceil(segmentCount / CHUNK_SEGMENTS)));
        const perChunk = Math.ceil(last / chunks);
        for (let k = 0; k < chunks; k++) {
            const from = k * perChunk;
            const to = Math.min(last, from + perChunk);
            let cMinX = bodyX[from];
            let cMaxX = cMinX;
            let cMinY = bodyY[from];
            let cMaxY = cMinY;
            for (let i = from + 1; i <= to; i++) {
                const x = bodyX[i];
                const y = bodyY[i];
                if (x < cMinX) cMinX = x;
                if (x > cMaxX) cMaxX = x;
                if (y < cMinY) cMinY = y;
                if (y > cMaxY) cMaxY = y;
            }
            cMinX -= BODY_MARGIN;
            cMaxX += BODY_MARGIN;
            cMinY -= BODY_MARGIN;
            cMaxY += BODY_MARGIN;
            if (k === 0) {
                cMinX = Math.min(cMinX, bodyX[0] - HEAD_MARGIN, headSnoutX - HEAD_MARGIN);
                cMaxX = Math.max(cMaxX, bodyX[0] + HEAD_MARGIN, headSnoutX + HEAD_MARGIN);
                cMinY = Math.min(cMinY, bodyY[0] - HEAD_MARGIN, headSnoutY - HEAD_MARGIN);
                cMaxY = Math.max(cMaxY, bodyY[0] + HEAD_MARGIN, headSnoutY + HEAD_MARGIN);
            }
            if (to === last) {
                cMinX = Math.min(cMinX, tailTipX - BODY_MARGIN);
                cMaxX = Math.max(cMaxX, tailTipX + BODY_MARGIN);
                cMinY = Math.min(cMinY, tailTipY - BODY_MARGIN);
                cMaxY = Math.max(cMaxY, tailTipY + BODY_MARGIN);
            }
            chunkRects[k * 4] = cMinX;
            chunkRects[k * 4 + 1] = cMinY;
            chunkRects[k * 4 + 2] = cMaxX;
            chunkRects[k * 4 + 3] = cMaxY;
        }
    }

    function chunkCount() {
        return chunks;
    }

    function chunkRect(k) {
        return Qt.rect(chunkRects[k * 4], chunkRects[k * 4 + 1], chunkRects[k * 4 + 2] - chunkRects[k * 4], chunkRects[k * 4 + 3] - chunkRects[k * 4 + 1]);
    }

    function version() {
        return stepVersion;
    }

    function count() {
        return segmentCount;
    }

    function pair(q) {
        const a = Math.min(q * 2, segmentCount - 1);
        const b = Math.min(q * 2 + 1, segmentCount - 1);
        return Qt.vector4d(bodyX[a], bodyY[a], bodyX[b], bodyY[b]);
    }

    function headVector() {
        return Qt.vector4d(jointX[0], jointY[0], headFx, headFy);
    }

    function tailVector() {
        const last = segmentCount - 1;
        return Qt.vector4d(bodyX[last], bodyY[last], tailTipX, tailTipY);
    }

    function tongueAlpha() {
        return tongueProgress > 0 ? 0.85 * Math.sin(tongueProgress * Math.PI) : 0;
    }

    function tongueBase() {
        const ext = Math.sin(tongueProgress * Math.PI);
        const flutter = Math.sin(tongueProgress * Math.PI * 4) * 1.6 * ext;
        const tongueLen = 11.4 * ext;
        return Qt.vector4d(
            headSnoutX - headFx * 2.0,
            headSnoutY - headFy * 2.0,
            headSnoutX + headFx * (tongueLen * 0.62) + headNx * (flutter * 0.5),
            headSnoutY + headFy * (tongueLen * 0.62) + headNy * (flutter * 0.5)
        );
    }

    function tongueTips() {
        const ext = Math.sin(tongueProgress * Math.PI);
        const flutter = Math.sin(tongueProgress * Math.PI * 4) * 1.6 * ext;
        const tongueLen = 11.4 * ext;
        const tipX = headSnoutX + headFx * tongueLen + headNx * flutter;
        const tipY = headSnoutY + headFy * tongueLen + headNy * flutter;
        const spread = 3.2 * ext;
        return Qt.vector4d(tipX + headNx * spread, tipY + headNy * spread, tipX - headNx * spread, tipY - headNy * spread);
    }

    function isInitialized() {
        return initialized;
    }

    return {
        init: init,
        isInitialized: isInitialized,
        resize: resize,
        setLength: setLength,
        advance: advance,
        prepare: prepare,
        count: count,
        chunkCount: chunkCount,
        chunkRect: chunkRect,
        version: version,
        pair: pair,
        headVector: headVector,
        tailVector: tailVector,
        tongueAlpha: tongueAlpha,
        tongueBase: tongueBase,
        tongueTips: tongueTips
    };
}
