import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const CF_BEACON_TOKEN = 'c2690c3444a34bc4aed5966aa3778e88';

const config: Config = {
  title: 'Serpantinum',
  tagline: 'A wayland shell built for you',
  favicon: 'favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://serpantinum.dev',
  baseUrl: '/',

  organizationName: 'ilyamiro',
  projectName: 'serpantinum',

  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  scripts: [
    {
      src: 'https://static.cloudflareinsights.com/beacon.min.js',
      type: 'module',
      'data-cf-beacon': JSON.stringify({token: CF_BEACON_TOKEN, spa: true}),
    },
  ],

  headTags: [
    {
      tagName: 'link',
      attributes: {rel: 'icon', href: '/favicon-48.png', type: 'image/png', sizes: '48x48'},
    },
    {
      tagName: 'link',
      attributes: {rel: 'icon', href: '/favicon-192.png', type: 'image/png', sizes: '192x192'},
    },
    {
      tagName: 'link',
      attributes: {rel: 'apple-touch-icon', href: '/apple-touch-icon.png'},
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'preload',
        href: '/img/logo-dark.svg',
        as: 'image',
        type: 'image/svg+xml',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'preload',
        href: '/img/logo-light.svg',
        as: 'image',
        type: 'image/svg+xml',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'preload',
        href: '/img/logo.svg',
        as: 'image',
        type: 'image/svg+xml',
      },
    },
  ],

  themes: [
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        docsRouteBasePath: '/',
        docsDir: '../docs',
        indexBlog: false,
        searchBarShortcutHint: false,
        highlightSearchTermsOnTargetPage: true,
        explicitSearchResultPath: true,
      },
    ],
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: '/',
          path: '../docs',
          editUrl: 'https://github.com/ilyamiro/serpantinum/edit/master/docs/',
        },
        blog: false,
        theme: {
          customCss: ['./src/css/custom.css', './src/css/docs.css'],
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/social-card.jpg',
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'Serpantinum',
      logo: {
        alt: 'Serpantinum Logo',
        src: 'img/logo-light.svg',
        srcDark: 'img/logo-dark.svg',
        width: 32,
        height: 32,
      },
      items: [
        {
          to: '/overview',
          label: 'Documentation',
          position: 'left',
        },
        {
          href: 'https://github.com/ilyamiro/serpantinum/blob/master/CHANGELOG.md',
          label: 'Changelog',
          position: 'left',
          className: 'navbar-changelog-link',
        },
        {
          type: 'search',
          position: 'right',
        },
        {
          href: 'https://github.com/ilyamiro/serpantinum',
          label: 'GitHub',
          position: 'right',
          className: 'navbar-github-link',
          'aria-label': 'GitHub repository',
        },
        {
          href: 'https://ko-fi.com/ilyamiro',
          label: 'Support',
          position: 'right',
          className: 'navbar-kofi-link',
          'aria-label': 'Support the creator on Ko-fi',
        },
      ],
    },
    footer: {
      style: 'dark',
      logo: {
        alt: 'Serpantinum Logo',
        src: 'img/logo-light.svg',
        srcDark: 'img/logo-dark.svg',
        width: 44,
        height: 44,
      },
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Overview',
              to: '/overview',
            },
            {
              label: 'Installation',
              to: '/installation',
            },
            {
              label: 'Variables',
              to: '/configure',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Telegram',
              href: 'https://t.me/serpantinum_git',
            },
            {
              label: 'Support on Ko-fi',
              href: 'https://ko-fi.com/ilyamiro',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/ilyamiro/serpantinum',
            },
          ],
        },
        {
          title: 'Creator',
          items: [
            {
              label: 'X (Twitter)',
              href: 'https://x.com/ilyamirox',
            },
            {
              label: 'Reddit',
              href: 'https://reddit.com/user/ilyamiro1',
            },
            {
              label: 'YouTube',
              href: 'https://youtube.com/@ilyamiro21',
            },
            {
              label: 'TikTok',
              href: 'https://tiktok.com/@ilyamiro.dev',
            },
          ],
        },
      ],
      copyright: `A desktop shell built for YOU. Copyright © ${new Date().getFullYear()} Serpantinum.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
