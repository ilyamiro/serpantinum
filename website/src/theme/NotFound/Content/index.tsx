import type {ReactNode, CSSProperties} from 'react';
import Link from '@docusaurus/Link';
import Heading from '@theme/Heading';
import FluidBackground from '@site/src/components/FluidBackground';

import styles from './styles.module.css';

const CODE = '404';

export default function NotFoundContent(): ReactNode {
  return (
    <div className={styles.pageWrapper}>
      <FluidBackground />
      <main className={styles.content}>
        <div className={styles.code} aria-hidden="true">
          {Array.from(CODE).map((char, index) => (
            <span
              key={index}
              className={styles.char}
              style={{'--char-index': index} as CSSProperties}>
              {char}
            </span>
          ))}
        </div>
        <Heading as="h1" className={styles.title}>
          Page not found
        </Heading>
        <p className={styles.subtitle}>
          This page slithered away. The link may be broken or the page may have moved.
        </p>
        <div className={styles.buttons}>
          <Link className={styles.actionButton} to="/">
            Back to home
          </Link>
          <Link className={styles.secondaryButton} to="/getting-started">
            Get started
          </Link>
        </div>
      </main>
    </div>
  );
}
