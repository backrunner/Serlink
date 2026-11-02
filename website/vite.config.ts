import tailwindcss from '@tailwindcss/vite';
import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';
import { svedocs } from 'svedocs/vite';
import { svedocsPreprocess, svedocsSvelteExtensions } from 'svedocs/svelte';
import config from './svedocs.config.ts';
export default defineConfig({ plugins: [
  svedocs({ config, components: { SupportForm: '#lib/SupportForm.svelte' }, theme: { components: {
    Navbar: '#lib/theme/Navbar.svelte', Footer: '#lib/theme/Footer.svelte',
    Article: '#lib/theme/Article.svelte', PageShell: '#lib/theme/PageShell.svelte',
    Sidebar: '#lib/theme/Sidebar.svelte', ThemeToggle: '#lib/theme/ThemeToggle.svelte'
  } } }), tailwindcss(), sveltekit({
    extensions: [...svedocsSvelteExtensions],
    preprocess: [vitePreprocess(), svedocsPreprocess()],
    adapter: adapter({ strict: true, fallback: '404.html' })
  })
] });
