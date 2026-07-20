<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import PageHero from '../components/PageHero.vue'
import ImageLinkGallery from '../components/ImageLinkGallery.vue'
import { getBgStyle as getBgStyleRaw } from '../composables/useBgStyle'
import { useTheme } from '../composables/useTheme'

const route   = useRoute()
const router  = useRouter()
const page    = ref(null)
const loading = ref(true)

// พื้นหลังบล็อกออกแบบไว้สำหรับโหมดสว่างเท่านั้น (เหมือน section หน้าแรก) — โหมดมืดไม่ใช้ กันตัวหนังสือกลืนพื้นหลัง
const { isDark } = useTheme()
function getBgStyle(block) {
  if (!block.bg_type || isDark.value) return {}
  return getBgStyleRaw(block)
}

// ── หัวข้อ: ขนาดตัวอักษร (แยกจาก level ซึ่งคุมแค่แท็ก h2/h3/h4 เพื่อ SEO) — ต้องตรงกับ AdminPageEditorView.vue ──
const HEADING_SIZE_CLASS = { sm:'text-lg', md:'text-xl', lg:'text-2xl', xl:'text-3xl', '2xl':'text-4xl' }
const HEADING_DEFAULT_SIZE = { h2:'lg', h3:'md', h4:'sm' }
function headingSizeClass(block) {
  return HEADING_SIZE_CLASS[block.size || HEADING_DEFAULT_SIZE[block.level] || 'lg']
}

// ── ลิงก์ภายใน (ปุ่ม CTA) — path สำหรับ router-link จาก "#/page" หรือ "/page" ──
function internalPath(url) {
  if (!url) return '/'
  return url.startsWith('#') ? url.slice(1) : url
}

// v-bind object แทนการ bind :href/:to แยกทีละตัว — ถ้า bind :href="undefined" ตรงๆ บน <component :is="'router-link'">
// จะไปทับ href ที่ RouterLink คำนวณเองผ่านกลไก fallthrough attribute ทำให้ href หายไป (แต่ยังคลิกได้เพราะ onClick ยังทำงาน)
function linkAttrs(block) {
  if (block.link_type === 'external' && block.link_url) {
    return { href: block.link_url, target: '_blank', rel: 'noopener' }
  }
  if (block.link_type === 'internal' && block.link_url) {
    return { to: internalPath(block.link_url) }
  }
  return {}
}

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
      <!-- Page header — icon/title default หรือรูป/วิดีโอ/GIF ถ้าตั้งค่าไว้ -->
      <PageHero v-if="!page.header_hidden" :title="page.title"
        :mode="page.header_mode || 'icon'"
        :icon="page.nav_icon || page.icon || '📄'"
        :media-url="page.header_media_url"
        :media-type="page.header_media_type"
        :aspect-ratio="page.header_aspect_ratio || '21:9'"
        :align="page.header_align || 'center'"/>

      <!-- Blocks -->
      <div :class="[
        'mx-auto px-4 py-10 space-y-6',
        page.layout === 'wide'   ? 'max-w-7xl' :
        page.layout === 'medium' ? 'max-w-5xl' : 'max-w-3xl'
      ]">
        <template v-for="block in (page.blocks || [])" :key="block.id">
        <div :class="block.bg_type ? 'rounded-2xl p-5 sm:p-6' : ''" :style="getBgStyle(block)">

          <!-- HEADING -->
          <component :is="block.level || 'h2'" v-if="block.type === 'heading'"
            :class="['font-extrabold', headingSizeClass(block), !block.color ? 'text-slate-900 dark:text-slate-50' : '',
              block.align==='center' ? 'text-center' : block.align==='right' ? 'text-right' : 'text-left']"
            :style="block.color ? { color: block.color } : {}">
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
            <component :is="block.link_type === 'external' ? 'a' : block.link_type === 'internal' ? 'router-link' : 'div'"
              v-bind="linkAttrs(block)"
              class="inline-block">
              <img :src="block.url" :class="['rounded-2xl shadow-md max-w-full',
                block.align==='center' ? 'mx-auto' : block.align==='right' ? 'ml-auto' : '']"/>
            </component>
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

          <!-- GALLERY -->
          <ImageLinkGallery v-else-if="block.type === 'gallery' && block.items?.length"
            :layout="block.layout" :items="block.items" :title="block.title"/>

          <!-- MEDIA-TEXT -->
          <div v-else-if="block.type === 'media-text' && block.url"
            :class="['flex flex-col md:flex-row gap-6 items-center', block.side === 'right' ? 'md:flex-row-reverse' : '']">
            <img :src="block.url" class="w-full md:w-1/2 rounded-2xl shadow-md object-cover"/>
            <div class="w-full md:w-1/2">
              <h3 v-if="block.heading" class="text-xl font-extrabold text-slate-900 dark:text-slate-50 mb-2">{{ block.heading }}</h3>
              <p v-if="block.text" class="text-slate-700 dark:text-slate-300 leading-relaxed whitespace-pre-wrap">{{ block.text }}</p>
            </div>
          </div>

          <!-- BUTTON -->
          <div v-else-if="block.type === 'button' && block.text"
            :class="['flex', block.align==='center' ? 'justify-center' : block.align==='right' ? 'justify-end' : 'justify-start']">
            <component :is="block.link_type === 'external' ? 'a' : 'router-link'"
              v-bind="linkAttrs(block)"
              class="inline-block px-6 py-3 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
              {{ block.text }}
            </component>
          </div>

          <!-- ACCORDION -->
          <div v-else-if="block.type === 'accordion' && block.items?.length" class="space-y-2">
            <details v-for="item in block.items" :key="item.id"
              class="group bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-2xl overflow-hidden">
              <summary class="flex items-center justify-between gap-3 px-4 py-3 cursor-pointer font-bold text-slate-800 dark:text-slate-100 select-none">
                {{ item.question }}
                <svg class="w-4 h-4 flex-shrink-0 transition-transform group-open:rotate-180" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                </svg>
              </summary>
              <p class="px-4 pb-4 text-slate-600 dark:text-slate-300 leading-relaxed whitespace-pre-wrap">{{ item.answer }}</p>
            </details>
          </div>

        </div>
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
