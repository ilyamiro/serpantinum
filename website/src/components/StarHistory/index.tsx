import {useState, useEffect, useRef, type ReactNode} from 'react';
import Heading from '@theme/Heading';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

interface TimelinePoint {
  label: string;
  date: string;
  stars: number;
}

const INITIAL_POINTS: TimelinePoint[] = [
  {label: 'Mid Apr', date: 'Apr 15', stars: 280},
  {label: 'Late Apr', date: 'Apr 30', stars: 420},
  {label: 'Early May', date: 'May 10', stars: 750},
  {label: 'Mid May', date: 'May 20', stars: 1180},
  {label: 'Late May', date: 'May 31', stars: 1690},
  {label: 'Early Jun', date: 'Jun 10', stars: 2150},
  {label: 'Mid Jun', date: 'Jun 20', stars: 2620},
  {label: 'Late Jun', date: 'Jun 30', stars: 3120},
  {label: 'Early Jul', date: 'Jul 10', stars: 3680},
  {label: 'Mid Jul', date: 'Jul 20', stars: 4250},
  {label: 'Late Jul', date: 'Jul 31', stars: 4810},
  {label: 'Early Aug', date: 'Aug 10', stars: 5290},
  {label: 'Mid Aug', date: 'Aug 20', stars: 5740},
  {label: 'Late Aug', date: 'Aug 30', stars: 6150},
  {label: 'Early Sep', date: 'Sep 10', stars: 6510},
  {label: 'Mid Sep', date: 'Sep 20', stars: 6830},
  {label: 'Late Sep', date: 'Sep 30', stars: 7080},
  {label: 'Early Oct', date: 'Oct 08', stars: 7210},
  {label: 'Current', date: 'Oct 12', stars: 7289},
];

const MONTH_LABELS = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'];

function useCountUp(target: number, trigger: boolean, duration: number = 1400): number {
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (!trigger) return;
    let startTimestamp: number | null = null;
    let animFrame: number;

    const step = (timestamp: number) => {
      if (!startTimestamp) startTimestamp = timestamp;
      const progress = Math.min((timestamp - startTimestamp) / duration, 1);
      const ease = progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);
      setCount(Math.round(target * ease));
      if (progress < 1) {
        animFrame = requestAnimationFrame(step);
      }
    };

    animFrame = requestAnimationFrame(step);
    return () => cancelAnimationFrame(animFrame);
  }, [target, trigger, duration]);

  return count;
}

export default function StarHistory(): ReactNode {
  const sectionRef = useRef<HTMLElement | null>(null);
  const [points, setPoints] = useState<TimelinePoint[]>(INITIAL_POINTS);
  const [totalStars, setTotalStars] = useState<number>(7289);
  const [totalCommits] = useState<number>(596);
  const [mergedPRs, setMergedPRs] = useState<number>(65);
  const [unmergedPRs, setUnmergedPRs] = useState<number>(60);
  const [totalForks, setTotalForks] = useState<number>(312);
  const [hasScrolledIntoView, setHasScrolledIntoView] = useState<boolean>(false);

  useEffect(() => {
    const el = sectionRef.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setHasScrolledIntoView(true);
        }
      },
      {threshold: 0.2},
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    fetch('https://api.github.com/repos/ilyamiro/serpantinum')
      .then((res) => (res.ok ? res.json() : Promise.reject()))
      .then((json) => {
        if (typeof json.stargazers_count === 'number') {
          setTotalStars(json.stargazers_count);
          setPoints((prev) =>
            prev.map((item, index) =>
              index === prev.length - 1
                ? {...item, stars: json.stargazers_count}
                : item,
            ),
          );
        }
        if (typeof json.forks_count === 'number') {
          setTotalForks(json.forks_count);
        }
      })
      .catch(() => {});

    fetch(
      'https://api.github.com/search/issues?q=repo:ilyamiro/serpantinum+type:pr+is:merged',
    )
      .then((res) => (res.ok ? res.json() : Promise.reject()))
      .then((json) => {
        if (typeof json.total_count === 'number') {
          setMergedPRs(json.total_count);
        }
      })
      .catch(() => {});

    fetch(
      'https://api.github.com/search/issues?q=repo:ilyamiro/serpantinum+type:pr+is:unmerged',
    )
      .then((res) => (res.ok ? res.json() : Promise.reject()))
      .then((json) => {
        if (typeof json.total_count === 'number') {
          setUnmergedPRs(json.total_count);
        }
      })
      .catch(() => {});
  }, []);

  const totalPRs = mergedPRs + unmergedPRs;

  const displayStars = useCountUp(totalStars, hasScrolledIntoView);
  const displayCommits = useCountUp(totalCommits, hasScrolledIntoView);
  const displayPRs = useCountUp(totalPRs, hasScrolledIntoView);
  const displayForks = useCountUp(totalForks, hasScrolledIntoView);

  const maxStars = Math.max(8000, Math.ceil(totalStars / 1000) * 1000);
  const yTicks = [
    `${Math.round(maxStars / 1000)}k`,
    `${Math.round((maxStars * 0.75) / 1000)}k`,
    `${Math.round((maxStars * 0.5) / 1000)}k`,
    `${Math.round((maxStars * 0.25) / 1000)}k`,
    '0',
  ];

  return (
    <section
      ref={sectionRef}
      className={styles.starSection}
      aria-label="GitHub Star History">
      <div className={styles.header}>
        <Heading as="h2" className={styles.title}>
          ilyamiro/serpantinum stars
        </Heading>
        <p className={styles.subtitle}>
          The growing community of{' '}
          <span className={styles.serpantinumGlow}>Serpantinum</span>
        </p>
      </div>

      <div className={styles.chartCard}>
        <div className={styles.metaRow}>
          <div className={styles.statGroup}>
            <div className={styles.statItem}>
              <span className={styles.statValue}>
                {displayStars.toLocaleString()}
              </span>
              <span className={styles.statLabel}>GitHub Stars</span>
            </div>
            <div className={styles.statItem}>
              <span className={styles.statValue}>
                {displayCommits.toLocaleString()}
              </span>
              <span className={styles.statLabel}>Commits</span>
            </div>
            <div className={styles.statItem}>
              <span className={styles.statValue}>
                {displayPRs.toLocaleString()}
              </span>
              <span className={styles.statLabel}>Pull Requests</span>
            </div>
            <div className={styles.statItem}>
              <span className={styles.statValue}>
                {displayForks.toLocaleString()}
              </span>
              <span className={styles.statLabel}>Forks</span>
            </div>
          </div>

          <Link
            className={styles.githubButton}
            href="https://github.com/ilyamiro/serpantinum/stargazers">
            <svg
              className={styles.starIcon}
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="currentColor">
              <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />
            </svg>
            <span>Star on GitHub</span>
          </Link>
        </div>

        <div className={styles.chartContainer}>
          <div className={styles.yAxis}>
            {yTicks.map((tick, i) => (
              <span key={i} className={styles.yLabel}>
                {tick}
              </span>
            ))}
          </div>

          <div className={styles.plotArea}>
            <div className={styles.gridLines}>
              <div className={styles.gridLine} />
              <div className={styles.gridLine} />
              <div className={styles.gridLine} />
              <div className={styles.gridLine} />
              <div className={styles.gridLine} />
            </div>

            <div className={styles.barsTrack}>
              {points.map((item, index) => {
                const heightPercent = Math.min(
                  100,
                  Math.max(3, (item.stars / maxStars) * 100),
                );
                return (
                  <div key={index} className={styles.barCol}>
                    <div
                      className={styles.barPillar}
                      style={{height: `${heightPercent}%`}}>
                      <div className={styles.tooltip}>
                        {item.stars.toLocaleString()} stars ({item.date}, 2026)
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          <div className={styles.xAxis}>
            {MONTH_LABELS.map((month, index) => (
              <span key={index} className={styles.xLabel}>
                {month}
              </span>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
