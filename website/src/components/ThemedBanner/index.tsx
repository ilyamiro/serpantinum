import {startTransition, useEffect, useState, type ReactNode} from 'react';
import Head from '@docusaurus/Head';
import useBaseUrl from '@docusaurus/useBaseUrl';

type PreviewTheme = 'amber' | 'blue' | 'olive' | 'violet';

const BANNER_SIZES = '(max-width: 996px) calc(100vw - 2rem), 860px';

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

  const banners: Record<PreviewTheme, {src: string; srcSet: string}> = {
    amber: {
      src: useBaseUrl('/img/banners/banner-amber-960.webp'),
      srcSet: `${useBaseUrl('/img/banners/banner-amber-960.webp')} 960w, ${useBaseUrl('/img/banners/banner-amber.webp')} 1920w`,
    },
    blue: {
      src: useBaseUrl('/img/banners/banner-blue-960.webp'),
      srcSet: `${useBaseUrl('/img/banners/banner-blue-960.webp')} 960w, ${useBaseUrl('/img/banners/banner-blue.webp')} 1920w`,
    },
    olive: {
      src: useBaseUrl('/img/banners/banner-olive-960.webp'),
      srcSet: `${useBaseUrl('/img/banners/banner-olive-960.webp')} 960w, ${useBaseUrl('/img/banners/banner-olive.webp')} 1920w`,
    },
    violet: {
      src: useBaseUrl('/img/banners/banner-violet-960.webp'),
      srcSet: `${useBaseUrl('/img/banners/banner-violet-960.webp')} 960w, ${useBaseUrl('/img/banners/banner-violet.webp')} 1920w`,
    },
  };

  useEffect(() => {
    setTheme(readActiveTheme());
    const observer = new MutationObserver(() => {
      startTransition(() => {
        setTheme(readActiveTheme());
      });
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-preview-theme'],
    });
    return () => observer.disconnect();
  }, []);

  const current = banners[theme];

  return (
    <>
      <Head>
        <link
          rel="preload"
          href={banners.amber.src}
          imageSrcSet={banners.amber.srcSet}
          imageSizes={BANNER_SIZES}
          as="image"
          type="image/webp"
          fetchPriority="high"
        />
      </Head>
      <img
        src={current.src}
        srcSet={current.srcSet}
        sizes={BANNER_SIZES}
        alt={alt || 'Serpantinum Banner'}
        width={1920}
        height={845}
        fetchPriority="high"
        loading="eager"
        decoding="sync"
      />
    </>
  );
}
