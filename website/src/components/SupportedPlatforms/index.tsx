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

interface ArchDistro {
  id: string;
  name: string;
}

const ARCH_DISTROS: ArchDistro[] = [
  { id: 'arch', name: 'Arch Linux' },
  { id: 'endeavouros', name: 'EndeavourOS' },
  { id: 'manjaro', name: 'Manjaro' },
  { id: 'cachyos', name: 'CachyOS' },
  { id: 'garuda', name: 'Garuda Linux' },
  { id: 'arcolinux', name: 'ArcoLinux' },
  { id: 'archcraft', name: 'Archcraft' },
  { id: 'artix', name: 'Artix Linux' },
  { id: 'blackarch', name: 'BlackArch' },
  { id: 'rebornos', name: 'RebornOS' },
  { id: 'mabox', name: 'Mabox Linux' },
  { id: 'blendos', name: 'blendOS' },
  { id: 'parch', name: 'Parch Linux' },
  { id: 'biglinux', name: 'BigLinux' },
  { id: 'archlabs', name: 'ArchLabs' },
  { id: 'archman', name: 'Archman' },
  { id: 'alci', name: 'ALCI' },
  { id: 'bluestar', name: 'BlueStar' },
  { id: 'archbang', name: 'ArchBang' },
  { id: 'archex', name: 'ArchEX' },
  { id: 'archstrike', name: 'ArchStrike' },
  { id: 'athena', name: 'Athena OS' },
  { id: 'chimeraos', name: 'ChimeraOS' },
  { id: 'ctlos', name: 'Ctlos Linux' },
  { id: 'crystal', name: 'Crystal Linux' },
  { id: 'hefftorlinux', name: 'HefftorLinux' },
  { id: 'instantos', name: 'instantOS' },
  { id: 'nyarch', name: 'Nyarch Linux' },
  { id: 'obarun', name: 'Obarun' },
  { id: 'hyperbola', name: 'Hyperbola' },
  { id: 'parabola', name: 'Parabola' },
  { id: 'salientos', name: 'Salient OS' },
  { id: 'snal', name: 'Snal Linux' },
  { id: 'steamos', name: 'SteamOS (Holo)' },
  { id: 'stormos', name: 'StormOS' },
  { id: 'tearch', name: 'TeArch' },
  { id: 'xerolinux', name: 'XeroLinux' },
  { id: 'axyl', name: 'Axyl' },
  { id: 'omarchy', name: 'OMARCHY' },
];

export default function SupportedPlatforms(): ReactNode {
  const sectionRef = useRef<HTMLElement | null>(null);
  const [isRevealed, setIsRevealed] = useState(false);
  const [isArchActive, setIsArchActive] = useState(false);
  const hoverTimeoutRef = useRef<number | null>(null);

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

  const handlePointerEnter = (e: React.PointerEvent) => {
    if (e.pointerType !== 'mouse') return;
    if (hoverTimeoutRef.current !== null) {
      window.clearTimeout(hoverTimeoutRef.current);
      hoverTimeoutRef.current = null;
    }
    setIsArchActive(true);
  };

  const handlePointerLeave = (e: React.PointerEvent) => {
    if (e.pointerType !== 'mouse') return;
    hoverTimeoutRef.current = window.setTimeout(() => {
      setIsArchActive(false);
    }, 320);
  };

  const toggleArch = () => {
    if (hoverTimeoutRef.current !== null) {
      window.clearTimeout(hoverTimeoutRef.current);
      hoverTimeoutRef.current = null;
    }
    setIsArchActive((active) => !active);
  };

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

          <div
            className={clsx(
              styles.archGroup,
              isArchActive && styles.archGroupActive,
            )}
            onPointerEnter={handlePointerEnter}
            onPointerLeave={handlePointerLeave}>
            <Link
              to="/installation"
              className={clsx(
                styles.card,
                styles.archCard,
                isRevealed && styles.cardRevealed,
                isArchActive && styles.cardActiveHover,
              )}
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

            <button
              type="button"
              className={styles.shelfToggle}
              aria-expanded={isArchActive}
              aria-controls="arch-distro-shelf"
              onClick={toggleArch}>
              {isArchActive ? 'Hide distros' : 'Show all distros'}
            </button>

            <div id="arch-distro-shelf" className={styles.integratedShelf}>
              <div className={styles.shelfCard}>
                <div className={styles.shelfHeader}>
                  <span className={styles.shelfTitle}>Arch-based distributions</span>
                  <span className={styles.shelfCount}>{ARCH_DISTROS.length} verified</span>
                </div>
                <div className={styles.distroGrid}>
                  {ARCH_DISTROS.map((distro) => (
                    <Link
                      key={distro.id}
                      to="/installation"
                      className={styles.distroItem}>
                      <span className={styles.distroName}>{distro.name}</span>
                    </Link>
                  ))}
                </div>
              </div>
            </div>
          </div>
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
