import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'Overview',
    'installation/installation',
    {
      type: 'category',
      label: 'NixOS',
      collapsible: false,
      items: [
        'installation/nixos/flake',
        'installation/nixos/home-manager',
      ],
    },
    {
      type: 'category',
      label: 'Configure',
      collapsible: false,
      items: [
        'configure/Configure',
        {
          type: 'category',
          label: 'Compositors',
          collapsible: false,
          items: [
            'configure/compositors/hyprland',
            'configure/compositors/niri',
            'configure/compositors/sway',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'CLI',
      collapsible: false,
      items: [
        'cli/client',
        'cli/daemon',
      ],
    },
  ],
};

export default sidebars;
