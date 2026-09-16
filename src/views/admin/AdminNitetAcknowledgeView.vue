<script setup>
/**
 * AdminNitetAcknowledgeView — คิวรับทราบบันทึกการนิเทศ (ผอ.กลุ่มนิเทศ)
 *
 * ใช้ RPC acknowledge_nithet_visit เท่านั้น — ไม่ UPDATE ตรง เพราะ trigger
 * nithet_visits_before_update คืนค่า ack_status เดิมเสมอสำหรับ client (migration 0078)
 * ลอกโครงจาก AdminAwardsApproveView.vue
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import { placeOf, fmtDate, visitTypeLabel } from '../../composables/useNithetVisits'

const items   = ref([])
const schools = ref({})
const people  = ref({})
const loading = ref(true)
const working = ref('')
const myRole  = ref('')
const myCanApprove = ref(false)
const tab     = ref('pending')

const canReview = computed(() => ['super_admin', 'admin'].includes(myRole.value) || myCanApprove.value)

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles')
      .select('role, can_approve_nithet').eq('id', user.id).single()
    myRole.value = p?.role || ''
    myCanApprove.value = !!p?.can_approve_nithet
  }

  // เฉพาะบันทึกสมบูรณ์ — ร่างยังไม่ต้องรอรับทราบ (ยังไม่เข้ารายงาน A4 อยู่แล้ว)
  const { data } = await supabase.from('nithet_visits')
    .select('*').eq('status', 'final').order('visit_date', { ascending: false })
  items.value = data || []

  const schoolIds = [...new Set(items.value.map(r => r.school_id).filter(Boolean))]
  if (schoolIds.length) {
    const { data: ss } = await supabase.from('schools').select('id, name, district').in('id', schoolIds)
    schools.value = Object.fromEntries((ss || []).map(s => [s.id, s]))
  }
  const peopleIds = [...new Set([
    ...items.value.map(r => r.created_by),
    ...items.value.map(r => r.acknowledged_by),
  ].filter(Boolean))]
  if (peopleIds.length) {
    const { data: pp } = await supabase.from('profiles')
      .select('id, title, first_name, last_name, full_name').in('id', peopleIds)
    people.value = Object.fromEntries((pp || []).map(p => [p.id,
      (p.full_name || '').trim() || [p.title, p.first_name, p.last_name].filter(Boolean).join(' ') || '—']))
  }
  loading.value = false
}
onMounted(load)

function decorate(r) {
  const s = schools.value[r.school_id]
  return { ...r, school_name: s?.name, district: s?.district }
}
const decorated = computed(() => items.value.map(decorate))

const counts = computed(() => ({
  pending:      decorated.value.filter(r => r.ack_status === 'pending').length,
  acknowledged: decorated.value.filter(r => r.ack_status === 'acknowledged').length,
}))
const filtered = computed(() =>
  decorated.value.filter(r => tab.value === 'all' || r.ack_status === tab.value))

async function acknowledge(r) {
  const res = await Swal.fire({
    title: 'รับทราบบันทึกนี้?',
    input: 'textarea',
    inputLabel: 'ข้อเสนอแนะ (ไม่ใส่ก็ได้ — เจ้าของบันทึกจะเห็นข้อความนี้)',
    inputPlaceholder: 'เช่น เยี่ยมมาก ให้ติดตามผลต่อเนื่องรอบหน้า',
    showCancelButton: true, confirmButtonText: 'รับทราบ', cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#059669',
  })
  if (!res.isConfirmed) return
  working.value = r.id
  const { error } = await supabase.rpc('acknowledge_nithet_visit', { p_id: r.id, p_note: res.value || '' })
  working.value = ''
  if (error) return Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message })
  await load()
  Swal.fire({ icon: 'success', title: 'รับทราบแล้ว', timer: 1000, showConfirmButton: false })
}
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div>
      <h1 class="text-2xl font-extrabold text-slate-800">✅ รับทราบบันทึกการนิเทศ</h1>
      <span class="block text-sm text-slate-500 mt-0.5">
        ตรวจบันทึกที่ ศน. กรอกสมบูรณ์แล้ว — ต้องรับทราบก่อนถึงจะพิมพ์รายงาน A4 ได้
      </span>
    </div>

    <div v-if="!loading && !canReview" class="glass-card p-8 text-center text-slate-500">
      <span class="block text-3xl mb-2">🔒</span>
      <span class="block font-bold">คุณไม่มีสิทธิ์รับทราบบันทึกการนิเทศ</span>
      <span class="block text-xs mt-1">เฉพาะ ผอ.กลุ่มนิเทศ และผู้ดูแลระบบเท่านั้น</span>
    </div>

    <template v-else>
      <div class="flex gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl w-fit">
        <button v-for="t in [
            { k: 'pending',      l: `รอรับทราบ (${counts.pending})` },
            { k: 'acknowledged', l: `รับทราบแล้ว (${counts.acknowledged})` },
            { k: 'all',          l: 'ทั้งหมด' }]"
          :key="t.k" @click="tab = t.k" type="button"
          :class="['px-3 py-1.5 text-sm font-bold rounded-lg transition-colors',
            tab === t.k ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          {{ t.l }}
        </button>
      </div>

      <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>
      <div v-else-if="!filtered.length" class="glass-card p-10 text-center text-slate-500">
        <span class="block text-3xl mb-2">✅</span>
        <span class="block font-medium">{{ tab === 'pending' ? 'ไม่มีรายการรอรับทราบ' : 'ไม่มีรายการ' }}</span>
      </div>

      <div v-else class="space-y-3">
        <div v-for="r in filtered" :key="r.id" class="glass-card p-4 flex items-start gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-1.5 mb-1">
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full',
                r.ack_status === 'acknowledged' ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700']">
                {{ r.ack_status === 'acknowledged' ? 'รับทราบแล้ว' : 'รอรับทราบ' }}
              </span>
              <span class="text-[11px] text-slate-400">{{ fmtDate(r.visit_date) }} · {{ visitTypeLabel(r) }}</span>
            </div>
            <span class="block font-bold text-slate-800">{{ r.title || '(ยังไม่ได้ใส่เรื่อง)' }}</span>
            <span class="block text-xs text-slate-500 mt-0.5">
              📍 {{ placeOf(r) }} · ผู้บันทึก: {{ people[r.created_by] || '—' }}
            </span>
            <div v-if="r.topics?.length" class="flex flex-wrap gap-1 mt-1.5">
              <span v-for="t in r.topics.slice(0, 4)" :key="t"
                class="text-[10px] px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">{{ t }}</span>
            </div>
            <span v-if="r.ack_status === 'acknowledged'"
              class="block text-xs text-slate-600 bg-emerald-50 rounded-lg px-2.5 py-1.5 mt-2">
              รับทราบโดย {{ people[r.acknowledged_by] || '—' }} · {{ fmtDate(r.acknowledged_at) }}
              <template v-if="r.ack_note"><br/>ข้อเสนอแนะ: {{ r.ack_note }}</template>
            </span>
          </div>
          <div class="flex gap-2 flex-shrink-0">
            <button v-if="r.ack_status !== 'acknowledged'" @click="acknowledge(r)" :disabled="working === r.id"
              class="px-3 py-1.5 text-xs font-bold text-white bg-emerald-600 rounded-lg hover:-translate-y-0.5 shadow-sm transition-all disabled:opacity-50">
              รับทราบ
            </button>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
