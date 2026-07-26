<script setup>
/**
 * WorkDetailView — หน้ารายละเอียดผลงาน /works/:id
 *
 * อ่านจาก view works_public → เห็นเฉพาะที่อนุมัติแล้ว (RLS/view คุมให้)
 * ต่างจาก MediaDetailView ที่ให้เครดิตเจ้าของเป็นการ์ดเต็ม เพราะเป็นหัวใจของระบบผลงาน
 */
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../supabase'
import ContentBlockRenderer from '../components/content/ContentBlockRenderer.vue'
import { workTypeMeta } from '../composables/useWorks'

const route  = useRoute()
const router = useRouter()

const item      = ref(null)
const loading   = ref(true)
const notFound  = ref(false)
const liked     = ref(false)
const likeCount = ref(0)

onMounted(async () => {
  const { data } = await supabase.from('works_public').select('*').eq('id', route.params.id).maybeSingle()
  if (!data) { notFound.value = true; loading.value = false; return }
  item.value      = data
  likeCount.value = data.like_count || 0
  loading.value   = false

  const sessionKey = `wv_${data.id}`
  if (!sessionStorage.getItem(sessionKey)) {
    sessionStorage.setItem(sessionKey, '1')
    await supabase.rpc('record_work_view', { p_work_id: data.id, p_session_id: sessionKey })
  }

  liked.value = !!localStorage.getItem(`wl_${data.id}`)
})

/** ตัวระบุผู้กดใจแบบไม่ล็อกอิน — เก็บใน localStorage ไม่แตะ IP จริง */
function getIpHash() {
  let h = localStorage.getItem('__ihash')
  if (!h) {
    h = Math.random().toString(36).slice(2) + Date.now().toString(36)
    localStorage.setItem('__ihash', h)
  }
  return h
}

async function toggleLike() {
  if (!item.value) return
  const { data } = await supabase.rpc('toggle_work_like', {
    p_work_id: item.value.id,
    p_ip_hash: getIpHash(),
  })
  if (data) {
    liked.value     = data.liked
    likeCount.value = data.like_count
    if (data.liked) localStorage.setItem(`wl_${item.value.id}`, '1')
    else localStorage.removeItem(`wl_${item.value.id}`)
  }
}

async function trackDownload() {
  if (item.value) await supabase.rpc('increment_work_download', { p_work_id: item.value.id })
}

const typeMeta = computed(() => workTypeMeta(item.value?.work_type))

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'long', day:'numeric' })
}
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <div v-if="loading" class="flex justify-center py-24">
      <div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <div v-else-if="notFound" class="max-w-lg mx-auto px-4 py-24 text-center">
      <p class="text-4xl mb-3">🔍</p>
      <p class="font-bold text-slate-700">ไม่พบผลงานนี้</p>
      <p class="text-sm text-slate-500 mt-1">อาจถูกลบ หรือยังไม่ได้รับการอนุมัติให้เผยแพร่</p>
      <button @click="router.push('/works')"
        class="mt-5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        ดูผลงานทั้งหมด
      </button>
    </div>

    <template v-else-if="item">
      <div class="max-w-4xl mx-auto px-4 pt-4 pb-10 space-y-4">

        <!-- หัวเรื่อง + ปุ่ม -->
        <div class="flex items-start justify-between gap-4 flex-wrap">
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap gap-2 mb-2">
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', typeMeta.bg, typeMeta.text]">
                {{ typeMeta.icon }} {{ typeMeta.label }}
              </span>
              <span v-if="item.is_featured" class="text-xs font-bold text-white bg-amber-500 px-2.5 py-0.5 rounded-full">⭐ แนะนำ</span>
              <span v-if="item.subject_group" class="text-xs bg-slate-100 text-slate-600 font-bold px-2.5 py-0.5 rounded-full">{{ item.subject_group }}</span>
              <span v-for="g in item.grade_levels" :key="g" class="text-xs bg-indigo-50 text-indigo-600 font-bold px-2 py-0.5 rounded-full">{{ g }}</span>
              <span v-if="item.academic_year" class="text-xs bg-slate-100 text-slate-600 font-bold px-2.5 py-0.5 rounded-full">ปีการศึกษา {{ item.academic_year }}</span>
            </div>
            <h1 class="text-xl md:text-2xl font-extrabold text-slate-800">{{ item.title }}</h1>
            <p v-if="item.description" class="text-slate-500 text-sm mt-1 whitespace-pre-line">{{ item.description }}</p>
            <p class="text-xs text-slate-400 mt-2">เผยแพร่ {{ fmtDate(item.published_at || item.created_at) }}</p>
          </div>

          <div class="flex flex-wrap gap-2 flex-shrink-0">
            <button @click="toggleLike"
              :class="['flex items-center gap-1.5 px-4 py-2.5 rounded-2xl font-bold text-sm border-2 transition-all',
                liked ? 'border-red-400 bg-red-50 text-red-500' : 'border-slate-200 text-slate-500 hover:border-red-300 hover:text-red-500']">
              <svg class="w-4 h-4" :fill="liked ? 'currentColor' : 'none'" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"/>
              </svg>
              {{ likeCount.toLocaleString() }}
            </button>
            <a v-if="item.file_url" :href="item.file_url" target="_blank" rel="noopener" @click="trackDownload"
              class="flex items-center gap-1.5 px-4 py-2.5 rounded-2xl font-bold text-sm bg-primary text-white hover:-translate-y-0.5 shadow-md transition-all">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"/></svg>
              เปิดไฟล์ผลงาน
            </a>
            <button @click="router.push('/works')"
              class="flex items-center gap-1.5 px-4 py-2.5 rounded-2xl font-bold text-sm bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors">
              ← กลับ
            </button>
          </div>
        </div>

        <!-- เครดิตเจ้าของผลงาน — หัวใจของระบบนี้ -->
        <div class="glass-card p-4 flex items-center gap-3">
          <img v-if="item.owner_avatar" :src="item.owner_avatar" :alt="item.owner_name"
            class="w-12 h-12 rounded-full object-cover flex-shrink-0"/>
          <div v-else class="w-12 h-12 rounded-full bg-primary/15 flex items-center justify-center flex-shrink-0">
            <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0"/></svg>
          </div>
          <div class="min-w-0">
            <p class="text-[11px] text-slate-400 font-bold">ผู้สร้างผลงาน</p>
            <p class="font-bold text-slate-800 truncate">{{ item.owner_name || item.school_name || '—' }}</p>
            <p v-if="item.owner_position || item.school_name" class="text-xs text-slate-500 truncate">
              {{ [item.owner_position, item.school_name].filter(Boolean).join(' · ') }}
            </p>
          </div>
        </div>

        <!-- สถิติ -->
        <div class="flex gap-4 text-xs text-slate-400 glass-tile px-4 py-3">
          <span class="flex items-center gap-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
            {{ (item.view_count || 0).toLocaleString() }} ครั้ง
          </span>
          <span class="flex items-center gap-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"/></svg>
            {{ likeCount.toLocaleString() }} ถูกใจ
          </span>
          <span v-if="item.download_count" class="flex items-center gap-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"/></svg>
            {{ item.download_count.toLocaleString() }} เปิดไฟล์
          </span>
        </div>

        <!-- ปก -->
        <img v-if="item.cover_url" :src="item.cover_url" :alt="item.title"
          class="w-full rounded-2xl shadow-sm" @error="$event.target.style.display='none'"/>

        <!-- แท็ก -->
        <div v-if="item.tags?.length" class="flex flex-wrap gap-2">
          <span v-for="tag in item.tags" :key="tag" class="text-xs bg-slate-100 text-slate-600 px-3 py-1 rounded-full">#{{ tag }}</span>
        </div>

        <!-- เนื้อหา -->
        <ContentBlockRenderer :blocks="item.content_blocks"/>

      </div>
    </template>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
