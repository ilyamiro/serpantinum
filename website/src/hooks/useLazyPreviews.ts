import {useCallback, useEffect, useRef, useState} from 'react';

const ROOT_MARGIN = '800px 0px';

export function useLazyPreviews<T extends HTMLElement>(activeIndex: number) {
  const ref = useRef<T | null>(null);
  const [isNear, setIsNear] = useState(false);
  const [isWarm, setIsWarm] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (typeof IntersectionObserver === 'undefined') {
      setIsNear(true);
      return;
    }
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setIsNear(true);
          observer.disconnect();
        }
      },
      {rootMargin: ROOT_MARGIN},
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const shouldLoad = useCallback(
    (index: number) => isNear && (isWarm || index === activeIndex),
    [isNear, isWarm, activeIndex],
  );

  const markLoaded = useCallback(() => setIsWarm(true), []);

  return {ref, shouldLoad, markLoaded};
}
