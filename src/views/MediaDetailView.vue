<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'

const route  = useRoute()
const router = useRouter()

const item    = ref(null)
const loading = ref(true)
const liked   = ref(false)
const likeCount = ref(0)

// ─── Load media ───────────────────────────────────────────────────────────────
onMounted(async () => {
  const { data } = await supabase.from('media').select('*')
    .eq('id', route.params.id).eq('is_published', true).eq('is_approved', true).single()
  if (!data) { router.push('/media'); return }
  item.value    = data
  likeCount.value = data.like_count
  loading.value = false

  // Record view
  const sessionKey = `mv_${data.id}`
  if (!sessionStorage.getItem(sessionKey)) {
    sessionStorage.setItem(sessionKey, '1')
    await supabase.rpc('record_media_view', {
      p_media_id: data.id,
      p_session_id: sessionKey,
    })
  }

  // Check if already liked
  const likeKey = `ml_${data.id}`
  liked.value = !!localStorage.getItem(likeKey)
})

// ─── Like ─────────────────────────────────────────────────────────────────────
async function toggleLike() {
  if (!item.value) return
  const likeKey = `ml_${item.value.id}`
  const ipHash  = await getIpHash()
  const { data } = await supabase.rpc('toggle_media_like', {
    p_media_id: item.value.id,
    p_ip_hash:  ipHash,
  })
  if (data) {
    liked.value     = data.liked
    likeCount.value = data.like_count
    if (data.liked) localStorage.setItem(likeKey, '1')
    else localStorage.removeItem(likeKey)
  }
}

async function getIpHash() {
  let h = localStorage.getItem('__ihash')
  if (!h) {
    h = Math.random().toString(36).slice(2) + Date.now().toString(36)
    localStorage.setItem('__ihash', h)
  }
  return h
}

// ─── Download ─────────────────────────────────────────────────────────────────
async function trackDownload() {
  if (!item.value) return
  await supabase.rpc('increment_media_download', { p_media_id: item.value.id })
}

// ─── Get embed URL ────────────────────────────────────────────────────────────
const embedUrl = computed(() => {
  if (!item.value) return null
  if (item.value.file_id) return `https://drive.google.com/file/d/${item.value.file_id}/preview`
  if (item.value.embed_url) {
    const url = item.value.embed_url
    // YouTube → embed
    const ytMatch = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&\n?#]+)/)
    if (ytMatch) return `https://www.youtube.com/embed/${ytMatch[1]}?autoplay=0`
    return url
  }
  return null
})

const mainUrl = computed(() =>
  item.value?.drive_url || item.value?.embed_url || item.value?.external_url || null
)

const MEDIA_TYPE_LABEL = {
  book:'หนังสือ', video:'วิดีโอ', image:'รูปภาพ', audio:'เสียง',
  app:'แอปพลิเคชัน', exam:'ข้อสอบ', template:'เทมเพลต', multimedia:'มัลติมีเดีย',
}

function fmtDate(d) {
  return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'long', day:'numeric' })
}

// ─── Block renderer (same as DynamicPageView) ─────────────────────────────────
function extractYtId(url) {
  const m = url?.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/)
  return m?.[1]
}
function extractDriveId(url) {
  const m = url?.match(/\/file\/d\/([a-zA-Z0-9_-]+)/)
  return m?.[1]
}
</script>

<template>
  <div class="font-sarabun bg-slate-50 dark:bg-slate-950 min-h-screen">
    <div v-if="loading" class="flex justify-center py-24">
      <div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else-if="item">

      <!-- ── Info + Content ──────────────────────────────────────────────── -->
      <div class="max-w-4xl mx-auto px-4 pt-4 pb-8 space-y-4">

        <!-- Title + meta -->
        <div class="flex items-start justify-between gap-4 flex-wrap">
          <div class="flex-1">
            <div class="flex flex-wrap gap-2 mb-2">
              <span class="text-xs bg-primary/10 text-primary font-bold px-2.5 py-0.5 rounded-full">
                {{ MEDIA_TYPE_LABEL[item.media_type] || item.media_type }}
              </span>
              <span v-if="item.subject_group" class="text-xs bg-slate-100 text-slate-600 font-bold px-2.5 py-0.5 rounded-full">
                {{ item.subject_group }}
              </span>
              <span v-for="g in item.grade_levels" :key="g" class="text-xs bg-indigo-50 text-indigo-600 font-bold px-2 py-0.5 rounded-full">{{ g }}</span>
            </div>
            <h1 class="text-xl md:text-2xl font-extrabold text-slate-800 dark:text-slate-100">{{ item.title }}</h1>
            <p v-if="item.description" class="text-slate-500 dark:text-slate-400 text-sm mt-1">{{ item.description }}</p>
            <div class="flex flex-wrap gap-4 mt-2 text-xs text-slate-400">
              <span v-if="item.author_name" class="flex items-center gap-1">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0"/></svg>
                {{ item.author_name }}
              </span>
              <span>{{ fmtDate(item.created_at) }}</span>
            </div>
          </div>

          <!-- Action buttons -->
          <div class="flex flex-wrap gap-2 flex-shrink-0">
            <!-- Like -->
            <button @click="toggleLike"
              :class="['flex items-center gap-1.5 px-4 py-2.5 rounded-2xl font-bold text-sm border-2 transition-all',
                liked ? 'border-red-400 bg-red-50 text-red-500' : 'border-slate-200 text-slate-500 hover:border-red-300 hover:text-red-500']">
              <svg class="w-4 h-4" :fill="liked ? 'currentColor' : 'none'" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"/>
              </svg>
              {{ likeCount.toLocaleString() }}
            </button>
            <!-- Open in source -->
            <a v-if="mainUrl" :href="mainUrl" target="_blank" rel="noopener" @click="trackDownload"
              class="flex items-center gap-1.5 px-4 py-2.5 rounded-2xl font-bold text-sm bg-primary text-white hover:-translate-y-0.5 shadow-md transition-all">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/></svg>
              เปิดต้นฉบับ
            </a>
            <!-- Back -->
            <button @click="router.push('/media')"
              class="flex items-center gap-1.5 px-4 py-2.5 rounded-2xl font-bold text-sm bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors">
              ← กลับ
            </button>
          </div>
        </div>

        <!-- Stats -->
        <div class="flex gap-4 text-xs text-slate-400 bg-white dark:bg-slate-800 rounded-2xl border border-slate-100 dark:border-slate-700 px-4 py-3">
          <span class="flex items-center gap-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
            {{ item.view_count.toLocaleString() }} ครั้ง
          </span>
          <span class="flex items-center gap-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"/></svg>
            {{ likeCount.toLocaleString() }} ถูกใจ
          </span>
          <span v-if="item.download_count" class="flex items-center gap-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"/></svg>
            {{ item.download_count.toLocaleString() }} ดาวน์โหลด
          </span>
        </div>

        <!-- Tags -->
        <div v-if="item.tags?.length" class="flex flex-wrap gap-2">
          <span v-for="tag in item.tags" :key="tag" class="text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-3 py-1 rounded-full">#{{ tag }}</span>
        </div>

        <!-- ── Block content ────────────────────────────────────────────────── -->
        <div v-if="item.content_blocks?.length" class="space-y-4">
          <div v-for="(block, i) in item.content_blocks" :key="i">

            <!-- heading -->
            <component :is="`h${block.level || 2}`"
              v-if="block.type === 'heading' && block.text"
              :class="['font-extrabold text-slate-800 dark:text-slate-100',
                block.level===2?'text-xl':block.level===3?'text-lg':'text-base']">
              {{ block.text }}
            </component>

            <!-- text -->
            <div v-else-if="block.type === 'text' && block.text"
              class="text-slate-600 dark:text-slate-300 leading-relaxed whitespace-pre-line">
              {{ block.text }}
            </div>

            <!-- image -->
            <figure v-else-if="block.type === 'image' && block.url" class="rounded-2xl overflow-hidden">
              <img :src="block.url" :alt="block.alt || ''" class="w-full rounded-2xl"/>
              <figcaption v-if="block.caption" class="text-xs text-center text-slate-400 mt-2">{{ block.caption }}</figcaption>
            </figure>

            <!-- drive embed -->
            <div v-else-if="block.type === 'drive' && block.url" class="rounded-2xl overflow-hidden border border-slate-200 dark:border-slate-700">
              <p v-if="block.label" class="text-xs font-bold text-slate-500 px-4 py-2 border-b border-slate-100 dark:border-slate-700 bg-slate-50 dark:bg-slate-800">📄 {{ block.label }}</p>
              <div class="aspect-video bg-slate-900">
                <iframe :src="`https://drive.google.com/file/d/${extractDriveId(block.url)}/preview`"
                  class="w-full h-full border-0" allow="autoplay" loading="lazy"/>
              </div>
            </div>

            <!-- embed URL -->
            <div v-else-if="block.type === 'embed' && block.url" class="rounded-2xl overflow-hidden border border-slate-200 dark:border-slate-700">
              <p v-if="block.label" class="text-xs font-bold text-slate-500 px-4 py-2 border-b border-slate-100 dark:border-slate-700 bg-slate-50 dark:bg-slate-800">🔗 {{ block.label }}</p>
              <div class="aspect-video bg-slate-900">
                <iframe v-if="extractYtId(block.url)"
                  :src="`https://www.youtube.com/embed/${extractYtId(block.url)}`"
                  class="w-full h-full border-0" allow="autoplay; encrypted-media" allowfullscreen/>
                <iframe v-else :src="block.url" class="w-full h-full border-0" loading="lazy"/>
              </div>
            </div>

            <!-- html — full doc → srcdoc iframe | snippet → v-html -->
            <div v-else-if="block.type === 'html' && block.code" class="rounded-2xl overflow-hidden">
              <iframe v-if="/<!DOCTYPE|<html/i.test(block.code)"
                :srcdoc="block.code"
                sandbox="allow-scripts allow-same-origin"
                class="w-full border-0 rounded-2xl"
                style="min-height:500px; height:80vh; max-height:900px"
                scrolling="yes"/>
              <div v-else v-html="block.code" class="prose max-w-none"/>
            </div>

            <!-- divider -->
            <hr v-else-if="block.type === 'divider'" class="border-slate-200 dark:border-slate-700"/>
          </div>
        </div>

      </div>
    </template>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
