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
const SPEED_UP_BLEND = 1 - Math.exp(-1.6 * FIXED_DT);
const SPEED_DOWN_BLEND = 1 - Math.exp(-2.2 * FIXED_DT);
const WANDER_BLEND = 1 - Math.exp(-1.1 * FIXED_DT);

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

    let boundsMinX = 0;
    let boundsMaxX = 0;
    let boundsMinY = 0;
    let boundsMaxY = 0;

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
        wanderTurn += (wanderTarget - wanderTurn) * WANDER_BLEND;

        const turnLoad = Math.min(1, Math.abs(wanderTurn + avoidTurn) / 1.6);
        const desiredSpeed = cruiseSpeed * (1 - 0.3 * turnLoad);
        headSpeed += (desiredSpeed - headSpeed) * (desiredSpeed > headSpeed ? SPEED_UP_BLEND : SPEED_DOWN_BLEND);

        const stepDist = headSpeed * dt;
        const speedNorm = Math.min(1, headSpeed / 1200);
        const gaitRate = (headSpeed * 0.024) / (1 + headSpeed * 0.0022);
        gaitPhase += gaitRate * dt;
        const weaveAmplitude = 0.28 - 0.16 * speedNorm;
        const weaveTurn = Math.cos(gaitPhase) * weaveAmplitude * gaitRate;

        const dynamicRadius = MIN_TURN_RADIUS + Math.min(34, headSpeed * 0.022);
        const maxTurnRate = headSpeed / dynamicRadius;
        const turnRate = Math.max(-maxTurnRate, Math.min(maxTurnRate, wanderTurn + avoidTurn + weaveTurn));
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

    function advance(frameTime, owner) {
        const now = Date.now();
        if (driver !== owner && now - lastAdvanceAt < 100) return;
        driver = owner;
        lastAdvanceAt = now;
        accumulator += Math.min(0.05, Math.max(0, frameTime));
        let steps = 0;
        while (accumulator >= FIXED_DT && steps < 4) {
            stepSimulation(FIXED_DT);
            accumulator -= FIXED_DT;
            steps++;
        }
    }

    function prepare() {
        const last = segmentCount - 1;
        let minX = jointX[0];
        let maxX = jointX[0];
        let minY = jointY[0];
        let maxY = jointY[0];
        for (let i = 1; i < segmentCount; i++) {
            const x = jointX[i];
            const y = jointY[i];
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
        }

        headFx = Math.cos(displayHeadAngle);
        headFy = Math.sin(displayHeadAngle);
        headNx = -headFy;
        headNy = headFx;
        headSnoutX = jointX[0] + headFx * 26.6;
        headSnoutY = jointY[0] + headFy * 26.6;

        const tailDx = jointX[last] - jointX[last - 1];
        const tailDy = jointY[last] - jointY[last - 1];
        const tailScale = 4.2 / (Math.sqrt(tailDx * tailDx + tailDy * tailDy) || 1);
        tailTipX = jointX[last] + tailDx * tailScale;
        tailTipY = jointY[last] + tailDy * tailScale;

        boundsMinX = Math.min(minX, headSnoutX);
        boundsMaxX = Math.max(maxX, headSnoutX);
        boundsMinY = Math.min(minY, headSnoutY);
        boundsMaxY = Math.max(maxY, headSnoutY);
    }

    function count() {
        return segmentCount;
    }

    function bounds() {
        return Qt.rect(boundsMinX, boundsMinY, boundsMaxX - boundsMinX, boundsMaxY - boundsMinY);
    }

    function pair(q) {
        const a = Math.min(q * 2, segmentCount - 1);
        const b = Math.min(q * 2 + 1, segmentCount - 1);
        return Qt.vector4d(jointX[a], jointY[a], jointX[b], jointY[b]);
    }

    function headVector() {
        return Qt.vector4d(jointX[0], jointY[0], headFx, headFy);
    }

    function tailVector() {
        const last = segmentCount - 1;
        return Qt.vector4d(jointX[last], jointY[last], tailTipX, tailTipY);
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
        bounds: bounds,
        pair: pair,
        headVector: headVector,
        tailVector: tailVector,
        tongueAlpha: tongueAlpha,
        tongueBase: tongueBase,
        tongueTips: tongueTips
    };
}
