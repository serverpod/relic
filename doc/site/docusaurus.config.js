// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

import { themes } from 'prism-react-renderer';
const lightCodeTheme = themes.github;
const darkCodeTheme = themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Relic',
  tagline: 'Strictly typed HTTP server with incredible performance.',
  url: 'https://docs.dartrelic.dev',
  baseUrl: '/',
  onBrokenLinks: 'throw',
  favicon: 'img/favicon.png',
  organizationName: 'serverpod', // Usually your GitHub org/user name.
  projectName: 'relic', // Usually your repo name.
  trailingSlash: false,
  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },
  themes: [
    '@docusaurus/theme-mermaid',
    'docusaurus-theme-github-codeblock'
  ],
  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          // Please change this to your repo.
          editUrl:
            'https://github.com/serverpod/relic/tree/main/doc/site/',
          breadcrumbs: false,
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
        gtag: {
          trackingID: 'G-0EYLJMP04H',
          anonymizeIP: true,
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        respectPrefersColorScheme: true,
        disableSwitch: false,
      },
      navbar: {
        // title: 'My Site',
        logo: {
          alt: 'Serverpod Logo',
          src: 'img/logo-horizontal.svg',
          srcDark: 'img/logo-horizontal-dark.svg',
          href: 'https://serverpod.dev',
        },
        items: [
          {
            type: 'docsVersionDropdown',
            position: 'left',
          },
          {
            href: 'https://pub.dev/documentation/relic/latest/relic/',
            label: 'API Reference',
            position: 'right',
          },
          {
            href: 'https://careers.serverpod.dev/',
            label: 'Career',
            position: 'right',
          },
          {
            href: 'https://twitter.com/ServerpodDev',
            label: 'Twitter',
            position: 'right',
          },
          {
            href: 'https://github.com/serverpod/serverpod',
            label: 'GitHub',
            position: 'right',
          },
          {
            type: 'search',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        copyright: `Copyright © ${new Date().getFullYear()} Serverpod authors.`,
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['dart', 'bash'],
      },
    }),
  plugins: [
    [
      '@docusaurus/plugin-client-redirects',
      {
        redirects: [],
      },
    ],
  ],
};

module.exports = config;