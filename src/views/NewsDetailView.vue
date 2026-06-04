<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'

const route  = useRoute()
const router = useRouter()

const news    = ref(null)
const related = ref([])
const loading = ref(true)

const catMeta = {
  pr:         { bg: 'bg-blue-100',    text: 'text-blue-700',   label: 'ประชาสัมพันธ์' },
  supervision:{ bg: 'bg-primary-light', text: 'text-primary',  label: 'นิเทศการศึกษา' },
  training:   { bg: 'bg-emerald-100', text: 'text-emerald-700',label: 'อบรม/สัมมนา' },
  policy:     { bg: 'bg-amber-100',   text: 'text-amber-700',  label: 'นโยบาย/หนังสือเวียน' },
  other:      { bg: 'bg-slate-100',   text: 'text-slate-600',  label: 'ทั่วไป' },
}

// ── Embed type labels ─────────────────────────────────────────────
const EMBED_SOURCE_LABEL = {
  youtube: 'YouTube',
  drive:   'Google Drive',
  slides:  'Google Slides',
  canva:   'Canva',
  pdf:     'PDF Viewer',
  iframe:  'เนื้อหาแทรก',
}

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', {
    year: 'numeric', month: 'long', day: 'numeric', weekday: 'long',
  })
}

// ── File attachment detect ────────────────────────────────────────
const FILE_EXTS = /\.(pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|7z|csv|txt)(\?.*)?$/i

function isFileAttachment(url) {
  if (!url) return false
  try {
    return FILE_EXTS.test(new URL(url).pathname)
  } catch {
    return FILE_EXTS.test(url)
  }
}

function attachmentLabel(url) {
  return isFileAttachment(url) ? 'เอกสารแนบ' : 'ลิงค์ที่เกี่ยวข้อง'
}
function attachmentBtnLabel(url) {
  return isFileAttachment(url) ? 'ดาวน์โหลด' : 'เปิดลิงค์'
}
function attachmentIcon(url) {
  return isFileAttachment(url)
    ? 'M18.375 12.739l-7.693 7.693a4.5 4.5 0 01-6.364-6.364l10.94-10.94A3 3 0 1119.5 7.372L8.552 18.32m.009-.01l-.01.01m5.699-9.941l-7.81 7.81a1.5 1.5 0 002.112 2.13'
    : 'M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25'
}

// ── HTML Code iframe ─────────────────────────────────────────────
const htmlFrameHeight = ref(400)

function wrappedHtml(code) {
  if (!code) return ''
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; overflow-x: hidden; font-family: Sarabun, sans-serif; }
  </style>
</head>
<body>
${code}
<script>
  function report() {
    var h = Math.max(document.documentElement.scrollHeight, document.body.scrollHeight);
    window.parent.postMessage({ type: 'iframeHeight', height: h }, '*');
  }
  window.addEventListener('load', report);
  try { new ResizeObserver(report).observe(document.body) } catch(e) { setTimeout(report, 800) }
<\/script>
</body>
</html>`
}

function onHtmlMessage(e) {
  if (e.data?.type === 'iframeHeight' && e.data.height > 0) {
    htmlFrameHeight.value = e.data.height + 24
  }
}

// ── Embed URL transform ───────────────────────────────────────────
function toEmbedUrl(url, type) {
  if (!url || !type) return url
  switch (type) {
    case 'youtube': {
      const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&?/]+)/)
      return m ? `https://www.youtube.com/embed/${m[1]}?rel=0` : url
    }
    case 'drive':
      return url.replace(/\/view.*$/, '/preview')
    case 'slides':
      return url.replace(/\/(edit|view|preview).*$/, '/embed?start=false&loop=false&delayms=3000')
    case 'canva': {
      const base = url.split('?')[0]
      return (base.endsWith('/view') ? base : base + '/view') + '?embed'
    }
    case 'pdf':
      // Use Google Docs Viewer for external PDFs
      if (url.includes('docs.google.com/viewer')) return url
      return `https://docs.google.com/viewer?url=${encodeURIComponent(url)}&embedded=true`
    default:
      return url
  }
}

async function loadNews(id) {
  loading.value = true
  news.value = null
  related.value = []
  window.scrollTo({ top: 0, behavior: 'smooth' })

  const { data } = await supabase
    .from('news')
    .select('*')
    .eq('id', id)
    .eq('is_published', true)
    .single()

  if (!data) { router.push('/news'); return }
  news.value = data

  supabase.rpc('increment_news_view', { news_id: id }).then()

  const { data: rel } = await supabase
    .from('news')
    .select('id, title, cover_url, published_at, category, view_count')
    .eq('is_published', true)
    .eq('category', data.category)
    .neq('id', id)
    .order('published_at', { ascending: false })
    .limit(3)
  related.value = rel || []
  loading.value = false
}

onMounted(() => loadNews(route.params.id))
watch(() => route.params.id, id => { if (id) loadNews(id) })

onMounted(() => window.addEventListener('message', onHtmlMessage))
onUnmounted(() => window.removeEventListener('message', onHtmlMessage))
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 dark:text-slate-100 min-h-screen transition-colors duration-300">

    <!-- Loading -->
    <div v-if="loading" class="max-w-3xl mx-auto px-4 py-16 space-y-4 animate-pulse">
      <div class="h-6 bg-slate-200 rounded w-1/4"></div>
      <div class="h-8 bg-slate-200 rounded w-3/4"></div>
      <div class="h-64 bg-slate-200 rounded-2xl"></div>
    </div>

    <template v-else-if="news">

      <!-- ── Top bar: back + category + date (sticky) ─────────────── -->
      <div class="sticky top-0 z-20 bg-white/90 dark:bg-slate-900/90 backdrop-blur border-b border-slate-100 dark:border-slate-800 shadow-sm">
        <div class="max-w-3xl mx-auto px-4 h-12 flex items-center gap-3">
          <button @click="router.push('/news')"
            class="flex items-center gap-1.5 text-sm font-bold text-slate-500 hover:text-primary transition-colors flex-shrink-0">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"/>
            </svg>
            กลับ
          </button>
          <div class="w-px h-4 bg-slate-200 flex-shrink-0"></div>
          <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full flex-shrink-0',
            catMeta[news.category]?.bg, catMeta[news.category]?.text]">
            {{ catMeta[news.category]?.label || news.category }}
          </span>
          <span v-if="news.is_pinned"
            class="flex items-center gap-1 text-xs font-bold px-2 py-0.5 bg-amber-100 text-amber-700 rounded-full flex-shrink-0">
            <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
              <path d="M16 12V4h1a1 1 0 000-2H7a1 1 0 000 2h1v8l-2 2v2h5v5l1 1 1-1v-5h5v-2l-2-2z"/>
            </svg>
            ปักหมุด
          </span>
          <div class="flex items-center gap-3 ml-auto text-xs text-slate-400 flex-shrink-0">
            <span class="flex items-center gap-1">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
              </svg>
              {{ (news.view_count || 0).toLocaleString() }} ครั้ง
            </span>
            <span class="hidden sm:block">{{ fmtDate(news.published_at) }}</span>
          </div>
        </div>
      </div>

      <!-- ── Title (เหนือภาพเสมอ) ────────────────────────────────── -->
      <div class="max-w-3xl mx-auto px-4 pt-8 pb-4">
        <div v-if="news.show_title ?? true" class="flex items-start gap-2.5">
          <span class="flex-shrink-0 text-lg leading-snug">📌</span>
          <h1 class="text-lg md:text-2xl font-extrabold text-slate-900 dark:text-slate-50 leading-snug">
            {{ news.title }}
          </h1>
        </div>
        <p class="text-xs text-slate-400 dark:text-slate-500 mt-2 pl-8">{{ fmtDate(news.published_at) }}</p>
      </div>

      <!-- ── Cover image ───────────────────────────────────────────── -->
      <div v-if="news.cover_url && (news.show_cover ?? true)"
        class="w-full bg-slate-100">
        <img :src="news.cover_url"
          class="w-full h-auto block mx-auto"
          style="max-height: 70vh; object-fit: contain;"/>
      </div>

      <!-- ── Content area ─────────────────────────────────────────── -->
      <div class="max-w-3xl mx-auto px-4 py-8">

        <!-- Excerpt -->
        <p v-if="news.excerpt"
          class="text-base text-slate-500 leading-relaxed mb-6 pb-6 border-b border-slate-100 italic">
          {{ news.excerpt }}
        </p>

        <!-- Content (plain text) -->
        <div v-if="news.content"
          class="prose prose-slate max-w-none text-slate-700 dark:text-slate-300 leading-relaxed whitespace-pre-wrap text-sm md:text-base">
          {{ news.content }}
        </div>

        <!-- ── Embed (PDF / Slides / YouTube / Drive / Canva) ──────── -->
        <div v-if="news.embed_url && news.embed_type" class="mt-8">
          <div class="rounded-2xl overflow-hidden border border-slate-200 bg-slate-100 shadow-sm"
            style="aspect-ratio:16/9">
            <iframe
              :src="toEmbedUrl(news.embed_url, news.embed_type)"
              class="w-full h-full"
              frameborder="0"
              allowfullscreen
              allow="autoplay; encrypted-media; clipboard-read; clipboard-write"
              loading="lazy"/>
          </div>
          <p class="text-xs text-slate-400 mt-2 text-center">
            เนื้อหาแทรกจาก {{ EMBED_SOURCE_LABEL[news.embed_type] || 'แหล่งภายนอก' }}
          </p>
        </div>

        <!-- ── HTML Code (Canva / Custom Widget) ──────────────────── -->
        <div v-if="news.html_code" class="mt-8">
          <iframe
            :srcdoc="wrappedHtml(news.html_code)"
            sandbox="allow-scripts allow-same-origin allow-popups allow-forms"
            class="w-full border-none block rounded-2xl overflow-hidden"
            :style="{ height: htmlFrameHeight + 'px' }"
            scrolling="no"
            loading="lazy"/>
        </div>

        <!-- ── File / Link attachment ───────────────────────────────── -->
        <div v-if="news.file_url"
          class="mt-8 p-4 bg-primary-light dark:bg-slate-800 border border-primary/20 dark:border-slate-700 rounded-2xl flex items-center gap-4">
          <!-- Icon -->
          <div class="w-10 h-10 rounded-xl bg-primary flex items-center justify-center flex-shrink-0">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" :d="attachmentIcon(news.file_url)"/>
            </svg>
          </div>
          <!-- Label + URL preview -->
          <div class="flex-1 min-w-0">
            <p class="text-sm font-bold text-primary">{{ attachmentLabel(news.file_url) }}</p>
            <p class="text-xs text-slate-500 truncate">
              {{ isFileAttachment(news.file_url)
                  ? news.file_url.split('/').pop().split('?')[0]
                  : news.file_url }}
            </p>
          </div>
          <!-- Button -->
          <a :href="news.file_url" target="_blank" rel="noopener"
            class="flex-shrink-0 px-4 py-2 bg-primary text-white text-sm font-bold rounded-xl
                   hover:bg-primary-dark transition-all flex items-center gap-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round"
                :d="isFileAttachment(news.file_url)
                  ? 'M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3'
                  : 'M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25'"/>
            </svg>
            {{ attachmentBtnLabel(news.file_url) }}
          </a>
        </div>

        <!-- ── Related news ─────────────────────────────────────────── -->
        <div v-if="related.length > 0" class="mt-12">
          <div class="w-6 h-0.5 bg-secondary mb-4"></div>
          <h2 class="text-lg font-extrabold text-slate-800 mb-4">ข่าวที่เกี่ยวข้อง</h2>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div v-for="r in related" :key="r.id"
              @click="router.push(`/news/${r.id}`)"
              class="group bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 overflow-hidden cursor-pointer hover:shadow-md transition-all">
              <div class="h-28 bg-slate-100 overflow-hidden">
                <img v-if="r.cover_url" :src="r.cover_url"
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"/>
                <div v-else class="w-full h-full flex items-center justify-center">
                  <svg class="w-8 h-8 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 7.5h1.5m-1.5 3h1.5m-7.5 3h7.5m-7.5 3h7.5m3-9h3.375c.621 0 1.125.504 1.125 1.125V18a2.25 2.25 0 01-2.25 2.25M16.5 7.5V18a2.25 2.25 0 002.25 2.25M16.5 7.5V4.875c0-.621-.504-1.125-1.125-1.125H4.125C3.504 3.75 3 4.254 3 4.875V18a2.25 2.25 0 002.25 2.25h13.5"/>
                  </svg>
                </div>
              </div>
              <div class="p-3">
                <p class="text-xs font-bold text-slate-700 dark:text-slate-200 line-clamp-2 group-hover:text-primary transition-colors">
                  {{ r.title }}
                </p>
                <div class="flex items-center justify-between mt-1">
                  <p class="text-[10px] text-slate-400">{{ fmtDate(r.published_at) }}</p>
                  <span class="flex items-center gap-0.5 text-[10px] text-slate-400">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    {{ r.view_count || 0 }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div><!-- /content area -->
    </template>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.line-clamp-2 { display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
</style>
