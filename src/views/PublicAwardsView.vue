<script setup>
/**
 * PublicAwardsView — หน้าสาธารณะ /awards
 * อ่านจาก view awards_public (มีแต่ที่อนุมัติแล้ว + join ศูนย์เครือข่าย/อำเภอ)
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import PageHero from '../components/PageHero.vue'
import {
  OWNER_KINDS, AWARD_LEVELS, AWARD_RANK_GROUPS,
  ownerKindMeta, levelMeta, rankMeta, rankLabel, iconMeta, fmtDate,
} from '../composables/useAwards'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('awards', { icon: 'trophy', title: 'ผลงานและรางวัล', align: 'center' })

const rows = ref([])
const loading = ref(true)
const ready = ref(false)

const fKind = ref('all'); const fLevel = ref('all')
const fRank = ref('all'); const fYear = ref('all')
const searchQ = ref('')

const enabled = computed(() => config.value?.show_public_awards !== false)

onMounted(async () => {
  await fetchConfig()
  ready.value = true
  if (!enabled.value) { loading.value = false; return }
  const { data } = await supabase.from('awards_public').select('*').order('awarded_date', { ascending: false, nullsFirst: false })
  rows.value = data || []
  loading.value = false
})

const years = computed(() => [...new Set(rows.value.map(r => r.academic_year).filter(Boolean))].sort().reverse())
const filtered = computed(() => {
  const q = searchQ.value.trim().toLowerCase()
  return rows.value.filter(a =>
    (fKind.value === 'all' || a.owner_kind === fKind.value) &&
    (fLevel.value === 'all' || a.level === fLevel.value) &&
    (fRank.value === 'all' || a.award_rank === fRank.value) &&
    (fYear.value === 'all' || a.academic_year === fYear.value) &&
    (!q || `${a.title} ${a.owner_label} ${a.issuer}`.toLowerCase().includes(q)))
})
const selCls = 'px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary'
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero v-if="!header.hidden" :title="header.title"
      :subtitle="header.subtitle || `${config?.area_name} · ${rows.length.toLocaleString()} รางวัล`"
      :mode="header.mode" :icon="header.icon" :media-url="header.mediaUrl" :media-type="header.mediaType"
      :aspect-ratio="header.aspectRatio" :align="header.align" max-width="5xl"/>

    <div v-if="ready && !enabled" class="max-w-lg mx-auto px-4 py-24 text-center">
      <span class="block text-4xl mb-3">🔒</span>
      <span class="block font-bold text-slate-700">ยังไม่เปิดให้ดูรางวัลสาธารณะ</span>
    </div>

    <div v-else class="max-w-5xl mx-auto px-4 py-6 space-y-5">
      <div class="max-w-lg mx-auto">
        <input v-model="searchQ" placeholder="ค้นหาชื่อรางวัล / ผู้รับ / หน่วยงานที่มอบ…"
          class="w-full px-4 py-3 rounded-2xl border border-slate-200 bg-white/70 backdrop-blur text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"/>
      </div>

      <div class="flex flex-wrap gap-2 justify-center">
        <select v-model="fKind" :class="selCls">
          <option value="all">ทุกประเภทผู้รับ</option>
          <option v-for="k in OWNER_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
        </select>
        <select v-model="fLevel" :class="selCls">
          <option value="all">ทุกระดับ</option>
          <option v-for="l in AWARD_LEVELS" :key="l.value" :value="l.value">{{ l.label }}</option>
        </select>
        <select v-model="fRank" :class="selCls">
          <option value="all">ทุกชนิดรางวัล</option>
          <optgroup v-for="g in AWARD_RANK_GROUPS" :key="g.label" :label="g.label">
            <option v-for="r in g.items" :key="r.value" :value="r.value">{{ r.label }}</option>
          </optgroup>
        </select>
        <select v-if="years.length" v-model="fYear" :class="selCls">
          <option value="all">ทุกปีการศึกษา</option>
          <option v-for="y in years" :key="y" :value="y">ปี {{ y }}</option>
        </select>
      </div>

      <div class="text-center text-sm text-slate-500">แสดง {{ filtered.length.toLocaleString() }} จาก {{ rows.length.toLocaleString() }} รางวัล</div>

      <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>
      <div v-else-if="!filtered.length" class="text-center py-16 text-slate-400">
        <span class="block text-4xl mb-3 opacity-40">🏆</span>
        <span class="block font-bold">ไม่พบรางวัลที่ตรงกัน</span>
      </div>

      <div v-else class="space-y-2">
        <div v-for="a in filtered" :key="a.id" class="glass-tile p-3.5 flex items-start gap-3">
          <div class="w-11 h-11 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
            <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" stroke-width="1.6" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" :d="iconMeta(a.icon).path"/>
            </svg>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-1.5 mb-1">
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', rankMeta(a.award_rank).bg, rankMeta(a.award_rank).text]">{{ rankLabel(a) }}</span>
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', levelMeta(a.level).bg, levelMeta(a.level).text]">{{ levelMeta(a.level).short }}</span>
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', ownerKindMeta(a.owner_kind).bg, ownerKindMeta(a.owner_kind).text]">{{ ownerKindMeta(a.owner_kind).label }}</span>
            </div>
            <a v-if="a.link_url" :href="a.link_url" target="_blank" rel="noopener"
              class="font-bold text-slate-800 hover:text-primary hover:underline break-words">{{ a.title }} <span class="text-primary text-xs">↗</span></a>
            <span v-else class="block font-bold text-slate-800 break-words">{{ a.title }}</span>
            <span class="block text-xs text-slate-500 mt-0.5">
              {{ a.owner_label }}
              <template v-if="a.school_group"> · ศูนย์ {{ a.school_group }}</template>
              <template v-if="a.issuer"> · มอบโดย {{ a.issuer }}</template>
              <template v-if="a.academic_year"> · ปี {{ a.academic_year }}</template>
            </span>
            <div v-if="(a.members||[]).length" class="flex flex-wrap gap-1 mt-1.5">
              <span v-for="(m, i) in a.members" :key="i" class="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full">{{ m.name }}</span>
            </div>
          </div>
          <span v-if="a.awarded_date" class="text-[11px] text-slate-400 flex-shrink-0">{{ fmtDate(a.awarded_date) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
