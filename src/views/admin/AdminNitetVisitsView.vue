<script setup>
/**
 * AdminNitetVisitsView — รายการบันทึกการนิเทศ
 *
 * แท็บ "ร่างค้าง" ขึ้นก่อนเสมอ เพราะโหมดบันทึกด่วนตั้งใจให้กรอกไม่ครบตอนอยู่หน้างาน
 * ถ้าไม่เตือนจะลืมกลับมาเติม
 *
 * RLS คัดให้แล้วว่าใครเห็นแถวไหน (ศน. เห็น final ทุกคน แต่เห็นร่างเฉพาะของตัวเอง)
 * ที่นี่จึงไม่ต้องใส่เงื่อนไขซ้ำ
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import {
  VISIT_TYPES, typeColor, visitTypeLabel, statusMeta, followupMeta,
  placeOf, coverOf, photoCount, fmtDate, isOverdue, currentAcademicYear,
} from '../../composables/useNithetVisits'

const rows     = ref([])
const schools  = ref({})
const people   = ref({})
const loading  = ref(true)
const myId     = ref('')
const myRole   = ref('')

const tab        = ref('draft')
const searchQ    = ref('')
const filterType = ref('all')
const filterMine = ref(false)
const filterFrom = ref('')
const filterTo   = ref('')

const isAdmin = computed(() => ['super_admin', 'admin'].includes(myRole.value))

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  myId.value = user?.id || ''
  if (user) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    myRole.value = p?.role || ''
  }

  const { data } = await supabase.from('nithet_visits')
    .select('*').order('visit_date', { ascending: false })
  rows.value = data || []

  // ดึงชื่อโรงเรียนกับชื่อคนทีเดียวทั้งชุด ไม่ยิงทีละแถว
  const schoolIds = [...new Set(rows.value.map(r => r.school_id).filter(Boolean))]
  if (schoolIds.length) {
    const { data: ss } = await supabase.from('schools')
      .select('id, name, district, school_group').in('id', schoolIds)
    schools.value = Object.fromEntries((ss || []).map(s => [s.id, s]))
  }
  const ownerIds = [...new Set(rows.value.map(r => r.created_by).filter(Boolean))]
  if (ownerIds.length) {
    const { data: pp } = await supabase.from('profiles')
      .select('id, title, first_name, last_name, full_name').in('id', ownerIds)
    people.value = Object.fromEntries((pp || []).map(p => [p.id,
      (p.full_name || '').trim() || [p.title, p.first_name, p.last_name].filter(Boolean).join(' ') || '—']))
  }
  loading.value = false
}

onMounted(load)

function decorate(r) {
  const s = schools.value[r.school_id]
  return { ...r, school_name: s?.name, district: s?.district, school_group: s?.school_group }
}

const decorated = computed(() => rows.value.map(decorate))

const counts = computed(() => ({
  draft: decorated.value.filter(r => r.status === 'draft').length,
  all:   decorated.value.length,
  follow: decorated.value.filter(r => r.followup_status === 'open').length,
}))

const filtered = computed(() => {
  let list = decorated.value
  if (tab.value === 'draft')  list = list.filter(r => r.status === 'draft')
  if (tab.value === 'follow') list = list.filter(r => r.followup_status === 'open')
  if (filterType.value !== 'all') list = list.filter(r => r.visit_type === filterType.value)
  if (filterMine.value) list = list.filter(r => r.created_by === myId.value)
  if (filterFrom.value) list = list.filter(r => r.visit_date >= filterFrom.value)
  if (filterTo.value)   list = list.filter(r => r.visit_date <= filterTo.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) {
    list = list.filter(r =>
      (r.title || '').toLowerCase().includes(q) ||
      (r.school_name || '').toLowerCase().includes(q) ||
      (r.place_name || '').toLowerCase().includes(q) ||
      (r.topics || []).some(t => t.toLowerCase().includes(q)))
  }
  if (tab.value === 'follow') {
    return [...list].sort((a, b) => (a.followup_due || '9999').localeCompare(b.followup_due || '9999'))
  }
  return list
})

/** โรงเรียนที่ไปแล้วในชุดที่กรองอยู่ — นับเฉพาะที่เลือกโรงเรียนจริง */
const schoolsVisited = computed(() =>
  new Set(filtered.value.map(r => r.school_id).filter(Boolean)).size)

function canEdit(r) { return isAdmin.value || r.created_by === myId.value }

async function del(r) {
  const res = await Swal.fire({
    icon: 'warning', title: 'ลบบันทึกนี้?', text: r.title || placeOf(r),
    showCancelButton: true, confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#dc2626',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('nithet_visits').delete().eq('id', r.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  await load()
}

async function closeFollowup(r) {
  const res = await Swal.fire({
    title: 'ปิดการติดตามนี้?',
    input: 'textarea',
    inputLabel: 'ผลการติดตาม',
    inputPlaceholder: 'เช่น โรงเรียนดำเนินการแก้ไขแล้ว',
    showCancelButton: true, confirmButtonText: 'ปิดงาน', cancelButtonText: 'ยกเลิก',
    inputValidator: v => !v?.trim() && 'กรุณาระบุผลการติดตาม',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('nithet_visits')
    .update({ followup_status: 'done', followup_note: res.value }).eq('id', r.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message }); return }
  await load()
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">บันทึกการนิเทศ</h1>
        <span class="block text-xs text-slate-400 mt-0.5">
          ทั้งหมด {{ counts.all }} ครั้ง · ไปแล้ว {{ schoolsVisited }} โรงเรียน
          <template v-if="counts.draft"> · <b class="text-amber-600">ร่างค้าง {{ counts.draft }}</b></template>
        </span>
      </div>
      <div class="flex gap-2">
        <RouterLink to="/dashboard/nithet-visits-report"
          class="px-4 py-2.5 rounded-2xl text-sm font-bold border-2 border-primary text-primary hover:bg-slate-50 transition-all">
          พิมพ์รายงาน
        </RouterLink>
        <RouterLink to="/dashboard/nithet-visits/new"
          class="flex items-center gap-1.5 px-4 py-2.5 bg-primary text-white text-sm font-bold rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
          บันทึกใหม่
        </RouterLink>
      </div>
    </div>

    <div class="flex gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl w-fit">
      <button v-for="t in [
          { k: 'draft',  l: `ร่างค้าง (${counts.draft})` },
          { k: 'all',    l: `ทั้งหมด (${counts.all})` },
          { k: 'follow', l: `ติดตามข้อเสนอแนะ (${counts.follow})` }]"
        :key="t.k" @click="tab = t.k" type="button"
        :class="['px-3 py-1.5 text-sm font-bold rounded-lg transition-colors',
          tab === t.k ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        {{ t.l }}
      </button>
    </div>

    <div class="glass-card p-3 flex flex-wrap items-center gap-2">
      <input v-model="searchQ" type="search" placeholder="ค้นหาเรื่อง / โรงเรียน / ประเด็น"
        class="flex-1 min-w-[180px] px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <select v-model="filterType" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกประเภท</option>
        <option v-for="t in VISIT_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
      </select>
      <input v-model="filterFrom" type="date" title="ตั้งแต่วันที่"
        class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <input v-model="filterTo" type="date" title="ถึงวันที่"
        class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <label class="flex items-center gap-1.5 text-sm text-slate-600 cursor-pointer select-none">
        <input type="checkbox" v-model="filterMine" class="rounded border-slate-300"/> ของฉันเท่านั้น
      </label>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400 text-sm">กำลังโหลด...</div>
    <div v-else-if="!filtered.length" class="glass-card text-center py-16 text-slate-400 text-sm">
      {{ tab === 'draft' ? 'ไม่มีร่างค้าง' : tab === 'follow' ? 'ไม่มีข้อเสนอแนะที่รอติดตาม' : 'ยังไม่มีบันทึก' }}
    </div>

    <div v-else class="space-y-3">
      <div v-for="r in filtered" :key="r.id" class="glass-card p-4 flex flex-col sm:flex-row gap-4">
        <div class="w-full sm:w-40 aspect-[4/3] rounded-xl overflow-hidden bg-slate-100 flex-shrink-0">
          <img v-if="coverOf(r)" :src="coverOf(r)" :alt="r.title" class="w-full h-full object-cover" loading="lazy"/>
          <div v-else class="w-full h-full flex items-center justify-center text-3xl text-slate-300">📋</div>
        </div>

        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', typeColor(r.visit_type)]">{{ visitTypeLabel(r) }}</span>
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', statusMeta(r.status).bg, statusMeta(r.status).text]">
              {{ statusMeta(r.status).label }}
            </span>
            <span v-if="r.followup_status === 'open'"
              :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', isOverdue(r) ? 'bg-red-100 text-red-600' : followupMeta(r.followup_status).bg + ' ' + followupMeta(r.followup_status).text]">
              {{ isOverdue(r) ? 'เกินกำหนดติดตาม' : 'รอติดตาม' }}
            </span>
            <span v-if="r.is_public" class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-sky-100 text-sky-700">เผยแพร่</span>
          </div>

          <h3 class="font-bold text-slate-800 mt-1.5 leading-snug">{{ r.title || '(ยังไม่ได้ใส่เรื่อง)' }}</h3>
          <p class="text-xs text-slate-500 mt-0.5">🏫 {{ placeOf(r) }} · {{ fmtDate(r.visit_date) }}</p>

          <div v-if="r.topics?.length" class="flex flex-wrap gap-1 mt-1.5">
            <span v-for="t in r.topics.slice(0, 4)" :key="t"
              class="text-[10px] px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">{{ t }}</span>
          </div>

          <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-slate-400 mt-2">
            <span>ผู้บันทึก: {{ people[r.created_by] || '—' }}</span>
            <span v-if="photoCount(r)">📷 {{ photoCount(r) }} รูป</span>
            <span v-if="r.followup_due">ติดตามภายใน {{ fmtDate(r.followup_due) }}</span>
          </div>

          <p v-if="tab === 'follow' && r.followup_note"
            class="text-xs text-slate-600 bg-amber-50 rounded-lg px-2.5 py-1.5 mt-2">{{ r.followup_note }}</p>

          <div class="flex flex-wrap gap-2 mt-3">
            <RouterLink v-if="canEdit(r)" :to="`/dashboard/nithet-visits/${r.id}/edit`"
              class="px-3 py-1.5 rounded-xl bg-primary text-white text-xs font-bold">
              {{ r.status === 'draft' ? 'เติมให้ครบ' : 'แก้ไข' }}
            </RouterLink>
            <RouterLink :to="`/dashboard/nithet-visits-report?id=${r.id}`" title="พิมพ์เป็น A4 ใช้เป็นหลักฐานเบิกจ่าย"
              class="px-3 py-1.5 rounded-xl bg-slate-100 text-slate-600 text-xs font-bold hover:bg-slate-200">
              พิมพ์
            </RouterLink>
            <button v-if="tab === 'follow' && canEdit(r)" @click="closeFollowup(r)" type="button"
              class="px-3 py-1.5 rounded-xl bg-emerald-600 text-white text-xs font-bold">ปิดการติดตาม</button>
            <button v-if="canEdit(r)" @click="del(r)" type="button"
              class="px-3 py-1.5 rounded-xl text-red-500 text-xs font-bold hover:bg-red-50">ลบ</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
