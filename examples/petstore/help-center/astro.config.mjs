import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
export default defineConfig({
  integrations: [starlight({
    title: 'Petstore Help Center',
    customCss: ['./src/styles/custom.css'],
    sidebar: [{ label: 'Start here', link: '/' }, { label: 'Marketplace / Listings', autogenerate: { directory: 'generated' } }],
  })],
});
