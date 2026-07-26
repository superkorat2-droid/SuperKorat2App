<script setup>
/**
 * AdminWorksApproveView — คิวอนุมัติผลงาน (ศน. ขึ้นไป)
 * ใช้ RPC review_work เท่านั้น — ไม่ UPDATE ตรง เพราะ RLS ไม่ให้ ศน. แก้แถวของคนอื่น
 * (ตั้งใจ: อนุมัติได้ แต่ไม่แก้เนื้อหาคนอื่น)
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import SvgIcon from '../../components/SvgIcon.vue'
import { workTypeMeta, workStatusMeta, fmtDate, REVIEWER_ROLES } from '../../composables/useWorks'

const items    = ref([])
const owners   = ref({})
const loading  = ref(true)
const working  = ref('')
const myRole   = ref('')
const tab      = ref('pending')

const canReview = computed(() => REVIEWER_ROLES.includes(myRole.value))

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  if (user?.id) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    myRole.value = p?.role || ''
  }
  const { data } = await supabase.from('works').select('*').order('created_at', { ascending: false })
  items.value = data || []

  const ids = [...new Set(items.value.map(w => w.owner_id).filter(Boolean))]
  if (ids.length) {
    const { data: ps } = await supabase.from('profiles')
      .select('id, full_name, first_name, last_name, title, position').in('id', ids)
    owners.value = Object.fromEntries((ps || []).map(p => [p.id, p]))
  }
  loading.value = false
}
onMounted(load)

function ownerName(id) {
  const p = owners.value[id]
  if (!p) return '—'
  const n = `${p.title || ''}${p.first_name || ''}${p.last_name ? ' ' + p.last_name : ''}`.trim()
  return n || p.full_name || '—'
}

const filtered = computed(() => items.value.filter(w => tab.value === 'all' || w.status === tab.value))
const counts = computed(() => ({
  pending:  items.value.filter(w => w.status === 'pending').length,
  approved: items.value.filter(w => w.status === 'approved').length,
  rejected: items.value.filter(w => w.status === 'rejected').length,
}))

async function review(w, status) {
  let reason = ''
  if (status === 'rejected') {
    const res = await Swal.fire({
      title: 'ตีกลับผลงานนี้?', input: 'textarea',
      inputLabel: 'เหตุผล (ผู้ส่งจะเห็นข้อความนี้)',
      inputPlaceholder: 'เช่น ขาดเอกสารแนบ / ข้อมูลไม่ครบ',
      showCancelButton: true, confirmButtonText: 'ตีกลับ', cancelButtonText: 'ยกเลิก',
      confirmButtonColor: '#ef4444',
      inputValidator: v => !v?.trim() && 'กรุณาระบุเหตุผลเพื่อให้ผู้ส่งแก้ไขได้ถูก',
    })
    if (!res.isConfirmed) return
    reason = res.value
  }

  working.value = w.id
  const { error } = await supabase.rpc('review_work', { p_id: w.id, p_status: status, p_reason: reason })
  working.value = ''
  if (error) return Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message })
  await load()
  Swal.fire({
    icon: 'success', title: status === 'approved' ? 'อนุมัติแล้ว' : 'ตีกลับแล้ว',
    timer: 1000, showConfirmButton: false,
  })
}
</script>

<template>
  <div class="font-sarabun space-y-5">
    <div>
      <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
        <SvgIcon name="clipboard" class="w-6 h-6 text-primary"/>
        อนุมัติผลงาน
      </h1>
      <p class="text-sm text-slate-500 mt-0.5">ตรวจผลงานที่ครูและโรงเรียนส่งเข้ามาก่อนขึ้นหน้าสาธารณะ</p>
    </div>

    <div v-if="!loading && !canReview" class="glass-card p-8 text-center text-slate-500">
      <p class="text-3xl mb-2">🔒</p>
      <p class="font-bold">คุณไม่มีสิทธิ์อนุมัติผลงาน</p>
      <p class="text-xs mt-1">เฉพาะศึกษานิเทศก์และผู้ดูแลระบบเท่านั้น</p>
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
        <p class="text-3xl mb-2">✅</p>
        <p class="font-medium">{{ tab === 'pending' ? 'ไม่มีผลงานรออนุมัติ' : 'ไม่มีรายการ' }}</p>
      </div>

      <div v-else class="space-y-3">
        <div v-for="w in filtered" :key="w.id" class="glass-card p-4">
          <div class="flex flex-wrap items-start gap-3">
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-1.5">
                <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', workTypeMeta(w.work_type).bg, workTypeMeta(w.work_type).text]">
                  {{ workTypeMeta(w.work_type).icon }} {{ workTypeMeta(w.work_type).label }}
                </span>
                <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', workStatusMeta(w.status).bg, workStatusMeta(w.status).text]">
                  {{ workStatusMeta(w.status).label }}
                </span>
                <span class="text-xs text-slate-500">{{ fmtDate(w.created_at) }}</span>
              </div>
              <h3 class="font-bold text-slate-800">{{ w.title }}</h3>
              <p v-if="w.description" class="text-xs text-slate-500 line-clamp-2 mt-0.5">{{ w.description }}</p>
              <p class="text-xs text-slate-500 mt-1">
                ผู้ส่ง: <b>{{ ownerName(w.owner_id) }}</b>
                <span v-if="w.school_name"> · {{ w.school_name }}</span>
                <a v-if="w.file_url" :href="w.file_url" target="_blank" rel="noopener" class="ml-2 font-bold text-primary hover:underline">เปิดไฟล์ →</a>
              </p>
              <p v-if="w.status === 'rejected' && w.reject_reason"
                class="text-xs text-red-600 bg-red-50 rounded-lg px-2.5 py-1.5 mt-2">เหตุผล: {{ w.reject_reason }}</p>
            </div>

            <div class="flex gap-2 flex-shrink-0">
              <button v-if="w.status !== 'approved'" @click="review(w, 'approved')" :disabled="working === w.id"
                class="px-3 py-1.5 text-xs font-bold text-white bg-emerald-600 rounded-lg hover:-translate-y-0.5 shadow-sm transition-all disabled:opacity-50">
                อนุมัติ
              </button>
              <button v-if="w.status !== 'rejected'" @click="review(w, 'rejected')" :disabled="working === w.id"
                class="px-3 py-1.5 text-xs font-bold text-red-600 bg-red-50 rounded-lg hover:bg-red-100 transition-colors disabled:opacity-50">
                ตีกลับ
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
