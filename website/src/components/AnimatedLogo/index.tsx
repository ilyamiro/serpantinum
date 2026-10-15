import React, {useRef, useEffect} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

const VS_SOURCE = `
attribute vec2 a_position;
varying vec2 v_texCoord;
void main() {
    v_texCoord = vec2((a_position.x + 1.0) * 0.5, (1.0 - a_position.y) * 0.5);
    gl_Position = vec4(a_position, 0.0, 1.0);
}
`;

const FS_SOURCE = `
precision highp float;
varying vec2 v_texCoord;
uniform vec2 u_itemSize;
uniform float u_fillLevel;
uniform float u_wavePhase;
uniform vec4 u_baseColor;
uniform vec4 u_bgColor;
uniform float u_s16;
uniform sampler2D u_mask;

const float PI = 3.141592653589793;

void main() {
    float maskAlpha = texture2D(u_mask, v_texCoord).a;
    if (maskAlpha <= 0.001) {
        gl_FragColor = vec4(0.0);
        return;
    }

    vec4 accum = u_bgColor;

    if (u_fillLevel > 0.001) {
        vec2 p = v_texCoord * u_itemSize;
        float s16 = u_s16 > 0.0 ? u_s16 : 12.0;

        float amps[5];
        amps[0] = 1.8; amps[1] = 1.5; amps[2] = 1.2; amps[3] = 0.9; amps[4] = 0.6;
        float offsets[5];
        offsets[0] = 0.0; offsets[1] = 0.5; offsets[2] = 1.0; offsets[3] = 1.5; offsets[4] = 2.0;
        float darken[5];
        darken[0] = 2.5; darken[1] = 2.0; darken[2] = 1.5; darken[3] = 1.1; darken[4] = 1.0;

        for (int k = 0; k < 5; ++k) {
            float prog = clamp((u_fillLevel - float(k) * 0.15) * 1.25, 0.0, 1.0);
            if (prog <= 0.0) continue;

            vec4 col = vec4(u_baseColor.rgb / darken[k], u_baseColor.a);

            if (prog >= 1.0) {
                accum = col;
                continue;
            }

            float fillY = u_itemSize.y * (1.0 - prog);
            float baseAmp = s16 * sin(prog * PI) * amps[k];
            float localPhase = u_wavePhase + offsets[k];

            float waveHeight = 0.0;
            for (int w = 1; w <= 3; ++w) {
                float freq = float(w) * 1.5;
                float amp = baseAmp * (1.0 - float(w - 1) * 0.3);
                waveHeight += sin(localPhase * freq + p.x * 0.01 * freq) * amp;
            }

            float surfaceY = fillY + waveHeight * 0.6;
            float edge = clamp(0.5 - (surfaceY - p.y), 0.0, 1.0);

            accum = mix(accum, col, edge);
        }
    }

    gl_FragColor = accum * maskAlpha;
}
`;

function createShader(gl: WebGLRenderingContext, type: number, source: string): WebGLShader | null {
  const shader = gl.createShader(type);
  if (!shader) return null;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

let preloadedImg: HTMLImageElement | null = null;

export default function AnimatedLogo(): React.JSX.Element {
  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const logoUrl = useBaseUrl('/img/logo.svg');
  const animStateRef = useRef({
    startTime: 0,
    animId: 0,
    restart: () => {},
  });

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;

    let destroyed = false;

    if (!preloadedImg && typeof window !== 'undefined') {
      preloadedImg = new Image();
      preloadedImg.src = logoUrl;
    }

    const img = preloadedImg || new Image();
    if (!img.src) {
      img.src = logoUrl;
    }

    const getColors = () => {
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      if (isDark) {
        return {
          base: [203 / 255, 166 / 255, 247 / 255, 1.0],
          bg: [205 / 255, 214 / 255, 244 / 255, 1.0],
        };
      }
      return {
        base: [124 / 255, 68 / 255, 158 / 255, 1.0],
        bg: [76 / 255, 79 / 255, 105 / 255, 1.0],
      };
    };

    let colors = getColors();

    const observer = new MutationObserver(() => {
      colors = getColors();
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme'],
    });

    const initRenderer = () => {
      if (destroyed) return;
      const rect = container.getBoundingClientRect();
      const cssWidth = rect.width || 270;
      const cssHeight = rect.height || 270;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const width = Math.round(cssWidth * dpr);
      const height = Math.round(cssHeight * dpr);

      canvas.width = width;
      canvas.height = height;

      const offscreen = document.createElement('canvas');
      offscreen.width = width;
      offscreen.height = height;
      const offCtx = offscreen.getContext('2d');
      if (offCtx) {
        const logoTargetHeight = Math.round(height * 0.96);
        const logoTargetWidth = Math.round(logoTargetHeight * 0.88);
        const padX = Math.round((width - logoTargetWidth) / 2);
        const padY = Math.round((height - logoTargetHeight) / 2);
        offCtx.drawImage(img, padX, padY, logoTargetWidth, logoTargetHeight);
      }

      let gl = canvas.getContext('webgl', {alpha: true, premultipliedAlpha: false});
      let program: WebGLProgram | null = null;
      let maskTexture: WebGLTexture | null = null;
      let posBuffer: WebGLBuffer | null = null;

      let locItemSize: WebGLUniformLocation | null = null;
      let locFillLevel: WebGLUniformLocation | null = null;
      let locWavePhase: WebGLUniformLocation | null = null;
      let locBaseColor: WebGLUniformLocation | null = null;
      let locBgColor: WebGLUniformLocation | null = null;
      let locS16: WebGLUniformLocation | null = null;
      let locMask: WebGLUniformLocation | null = null;

      if (gl) {
        const vs = createShader(gl, gl.VERTEX_SHADER, VS_SOURCE);
        const fs = createShader(gl, gl.FRAGMENT_SHADER, FS_SOURCE);
        if (vs && fs) {
          program = gl.createProgram();
          if (program) {
            gl.attachShader(program, vs);
            gl.attachShader(program, fs);
            gl.linkProgram(program);
            if (gl.getProgramParameter(program, gl.LINK_STATUS)) {
              gl.useProgram(program);
              posBuffer = gl.createBuffer();
              gl.bindBuffer(gl.ARRAY_BUFFER, posBuffer);
              gl.bufferData(
                gl.ARRAY_BUFFER,
                new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
                gl.STATIC_DRAW,
              );

              const aPos = gl.getAttribLocation(program, 'a_position');
              gl.enableVertexAttribArray(aPos);
              gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);

              maskTexture = gl.createTexture();
              gl.bindTexture(gl.TEXTURE_2D, maskTexture);
              gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
              gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
              gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
              gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
              gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, offscreen);

              locItemSize = gl.getUniformLocation(program, 'u_itemSize');
              locFillLevel = gl.getUniformLocation(program, 'u_fillLevel');
              locWavePhase = gl.getUniformLocation(program, 'u_wavePhase');
              locBaseColor = gl.getUniformLocation(program, 'u_baseColor');
              locBgColor = gl.getUniformLocation(program, 'u_bgColor');
              locS16 = gl.getUniformLocation(program, 'u_s16');
              locMask = gl.getUniformLocation(program, 'u_mask');
            } else {
              program = null;
              gl = null;
            }
          }
        } else {
          gl = null;
        }
      }

      const ctx2d = !gl ? canvas.getContext('2d') : null;

      let startTimestamp = performance.now();
      const fillDuration = 6500;
      const phaseDuration = 4500;

      const restart = () => {
        startTimestamp = performance.now();
      };
      animStateRef.current.restart = restart;

      const render = (now: number) => {
        if (destroyed) return;
        const elapsed = now - startTimestamp;
        const fillT = Math.min(1.0, Math.max(0.0, elapsed / fillDuration));
        const easedFill = 1.0 - Math.pow(1.0 - fillT, 3.0);
        const fillLevel = easedFill * 1.15;
        const wavePhase = ((elapsed % phaseDuration) / phaseDuration) * Math.PI * 2.0;

        if (gl && program) {
          gl.viewport(0, 0, width, height);
          gl.clearColor(0.0, 0.0, 0.0, 0.0);
          gl.clear(gl.COLOR_BUFFER_BIT);

          gl.useProgram(program);
          gl.uniform2f(locItemSize, width, height);
          gl.uniform1f(locFillLevel, fillLevel);
          gl.uniform1f(locWavePhase, wavePhase);
          gl.uniform4fv(locBaseColor, colors.base);
          gl.uniform4fv(locBgColor, colors.bg);
          gl.uniform1f(locS16, 12.0 * dpr);

          gl.activeTexture(gl.TEXTURE0);
          gl.bindTexture(gl.TEXTURE_2D, maskTexture);
          gl.uniform1i(locMask, 0);

          gl.drawArrays(gl.TRIANGLES, 0, 6);
        } else if (ctx2d) {
          ctx2d.clearRect(0, 0, width, height);
          ctx2d.fillStyle = `rgba(${Math.round(colors.bg[0] * 255)}, ${Math.round(colors.bg[1] * 255)}, ${Math.round(colors.bg[2] * 255)}, 1.0)`;
          ctx2d.fillRect(0, 0, width, height);

          if (fillLevel > 0.001) {
            const amps = [1.8, 1.5, 1.2, 0.9, 0.6];
            const offsets = [0.0, 0.5, 1.0, 1.5, 2.0];
            const darken = [2.5, 2.0, 1.5, 1.1, 1.0];
            const s16 = 12.0 * dpr;

            for (let k = 0; k < 5; ++k) {
              const prog = Math.min(1.0, Math.max(0.0, (fillLevel - k * 0.15) * 1.25));
              if (prog <= 0.0) continue;

              const r = Math.round((colors.base[0] * 255) / darken[k]);
              const g = Math.round((colors.base[1] * 255) / darken[k]);
              const b = Math.round((colors.base[2] * 255) / darken[k]);
              const col = `rgba(${r}, ${g}, ${b}, 1.0)`;

              if (prog >= 1.0) {
                ctx2d.fillStyle = col;
                ctx2d.fillRect(0, 0, width, height);
                continue;
              }

              const fillY = height * (1.0 - prog);
              const baseAmp = s16 * Math.sin(prog * Math.PI) * amps[k];
              const localPhase = wavePhase + offsets[k];

              ctx2d.beginPath();
              ctx2d.moveTo(0, height);
              for (let x = 0; x <= width; x += 3) {
                let waveHeight = 0.0;
                for (let w = 1; w <= 3; ++w) {
                  const freq = w * 1.5;
                  const amp = baseAmp * (1.0 - (w - 1) * 0.3);
                  waveHeight += Math.sin(localPhase * freq + x * 0.01 * freq) * amp;
                }
                const surfaceY = fillY + waveHeight * 0.6;
                ctx2d.lineTo(x, surfaceY);
              }
              ctx2d.lineTo(width, height);
              ctx2d.closePath();
              ctx2d.fillStyle = col;
              ctx2d.fill();
            }
          }

          ctx2d.globalCompositeOperation = 'destination-in';
          ctx2d.drawImage(offscreen, 0, 0);
          ctx2d.globalCompositeOperation = 'source-over';
        }

        animStateRef.current.animId = requestAnimationFrame(render);
      };

      animStateRef.current.animId = requestAnimationFrame(render);
    };

    if (img.complete && img.naturalWidth > 0) {
      initRenderer();
    } else {
      img.onload = () => {
        initRenderer();
      };
    }

    return () => {
      destroyed = true;
      observer.disconnect();
      cancelAnimationFrame(animStateRef.current.animId);
    };
  }, [logoUrl]);

  return (
    <div
      ref={containerRef}
      className={styles.logoContainer}
      onClick={() => animStateRef.current.restart()}
      title="Serpantinum">
      <canvas ref={canvasRef} className={styles.canvas} />
    </div>
  );
}
