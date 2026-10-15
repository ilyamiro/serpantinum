import {
  useState,
  useRef,
  useCallback,
  useEffect,
  type ReactNode,
  type MouseEvent as ReactMouseEvent,
  type TouchEvent as ReactTouchEvent,
  type WheelEvent as ReactWheelEvent,
} from 'react';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import {useHistory} from '@docusaurus/router';
import {useLazyPreviews} from '@site/src/hooks/useLazyPreviews';
import FluidBackground from '@site/src/components/FluidBackground';

import styles from './styles.module.css';

interface StepCard {
  title: string;
  image: string;
  buttonText: string;
  buttonLink: string;
}

const SLIDE_DURATION_MS = 5000;

const STEPS: StepCard[] = [
  {
    title: 'Install',
    image: '/img/previews/steps/install_preview.webp',
    buttonText: 'Install',
    buttonLink: '/installation',
  },
  {
    title: 'Configure',
    image: '/img/previews/steps/configure_preview.webp',
    buttonText: 'Configure',
    buttonLink: '/configure',
  },
  {
    title: 'Enjoy!',
    image: '/img/previews/steps/enjoy_preview.webp',
    buttonText: 'Enjoy!',
    buttonLink: '/',
  },
];

export default function GettingStarted(): ReactNode {
  const history = useHistory();
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const {ref: carouselRef, shouldLoad, markLoaded} = useLazyPreviews<HTMLDivElement>(currentIndex);

  const stepUrls = [
    useBaseUrl('/installation'),
    useBaseUrl('/configure'),
    useBaseUrl('/'),
  ];

  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const dragStartXRef = useRef(0);
  const dragDeltaRef = useRef(0);
  const touchStartXRef = useRef<number | null>(null);
  const touchStartYRef = useRef<number | null>(null);
  const touchDeltaRef = useRef(0);
  const lastWheelTimeRef = useRef(0);

  const handleNext = useCallback(() => {
    setCurrentIndex((curr) => (curr + 1) % STEPS.length);
  }, []);

  const handlePrev = useCallback(() => {
    setCurrentIndex((curr) => (curr === 0 ? STEPS.length - 1 : curr - 1));
  }, []);

  const resetTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }
    timerRef.current = setInterval(() => {
      handleNext();
    }, SLIDE_DURATION_MS);
  }, [handleNext]);

  const handleManualNext = useCallback(() => {
    handleNext();
    resetTimer();
  }, [handleNext, resetTimer]);

  const handleManualPrev = useCallback(() => {
    handlePrev();
    resetTimer();
  }, [handlePrev, resetTimer]);

  const goTo = useCallback(
    (index: number) => {
      setCurrentIndex(index);
      resetTimer();
    },
    [resetTimer],
  );

  const openCurrentStep = useCallback(() => {
    history.push(stepUrls[currentIndex]);
  }, [currentIndex, history, stepUrls]);

  useEffect(() => {
    resetTimer();
    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, [resetTimer]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return;
      }
      if (e.key === 'ArrowLeft') {
        e.preventDefault();
        handleManualPrev();
      } else if (e.key === 'ArrowRight') {
        e.preventDefault();
        handleManualNext();
      } else if (e.key === 'Enter') {
        e.preventDefault();
        openCurrentStep();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [handleManualNext, handleManualPrev, openCurrentStep]);

  const handleMouseEnter = () => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }
  };

  const handleMouseLeave = () => {
    resetTimer();
  };

  const handleMouseDown = (e: ReactMouseEvent) => {
    setIsDragging(true);
    dragStartXRef.current = e.clientX;
    dragDeltaRef.current = 0;
  };

  useEffect(() => {
    const handleWindowMouseMove = (e: MouseEvent) => {
      if (!dragStartXRef.current) return;
      dragDeltaRef.current = e.clientX - dragStartXRef.current;
    };

    const handleWindowMouseUp = () => {
      if (!dragStartXRef.current) return;
      if (Math.abs(dragDeltaRef.current) > 40) {
        if (dragDeltaRef.current < 0) {
          handleManualNext();
        } else {
          handleManualPrev();
        }
      }
      dragStartXRef.current = 0;
      dragDeltaRef.current = 0;
      setIsDragging(false);
    };

    window.addEventListener('mousemove', handleWindowMouseMove);
    window.addEventListener('mouseup', handleWindowMouseUp);
    return () => {
      window.removeEventListener('mousemove', handleWindowMouseMove);
      window.removeEventListener('mouseup', handleWindowMouseUp);
    };
  }, [handleManualNext, handleManualPrev]);

  const handleTouchStart = (e: ReactTouchEvent) => {
    touchStartXRef.current = e.touches[0].clientX;
    touchStartYRef.current = e.touches[0].clientY;
  };

  const handleTouchEnd = (e: ReactTouchEvent) => {
    if (touchStartXRef.current === null || touchStartYRef.current === null) return;
    const endX = e.changedTouches[0].clientX;
    const endY = e.changedTouches[0].clientY;
    const dx = endX - touchStartXRef.current;
    const dy = endY - touchStartYRef.current;
    touchStartXRef.current = null;
    touchStartYRef.current = null;

    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 40) {
      if (dx < 0) {
        handleManualNext();
      } else {
        handleManualPrev();
      }
    }
  };

  const handleWheel = (e: ReactWheelEvent) => {
    if (Math.abs(e.deltaX) > 40 && Math.abs(e.deltaX) > Math.abs(e.deltaY) * 1.5) {
      const now = Date.now();
      if (now - lastWheelTimeRef.current < 650) return;
      lastWheelTimeRef.current = now;
      if (e.deltaX > 0) {
        handleManualNext();
      } else {
        handleManualPrev();
      }
    }
  };

  return (
    <Layout
      title="Getting started"
      description="Getting started with the Serpantinum desktop shell">
      <div className={styles.pageWrapper}>
        <FluidBackground />
        <div className={styles.headerSection}>
          <Heading as="h1" className={styles.title}>
            Getting started
          </Heading>
          <div className={styles.buttonRow}>
            <Link to="/overview" className={styles.surfaceButton}>
              Documentation
            </Link>
            <Link
              href="https://github.com/ilyamiro/serpantinum/issues"
              target="_blank"
              rel="noopener noreferrer"
              className={styles.surfaceButton}>
              Report an issue
              <svg
                className={styles.arrowIcon}
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true">
                <line x1="7" y1="17" x2="17" y2="7" />
                <polyline points="7 7 17 7 17 17" />
              </svg>
            </Link>
          </div>
        </div>

        <div
          ref={carouselRef}
          className={styles.carouselContainer}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}>
          <button
            type="button"
            className={styles.navButton}
            onClick={handleManualPrev}
            aria-label="Previous preview">
            <svg
              className={styles.navArrowIcon}
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
            className={`${styles.stage3D} ${isDragging ? styles.stage3DDragging : ''}`}
            onMouseDown={handleMouseDown}
            onTouchStart={handleTouchStart}
            onTouchEnd={handleTouchEnd}
            onWheel={handleWheel}>
            {STEPS.map((step, index) => {
              const previewUrl = useBaseUrl(step.image);
              let diff = index - currentIndex;
              if (diff > 1) diff -= STEPS.length;
              if (diff < -1) diff += STEPS.length;

              let cardClass = styles.cardCenter;
              if (diff === -1) {
                cardClass = styles.cardLeft;
              } else if (diff === 1) {
                cardClass = styles.cardRight;
              }

              const isForemost = diff === 0;

              return (
                <div
                  key={step.title}
                  className={`${styles.card3D} ${cardClass}`}
                  role={isForemost ? 'button' : undefined}
                  tabIndex={isForemost ? 0 : -1}
                  onKeyDown={(e) => {
                    if (isForemost && e.key === 'Enter') {
                      openCurrentStep();
                    }
                  }}
                  onClick={() => {
                    if (!isForemost) {
                      goTo(index);
                    } else {
                      openCurrentStep();
                    }
                  }}>
                  <div className={styles.imageWrapper}>
                    <img
                      src={shouldLoad(index) ? previewUrl : undefined}
                      onLoad={markLoaded}
                      decoding="async"
                      alt={step.title}
                      className={styles.cardImage}
                      draggable={false}
                    />
                  </div>
                  <div className={styles.cardBody}>
                    <Link
                      to={step.buttonLink}
                      className={styles.cardButton}
                      onClick={(e) => e.stopPropagation()}
                      tabIndex={isForemost ? 0 : -1}>
                      {step.buttonText}
                    </Link>
                  </div>
                </div>
              );
            })}
          </div>

          <button
            type="button"
            className={styles.navButton}
            onClick={handleManualNext}
            aria-label="Next preview">
            <svg
              className={styles.navArrowIcon}
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

        <div className={styles.indicators}>
          {STEPS.map((step, index) => (
            <button
              key={step.title}
              type="button"
              className={`${styles.dot} ${
                index === currentIndex ? styles.dotActive : ''
              }`}
              onClick={() => goTo(index)}
              aria-label={`Go to ${step.title}`}
            />
          ))}
        </div>
      </div>
    </Layout>
  );
}
