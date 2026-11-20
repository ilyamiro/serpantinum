import {useEffect, useState, type ReactNode} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';

type PreviewTheme = 'amber' | 'blue' | 'olive' | 'violet';

function readActiveTheme(): PreviewTheme {
  if (typeof document === 'undefined') return 'amber';
  const attr = document.documentElement.getAttribute('data-preview-theme');
  if (attr === 'blue' || attr === 'olive' || attr === 'violet') {
    return attr;
  }
  return 'amber';
}

export default function ThemedBanner({alt}: {alt?: string}): ReactNode {
  const [theme, setTheme] = useState<PreviewTheme>(readActiveTheme);

  const banners: Record<PreviewTheme, string> = {
    amber: useBaseUrl('/img/banners/banner-amber.webp'),
    blue: useBaseUrl('/img/banners/banner-blue.webp'),
    olive: useBaseUrl('/img/banners/banner-olive.webp'),
    violet: useBaseUrl('/img/banners/banner-violet.webp'),
  };

  useEffect(() => {
    setTheme(readActiveTheme());
    const observer = new MutationObserver(() => {
      setTheme(readActiveTheme());
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-preview-theme'],
    });
    return () => observer.disconnect();
  }, []);

  return (
    <img
      src={banners[theme]}
      alt={alt || 'Serpantinum Banner'}
      width={1920}
      height={845}
      decoding="async"
    />
  );
}
