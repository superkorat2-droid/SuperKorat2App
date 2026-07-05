<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { iconPath, isIconKey } from '../composables/useIcons.js'

const route   = useRoute()
const router  = useRouter()
const page    = ref(null)
const loading = ref(true)

// ── Embed URL transform ───────────────────────────────────────────
function toEmbedUrl(url, type) {
  if (!url) return url
  switch (type) {
    case 'youtube': {
      const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&?/]+)/)
      return m ? `https://www.youtube.com/embed/${m[1]}?rel=0` : url
    }
    case 'drive':  return url.replace(/\/view.*$/, '/preview')
    case 'slides': return url.replace(/\/(edit|view|preview).*$/, '/embed?start=false&loop=false')
    case 'canva': {
      const base = url.split('?')[0]
      return (base.endsWith('/view') ? base : base + '/view') + '?embed'
    }
    default: return url
  }
}

async function load(slug) {
  loading.value = true
  page.value    = null
  const { data } = await supabase
    .from('pages')
    .select('*')
    .eq('slug', slug)
    .eq('is_published', true)
    .single()
  if (!data) { router.push('/'); return }
  page.value    = data
  loading.value = false
}

// ── HTML block auto-height ────────────────────────────────────────
const iframeHeights = ref({})

function htmlWithHeightScript(html, id) {
  const s = `<script>(function(){function r(){var h=Math.max(document.documentElement.scrollHeight,document.body.scrollHeight);window.parent.postMessage({type:'iframeHeight',id:'${id}',height:h},'*')}window.addEventListener('load',r);try{new ResizeObserver(r).observe(document.body)}catch(e){}})()<\/script>`
  return html.includes('</body>') ? html.replace('</body>', s + '</body>') : html + s
}

function onIframeMsg(e) {
  if (e.data?.type === 'iframeHeight' && e.data.id) {
    iframeHeights.value[e.data.id] = e.data.height
  }
}

onMounted(() => {
  load(route.params.slug)
  window.addEventListener('message', onIframeMsg)
})
onUnmounted(() => window.removeEventListener('message', onIframeMsg))
watch(() => route.params.slug, s => { if (s) load(s) })
</script>

<template>
  <div class="font-sarabun min-h-screen bg-slate-50 dark:bg-slate-950 dark:text-slate-100 transition-colors">

    <!-- Loading -->
    <div v-if="loading" class="max-w-3xl mx-auto px-4 py-16 space-y-4 animate-pulse">
      <div class="h-8 bg-slate-200 rounded w-1/3"></div>
      <div class="h-4 bg-slate-200 rounded w-full"></div>
      <div class="h-4 bg-slate-200 rounded w-4/5"></div>
    </div>

    <template v-else-if="page">
      <!-- Page header — gradient banner + icon + title กลางหน้า -->
      <div class="relative overflow-hidden"
        style="background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-secondary) 100%)">
        <!-- dot pattern -->
        <div class="absolute inset-0 opacity-10">
          <svg width="100%" height="100%"><defs><pattern id="dp" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="12" cy="12" r="1" fill="white"/></pattern></defs><rect width="100%" height="100%" fill="url(#dp)"/></svg>
        </div>
        <div class="relative max-w-3xl mx-auto px-4 py-12 text-center">
          <!-- SVG icon วงกลม -->
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-white/15 backdrop-blur ring-2 ring-white/20 mb-5 shadow-lg">
            <svg v-if="isIconKey(page.nav_icon)" class="w-7 h-7 text-white" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" :d="iconPath(page.nav_icon)"/>
            </svg>
            <span v-else class="text-2xl">{{ page.nav_icon || page.icon || '📄' }}</span>
          </div>
          <h1 class="text-2xl md:text-3xl font-extrabold text-white leading-tight">{{ page.title }}</h1>
        </div>
      </div>

      <!-- Blocks -->
      <div class="max-w-3xl mx-auto px-4 py-10 space-y-6">
        <template v-for="block in (page.blocks || [])" :key="block.id">

          <!-- HEADING -->
          <component :is="block.level || 'h2'" v-if="block.type === 'heading'"
            :class="['font-extrabold text-slate-900 dark:text-slate-50',
              block.level==='h2' ? 'text-2xl' : block.level==='h3' ? 'text-xl' : 'text-lg']">
            {{ block.text }}
          </component>

          <!-- TEXT -->
          <p v-else-if="block.type === 'text'"
            class="text-slate-700 dark:text-slate-300 leading-relaxed whitespace-pre-wrap text-base">
            {{ block.text }}
          </p>

          <!-- IMAGE -->
          <figure v-else-if="block.type === 'image' && block.url"
            :class="['', block.align==='center' ? 'text-center' : block.align==='right' ? 'text-right' : 'text-left']">
            <img :src="block.url" :class="['rounded-2xl shadow-md max-w-full',
              block.align==='center' ? 'mx-auto' : block.align==='right' ? 'ml-auto' : '']"/>
            <figcaption v-if="block.caption"
              class="text-xs text-slate-400 mt-2 italic">{{ block.caption }}</figcaption>
          </figure>

          <!-- EMBED -->
          <div v-else-if="block.type === 'embed' && block.url"
            class="rounded-2xl overflow-hidden border border-slate-200 dark:border-slate-700 bg-slate-100 shadow-sm"
            :style="`aspect-ratio:${block.aspect || '16/9'}`">
            <iframe :src="toEmbedUrl(block.url, block.embed_type)"
              class="w-full h-full" frameborder="0" allowfullscreen
              allow="autoplay; encrypted-media" loading="lazy"/>
          </div>

          <!-- HTML: full document → auto-height iframe | snippet → v-html -->
          <template v-else-if="block.type === 'html' && block.code">
            <div v-if="/<!DOCTYPE|<html/i.test(block.code)" class="rounded-2xl overflow-hidden w-full">
              <iframe
                :srcdoc="htmlWithHeightScript(block.code, block.id)"
                sandbox="allow-scripts allow-same-origin"
                class="w-full border-0 block"
                :style="`height:${iframeHeights[block.id] || 200}px`"
                scrolling="no"
              />
            </div>
            <div v-else class="prose prose-slate dark:prose-invert max-w-none rounded-2xl overflow-hidden" v-html="block.code"/>
          </template>

          <!-- DIVIDER -->
          <hr v-else-if="block.type === 'divider'"
            class="border-slate-200 dark:border-slate-700"/>

        </template>

        <!-- Empty -->
        <div v-if="!page.blocks?.length"
          class="text-center py-16 text-slate-400">
          <p class="text-4xl mb-3">📭</p>
          <p class="text-sm">หน้านี้ยังไม่มีเนื้อหา</p>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
