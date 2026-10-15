import type {ReactNode, CSSProperties} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Head from '@docusaurus/Head';
import DesktopPreviews from '@site/src/components/DesktopPreviews';
import SupportedPlatforms from '@site/src/components/SupportedPlatforms';
import StarHistory from '@site/src/components/StarHistory';
import AnimatedLogo from '@site/src/components/AnimatedLogo';
import FluidBackground from '@site/src/components/FluidBackground';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  const titleText = siteConfig.title;

  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className="container">
        <AnimatedLogo />
        <Heading as="h1" className={clsx('hero__title', styles.waveTitle)}>
          {Array.from(titleText).map((char, index) => (
            <span
              key={index}
              className={styles.waveChar}
              style={{'--char-index': index} as CSSProperties}>
              {char === ' ' ? '\u00A0' : char}
            </span>
          ))}
        </Heading>
        <p className={clsx('hero__subtitle', styles.heroSubtitle)}>
          {siteConfig.tagline}
        </p>
        <div className={styles.buttons}>
          <Link className={styles.actionButton} to="/getting-started">
            Get started
          </Link>
          <Link
            className={styles.secondaryButton}
            href="https://github.com/ilyamiro/serpantinum">
            <svg
              className={styles.githubIcon}
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="currentColor"
              aria-hidden="true">
              <path d="M12 .3a12 12 0 0 0-3.8 23.4c.6.1.8-.3.8-.6v-2c-3.3.7-4-1.6-4-1.6-.6-1.4-1.4-1.8-1.4-1.8-1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1 1.8 2.8 1.3 3.5 1 0-.8.4-1.3.7-1.6-2.7-.3-5.5-1.3-5.5-5.9 0-1.3.5-2.4 1.2-3.2 0-.4-.5-1.6.1-3.2 0 0 1-.3 3.3 1.2a11.5 11.5 0 0 1 6 0c2.3-1.5 3.3-1.2 3.3-1.2.6 1.6.2 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.5 5.9.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6A12 12 0 0 0 12 .3" />
            </svg>
            GitHub
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={siteConfig.title}
      description="Serpantinum is a customizable Wayland desktop shell for Hyprland, Sway and Niri, built for you.">
      <Head>
        <title>Serpantinum - a desktop shell built for YOU</title>
        <meta property="og:title" content="Serpantinum - a desktop shell built for YOU" />
      </Head>
      <div className={styles.pageWrapper}>
        <FluidBackground />
        <HomepageHeader />
        <main className={styles.mainContent}>
          <DesktopPreviews />
          <SupportedPlatforms />
          <StarHistory />
        </main>
      </div>
    </Layout>
  );
}
