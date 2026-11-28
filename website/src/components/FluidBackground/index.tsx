import React, {useEffect, useRef} from 'react';
import styles from './styles.module.css';

interface ThemePalette {
  primary: [number, number, number];
  isDark: boolean;
}

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
const CANVAS_OVERSCAN = 140;
const HEADER_CLEARANCE = 35;
const POINTER_IDLE_TIMEOUT = 5;
const LOUNGE_ENTER_DIST = 60;
const LOUNGE_EXIT_DIST = 40;
const LOUNGE_SPEED = 70;
const LOUNGE_BLEND_RATE = 0.5;
const ACCEL_UP_BLEND = 1 - Math.exp(-14 * FIXED_DT);
const ACCEL_DOWN_BLEND = 1 - Math.exp(-9.5 * FIXED_DT);
const WEAVE_AMPLITUDE = 9;
const WEAVE_WAVENUMBER = (Math.PI * 2) / 200;
const WEAVE_NECK_SEGMENTS = 12;

function parseRgbTriplet(
  value: string,
  fallback: [number, number, number],
): [number, number, number] {
  const parts = value
    .split(',')
    .map((part) => Number(part.trim()))
    .filter((num) => !Number.isNaN(num));
  if (parts.length >= 3) {
    return [parts[0], parts[1], parts[2]];
  }
  return fallback;
}

function readThemePalette(): ThemePalette {
  const style = getComputedStyle(document.documentElement);
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  const fallbackPrimary: [number, number, number] = isDark ? [216, 199, 112] : [107, 94, 16];
  return {
    primary: parseRgbTriplet(style.getPropertyValue('--theme-primary-rgb'), fallbackPrimary),
    isDark,
  };
}

function normalizeAngle(angle: number): number {
  let a = angle;
  while (a > Math.PI) a -= Math.PI * 2;
  while (a < -Math.PI) a += Math.PI * 2;
  return a;
}

function snakeHalfWidth(index: number): number {
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

export default function FluidBackground(): React.JSX.Element {
  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    const canvas = canvasRef.current;
    if (!container || !canvas) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const ctx = canvas.getContext('2d', {alpha: true});
    if (!ctx) return;

    let destroyed = false;
    let rafId = 0;
    let colorSyncFrame = 0;
    let viewportWidth = window.innerWidth;
    let viewportHeight = window.innerHeight;
    let containerWidth = container.clientWidth || viewportWidth;
    let containerHeight = Math.max(container.clientHeight || viewportHeight, viewportHeight);
    let canvasWidth = containerWidth;
    let canvasHeight = Math.min(containerHeight, viewportHeight + CANVAS_OVERSCAN * 2);
    let canvasTop = 0;
    let dpr = Math.min(window.devicePixelRatio || 1, 1.5);

    const navbarEl = document.querySelector<HTMLElement>('.navbar');
    let containerDocLeft = 0;
    let containerDocTop = 0;
    let navbarBottom = 0;
    let scrollX = window.scrollX;
    let scrollY = window.scrollY;
    let containerRectLeft = 0;
    let containerRectTop = 0;
    let headerFloorY = 0;

    const updateScrollMetrics = () => {
      containerRectLeft = containerDocLeft - scrollX;
      containerRectTop = containerDocTop - scrollY;
      headerFloorY = Math.max(0, navbarBottom - containerRectTop);
    };

    const measureLayout = () => {
      scrollX = window.scrollX;
      scrollY = window.scrollY;
      const rect = container.getBoundingClientRect();
      containerDocLeft = rect.left + scrollX;
      containerDocTop = rect.top + scrollY;
      navbarBottom = navbarEl ? Math.max(0, navbarEl.getBoundingClientRect().bottom) : 0;
      updateScrollMetrics();
    };

    const initialPalette = readThemePalette();
    let currentPrimary: [number, number, number] = [...initialPalette.primary];
    let targetPrimary: [number, number, number] = [...initialPalette.primary];
    let darkBlend = initialPalette.isDark ? 1 : 0;
    let targetDarkBlend = darkBlend;
    let paletteDirty = true;

    let primaryPrefix = '';
    let snakeFillStyle = '';
    let castShadowColor = '';

    const rebuildStyles = () => {
      const rInt = Math.round(currentPrimary[0]);
      const gInt = Math.round(currentPrimary[1]);
      const bInt = Math.round(currentPrimary[2]);
      const isDarkNow = darkBlend > 0.5;
      primaryPrefix = `rgba(${rInt}, ${gInt}, ${bInt}, `;
      snakeFillStyle = `rgb(${rInt}, ${gInt}, ${bInt})`;
      castShadowColor = isDarkNow ? 'rgba(0, 0, 0, 0.56)' : 'rgba(0, 0, 0, 0.36)';
      paletteDirty = false;
    };

    const jointX = new Float32Array(SNAKE_SEGMENTS);
    const jointY = new Float32Array(SNAKE_SEGMENTS);
    const leftX = new Float32Array(SNAKE_SEGMENTS);
    const leftY = new Float32Array(SNAKE_SEGMENTS);
    const rightX = new Float32Array(SNAKE_SEGMENTS);
    const rightY = new Float32Array(SNAKE_SEGMENTS);
    const halfWidths = new Float32Array(SNAKE_SEGMENTS);
    const bodyX = new Float32Array(SNAKE_SEGMENTS);
    const bodyY = new Float32Array(SNAKE_SEGMENTS);
    const weaveEnvelope = new Float32Array(SNAKE_SEGMENTS);
    const splitPoints = new Int16Array(SNAKE_SEGMENTS);
    const pieceStarts = new Int16Array(SNAKE_SEGMENTS);
    const pieceEnds = new Int16Array(SNAKE_SEGMENTS);

    measureLayout();
    const startX = containerWidth * 0.28;
    const startY = Math.max(
      headerFloorY + 90,
      Math.min(containerHeight - 80, viewportHeight * 0.42),
    );
    for (let i = 0; i < SNAKE_SEGMENTS; i++) {
      jointX[i] = startX - i * SNAKE_SEG_LEN;
      jointY[i] = startY + Math.sin(i * 0.32) * 14;
      halfWidths[i] = snakeHalfWidth(i);
      const neck = Math.min(1, i / WEAVE_NECK_SEGMENTS);
      const tail = 1 - 0.4 * (i / (SNAKE_SEGMENTS - 1));
      weaveEnvelope[i] = WEAVE_AMPLITUDE * neck * neck * (3 - 2 * neck) * tail;
    }

    let headSpeed = 110;
    let headAngle = 0;
    let displayHeadAngle = 0;
    let turnCommitSign = 1;
    let gaitPhase = 0;
    let tongueTimer = 3.2;
    let tongueProgress = 0;
    let pointerActive = false;
    let pointerClientX = viewportWidth * 0.55;
    let pointerClientY = viewportHeight * 0.45;
    let pointerLastMoveTime = -20;
    let pointerSurge = 0;
    let wasTrackingPointer = false;
    let lounging = false;
    let loungeSign = 1;
    let loungeBlend = 0;
    let loungeAnchorX = 0;
    let loungeAnchorY = 0;
    let roamTargetX = containerWidth * 0.68;
    let roamTargetY = startY;
    let roamSpeed = 195;
    let roamTimer = 0;
    let simTime = 0;
    let accumulator = 0;
    let lastNow = performance.now();

    let geometryDirty = true;
    let visualDirty = true;
    let bodyMinX = 0;
    let bodyMaxX = 0;
    let bodyMinY = 0;
    let bodyMaxY = 0;
    let tailTipX = 0;
    let tailTipY = 0;
    let pieceCount = 1;
    let headOverlaps = false;

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

    let hasDirtyRect = false;
    let dirtyMinX = 0;
    let dirtyMinY = 0;
    let dirtyMaxX = 0;
    let dirtyMaxY = 0;

    const updateCanvasWindow = (forceClear: boolean) => {
      const maxTop = Math.max(0, containerHeight - canvasHeight);
      const nextTop = Math.round(
        Math.max(0, Math.min(maxTop, -containerRectTop - CANVAS_OVERSCAN)),
      );
      if (forceClear || nextTop !== canvasTop) {
        if (hasDirtyRect) {
          ctx.clearRect(dirtyMinX, dirtyMinY, dirtyMaxX - dirtyMinX, dirtyMaxY - dirtyMinY);
        } else {
          ctx.clearRect(0, 0, canvasWidth, canvasHeight);
        }
        canvasTop = nextTop;
        canvas.style.transform = `translate3d(0, ${canvasTop}px, 0)`;
        hasDirtyRect = false;
        visualDirty = true;
      }
    };

    const resize = () => {
      viewportWidth = window.innerWidth;
      viewportHeight = window.innerHeight;
      containerWidth = container.clientWidth || viewportWidth;
      containerHeight = Math.max(container.clientHeight || viewportHeight, viewportHeight);
      canvasWidth = containerWidth;
      canvasHeight = Math.min(containerHeight, viewportHeight + CANVAS_OVERSCAN * 2);
      dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      canvas.width = Math.max(1, Math.round(canvasWidth * dpr));
      canvas.height = Math.max(1, Math.round(canvasHeight * dpr));
      canvas.style.width = `${canvasWidth}px`;
      canvas.style.height = `${canvasHeight}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      measureLayout();
      geometryDirty = true;
      updateCanvasWindow(true);
    };

    const pickRoamTarget = (minY: number, maxY: number) => {
      const padX = Math.min(90, containerWidth * 0.14);
      const minX = padX;
      const maxX = Math.max(minX + 40, containerWidth - padX);
      const spanX = maxX - minX;
      const spanY = Math.max(60, maxY - minY);
      const minJumpSq = Math.min(240, Math.max(120, spanX * 0.3)) ** 2;

      let nextX = minX + Math.random() * spanX;
      let nextY = minY + Math.random() * spanY;
      for (let attempt = 0; attempt < 6; attempt++) {
        const cx = minX + Math.random() * spanX;
        const cy = minY + Math.random() * spanY;
        const dx = cx - jointX[0];
        const dy = cy - jointY[0];
        if (dx * dx + dy * dy >= minJumpSq) {
          nextX = cx;
          nextY = cy;
          break;
        }
      }
      roamTargetX = nextX;
      roamTargetY = nextY;
      roamSpeed = 165 + Math.random() * 65;
      roamTimer = 3.2 + Math.random() * 2.8;
    };

    const stepSimulation = (dt: number) => {
      simTime += dt;
      const pointerIdleSec = simTime - pointerLastMoveTime;
      const trackingPointer = pointerActive && pointerIdleSec < POINTER_IDLE_TIMEOUT;

      const minHeadY = headerFloorY + HEADER_CLEARANCE;
      const maxHeadY = Math.max(minHeadY, containerHeight - 28);
      const visibleBottomY = Math.min(maxHeadY, viewportHeight - containerRectTop - 36);

      let targetX: number;
      let targetY: number;
      if (trackingPointer) {
        targetX = Math.max(
          28,
          Math.min(containerWidth - 28, pointerClientX - containerRectLeft),
        );
        const pointerPageY = pointerClientY - containerRectTop;
        targetY = Math.max(minHeadY, Math.min(maxHeadY, pointerPageY));
        const cdx = jointX[0] - targetX;
        const cdy = jointY[0] - targetY;
        const cursorDist = Math.sqrt(cdx * cdx + cdy * cdy);
        if (!lounging && cursorDist < LOUNGE_ENTER_DIST) {
          lounging = true;
          loungeBlend = 0;
          loungeAnchorX = targetX;
          loungeAnchorY = targetY;
          loungeSign = Math.sin(headAngle) * cdx - Math.cos(headAngle) * cdy >= 0 ? 1 : -1;
        } else if (
          lounging &&
          Math.abs(targetX - loungeAnchorX) + Math.abs(targetY - loungeAnchorY) > LOUNGE_EXIT_DIST
        ) {
          lounging = false;
        }
        if (lounging) {
          loungeBlend = Math.min(1, loungeBlend + dt * LOUNGE_BLEND_RATE);
          const ease = loungeBlend * loungeBlend * (3 - 2 * loungeBlend);
          const radius = 44 + Math.sin(simTime * 0.8) * 10;
          const orbitAngle = Math.atan2(cdy, cdx) + loungeSign * 0.85;
          const orbitX = targetX + Math.cos(orbitAngle) * radius;
          const orbitY = targetY + Math.sin(orbitAngle) * radius;
          const aheadX = jointX[0] + Math.cos(headAngle) * 100;
          const aheadY = jointY[0] + Math.sin(headAngle) * 100;
          targetX = Math.max(
            28,
            Math.min(containerWidth - 28, aheadX + (orbitX - aheadX) * ease),
          );
          targetY = Math.max(
            minHeadY,
            Math.min(maxHeadY, aheadY + (orbitY - aheadY) * ease),
          );
        }
      } else {
        lounging = false;
        const roamMinY = minHeadY + 24;
        const roamMaxY = Math.max(roamMinY + 80, visibleBottomY - 24);
        roamTimer -= dt;
        const rdx = roamTargetX - jointX[0];
        const rdy = roamTargetY - jointY[0];
        const outOfView =
          roamTargetY < roamMinY - 20 ||
          roamTargetY > roamMaxY + 20 ||
          roamTargetX < 28 ||
          roamTargetX > containerWidth - 28;
        if (wasTrackingPointer || roamTimer <= 0 || outOfView || rdx * rdx + rdy * rdy < 7200) {
          pickRoamTarget(roamMinY, roamMaxY);
        }
        targetX = roamTargetX;
        targetY = roamTargetY;
      }
      wasTrackingPointer = trackingPointer;

      if (pointerSurge > 0) {
        pointerSurge = Math.max(0, pointerSurge - dt * 2.6);
      }

      const dx = targetX - jointX[0];
      const dy = targetY - jointY[0];
      const distSq = dx * dx + dy * dy;
      const dist = Math.sqrt(distSq);
      const rawTargetAngle = dist > 1 ? Math.atan2(dy, dx) : headAngle;
      const rawDiff = normalizeAngle(rawTargetAngle - headAngle);

      if (Math.abs(rawDiff) < 2.5 && Math.abs(rawDiff) > 0.08) {
        turnCommitSign = rawDiff >= 0 ? 1 : -1;
      } else if (Math.abs(rawDiff) >= 2.5) {
        const nearTop = jointY[0] < minHeadY + 75;
        const nearBottom = jointY[0] > maxHeadY - 75;
        const nearLeft = jointX[0] < 75;
        const nearRight = jointX[0] > containerWidth - 75;
        if (nearTop || nearBottom || nearLeft || nearRight) {
          const pCos = Math.cos(headAngle + 0.6);
          const pSin = Math.sin(headAngle + 0.6);
          const mCos = Math.cos(headAngle - 0.6);
          const mSin = Math.sin(headAngle - 0.6);
          let plusScore = 0;
          let minusScore = 0;
          if (nearTop) {
            plusScore += pSin;
            minusScore += mSin;
          }
          if (nearBottom) {
            plusScore -= pSin;
            minusScore -= mSin;
          }
          if (nearLeft) {
            plusScore += pCos;
            minusScore += mCos;
          }
          if (nearRight) {
            plusScore -= pCos;
            minusScore -= mCos;
          }
          if (plusScore !== minusScore) {
            turnCommitSign = plusScore > minusScore ? 1 : -1;
          }
        }
      }

      const stopRadius = trackingPointer ? 18 : 0;
      const effectiveDist = Math.max(0, dist - stopRadius);
      const turnAlignment = Math.max(0, Math.cos(rawDiff));
      const turnSlowdown = 0.42 + 0.58 * turnAlignment;

      let desiredSpeed: number;
      if (lounging) {
        desiredSpeed = LOUNGE_SPEED * (0.7 + 0.3 * turnAlignment);
      } else if (trackingPointer) {
        if (effectiveDist < 1.5 && pointerIdleSec > 0.12) {
          desiredSpeed = 0;
        } else {
          const speedCap = 1320 + pointerSurge * 256;
          const baseSpeed = Math.min(speedCap, effectiveDist * 10.5);
          const minCurveSpeed = effectiveDist > 8 ? 175 : 0;
          desiredSpeed = Math.max(minCurveSpeed, baseSpeed) * turnSlowdown;
        }
      } else {
        desiredSpeed = roamSpeed * (0.7 + 0.3 * turnAlignment);
      }

      headSpeed +=
        (desiredSpeed - headSpeed) * (desiredSpeed > headSpeed ? ACCEL_UP_BLEND : ACCEL_DOWN_BLEND);
      if (headSpeed < 1.5 && desiredSpeed === 0) {
        headSpeed = 0;
      }

      const stepDist = headSpeed * dt;
      gaitPhase = (gaitPhase + stepDist * WEAVE_WAVENUMBER) % (Math.PI * 2);

      let desiredHeading = rawTargetAngle;

      const wasBelowHeader = jointY[0] >= minHeadY - 2;
      if (wasBelowHeader && jointY[0] < minHeadY + 38 && Math.sin(desiredHeading) < 0) {
        const proximity = 1 - Math.max(0, (jointY[0] - minHeadY) / 38);
        let escapeAngle: number;
        if (jointX[0] < 64) {
          escapeAngle = 0.35;
        } else if (jointX[0] > containerWidth - 64) {
          escapeAngle = Math.PI - 0.35;
        } else {
          escapeAngle = Math.cos(desiredHeading) >= 0 ? 0 : Math.PI;
        }
        const deflect = normalizeAngle(escapeAngle - desiredHeading);
        desiredHeading = normalizeAngle(desiredHeading + deflect * proximity);
      }

      let headingDiff = normalizeAngle(desiredHeading - headAngle);
      if (Math.abs(rawDiff) >= 2.5) {
        headingDiff = turnCommitSign * Math.abs(headingDiff);
      }

      if (headSpeed > 4) {
        const dynamicRadius = MIN_TURN_RADIUS + Math.min(34, headSpeed * 0.022);
        const maxTurnRate = headSpeed / dynamicRadius;
        const maxStep = maxTurnRate * dt;
        const clampedTurn = Math.max(-maxStep, Math.min(maxStep, headingDiff));
        headAngle = normalizeAngle(headAngle + clampedTurn);

        const cosHead = Math.cos(headAngle);
        const sinHead = Math.sin(headAngle);
        let nextHeadX = jointX[0] + cosHead * stepDist;
        let nextHeadY = jointY[0] + sinHead * stepDist;
        const sidePad = 24;
        const hitLeft = nextHeadX < sidePad;
        const hitRight = nextHeadX > containerWidth - sidePad;
        const hitTop = wasBelowHeader && nextHeadY < minHeadY;
        const hitBottom = nextHeadY > maxHeadY;

        if (hitLeft) nextHeadX = sidePad;
        if (hitRight) nextHeadX = containerWidth - sidePad;
        if (hitTop) nextHeadY = minHeadY;
        if (hitBottom) nextHeadY = maxHeadY;

        if (hitTop && sinHead < 0) {
          if (hitLeft || (nextHeadX <= sidePad + 8 && cosHead < 0)) {
            headAngle = 0.5;
          } else if (hitRight || (nextHeadX >= containerWidth - sidePad - 8 && cosHead > 0)) {
            headAngle = Math.PI - 0.5;
          } else {
            headAngle = cosHead >= 0 ? 0 : Math.PI;
          }
        } else if (hitLeft && cosHead < 0) {
          headAngle = sinHead >= 0 ? Math.PI * 0.5 : -Math.PI * 0.5;
        } else if (hitRight && cosHead > 0) {
          headAngle = sinHead >= 0 ? Math.PI * 0.5 : -Math.PI * 0.5;
        } else if (hitBottom && sinHead > 0) {
          headAngle = cosHead >= 0 ? 0 : Math.PI;
        }

        jointX[0] = nextHeadX;
        jointY[0] = nextHeadY;

        let prevUx = -Math.cos(headAngle);
        let prevUy = -Math.sin(headAngle);
        const segFloorY = headerFloorY + 12;

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

          const segX = leadX + ux * SNAKE_SEG_LEN;
          let segY = leadY + uy * SNAKE_SEG_LEN;
          if (wasBelowHeader && segY < segFloorY) {
            segY = segFloorY;
          }
          jointX[i] = segX;
          jointY[i] = segY;
          prevUx = ux;
          prevUy = uy;
        }

        geometryDirty = true;
        visualDirty = true;
      }

      const neckAngle = Math.atan2(jointY[0] - jointY[1], jointX[0] - jointX[1]);
      if (Math.abs(normalizeAngle(neckAngle - displayHeadAngle)) > 0.0005) {
        displayHeadAngle = neckAngle;
        visualDirty = true;
      }

      if (tongueProgress > 0) {
        tongueProgress += dt / 0.28;
        if (tongueProgress >= 1) {
          tongueProgress = 0;
          tongueTimer = 4.2 + Math.random() * 4.5;
        }
        visualDirty = true;
      } else {
        tongueTimer -= dt;
        if (tongueTimer <= 0) {
          tongueProgress = 0.001;
          visualDirty = true;
        }
      }
    };

    const rebuildBodyGeometry = () => {
      const last = SNAKE_SEGMENTS - 1;
      for (let i = 0; i < SNAKE_SEGMENTS; i++) {
        const prev = i === 0 ? 0 : i - 1;
        const next = i === last ? last : i + 1;
        const tx = jointX[prev] - jointX[next];
        const ty = jointY[prev] - jointY[next];
        const len = Math.sqrt(tx * tx + ty * ty) || 1;
        const offset =
          weaveEnvelope[i] * Math.sin(gaitPhase - i * SNAKE_SEG_LEN * WEAVE_WAVENUMBER);
        bodyX[i] = jointX[i] - (ty / len) * offset;
        bodyY[i] = jointY[i] + (tx / len) * offset;
      }

      let minX = bodyX[0];
      let maxX = bodyX[0];
      let minY = bodyY[0];
      let maxY = bodyY[0];

      for (let i = 0; i < SNAKE_SEGMENTS; i++) {
        const rx = bodyX[i];
        const ry = bodyY[i];
        if (rx < minX) minX = rx;
        if (rx > maxX) maxX = rx;
        if (ry < minY) minY = ry;
        if (ry > maxY) maxY = ry;

        let tx: number;
        let ty: number;
        if (i === 0) {
          tx = bodyX[0] - bodyX[1];
          ty = bodyY[0] - bodyY[1];
        } else if (i === last) {
          tx = bodyX[i - 1] - bodyX[i];
          ty = bodyY[i - 1] - bodyY[i];
        } else {
          tx = bodyX[i - 1] - bodyX[i + 1];
          ty = bodyY[i - 1] - bodyY[i + 1];
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

      const tailDx = bodyX[last] - bodyX[last - 1];
      const tailDy = bodyY[last] - bodyY[last - 1];
      const tailLen = Math.sqrt(tailDx * tailDx + tailDy * tailDy) || 1;
      const tailScale = 4.2 / tailLen;
      tailTipX = bodyX[last] + tailDx * tailScale;
      tailTipY = bodyY[last] + tailDy * tailScale;

      let splitCount = 0;
      for (let i = 1; i <= last - MIN_CROSS_GAP; i++) {
        const ix = bodyX[i];
        const iy = bodyY[i];
        const iw = halfWidths[i];
        let j = i + MIN_CROSS_GAP;
        while (j <= last) {
          const ddx = ix - bodyX[j];
          const ddy = iy - bodyY[j];
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
    };

    const appendRibbonSubpath = (startIdx: number, endIdx: number) => {
      const last = SNAKE_SEGMENTS - 1;
      const hasTailCap = endIdx === last;

      ctx.moveTo(leftX[startIdx], leftY[startIdx]);
      if (endIdx > startIdx) {
        ctx.lineTo(
          (leftX[startIdx] + leftX[startIdx + 1]) * 0.5,
          (leftY[startIdx] + leftY[startIdx + 1]) * 0.5,
        );
      }

      for (let i = startIdx + 1; i < endIdx; i++) {
        ctx.quadraticCurveTo(
          leftX[i],
          leftY[i],
          (leftX[i] + leftX[i + 1]) * 0.5,
          (leftY[i] + leftY[i + 1]) * 0.5,
        );
      }

      if (hasTailCap) {
        ctx.quadraticCurveTo(leftX[last], leftY[last], tailTipX, tailTipY);
        ctx.quadraticCurveTo(
          rightX[last],
          rightY[last],
          (rightX[last - 1] + rightX[last]) * 0.5,
          (rightY[last - 1] + rightY[last]) * 0.5,
        );
      } else {
        ctx.lineTo(leftX[endIdx], leftY[endIdx]);
        ctx.lineTo(rightX[endIdx], rightY[endIdx]);
        ctx.lineTo(
          (rightX[endIdx - 1] + rightX[endIdx]) * 0.5,
          (rightY[endIdx - 1] + rightY[endIdx]) * 0.5,
        );
      }

      for (let i = endIdx - 1; i > startIdx; i--) {
        ctx.quadraticCurveTo(
          rightX[i],
          rightY[i],
          (rightX[i] + rightX[i - 1]) * 0.5,
          (rightY[i] + rightY[i - 1]) * 0.5,
        );
      }

      ctx.lineTo(rightX[startIdx], rightY[startIdx]);
      ctx.closePath();
    };

    const traceHeadShape = () => {
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
        headCheekLY,
      );
      ctx.bezierCurveTo(
        hx + hfx * 4.2 + hnx * 9.0,
        hy + hfy * 4.2 + hny * 9.0,
        hx - hfx * 1.4 + hnx * 6.8,
        hy - hfy * 1.4 + hny * 6.8,
        leftX[1],
        leftY[1],
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
        headCheekRY,
      );
      ctx.bezierCurveTo(
        hx + hfx * 17.4 - hnx * 7.4,
        hy + hfy * 17.4 - hny * 7.4,
        hx + hfx * 26.2 - hnx * 2.4,
        hy + hfy * 26.2 - hny * 2.4,
        headSnoutX,
        headSnoutY,
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
        holeLeftY,
      );
      ctx.quadraticCurveTo(
        hx + hfx * 4.8 + hnx * 1.65,
        hy + hfy * 4.8 + hny * 1.65,
        holeBackX,
        holeBackY,
      );
      ctx.quadraticCurveTo(
        hx + hfx * 4.8 - hnx * 1.65,
        hy + hfy * 4.8 - hny * 1.65,
        holeRightX,
        holeRightY,
      );
      ctx.quadraticCurveTo(
        hx + hfx * 13.0 - hnx * 1.75,
        hy + hfy * 13.0 - hny * 1.75,
        holeFrontX,
        holeFrontY,
      );
      ctx.closePath();
    };

    const drawSnake = () => {
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

      let minX = bodyMinX;
      let maxX = bodyMaxX;
      let minY = bodyMinY;
      let maxY = bodyMaxY;
      if (headSnoutX < minX) minX = headSnoutX;
      if (headSnoutX > maxX) maxX = headSnoutX;
      if (headSnoutY < minY) minY = headSnoutY;
      if (headSnoutY > maxY) maxY = headSnoutY;
      if (headCheekLX < minX) minX = headCheekLX;
      if (headCheekLX > maxX) maxX = headCheekLX;
      if (headCheekLY < minY) minY = headCheekLY;
      if (headCheekLY > maxY) maxY = headCheekLY;
      if (headCheekRX < minX) minX = headCheekRX;
      if (headCheekRX > maxX) maxX = headCheekRX;
      if (headCheekRY < minY) minY = headCheekRY;
      if (headCheekRY > maxY) maxY = headCheekRY;

      const margin = 54;
      const localMinY = Math.floor(minY - canvasTop - margin);
      const localMaxY = Math.ceil(maxY - canvasTop + margin);
      if (localMaxY < 0 || localMinY > canvasHeight) {
        hasDirtyRect = false;
        return;
      }

      const last = SNAKE_SEGMENTS - 1;
      const headMinLowerIdx = 8;
      headOverlaps = false;
      for (let j = headMinLowerIdx; j <= last; j++) {
        const reach = 36 + halfWidths[j];
        const ddx = headX - bodyX[j];
        const ddy = headY - bodyY[j];
        if (ddx * ddx + ddy * ddy < reach * reach) {
          headOverlaps = true;
          break;
        }
        const sdx = headSnoutX - bodyX[j];
        const sdy = headSnoutY - bodyY[j];
        if (sdx * sdx + sdy * sdy < reach * reach) {
          headOverlaps = true;
          break;
        }
      }

      const shifted = canvasTop !== 0;
      if (shifted) {
        ctx.save();
        ctx.translate(0, -canvasTop);
      }

      ctx.fillStyle = snakeFillStyle;

      for (let p = pieceCount - 1; p >= 0; p--) {
        const start = pieceStarts[p];
        const end = pieceEnds[p];
        const drawEnd = p < pieceCount - 1 ? Math.min(last, end + 1) : end;

        if (p < pieceCount - 1) {
          const clipStart = Math.min(last, end + 3);
          if (clipStart < last) {
            ctx.save();
            ctx.beginPath();
            appendRibbonSubpath(clipStart, last);
            ctx.clip();

            ctx.shadowColor = castShadowColor;
            ctx.shadowBlur = 9;
            ctx.shadowOffsetX = 0;
            ctx.shadowOffsetY = 0;

            ctx.beginPath();
            appendRibbonSubpath(start, drawEnd);
            ctx.fill();
            ctx.restore();
          }
        }

        if (p === 0 && headOverlaps) {
          ctx.save();
          ctx.beginPath();
          appendRibbonSubpath(headMinLowerIdx, last);
          ctx.clip();

          ctx.shadowColor = castShadowColor;
          ctx.shadowBlur = 9;
          ctx.shadowOffsetX = 0;
          ctx.shadowOffsetY = 0;

          ctx.beginPath();
          traceHeadShape();
          ctx.fill('evenodd');
          ctx.restore();
        }

        ctx.beginPath();
        appendRibbonSubpath(start, drawEnd);
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
        ctx.strokeStyle = `${primaryPrefix}${(0.85 * ext).toFixed(3)})`;
        ctx.lineWidth = 1.4;
        ctx.lineCap = 'round';
        ctx.stroke();
      }

      ctx.beginPath();
      traceHeadShape();
      ctx.fill('evenodd');

      if (shifted) {
        ctx.restore();
      }

      dirtyMinX = Math.max(0, Math.floor(minX - margin));
      dirtyMinY = Math.max(0, localMinY);
      dirtyMaxX = Math.min(canvasWidth, Math.ceil(maxX + margin));
      dirtyMaxY = Math.min(canvasHeight, localMaxY);
      hasDirtyRect = true;
    };

    const render = (now: number) => {
      rafId = 0;
      if (destroyed) return;

      const rawDt = Math.min(0.05, Math.max(0, (now - lastNow) / 1000));
      lastNow = now;

      updateScrollMetrics();
      updateCanvasWindow(false);

      const colorStep = Math.min(1, rawDt * 5.5);
      for (let i = 0; i < 3; i++) {
        const dp = targetPrimary[i] - currentPrimary[i];
        if (Math.abs(dp) > 0.15) {
          currentPrimary[i] += dp * colorStep;
          paletteDirty = true;
        } else if (dp !== 0) {
          currentPrimary[i] = targetPrimary[i];
          paletteDirty = true;
        }
      }

      const dDark = targetDarkBlend - darkBlend;
      if (Math.abs(dDark) > 0.002) {
        darkBlend += dDark * colorStep;
        paletteDirty = true;
      } else if (dDark !== 0) {
        darkBlend = targetDarkBlend;
        paletteDirty = true;
      }

      if (paletteDirty) {
        rebuildStyles();
        visualDirty = true;
      }

      accumulator += rawDt;
      let steps = 0;
      while (accumulator >= FIXED_DT && steps < 4) {
        stepSimulation(FIXED_DT);
        accumulator -= FIXED_DT;
        steps++;
      }

      if (visualDirty) {
        if (hasDirtyRect) {
          ctx.clearRect(dirtyMinX, dirtyMinY, dirtyMaxX - dirtyMinX, dirtyMaxY - dirtyMinY);
        } else {
          ctx.clearRect(0, 0, canvasWidth, canvasHeight);
        }
        drawSnake();
        visualDirty = false;
      }

      if (!document.hidden) {
        rafId = requestAnimationFrame(render);
      }
    };

    const scheduleFrame = () => {
      if (destroyed || document.hidden || rafId !== 0) return;
      lastNow = performance.now();
      rafId = requestAnimationFrame(render);
    };

    const stopFrame = () => {
      if (rafId !== 0) {
        cancelAnimationFrame(rafId);
        rafId = 0;
      }
    };

    const handlePointerMove = (e: PointerEvent) => {
      if (pointerActive && e.clientX === pointerClientX && e.clientY === pointerClientY) {
        return;
      }
      pointerClientX = e.clientX;
      pointerClientY = e.clientY;
      pointerActive = true;
      pointerLastMoveTime = simTime;
    };

    const handlePointerDown = (e: PointerEvent) => {
      pointerClientX = e.clientX;
      pointerClientY = e.clientY;
      pointerActive = true;
      pointerLastMoveTime = simTime;
      pointerSurge = 1;
      if (tongueProgress === 0) {
        tongueProgress = 0.001;
        visualDirty = true;
      }
    };

    const handleScroll = () => {
      scrollX = window.scrollX;
      scrollY = window.scrollY;
      pointerActive = true;
      pointerLastMoveTime = simTime;
    };

    const handlePointerLeave = () => {
      pointerActive = false;
    };

    const handleVisibilityChange = () => {
      if (document.hidden) {
        stopFrame();
      } else {
        scheduleFrame();
      }
    };

    const themeObserver = new MutationObserver(() => {
      if (colorSyncFrame !== 0) return;
      colorSyncFrame = requestAnimationFrame(() => {
        colorSyncFrame = 0;
        if (destroyed) return;
        const nextPalette = readThemePalette();
        targetPrimary = nextPalette.primary;
        targetDarkBlend = nextPalette.isDark ? 1 : 0;
        paletteDirty = true;
      });
    });

    themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme', 'data-preview-theme'],
    });

    const resizeObserver =
      typeof ResizeObserver !== 'undefined' ? new ResizeObserver(resize) : null;
    resizeObserver?.observe(container);

    rebuildStyles();
    resize();
    window.addEventListener('pointermove', handlePointerMove, {passive: true});
    window.addEventListener('pointerdown', handlePointerDown, {passive: true});
    window.addEventListener('scroll', handleScroll, {passive: true});
    document.addEventListener('mouseleave', handlePointerLeave);
    window.addEventListener('resize', resize, {passive: true});
    document.addEventListener('visibilitychange', handleVisibilityChange);
    scheduleFrame();

    return () => {
      destroyed = true;
      stopFrame();
      if (colorSyncFrame !== 0) cancelAnimationFrame(colorSyncFrame);
      themeObserver.disconnect();
      resizeObserver?.disconnect();
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerdown', handlePointerDown);
      window.removeEventListener('scroll', handleScroll);
      document.removeEventListener('mouseleave', handlePointerLeave);
      window.removeEventListener('resize', resize);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return (
    <div ref={containerRef} className={styles.waveContainer} aria-hidden="true">
      <div className={styles.waveLayer}>
        <svg
          className={`${styles.waveSvg} ${styles.waveAnim1}`}
          viewBox="0 0 2880 1200"
          fill="none"
          preserveAspectRatio="none">
          <path
            d="M0,160 C240,90 480,230 720,150 C960,90 1200,230 1440,160 C1680,90 1920,230 2160,150 C2400,90 2640,230 2880,160 L2880,1200 L0,1200 Z"
            fill="var(--homepage-wave-1)"
          />
        </svg>
      </div>

      <div className={styles.waveLayer}>
        <svg
          className={`${styles.waveSvg} ${styles.waveAnim2}`}
          viewBox="0 0 2880 1200"
          fill="none"
          preserveAspectRatio="none">
          <path
            d="M0,420 C240,340 480,500 720,410 C960,340 1200,500 1440,420 C1680,340 1920,500 2160,410 C2400,340 2640,500 2880,420 L2880,1200 L0,1200 Z"
            fill="var(--homepage-wave-2)"
          />
        </svg>
      </div>

      <canvas ref={canvasRef} className={styles.snakeCanvas} />

      <div className={`${styles.waveLayer} ${styles.waveLayerSecondary}`}>
        <svg
          className={`${styles.waveSvg} ${styles.waveAnim3}`}
          viewBox="0 0 2880 1200"
          fill="none"
          preserveAspectRatio="none">
          <path
            d="M0,700 C240,620 480,780 720,690 C960,620 1200,780 1440,700 C1680,620 1920,780 2160,690 C2400,620 2640,780 2880,700 L2880,1200 L0,1200 Z"
            fill="var(--homepage-wave-3)"
          />
        </svg>
      </div>

      <div className={`${styles.waveLayer} ${styles.waveLayerSecondary}`}>
        <svg
          className={`${styles.waveSvg} ${styles.waveAnim4}`}
          viewBox="0 0 2880 1200"
          fill="none"
          preserveAspectRatio="none">
          <path
            d="M0,960 C240,880 480,1040 720,950 C960,880 1200,1040 1440,960 C1680,880 1920,1040 2160,950 C2400,880 2640,1040 2880,960 L2880,1200 L0,1200 Z"
            fill="var(--homepage-wave-4)"
          />
        </svg>
      </div>
    </div>
  );
}
