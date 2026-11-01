import React from 'react';
import styles from './styles.module.css';

export default function FluidBackground(): React.JSX.Element {
  return (
    <div className={styles.waveContainer} aria-hidden="true">
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

      <div className={styles.waveLayer}>
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

      <div className={styles.waveLayer}>
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
