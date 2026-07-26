<script setup>
/**
 * AdminAwardsApproveView — คิวอนุมัติรางวัล (ศน. ขึ้นไป)
 * ใช้ RPC review_award เท่านั้น — ไม่ UPDATE ตรง เพราะ trigger awards_before_update
 * คืนค่า status เดิมเสมอสำหรับ client (ตั้งใจให้เปลี่ยนสถานะได้ทางเดียว)
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import {
  ownerKindMeta, levelMeta, rankMeta, rankLabel, iconMeta, fmtDate,
  AWARD_REVIEWER_ROLES,
} from '../../composables/useAwards'

const items   = ref([])
const loading = ref(true)
const working = ref('')
const myRole  = ref('')
const tab     = ref('pending')

const canReview = computed(() => AWARD_REVIEWER_ROLES.includes(myRole.value))

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    myRole.value = p?.role || ''
  }
  const { data } = await supabase.from('awards').select('*').order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
}
onMounted(load)

const counts = computed(() => ({
  pending:  items.value.filter(a => a.status === 'pending').length,
  approved: items.value.filter(a => a.status === 'approved').length,
  rejected: items.value.filter(a => a.status === 'rejected').length,
}))
const filtered = computed(() => items.value.filter(a => tab.value === 'all' || a.status === tab.value))

async function review(a, status) {
  let reason = ''
  if (status === 'rejected') {
    const res = await Swal.fire({
      title: 'ตีกลับรายการนี้?', input: 'textarea',
      inputLabel: 'เหตุผล (ผู้ส่งจะเห็นข้อความนี้)',
      inputPlaceholder: 'เช่น ลิงก์เกียรติบัตรเปิดไม่ได้ / ข้อมูลไม่ครบ',
      showCancelButton: true, confirmButtonText: 'ตีกลับ', cancelButtonText: 'ยกเลิก',
      confirmButtonColor: '#ef4444',
      inputValidator: v => !v?.trim() && 'กรุณาระบุเหตุผลเพื่อให้ผู้ส่งแก้ไขได้ถูก',
    })
    if (!res.isConfirmed) return
    reason = res.value
  }
  working.value = a.id
  const { error } = await supabase.rpc('review_award', { p_id: a.id, p_status: status, p_reason: reason })
  working.value = ''
  if (error) return Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message })
  await load()
  Swal.fire({ icon: 'success', title: status === 'approved' ? 'อนุมัติแล้ว' : 'ตีกลับแล้ว', timer: 1000, showConfirmButton: false })
}
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div>
      <h1 class="text-2xl font-extrabold text-slate-800">✅ อนุมัติรางวัล</h1>
      <span class="block text-sm text-slate-500 mt-0.5">ตรวจรายการที่โรงเรียนและครูส่งเข้ามาก่อนขึ้นหน้าสาธารณะ</span>
    </div>

    <div v-if="!loading && !canReview" class="glass-card p-8 text-center text-slate-500">
      <span class="block text-3xl mb-2">🔒</span>
      <span class="block font-bold">คุณไม่มีสิทธิ์อนุมัติรางวัล</span>
      <span class="block text-xs mt-1">เฉพาะศึกษานิเทศก์และผู้ดูแลระบบเท่านั้น</span>
    </div>

    <template v-else>
      <div class="flex gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl w-fit">
        <button v-for="t in [{k:'pending',l:`รออนุมัติ (${counts.pending})`},{k:'approved',l:`เผยแพร่ (${counts.approved})`},{k:'rejected',l:`ตีกลับ (${counts.rejected})`},{k:'all',l:'ทั้งหมด'}]"
          :key="t.k" @click="tab = t.k"
          :class="['px-3 py-1.5 text-sm font-bold rounded-lg transition-colors',
            tab === t.k ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          {{ t.l }}
        </button>
      </div>

      <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>
      <div v-else-if="!filtered.length" class="glass-card p-10 text-center text-slate-500">
        <span class="block text-3xl mb-2">✅</span>
        <span class="block font-medium">{{ tab === 'pending' ? 'ไม่มีรายการรออนุมัติ' : 'ไม่มีรายการ' }}</span>
      </div>

      <div v-else class="space-y-3">
        <div v-for="a in filtered" :key="a.id" class="glass-card p-4 flex items-start gap-3">
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
              <span class="text-[11px] text-slate-400">{{ fmtDate(a.created_at) }}</span>
            </div>
            <span class="block font-bold text-slate-800">{{ a.title }}</span>
            <span class="block text-xs text-slate-500 mt-0.5">
              {{ a.owner_label }}<template v-if="a.issuer"> · มอบโดย {{ a.issuer }}</template>
              <template v-if="a.academic_year"> · ปี {{ a.academic_year }}</template>
            </span>
            <div v-if="(a.members||[]).length" class="flex flex-wrap gap-1 mt-1.5">
              <span v-for="(m, i) in a.members" :key="i" class="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full">{{ m.name }}</span>
            </div>
            <a v-if="a.link_url" :href="a.link_url" target="_blank" rel="noopener"
              class="inline-block mt-1.5 text-xs font-bold text-primary hover:underline">เปิดเกียรติบัตร/ผลงาน →</a>
            <span v-if="a.status === 'rejected' && a.reject_reason"
              class="block text-xs text-red-600 bg-red-50 rounded-lg px-2.5 py-1.5 mt-2">เหตุผล: {{ a.reject_reason }}</span>
          </div>
          <div class="flex gap-2 flex-shrink-0">
            <button v-if="a.status !== 'approved'" @click="review(a, 'approved')" :disabled="working === a.id"
              class="px-3 py-1.5 text-xs font-bold text-white bg-emerald-600 rounded-lg hover:-translate-y-0.5 shadow-sm transition-all disabled:opacity-50">อนุมัติ</button>
            <button v-if="a.status !== 'rejected'" @click="review(a, 'rejected')" :disabled="working === a.id"
              class="px-3 py-1.5 text-xs font-bold text-red-600 bg-red-50 rounded-lg hover:bg-red-100 transition-colors disabled:opacity-50">ตีกลับ</button>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
