import React, {
  startTransition,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import {useThemeConfig} from '@docusaurus/theme-common';
import {
  CodeBlockContextProvider,
  createCodeBlockMetadata,
} from '@docusaurus/theme-common/internal';
import CodeBlockLayout from '@theme/CodeBlock/Layout';
import type {Props} from '@theme/CodeBlock/Content/String';

function useDeferredCodeWordWrap() {
  const [isEnabled, setIsEnabled] = useState(false);
  const [isCodeScrollable, setIsCodeScrollable] = useState(false);
  const codeBlockRef = useRef<HTMLPreElement>(null);

  const toggle = useCallback(() => {
    const pre = codeBlockRef.current;
    const codeElement = pre?.querySelector('code');
    if (!codeElement) return;
    if (isEnabled) {
      codeElement.removeAttribute('style');
    } else {
      codeElement.style.whiteSpace = 'pre-wrap';
      codeElement.style.overflowWrap = 'anywhere';
    }
    setIsEnabled((value) => !value);
  }, [isEnabled]);

  useEffect(() => {
    const pre = codeBlockRef.current;
    if (!pre) return;

    const measure = () => {
      const code = pre.querySelector('code');
      const scrollable =
        pre.scrollWidth > pre.clientWidth || Boolean(code?.hasAttribute('style'));
      startTransition(() => {
        setIsCodeScrollable((prev) => (prev === scrollable ? prev : scrollable));
      });
    };

    if (typeof ResizeObserver !== 'undefined') {
      const observer = new ResizeObserver(measure);
      observer.observe(pre);
      return () => observer.disconnect();
    }

    const frameId = requestAnimationFrame(measure);
    window.addEventListener('resize', measure, {passive: true});
    return () => {
      cancelAnimationFrame(frameId);
      window.removeEventListener('resize', measure);
    };
  }, [isEnabled]);

  return useMemo(
    () => ({codeBlockRef, isEnabled, isCodeScrollable, toggle}),
    [isEnabled, isCodeScrollable, toggle],
  );
}

export default function CodeBlockString(props: Props): ReactNode {
  const {prism} = useThemeConfig();
  const metadata = useMemo(
    () =>
      createCodeBlockMetadata({
        code: props.children,
        className: props.className,
        metastring: props.metastring,
        magicComments: prism.magicComments,
        defaultLanguage: prism.defaultLanguage,
        language: props.language,
        title: props.title,
        showLineNumbers: props.showLineNumbers,
      }),
    [
      props.children,
      props.className,
      props.metastring,
      props.language,
      props.title,
      props.showLineNumbers,
      prism.magicComments,
      prism.defaultLanguage,
    ],
  );
  const wordWrap = useDeferredCodeWordWrap();
  return (
    <CodeBlockContextProvider metadata={metadata} wordWrap={wordWrap}>
      <CodeBlockLayout />
    </CodeBlockContextProvider>
  );
}
