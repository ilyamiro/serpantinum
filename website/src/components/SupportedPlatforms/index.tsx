import {useState, useEffect, useRef, type ReactNode} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Heading from '@theme/Heading';
import Link from '@docusaurus/Link';
import clsx from 'clsx';

import styles from './styles.module.css';

interface CompositorItem {
  id: string;
  name: string;
  logo: string;
  alt: string;
  url: string;
}

export default function SupportedPlatforms(): ReactNode {
  const sectionRef = useRef<HTMLElement | null>(null);
  const [isRevealed, setIsRevealed] = useState(false);

  const compositors: CompositorItem[] = [
    {
      id: 'hyprland',
      name: 'Hyprland',
      logo: useBaseUrl('/img/logos/hyprland.png'),
      alt: 'Hyprland logo',
      url: 'https://hyprland.org',
    },
    {
      id: 'niri',
      name: 'Niri',
      logo: useBaseUrl('/img/logos/niri.png'),
      alt: 'Niri logo',
      url: 'https://github.com/YaLTeR/niri',
    },
    {
      id: 'sway',
      name: 'Sway',
      logo: useBaseUrl('/img/logos/sway.png'),
      alt: 'Sway logo',
      url: 'https://github.com/swaywm/sway',
    },
    {
      id: 'mango',
      name: 'Mango',
      logo: useBaseUrl('/img/logos/mango.svg'),
      alt: 'Mango logo',
      url: 'https://github.com/mangowm/mango',
    },
  ];

  useEffect(() => {
    const el = sectionRef.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsRevealed(true);
        }
      },
      {threshold: 0.15},
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <section ref={sectionRef} className={styles.section}>
      <div className={styles.group}>
        <Heading as="h2" className={styles.heading}>
          Supported distros
        </Heading>
        <div className={styles.distroRow}>
          <Link
            to="/installation/nixos"
            className={clsx(styles.card, isRevealed && styles.cardRevealed)}
            style={{'--card-delay': '0ms'} as React.CSSProperties}>
            <div
              className={clsx(styles.logoWrapper, isRevealed && styles.logoRevealed)}
              style={{'--logo-delay': '80ms'} as React.CSSProperties}>
              <img
                src={useBaseUrl('/img/logos/nixos.png')}
                alt="NixOS logo"
                className={styles.logoImage}
                loading="lazy"
              />
            </div>
            <span className={styles.platformName}>NixOS</span>
          </Link>

          <Link
            to="/installation"
            className={clsx(styles.card, isRevealed && styles.cardRevealed)}
            style={{'--card-delay': '60ms'} as React.CSSProperties}>
            <div
              className={clsx(styles.logoWrapper, isRevealed && styles.logoRevealed)}
              style={{'--logo-delay': '140ms'} as React.CSSProperties}>
              <img
                src={useBaseUrl('/img/logos/fedora.png')}
                alt="Fedora logo"
                className={styles.logoImage}
                loading="lazy"
              />
            </div>
            <span className={styles.platformName}>Fedora</span>
          </Link>

          <Link
            to="/installation"
            className={clsx(styles.card, isRevealed && styles.cardRevealed)}
            style={{'--card-delay': '120ms'} as React.CSSProperties}>
            <div
              className={clsx(styles.logoWrapper, isRevealed && styles.logoRevealed)}
              style={{'--logo-delay': '200ms'} as React.CSSProperties}>
              <img
                src={useBaseUrl('/img/logos/void.png')}
                alt="Void Linux logo"
                className={styles.logoImage}
                loading="lazy"
              />
            </div>
            <span className={styles.platformName}>Void</span>
          </Link>

          <Link
            to="/installation#arch-linux-and-derivatives"
            className={clsx(styles.card, isRevealed && styles.cardRevealed)}
            style={{'--card-delay': '180ms'} as React.CSSProperties}>
            <div
              className={clsx(styles.logoWrapper, isRevealed && styles.logoRevealed)}
              style={{'--logo-delay': '260ms'} as React.CSSProperties}>
              <img
                src={useBaseUrl('/img/logos/arch.png')}
                alt="Arch Linux logo"
                className={styles.logoImage}
                loading="lazy"
              />
            </div>
            <div className={styles.nameBadgeWrapper}>
              <span className={styles.platformName}>Arch Linux</span>
              <span className={styles.archBadge}>40+ distros &rarr;</span>
            </div>
          </Link>
        </div>
      </div>

      <div className={styles.group}>
        <Heading as="h2" className={styles.heading}>
          Supported compositors
        </Heading>
        <div className={styles.compositorGrid}>
          {compositors.map((item, index) => (
            <a
              key={item.id}
              href={item.url}
              target="_blank"
              rel="noopener noreferrer"
              className={clsx(styles.card, isRevealed && styles.cardRevealed)}
              style={{'--card-delay': `${index * 120}ms`} as React.CSSProperties}>
              <div
                className={clsx(styles.logoWrapper, isRevealed && styles.logoRevealed)}
                style={{'--logo-delay': `${index * 120 + 80}ms`} as React.CSSProperties}>
                <img
                  src={item.logo}
                  alt={item.alt}
                  className={styles.logoImage}
                  loading="lazy"
                />
              </div>
              <span className={styles.platformName}>{item.name}</span>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
}
