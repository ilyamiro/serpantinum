import {useState, useRef, useEffect, type ReactNode, type CSSProperties} from 'react';
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

const INSTALL_COMMAND = 'curl -fsSL install.serpantinum.dev | bash';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  const titleText = siteConfig.title;
  const [copied, setCopied] = useState(false);
  const copyTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (copyTimerRef.current) {
        clearTimeout(copyTimerRef.current);
      }
    };
  }, []);

  const handleCopy = () => {
    const finishCopy = () => {
      setCopied(true);
      if (copyTimerRef.current) {
        clearTimeout(copyTimerRef.current);
      }
      copyTimerRef.current = setTimeout(() => {
        setCopied(false);
      }, 2000);
    };

    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(INSTALL_COMMAND).then(finishCopy).catch(() => {});
      return;
    }

    const textarea = document.createElement('textarea');
    textarea.value = INSTALL_COMMAND;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    try {
      document.execCommand('copy');
      finishCopy();
    } catch {}
    document.body.removeChild(textarea);
  };

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
        <div className={styles.heroActions}>
          <div className={styles.installBox}>
            <span className={styles.installPrompt} aria-hidden="true">
              $
            </span>
            <code className={styles.installCode}>{INSTALL_COMMAND}</code>
            <button
              type="button"
              className={clsx(styles.copyButton, copied && styles.copyButtonCopied)}
              onClick={handleCopy}
              aria-label={copied ? 'Copied install command' : 'Copy install command'}
              title={copied ? 'Copied' : 'Copy command'}>
              {copied ? (
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.4"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true">
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              ) : (
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true">
                  <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                  <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                </svg>
              )}
            </button>
          </div>
          <Link className={styles.actionButton} to="/getting-started">
            Get started
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
      description="Serpantinum is a customizable Wayland desktop shell for Hyprland, Sway, Niri, Mango and Umbriel, built for you.">
      <Head>
        <title>Serpantinum - a desktop shell built for YOU</title>
        <meta property="og:title" content="Serpantinum - a desktop shell built for YOU" />
        <link
          rel="preload"
          href="/img/previews/preview_4.webp"
          as="image"
          type="image/webp"
          fetchPriority="high"
        />
        <link
          rel="preload"
          href="/img/logo.svg"
          as="image"
          type="image/svg+xml"
        />
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
