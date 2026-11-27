import type {ReactNode} from 'react';
import styles from './styles.module.css';

export default function ThemedBanner({alt}: {alt?: string}): ReactNode {
  return (
    <span
      className={styles.banner}
      role="img"
      aria-label={alt || 'Serpantinum Wayland desktop shell'}>
      <svg
        className={styles.waveBg}
        viewBox="0 0 960 280"
        fill="none"
        preserveAspectRatio="none"
        aria-hidden="true">
        <path
          d="M0,180 C180,110 360,250 540,170 C720,100 840,210 960,150 L960,280 L0,280 Z"
          fill="var(--homepage-wave-1)"
        />
        <path
          d="M0,220 C220,160 440,270 680,200 C820,160 900,220 960,195 L960,280 L0,280 Z"
          fill="var(--homepage-wave-2)"
        />
      </svg>
      <span className={styles.content}>
        <span className={styles.logoMark} aria-hidden="true" />
        <span className={styles.wordmarkGroup}>
          <span className={styles.wordmark}>Serpantinum</span>
          <span className={styles.tagline}>A Wayland desktop shell built for you.</span>
        </span>
      </span>
    </span>
  );
}
