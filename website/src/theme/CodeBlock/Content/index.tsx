import React, {
  startTransition,
  useDeferredValue,
  useEffect,
  useState,
  type ComponentProps,
  type ReactNode,
} from 'react';
import clsx from 'clsx';
import {useCodeBlockContext} from '@docusaurus/theme-common/internal';
import {usePrismTheme} from '@docusaurus/theme-common';
import {Highlight} from 'prism-react-renderer';
import Line from '@theme/CodeBlock/Line';
import type {Props} from '@theme/CodeBlock/Content';
import styles from './styles.module.css';

const Pre = React.forwardRef<HTMLPreElement, ComponentProps<'pre'>>(
  (props, ref) => (
    <pre
      ref={ref}
      tabIndex={0}
      {...props}
      className={clsx(props.className, styles.codeBlock, 'thin-scrollbar')}
    />
  ),
);

function Code(props: ComponentProps<'code'>) {
  const {metadata} = useCodeBlockContext();
  return (
    <code
      {...props}
      className={clsx(
        props.className,
        styles.codeBlockLines,
        metadata.lineNumbersStart !== undefined &&
          styles.codeBlockLinesWithNumbering,
      )}
      style={{
        ...props.style,
        counterReset:
          metadata.lineNumbersStart === undefined
            ? undefined
            : `line-count ${metadata.lineNumbersStart - 1}`,
      }}
    />
  );
}

function shouldDeferInitialHighlight(): boolean {
  if (typeof document === 'undefined') return false;
  return document.documentElement.getAttribute('data-has-hydrated') === 'true';
}

function CodeBlockContent({className: classNameProp}: Props): ReactNode {
  const {metadata, wordWrap} = useCodeBlockContext();
  const prismTheme = useDeferredValue(usePrismTheme());
  const {code, language, lineNumbersStart, lineClassNames} = metadata;
  const [highlighted, setHighlighted] = useState(
    () => !shouldDeferInitialHighlight(),
  );

  useEffect(() => {
    if (highlighted) return;
    const pre = wordWrap.codeBlockRef.current;
    if (!pre || typeof IntersectionObserver === 'undefined') {
      startTransition(() => setHighlighted(true));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          observer.disconnect();
          startTransition(() => setHighlighted(true));
        }
      },
      {rootMargin: '400px 0px'},
    );
    observer.observe(pre);
    return () => observer.disconnect();
  }, [highlighted, wordWrap.codeBlockRef]);

  if (!highlighted) {
    const plainLines = code.split('\n');
    return (
      <Pre
        ref={wordWrap.codeBlockRef}
        className={clsx(classNameProp, 'prism-code', `language-${language}`)}>
        <Code>
          {plainLines.map((line, i) => (
            <div key={i} className={clsx('token-line', lineClassNames[i])}>
              {line}
              <br />
            </div>
          ))}
        </Code>
      </Pre>
    );
  }

  return (
    <Highlight theme={prismTheme} code={code} language={language}>
      {({className, style, tokens: lines, getLineProps, getTokenProps}) => (
        <Pre
          ref={wordWrap.codeBlockRef}
          className={clsx(classNameProp, className)}
          style={style}>
          <Code>
            {lines.map((line, i) => (
              <Line
                key={i}
                line={line}
                getLineProps={getLineProps}
                getTokenProps={getTokenProps}
                classNames={lineClassNames[i]}
                showLineNumbers={lineNumbersStart !== undefined}
              />
            ))}
          </Code>
        </Pre>
      )}
    </Highlight>
  );
}

export default React.memo(CodeBlockContent);
