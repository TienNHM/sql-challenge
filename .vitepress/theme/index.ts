import type { Theme } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import HeroQuery from './HeroQuery.vue'
import HomeContent from './HomeContent.vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout: () => h(DefaultTheme.Layout, null, { 'home-hero-image': () => h(HeroQuery) }),
  enhanceApp({ app }) {
    app.component('HomeContent', HomeContent)
  },
} satisfies Theme
