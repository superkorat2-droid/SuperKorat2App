<script setup>
/**
 * NitetVisitDetailView — หน้ารายละเอียดบันทึกการนิเทศ /nithet-visits/:id
 *
 * อ่านจาก view `nithet_visits_public` เท่านั้น — view ไม่ส่ง
 * จุดที่ควรพัฒนา / ข้อเสนอแนะ / ผู้รับการนิเทศ / การติดตามผล ออกมาให้เลย
 * หน้านี้จึงแสดงไม่ได้แม้จะเขียนโค้ดพลาด (กันไว้ที่ระดับฐานข้อมูล)
 *
 * เป็นหน้าแยกเพื่อให้ส่งลิงก์ต่อได้ — มีปุ่มคัดลอกลิงก์ในตัว
 * แกลเลอรีครอบ 4:3 ให้เป็นระเบียบ กดแล้วเปิด Lightbox ดูเต็มใบไม่ครอบ
 */
import { ref, computed, onMounted } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import PhotoLightbox from '../components/nithet/PhotoLightbox.vue'
import { typeMeta, placeOf, fmtDateLong, linkKind, LINK_ICON } from '../composables/useNithetVisits'

const route = useRoute()
const { config, fetchConfig } = useAreaConfig()

const item     = ref(null)
const loading  = ref(true)
const notFound = ref(false)
const lightbox = ref(-1)
const copied   = ref(false)

onMounted(async () => {
  await fetchConfig()
  const { data } = await supabase.from('nithet_visits_public')
    .select('*').eq('id', route.params.id).maybeSingle()
  if (!data) { notFound.value = true; loading.value = false; return }
  item.value = data
  loading.value = false
})

const photos = computed(() => (item.value?.photos || []).filter(p => p?.url))
const meta   = computed(() => typeMeta(item.value?.visit_type))

const sections = computed(() => [
  ['สภาพที่พบ', item.value?.summary],
  ['จุดเด่น', item.value?.strengths],
].filter(s => (s[1] || '').trim()))

async function copyLink() {
  try {
    await navigator.clipboard.writeText(window.location.href)
    copied.value = true
    setTimeout(() => { copied.value = false }, 2000)
  } catch {
    // เบราว์เซอร์เก่า/ไม่ใช่ https — ให้ผู้ใช้คัดลอกจากแถบที่อยู่เอง
    copied.value = false
  }
}
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <div class="max-w-4xl mx-auto px-4 py-8 space-y-5">

      <RouterLink to="/nithet-visits" class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-primary transition-colors">
        ← กลับไปหน้ารวมบันทึกการนิเทศ
      </RouterLink>

      <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

      <div v-else-if="notFound" class="text-center py-16 glass-card text-slate-400">
        <p class="font-medium">ไม่พบบันทึกนี้</p>
        <p class="text-sm mt-1">อาจถูกยกเลิกการเผยแพร่ หรือลิงก์ไม่ถูกต้อง</p>
      </div>

      <template v-else>
        <div class="glass-card p-5 sm:p-7 space-y-3">
          <div class="flex flex-wrap items-center gap-2">
            <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', meta.color]">
              {{ meta.icon }} {{ meta.label }}
            </span>
            <span class="text-sm text-slate-400">{{ fmtDateLong(item.visit_date) }}</span>
            <span v-if="item.academic_year" class="text-sm text-slate-400">
              · ปีการศึกษา {{ item.academic_year }}{{ item.term ? ` ภาคเรียนที่ ${item.term}` : '' }}
            </span>
            <button @click="copyLink" type="button"
              class="ml-auto px-3 py-1.5 rounded-xl text-xs font-bold bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors">
              {{ copied ? '✓ คัดลอกแล้ว' : '🔗 คัดลอกลิงก์' }}
            </button>
          </div>

          <h1 class="text-2xl sm:text-3xl font-extrabold text-slate-800 leading-snug">
            {{ item.title || placeOf(item) }}
          </h1>

          <div class="flex flex-wrap gap-x-4 gap-y-1 text-sm text-slate-500">
            <span>📍 {{ placeOf(item) }}</span>
            <span v-if="item.school_district">อำเภอ{{ item.school_district }}</span>
            <span v-if="item.school_group">{{ item.school_group }}</span>
            <span v-if="item.supervisor_name">
              โดย {{ item.supervisor_name }}<template v-if="item.supervisor_position"> · {{ item.supervisor_position }}</template>
            </span>
          </div>

          <div v-if="(item.topics || []).length" class="flex flex-wrap gap-1.5 pt-1">
            <span v-for="t in item.topics" :key="t"
              class="text-xs font-bold text-slate-600 bg-slate-100 rounded-full px-3 py-1">{{ t }}</span>
          </div>
        </div>

        <div v-for="s in sections" :key="s[0]" class="glass-card p-5 sm:p-7">
          <span class="block font-bold text-slate-700 mb-2">{{ s[0] }}</span>
          <p class="text-slate-600 leading-relaxed whitespace-pre-line">{{ s[1] }}</p>
        </div>

        <div v-if="photos.length" class="glass-card p-5 sm:p-7">
          <span class="block font-bold text-slate-700 mb-3">ภาพกิจกรรม ({{ photos.length }})</span>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <button v-for="(p, i) in photos" :key="p.url" type="button" @click="lightbox = i"
              class="relative aspect-[4/3] rounded-xl overflow-hidden bg-slate-100 group">
              <img :src="p.url" :alt="p.caption || `ภาพที่ ${i + 1}`" loading="lazy"
                class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"/>
              <span v-if="p.caption"
                class="absolute inset-x-0 bottom-0 text-[11px] text-white bg-black/50 px-2 py-1 text-left line-clamp-1">
                {{ p.caption }}
              </span>
            </button>
          </div>
          <p class="text-xs text-slate-400 mt-2">กดที่ภาพเพื่อดูเต็มใบ</p>
        </div>

        <div v-if="(item.links || []).length" class="glass-card p-5 sm:p-7">
          <span class="block font-bold text-slate-700 mb-3">เอกสาร/สื่อที่เกี่ยวข้อง</span>
          <ul class="space-y-2">
            <li v-for="(l, i) in item.links" :key="i">
              <a :href="l.url" target="_blank" rel="noopener noreferrer"
                class="flex items-center gap-2 text-sm text-slate-600 hover:text-primary transition-colors break-all">
                <span class="flex-shrink-0">{{ LINK_ICON[l.kind || linkKind(l.url)] }}</span>
                <span class="font-medium">{{ l.label || l.url }}</span>
              </a>
            </li>
          </ul>
        </div>

        <span class="block text-center text-xs text-slate-300 pb-6">{{ config?.area_name }}</span>
      </template>
    </div>

    <PhotoLightbox :photos="photos" :index="lightbox"
      @update:index="lightbox = $event" @close="lightbox = -1"/>
  </div>
</template>
