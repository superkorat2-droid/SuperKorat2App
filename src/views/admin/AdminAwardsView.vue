<script setup>
/**
 * AdminAwardsView — รายการผลงานและรางวัล
 * ใช้ไฟล์เดียวกันทั้งหลังบ้านเขต (/dashboard/awards) และ portal โรงเรียน (/school/awards)
 * เพราะ router guard เด้ง role school ออกจาก /dashboard — คิด path ปลายทางจาก route เอง
 * (บทเรียนจากตอนทำ works ที่ประกาศสิทธิ์ให้ school ไว้แต่เข้าไม่ถึง)
 */
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import {
  OWNER_KINDS, AWARD_LEVELS, AWARD_RANK_GROUPS,
  ownerKindMeta, levelMeta, rankMeta, rankLabel, iconMeta, fmtDate,
  AWARD_AUTO_APPROVE_ROLES,
} from '../../composables/useAwards'

const route  = useRoute()
const router = useRouter()
const base = computed(() => route.path.startsWith('/school') ? '/school/awards' : '/dashboard/awards')

const items   = ref([])
const loading = ref(true)
const myId    = ref(null)
const myRole  = ref('')
const canManageAll = ref(false)

const fKind  = ref('all')
const fLevel = ref('all')
const fRank  = ref('all')
const fYear  = ref('all')
const fStatus= ref('all')
const searchQ = ref('')

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  myId.value = user?.id || null
  if (user?.id) {
    const { data: p } = await supabase.from('profiles')
      .select('role, can_manage_awards').eq('id', user.id).single()
    myRole.value = p?.role || ''
    canManageAll.value = AWARD_AUTO_APPROVE_ROLES.includes(p?.role) || p?.can_manage_awards === true
  }
  // RLS คุมอยู่แล้วว่าเห็นอะไรได้บ้าง ไม่ต้องกรองซ้ำที่นี่
  const { data } = await supabase.from('awards').select('*').order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
}
onMounted(load)

const years = computed(() =>
  [...new Set(items.value.map(a => a.academic_year).filter(Boolean))].sort().reverse())

const filtered = computed(() => {
  const q = searchQ.value.trim().toLowerCase()
  return items.value.filter(a =>
    (fKind.value  === 'all' || a.owner_kind === fKind.value) &&
    (fLevel.value === 'all' || a.level === fLevel.value) &&
    (fRank.value  === 'all' || a.award_rank === fRank.value) &&
    (fYear.value  === 'all' || a.academic_year === fYear.value) &&
    (fStatus.value=== 'all' || a.status === fStatus.value) &&
    (!q || `${a.title} ${a.owner_label} ${a.issuer}`.toLowerCase().includes(q))
  )
})

const stats = computed(() => ({
  total:    items.value.length,
  approved: items.value.filter(a => a.status === 'approved').length,
  pending:  items.value.filter(a => a.status === 'pending').length,
  hours:    items.value.reduce((s, a) => s + Number(a.training_hours || 0), 0),
}))

function canEdit(a) { return canManageAll.value || a.created_by === myId.value }

const isFiltered = computed(() =>
  searchQ.value.trim() || [fKind, fLevel, fRank, fYear, fStatus].some(f => f.value !== 'all'))
function resetFilter() {
  searchQ.value = ''
  ;[fKind, fLevel, fRank, fYear, fStatus].forEach(f => { f.value = 'all' })
}

async function del(a) {
  const res = await Swal.fire({
    title: 'ลบรายการนี้?', text: a.title, icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('awards').delete().eq('id', a.id)
  if (error) return Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message })
  await load()
}
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">🏆 ผลงานและรางวัล</h1>
        <span class="block text-sm text-slate-500 mt-0.5">
          <template v-if="canManageAll">บันทึกได้ทันที ไม่ต้องรออนุมัติ · กรอกแทนโรงเรียนและครูได้</template>
          <template v-else>บันทึกแล้วรอศึกษานิเทศก์ตรวจสอบก่อนแสดงบนเว็บ</template>
        </span>
      </div>
      <button @click="router.push(`${base}/new`)"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        + เพิ่มรางวัล
      </button>
    </div>

    <!-- สถิติย่อ -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="glass-tile p-4 text-center"><span class="block text-2xl font-extrabold text-slate-800">{{ stats.total }}</span><span class="block text-xs text-slate-500">ทั้งหมด</span></div>
      <div class="glass-tile p-4 text-center"><span class="block text-2xl font-extrabold text-emerald-600">{{ stats.approved }}</span><span class="block text-xs text-slate-500">เผยแพร่แล้ว</span></div>
      <div class="glass-tile p-4 text-center"><span class="block text-2xl font-extrabold text-amber-600">{{ stats.pending }}</span><span class="block text-xs text-slate-500">รออนุมัติ</span></div>
      <div class="glass-tile p-4 text-center"><span class="block text-2xl font-extrabold text-primary">{{ stats.hours.toLocaleString() }}</span><span class="block text-xs text-slate-500">ชั่วโมงอบรมรวม</span></div>
    </div>

    <!-- ตัวกรอง -->
    <div class="flex flex-wrap items-center gap-2">
      <input v-model="searchQ" placeholder="ค้นหาชื่อรางวัล / เจ้าของ / หน่วยงานที่มอบ…"
        class="flex-1 min-w-[200px] px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm focus:outline-none focus:border-primary"/>
      <select v-model="fKind" class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600">
        <option value="all">ทุกประเภทผู้รับ</option>
        <option v-for="k in OWNER_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
      </select>
      <select v-model="fLevel" class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600">
        <option value="all">ทุกระดับ</option>
        <option v-for="l in AWARD_LEVELS" :key="l.value" :value="l.value">{{ l.label }}</option>
      </select>
      <select v-model="fRank" class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600">
        <option value="all">ทุกชนิดรางวัล</option>
        <optgroup v-for="g in AWARD_RANK_GROUPS" :key="g.label" :label="g.label">
          <option v-for="r in g.items" :key="r.value" :value="r.value">{{ r.label }}</option>
        </optgroup>
      </select>
      <select v-if="years.length" v-model="fYear" class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600">
        <option value="all">ทุกปีการศึกษา</option>
        <option v-for="y in years" :key="y" :value="y">ปี {{ y }}</option>
      </select>
      <select v-model="fStatus" class="px-3 py-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-sm text-slate-600">
        <option value="all">ทุกสถานะ</option>
        <option value="approved">เผยแพร่แล้ว</option>
        <option value="pending">รออนุมัติ</option>
        <option value="rejected">ถูกตีกลับ</option>
      </select>
      <button v-if="isFiltered" @click="resetFilter" class="text-sm text-slate-400 hover:text-red-500 px-2 py-2">ล้าง</button>
    </div>

    <div class="text-sm text-slate-500">แสดง {{ filtered.length.toLocaleString() }} จาก {{ items.length.toLocaleString() }} รายการ</div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>
    <div v-else-if="!filtered.length" class="glass-card p-10 text-center text-slate-500">
      <span class="block text-3xl mb-2">🏆</span>
      <span class="block font-medium">{{ isFiltered ? 'ไม่พบรายการที่ตรงกัน' : 'ยังไม่มีรางวัล' }}</span>
      <button v-if="isFiltered" @click="resetFilter" class="mt-2 text-sm text-primary hover:underline">ล้างตัวกรอง</button>
    </div>

    <!-- รายการ -->
    <div v-else class="space-y-2">
      <div v-for="a in filtered" :key="a.id" class="glass-card p-3.5 flex items-start gap-3">
        <div class="w-11 h-11 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
          <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" stroke-width="1.6" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" :d="iconMeta(a.icon).path"/>
          </svg>
        </div>

        <div class="flex-1 min-w-0">
          <div class="flex flex-wrap items-center gap-1.5 mb-1">
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', rankMeta(a.award_rank).bg, rankMeta(a.award_rank).text]">
              {{ rankLabel(a) }}
            </span>
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', levelMeta(a.level).bg, levelMeta(a.level).text]">
              {{ levelMeta(a.level).short }}
            </span>
            <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', ownerKindMeta(a.owner_kind).bg, ownerKindMeta(a.owner_kind).text]">
              {{ ownerKindMeta(a.owner_kind).label }}
            </span>
            <span v-if="a.is_group" class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">กลุ่ม {{ (a.members||[]).length }} คน</span>
            <span v-if="a.is_training" class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-teal-100 text-teal-700">อบรม {{ a.training_hours }} ชม.</span>
            <span v-if="a.status !== 'approved'"
              :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', a.status === 'pending' ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-600']">
              {{ a.status === 'pending' ? 'รออนุมัติ' : 'ถูกตีกลับ' }}
            </span>
          </div>

          <!-- ชื่อรางวัลเป็นลิงก์เปิดผลงาน/เกียรติบัตรได้เลย -->
          <a v-if="a.link_url" :href="a.link_url" target="_blank" rel="noopener"
            class="font-bold text-slate-800 hover:text-primary hover:underline break-words">
            {{ a.title }} <span class="text-primary text-xs">↗</span>
          </a>
          <span v-else class="block font-bold text-slate-800 break-words">{{ a.title }}</span>

          <span class="block text-xs text-slate-500 mt-0.5 truncate">
            {{ a.owner_label || '—' }}
            <template v-if="a.issuer"> · มอบโดย {{ a.issuer }}</template>
            <template v-if="a.academic_year"> · ปี {{ a.academic_year }}</template>
            <template v-if="a.awarded_date"> · {{ fmtDate(a.awarded_date) }}</template>
          </span>
          <span v-if="a.status === 'rejected' && a.reject_reason"
            class="block text-xs text-red-600 bg-red-50 rounded-lg px-2.5 py-1.5 mt-1.5">เหตุผล: {{ a.reject_reason }}</span>
        </div>

        <div v-if="canEdit(a)" class="flex gap-1.5 flex-shrink-0">
          <button @click="router.push(`${base}/${a.id}/edit`)"
            class="px-2.5 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-lg hover:bg-primary/20 transition-colors">แก้ไข</button>
          <button @click="del(a)"
            class="px-2.5 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-lg hover:bg-red-100 transition-colors">ลบ</button>
        </div>
      </div>
    </div>
  </div>
</template>
