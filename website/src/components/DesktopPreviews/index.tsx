import {
  useState,
  useEffect,
  useCallback,
  useRef,
  startTransition,
  type ReactNode,
  type KeyboardEvent as ReactKeyboardEvent,
  type MouseEvent as ReactMouseEvent,
  type TouchEvent as ReactTouchEvent,
  type WheelEvent as ReactWheelEvent,
} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import clsx from 'clsx';
import {useLazyPreviews} from '@site/src/hooks/useLazyPreviews';

import styles from './styles.module.css';

interface PreviewItem {
  id: number;
  src: string;
  srcSet: string;
  alt: string;
  theme: 'amber' | 'violet' | 'blue' | 'olive';
  label: string;
}

const PREVIEW_SIZES =
  '(max-width: 768px) calc(100vw - 1.5rem), (max-width: 1380px) calc(100vw - 12rem), 1200px';

export default function DesktopPreviews(): ReactNode {
  const preview4 = useBaseUrl('/img/previews/preview_4.webp');
  const preview4_1280 = useBaseUrl('/img/previews/preview_4-1280.webp');
  const preview4_800 = useBaseUrl('/img/previews/preview_4-800.webp');
  const preview3 = useBaseUrl('/img/previews/preview_3.webp');
  const preview3_1280 = useBaseUrl('/img/previews/preview_3-1280.webp');
  const preview3_800 = useBaseUrl('/img/previews/preview_3-800.webp');
  const preview1 = useBaseUrl('/img/previews/preview_1.webp');
  const preview1_1280 = useBaseUrl('/img/previews/preview_1-1280.webp');
  const preview1_800 = useBaseUrl('/img/previews/preview_1-800.webp');
  const preview2 = useBaseUrl('/img/previews/preview_2.webp');
  const preview2_1280 = useBaseUrl('/img/previews/preview_2-1280.webp');
  const preview2_800 = useBaseUrl('/img/previews/preview_2-800.webp');

  const previewItems: PreviewItem[] = [
    {
      id: 4,
      src: preview4_1280,
      srcSet: `${preview4_800} 800w, ${preview4_1280} 1280w, ${preview4} 1920w`,
      alt: 'Serpantinum Desktop Preview 4',
      theme: 'amber',
      label: 'Amber',
    },
    {
      id: 3,
      src: preview3_1280,
      srcSet: `${preview3_800} 800w, ${preview3_1280} 1280w, ${preview3} 1920w`,
      alt: 'Serpantinum Desktop Preview 3',
      theme: 'violet',
      label: 'Violet',
    },
    {
      id: 1,
      src: preview1_1280,
      srcSet: `${preview1_800} 800w, ${preview1_1280} 1280w, ${preview1} 1920w`,
      alt: 'Serpantinum Desktop Preview 1',
      theme: 'blue',
      label: 'Blue',
    },
    {
      id: 2,
      src: preview2_1280,
      srcSet: `${preview2_800} 800w, ${preview2_1280} 1280w, ${preview2} 1920w`,
      alt: 'Serpantinum Desktop Preview 2',
      theme: 'olive',
      label: 'Olive',
    },
  ];

  const [slideState, setSlideState] = useState<{current: number; prev: number | null}>(() => {
    if (typeof document !== 'undefined') {
      const activeAttr = document.documentElement.getAttribute('data-preview-theme');
      const idx = previewItems.findIndex((item) => item.theme === activeAttr);
      if (idx >= 0) {
        return {current: idx, prev: null};
      }
    }
    return {current: 0, prev: null};
  });
  const currentIndex = slideState.current;
  const prevIndex = slideState.prev;

  const [isDragging, setIsDragging] = useState(false);
  const {ref: sectionRef, shouldLoad, markLoaded} = useLazyPreviews<HTMLElement>(currentIndex);

  const isDraggingRef = useRef(false);
  const dragStartXRef = useRef(0);
  const dragDistanceRef = useRef(0);

  const touchStartXRef = useRef<number | null>(null);
  const touchStartYRef = useRef<number | null>(null);
  const lastWheelTimeRef = useRef(0);

  useEffect(() => {
    const activeTheme = previewItems[currentIndex]?.theme ?? 'amber';
    if (activeTheme === 'amber') {
      document.documentElement.removeAttribute('data-preview-theme');
    } else {
      document.documentElement.setAttribute('data-preview-theme', activeTheme);
    }
  }, [currentIndex]);

  const transitionTo = useCallback((nextIndex: number) => {
    startTransition(() => {
      setSlideState((curr) => {
        if (nextIndex === curr.current) return curr;
        return {current: nextIndex, prev: curr.current};
      });
    });
  }, []);

  const handleNext = useCallback(() => {
    startTransition(() => {
      setSlideState((curr) => ({
        current: (curr.current + 1) % previewItems.length,
        prev: curr.current,
      }));
    });
  }, [previewItems.length]);

  const handlePrev = useCallback(() => {
    startTransition(() => {
      setSlideState((curr) => ({
        current: curr.current === 0 ? previewItems.length - 1 : curr.current - 1,
        prev: curr.current,
      }));
    });
  }, [previewItems.length]);

  const goToSlide = useCallback(
    (index: number) => {
      transitionTo(index);
    },
    [transitionTo],
  );

  const handleKeyDown = (e: ReactKeyboardEvent<HTMLElement>) => {
    if (e.key === 'ArrowLeft') {
      e.preventDefault();
      handlePrev();
    } else if (e.key === 'ArrowRight') {
      e.preventDefault();
      handleNext();
    }
  };

  const handleMouseDown = (e: ReactMouseEvent<HTMLDivElement>) => {
    if (e.button !== 0) return;
    isDraggingRef.current = true;
    dragStartXRef.current = e.clientX;
    dragDistanceRef.current = 0;
    setIsDragging(true);
  };

  useEffect(() => {
    if (!isDragging) return;

    const handleMouseMove = (e: MouseEvent) => {
      if (!isDraggingRef.current) return;
      dragDistanceRef.current = e.clientX - dragStartXRef.current;
    };

    const handleMouseUp = () => {
      if (!isDraggingRef.current) return;
      isDraggingRef.current = false;
      setIsDragging(false);

      const distance = dragDistanceRef.current;
      dragDistanceRef.current = 0;

      if (distance < -50) {
        handleNext();
      } else if (distance > 50) {
        handlePrev();
      }
    };

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging, handleNext, handlePrev]);

  const handleTouchStart = (e: ReactTouchEvent<HTMLDivElement>) => {
    touchStartXRef.current = e.touches[0].clientX;
    touchStartYRef.current = e.touches[0].clientY;
  };

  const handleTouchEnd = (e: ReactTouchEvent<HTMLDivElement>) => {
    if (touchStartXRef.current === null) return;
    const endX = e.changedTouches[0].clientX;
    const endY = e.changedTouches[0].clientY;
    const dx = endX - touchStartXRef.current;
    const dy = endY - (touchStartYRef.current || endY);

    touchStartXRef.current = null;
    touchStartYRef.current = null;

    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 40) {
      if (dx < 0) {
        handleNext();
      } else {
        handlePrev();
      }
    }
  };

  const handleWheel = (e: ReactWheelEvent<HTMLDivElement>) => {
    if (Math.abs(e.deltaX) > 35 && Math.abs(e.deltaX) > Math.abs(e.deltaY)) {
      const now = Date.now();
      if (now - lastWheelTimeRef.current < 500) return;
      lastWheelTimeRef.current = now;
      if (e.deltaX > 0) {
        handleNext();
      } else {
        handlePrev();
      }
    }
  };

  return (
    <section
      ref={sectionRef}
      className={styles.previewSection}
      aria-roledescription="carousel"
      aria-label="Desktop showcases"
      tabIndex={0}
      onKeyDown={handleKeyDown}>
      <div className={styles.carouselContainer}>
        <button
          type="button"
          className={`${styles.navButton} ${styles.navButtonPrevVisible}`}
          onClick={handlePrev}
          aria-label="Previous preview">
          <svg
            className={`${styles.arrowIcon} ${styles.arrowIconPrevVisible}`}
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round">
            <polyline points="15 18 9 12 15 6" />
          </svg>
        </button>

        <div
          className={`${styles.viewport} ${isDragging ? styles.viewportDragging : ''}`}
          onMouseDown={handleMouseDown}
          onTouchStart={handleTouchStart}
          onTouchEnd={handleTouchEnd}
          onWheel={handleWheel}>
          <div className={styles.slidesStage} aria-live="off">
            {previewItems.map((item, index) => {
              const isActive = index === currentIndex;
              const isExiting = index === prevIndex;
              let slideClass = styles.slide;
              if (isActive) {
                slideClass = `${styles.slide} ${styles.slideActive}`;
              } else if (isExiting) {
                slideClass = `${styles.slide} ${styles.slideExiting}`;
              }

              return (
                <div
                  key={item.id}
                  className={slideClass}
                  role="group"
                  aria-roledescription="slide"
                  aria-label={`${index + 1} of ${previewItems.length}: ${item.label}`}
                  aria-hidden={!isActive}>
                  <img
                    src={shouldLoad(index) ? item.src : undefined}
                    srcSet={shouldLoad(index) ? item.srcSet : undefined}
                    sizes={PREVIEW_SIZES}
                    onLoad={markLoaded}
                    width={1920}
                    height={1080}
                    fetchPriority={isActive ? 'high' : 'low'}
                    decoding={isActive ? 'sync' : 'async'}
                    loading={isActive ? 'eager' : 'lazy'}
                    alt={item.alt}
                    className={styles.previewImage}
                    draggable={false}
                  />
                </div>
              );
            })}
          </div>
        </div>

        <button
          type="button"
          className={`${styles.navButton} ${styles.navButtonNextVisible}`}
          onClick={handleNext}
          aria-label="Next preview">
          <svg
            className={`${styles.arrowIcon} ${styles.arrowIconNextVisible}`}
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round">
            <polyline points="9 18 15 12 9 6" />
          </svg>
        </button>
      </div>

      <div
        className={styles.paletteSwitcher}
        role="tablist"
        aria-label="Switch desktop theme preview">
        {previewItems.map((item, index) => {
          const isSelected = index === currentIndex;
          return (
            <button
              key={item.id}
              type="button"
              role="tab"
              aria-selected={isSelected}
              className={clsx(
                styles.paletteTab,
                isSelected && styles.paletteTabActive,
              )}
              onClick={() => goToSlide(index)}>
              {item.label}
            </button>
          );
        })}
      </div>
    </section>
  );
}
