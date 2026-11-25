const FIXED_DT = 1 / 60;
const SNAKE_SEGMENTS = 48;
const SNAKE_SEG_LEN = 6.8;
const MAX_TURN_PER_SEG = 0.26;
const COS_MAX_TURN = Math.cos(MAX_TURN_PER_SEG);
const SIN_MAX_TURN = Math.sin(MAX_TURN_PER_SEG);
const MIN_TURN_RADIUS = 24;
const MIN_CROSS_GAP = 10;
const MAX_CROSS_REACH = 23;
const INV_SEG_LEN = 1 / SNAKE_SEG_LEN;
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

function snakeHalfWidth(index) {
    if (index === 0) return 4.9;
    if (index === 1) return 4.8;
    if (index === 2) return 4.95;
    const u = (index - 2) / (SNAKE_SEGMENTS - 3);
    if (u < 0.65) {
        const swell = Math.sin((u / 0.65) * Math.PI) * 0.75;
        return 5.1 + swell;
    }
    const t = (u - 0.65) / 0.35;
    return 5.1 - 2.9 * t * t;
}

const jointX = new Float32Array(SNAKE_SEGMENTS);
const jointY = new Float32Array(SNAKE_SEGMENTS);
const leftX = new Float32Array(SNAKE_SEGMENTS);
const leftY = new Float32Array(SNAKE_SEGMENTS);
const rightX = new Float32Array(SNAKE_SEGMENTS);
const rightY = new Float32Array(SNAKE_SEGMENTS);
const halfWidths = new Float32Array(SNAKE_SEGMENTS);
const splitPoints = new Int16Array(SNAKE_SEGMENTS);
const pieceStarts = new Int16Array(SNAKE_SEGMENTS);
const pieceEnds = new Int16Array(SNAKE_SEGMENTS);

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

let geometryDirty = true;
let bodyMinX = 0;
let bodyMaxX = 0;
let bodyMinY = 0;
let bodyMaxY = 0;
let boundsMinX = 0;
let boundsMaxX = 0;
let boundsMinY = 0;
let boundsMaxY = 0;
let tailTipX = 0;
let tailTipY = 0;
let pieceCount = 1;

let headX = 0;
let headY = 0;
let headFx = 1;
let headFy = 0;
let headNx = 0;
let headNy = 1;
let headSnoutX = 0;
let headSnoutY = 0;
let headCheekLX = 0;
let headCheekLY = 0;
let headCheekRX = 0;
let headCheekRY = 0;

function init(width, height) {
    areaWidth = width;
    areaHeight = height;
    const startX = width * 0.28;
    const startY = Math.max(90, Math.min(height - 80, height * 0.42));
    for (let i = 0; i < SNAKE_SEGMENTS; i++) {
        jointX[i] = startX - i * SNAKE_SEG_LEN;
        jointY[i] = startY + Math.sin(i * 0.32) * 14;
        halfWidths[i] = snakeHalfWidth(i);
    }
    geometryDirty = true;
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
    for (let i = 1; i < SNAKE_SEGMENTS; i++) {
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

    geometryDirty = true;

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

function advance(frameTime) {
    accumulator += Math.min(0.05, Math.max(0, frameTime));
    let steps = 0;
    while (accumulator >= FIXED_DT && steps < 4) {
        stepSimulation(FIXED_DT);
        accumulator -= FIXED_DT;
        steps++;
    }
}

function rebuildBodyGeometry() {
    const last = SNAKE_SEGMENTS - 1;
    let minX = jointX[0];
    let maxX = jointX[0];
    let minY = jointY[0];
    let maxY = jointY[0];

    for (let i = 0; i < SNAKE_SEGMENTS; i++) {
        const rx = jointX[i];
        const ry = jointY[i];
        if (rx < minX) minX = rx;
        if (rx > maxX) maxX = rx;
        if (ry < minY) minY = ry;
        if (ry > maxY) maxY = ry;

        let tx;
        let ty;
        if (i === 0) {
            tx = jointX[0] - jointX[1];
            ty = jointY[0] - jointY[1];
        } else if (i === last) {
            tx = jointX[i - 1] - jointX[i];
            ty = jointY[i - 1] - jointY[i];
        } else {
            tx = jointX[i - 1] - jointX[i + 1];
            ty = jointY[i - 1] - jointY[i + 1];
        }
        const len = Math.sqrt(tx * tx + ty * ty) || 1;
        const invLen = halfWidths[i] / len;
        const nx = -ty * invLen;
        const ny = tx * invLen;
        leftX[i] = rx + nx;
        leftY[i] = ry + ny;
        rightX[i] = rx - nx;
        rightY[i] = ry - ny;
    }

    bodyMinX = minX;
    bodyMaxX = maxX;
    bodyMinY = minY;
    bodyMaxY = maxY;

    const tailDx = jointX[last] - jointX[last - 1];
    const tailDy = jointY[last] - jointY[last - 1];
    const tailLen = Math.sqrt(tailDx * tailDx + tailDy * tailDy) || 1;
    const tailScale = 4.2 / tailLen;
    tailTipX = jointX[last] + tailDx * tailScale;
    tailTipY = jointY[last] + tailDy * tailScale;

    let splitCount = 0;
    for (let i = 1; i <= last - MIN_CROSS_GAP; i++) {
        const ix = jointX[i];
        const iy = jointY[i];
        const iw = halfWidths[i];
        let j = i + MIN_CROSS_GAP;
        while (j <= last) {
            const ddx = ix - jointX[j];
            const ddy = iy - jointY[j];
            const adx = ddx < 0 ? -ddx : ddx;
            const ady = ddy < 0 ? -ddy : ddy;
            const chebyshev = adx > ady ? adx : ady;
            if (chebyshev >= MAX_CROSS_REACH) {
                const skip = ((chebyshev - MAX_CROSS_REACH) * INV_SEG_LEN) | 0;
                j += skip > 1 ? skip : 1;
                continue;
            }
            const reach = iw + halfWidths[j] + 10;
            if (ddx * ddx + ddy * ddy < reach * reach) {
                const mid = (i + j) >> 1;
                let merged = false;
                for (let k = 0; k < splitCount; k++) {
                    const diff = splitPoints[k] - mid;
                    if (diff >= -5 && diff <= 5) {
                        merged = true;
                        break;
                    }
                }
                if (!merged) {
                    let insertPos = splitCount;
                    while (insertPos > 0 && splitPoints[insertPos - 1] > mid) {
                        splitPoints[insertPos] = splitPoints[insertPos - 1];
                        insertPos--;
                    }
                    splitPoints[insertPos] = mid;
                    splitCount++;
                }
            }
            j++;
        }
    }

    pieceCount = 0;
    let curStart = 1;
    for (let k = 0; k < splitCount; k++) {
        const sp = splitPoints[k];
        if (sp > curStart + 2 && sp < last - 2) {
            pieceStarts[pieceCount] = curStart;
            pieceEnds[pieceCount] = sp;
            pieceCount++;
            curStart = sp;
        }
    }
    pieceStarts[pieceCount] = curStart;
    pieceEnds[pieceCount] = last;
    pieceCount++;

    geometryDirty = false;
}

function prepare() {
    if (geometryDirty) {
        rebuildBodyGeometry();
    }

    headX = jointX[0];
    headY = jointY[0];
    headFx = Math.cos(displayHeadAngle);
    headFy = Math.sin(displayHeadAngle);
    headNx = -headFy;
    headNy = headFx;

    headSnoutX = headX + headFx * 26.6;
    headSnoutY = headY + headFy * 26.6;
    headCheekLX = headX + headFx * 8.8 + headNx * 8.8;
    headCheekLY = headY + headFy * 8.8 + headNy * 8.8;
    headCheekRX = headX + headFx * 8.8 - headNx * 8.8;
    headCheekRY = headY + headFy * 8.8 - headNy * 8.8;

    boundsMinX = Math.min(bodyMinX, headSnoutX, headCheekLX, headCheekRX);
    boundsMaxX = Math.max(bodyMaxX, headSnoutX, headCheekLX, headCheekRX);
    boundsMinY = Math.min(bodyMinY, headSnoutY, headCheekLY, headCheekRY);
    boundsMaxY = Math.max(bodyMaxY, headSnoutY, headCheekLY, headCheekRY);
}

function centerX() {
    return (boundsMinX + boundsMaxX) * 0.5;
}

function centerY() {
    return (boundsMinY + boundsMaxY) * 0.5;
}

function appendRibbonSubpath(ctx, startIdx, endIdx) {
    const last = SNAKE_SEGMENTS - 1;
    const hasTailCap = endIdx === last;

    ctx.moveTo(leftX[startIdx], leftY[startIdx]);
    if (endIdx > startIdx) {
        ctx.lineTo(
            (leftX[startIdx] + leftX[startIdx + 1]) * 0.5,
            (leftY[startIdx] + leftY[startIdx + 1]) * 0.5
        );
    }

    for (let i = startIdx + 1; i < endIdx; i++) {
        ctx.quadraticCurveTo(
            leftX[i],
            leftY[i],
            (leftX[i] + leftX[i + 1]) * 0.5,
            (leftY[i] + leftY[i + 1]) * 0.5
        );
    }

    if (hasTailCap) {
        ctx.quadraticCurveTo(leftX[last], leftY[last], tailTipX, tailTipY);
        ctx.quadraticCurveTo(
            rightX[last],
            rightY[last],
            (rightX[last - 1] + rightX[last]) * 0.5,
            (rightY[last - 1] + rightY[last]) * 0.5
        );
    } else {
        ctx.lineTo(leftX[endIdx], leftY[endIdx]);
        ctx.lineTo(rightX[endIdx], rightY[endIdx]);
        ctx.lineTo(
            (rightX[endIdx - 1] + rightX[endIdx]) * 0.5,
            (rightY[endIdx - 1] + rightY[endIdx]) * 0.5
        );
    }

    for (let i = endIdx - 1; i > startIdx; i--) {
        ctx.quadraticCurveTo(
            rightX[i],
            rightY[i],
            (rightX[i] + rightX[i - 1]) * 0.5,
            (rightY[i] + rightY[i - 1]) * 0.5
        );
    }

    ctx.lineTo(rightX[startIdx], rightY[startIdx]);
    ctx.closePath();
}

function traceHeadShape(ctx) {
    const hx = headX;
    const hy = headY;
    const hfx = headFx;
    const hfy = headFy;
    const hnx = headNx;
    const hny = headNy;

    ctx.moveTo(headSnoutX, headSnoutY);
    ctx.bezierCurveTo(
        hx + hfx * 26.2 + hnx * 2.4,
        hy + hfy * 26.2 + hny * 2.4,
        hx + hfx * 17.4 + hnx * 7.4,
        hy + hfy * 17.4 + hny * 7.4,
        headCheekLX,
        headCheekLY
    );
    ctx.bezierCurveTo(
        hx + hfx * 4.2 + hnx * 9.0,
        hy + hfy * 4.2 + hny * 9.0,
        hx - hfx * 1.4 + hnx * 6.8,
        hy - hfy * 1.4 + hny * 6.8,
        leftX[1],
        leftY[1]
    );
    ctx.lineTo((leftX[1] + leftX[2]) * 0.5, (leftY[1] + leftY[2]) * 0.5);
    ctx.lineTo((rightX[1] + rightX[2]) * 0.5, (rightY[1] + rightY[2]) * 0.5);
    ctx.lineTo(rightX[1], rightY[1]);
    ctx.bezierCurveTo(
        hx - hfx * 1.4 - hnx * 6.8,
        hy - hfy * 1.4 - hny * 6.8,
        hx + hfx * 4.2 - hnx * 9.0,
        hy + hfy * 4.2 - hny * 9.0,
        headCheekRX,
        headCheekRY
    );
    ctx.bezierCurveTo(
        hx + hfx * 17.4 - hnx * 7.4,
        hy + hfy * 17.4 - hny * 7.4,
        hx + hfx * 26.2 - hnx * 2.4,
        hy + hfy * 26.2 - hny * 2.4,
        headSnoutX,
        headSnoutY
    );
    ctx.closePath();

    const holeFrontX = hx + hfx * 17.6;
    const holeFrontY = hy + hfy * 17.6;
    const holeLeftX = hx + hfx * 8.8 + hnx * 2.75;
    const holeLeftY = hy + hfy * 8.8 + hny * 2.75;
    const holeBackX = hx + hfx * 0.5;
    const holeBackY = hy + hfy * 0.5;
    const holeRightX = hx + hfx * 8.8 - hnx * 2.75;
    const holeRightY = hy + hfy * 8.8 - hny * 2.75;

    ctx.moveTo(holeFrontX, holeFrontY);
    ctx.quadraticCurveTo(
        hx + hfx * 13.0 + hnx * 1.75,
        hy + hfy * 13.0 + hny * 1.75,
        holeLeftX,
        holeLeftY
    );
    ctx.quadraticCurveTo(
        hx + hfx * 4.8 + hnx * 1.65,
        hy + hfy * 4.8 + hny * 1.65,
        holeBackX,
        holeBackY
    );
    ctx.quadraticCurveTo(
        hx + hfx * 4.8 - hnx * 1.65,
        hy + hfy * 4.8 - hny * 1.65,
        holeRightX,
        holeRightY
    );
    ctx.quadraticCurveTo(
        hx + hfx * 13.0 - hnx * 1.75,
        hy + hfy * 13.0 - hny * 1.75,
        holeFrontX,
        holeFrontY
    );
    ctx.closePath();
}

function fillHead(ctx) {
    ctx.beginPath();
    traceHeadShape(ctx);
    ctx.fillRule = Qt.OddEvenFill;
    ctx.fill();
    ctx.fillRule = Qt.WindingFill;
}

function draw(ctx, offsetX, offsetY, unit, fillColor, castShadowColor) {
    ctx.setTransform(unit, 0, 0, unit, offsetX, offsetY);

    const last = SNAKE_SEGMENTS - 1;
    const headMinLowerIdx = 8;
    let headOverlaps = false;
    for (let j = headMinLowerIdx; j <= last; j++) {
        const reach = 36 + halfWidths[j];
        const ddx = headX - jointX[j];
        const ddy = headY - jointY[j];
        if (ddx * ddx + ddy * ddy < reach * reach) {
            headOverlaps = true;
            break;
        }
        const sdx = headSnoutX - jointX[j];
        const sdy = headSnoutY - jointY[j];
        if (sdx * sdx + sdy * sdy < reach * reach) {
            headOverlaps = true;
            break;
        }
    }

    ctx.fillStyle = fillColor;

    for (let p = pieceCount - 1; p >= 0; p--) {
        const start = pieceStarts[p];
        const end = pieceEnds[p];
        const drawEnd = p < pieceCount - 1 ? Math.min(last, end + 1) : end;

        if (p < pieceCount - 1) {
            const clipStart = Math.min(last, end + 3);
            if (clipStart < last) {
                ctx.save();
                ctx.beginPath();
                appendRibbonSubpath(ctx, clipStart, last);
                ctx.clip();

                ctx.shadowColor = castShadowColor;
                ctx.shadowBlur = 9;
                ctx.shadowOffsetX = 0;
                ctx.shadowOffsetY = 0;

                ctx.beginPath();
                appendRibbonSubpath(ctx, start, drawEnd);
                ctx.fill();
                ctx.restore();
            }
        }

        if (p === 0 && headOverlaps) {
            ctx.save();
            ctx.beginPath();
            appendRibbonSubpath(ctx, headMinLowerIdx, last);
            ctx.clip();

            ctx.shadowColor = castShadowColor;
            ctx.shadowBlur = 9;
            ctx.shadowOffsetX = 0;
            ctx.shadowOffsetY = 0;

            fillHead(ctx);
            ctx.restore();
        }

        ctx.beginPath();
        appendRibbonSubpath(ctx, start, drawEnd);
        ctx.fill();
    }

    if (tongueProgress > 0) {
        const ext = Math.sin(tongueProgress * Math.PI);
        const flutter = Math.sin(tongueProgress * Math.PI * 4) * 1.6 * ext;
        const tongueLen = 11.4 * ext;
        const tipX = headSnoutX + headFx * tongueLen + headNx * flutter;
        const tipY = headSnoutY + headFy * tongueLen + headNy * flutter;
        const forkBaseX = headSnoutX + headFx * (tongueLen * 0.62) + headNx * (flutter * 0.5);
        const forkBaseY = headSnoutY + headFy * (tongueLen * 0.62) + headNy * (flutter * 0.5);
        const forkSpread = 3.2 * ext;

        ctx.beginPath();
        ctx.moveTo(headSnoutX - headFx * 2.0, headSnoutY - headFy * 2.0);
        ctx.lineTo(forkBaseX, forkBaseY);
        ctx.moveTo(forkBaseX, forkBaseY);
        ctx.lineTo(tipX + headNx * forkSpread, tipY + headNy * forkSpread);
        ctx.moveTo(forkBaseX, forkBaseY);
        ctx.lineTo(tipX - headNx * forkSpread, tipY - headNy * forkSpread);
        ctx.strokeStyle = Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 0.85 * ext);
        ctx.lineWidth = 1.4;
        ctx.lineCap = "round";
        ctx.stroke();
    }

    fillHead(ctx);
}
