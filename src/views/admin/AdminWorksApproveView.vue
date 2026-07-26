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
const subs     = ref([])      // ผลงานจากบุคคลภายนอก (ตาราง work_submissions)
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

  // RLS ให้เฉพาะ ศน. ขึ้นไปอ่านได้ — บทบาทอื่นจะได้ [] เอง ไม่ต้องเช็คซ้ำที่นี่
  const { data: sb } = await supabase.from('work_submissions').select('*').order('created_at', { ascending: false })
  subs.value = sb || []

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
const subsPending = computed(() => subs.value.filter(s => s.status === 'pending').length)
const counts = computed(() => ({
  pending:  items.value.filter(w => w.status === 'pending').length,
  approved: items.value.filter(w => w.status === 'approved').length,
  rejected: items.value.filter(w => w.status === 'rejected').length,
}))

/** ติ๊ก/ยกเลิกติ๊ก "ตรวจกับทะเบียนรับหนังสือแล้ว" โดยยังไม่ตัดสิน */
async function toggleVerify(sb) {
  working.value = sb.id
  const { error } = await supabase.rpc('review_work_submission', {
    p_id: sb.id, p_status: 'pending', p_reason: '', p_letter_verified: !sb.letter_verified,
  })
  working.value = ''
  if (error) return Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message })
  sb.letter_verified = !sb.letter_verified
}

async function reviewSub(sb, status) {
  let reason = ''
  if (status === 'rejected') {
    const res = await Swal.fire({
      title: 'ตีกลับผลงานจากภายนอก?', input: 'textarea',
      inputLabel: 'เหตุผล (บันทึกไว้ในระบบ ใช้อ้างอิงเวลาตอบหนังสือกลับ)',
      inputPlaceholder: 'เช่น ไม่พบหนังสือนำส่งในทะเบียนรับ / ลิงก์ผลงานเปิดไม่ได้',
      showCancelButton: true, confirmButtonText: 'ตีกลับ', cancelButtonText: 'ยกเลิก',
      confirmButtonColor: '#ef4444',
      inputValidator: v => !v?.trim() && 'กรุณาระบุเหตุผล',
    })
    if (!res.isConfirmed) return
    reason = res.value
  } else {
    if (!sb.letter_verified) {
      return Swal.fire({
        icon: 'warning', title: 'ยังไม่ได้ยืนยันหนังสือนำส่ง',
        text: 'กรุณาติ๊ก "ตรวจกับทะเบียนรับหนังสือแล้ว" ก่อนอนุมัติ',
      })
    }
    const res = await Swal.fire({
      icon: 'question', title: 'อนุมัติและเผยแพร่ผลงานนี้?',
      html: `ระบบจะสร้างผลงานขึ้นหน้าสาธารณะ<br/>เครดิต: <b>${sb.submitter_name} · ${sb.submitter_org}</b>`,
      showCancelButton: true, confirmButtonText: 'อนุมัติและเผยแพร่', cancelButtonText: 'ยกเลิก',
    })
    if (!res.isConfirmed) return
  }

  working.value = sb.id
  const { error } = await supabase.rpc('review_work_submission', {
    p_id: sb.id, p_status: status, p_reason: reason, p_letter_verified: null,
  })
  working.value = ''
  if (error) return Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message })
  await load()
  Swal.fire({
    icon: 'success', title: status === 'approved' ? 'อนุมัติและเผยแพร่แล้ว' : 'ตีกลับแล้ว',
    timer: 1200, showConfirmButton: false,
  })
}

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
        <button v-for="t in [{k:'pending',l:`รออนุมัติ (${counts.pending})`},{k:'approved',l:`เผยแพร่ (${counts.approved})`},{k:'rejected',l:`ตีกลับ (${counts.rejected})`},{k:'all',l:'ทั้งหมด'},{k:'external',l:`จากภายนอก (${subsPending})`}]"
          :key="t.k" @click="tab = t.k"
          :class="['px-3 py-1.5 text-sm font-bold rounded-lg transition-colors',
            tab === t.k ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          {{ t.l }}
        </button>
      </div>

      <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

      <!-- ══ ผลงานจากบุคคลภายนอกเขต ══════════════════════════════════ -->
      <template v-else-if="tab === 'external'">
        <div v-if="!subs.length" class="glass-card p-10 text-center text-slate-500">
          <p class="text-3xl mb-2">📮</p>
          <p class="font-medium">ยังไม่มีผลงานส่งเข้ามาจากภายนอก</p>
          <p class="text-xs mt-1">ลิงก์ฟอร์มสำหรับคนภายนอก: <code class="bg-slate-100 px-1.5 py-0.5 rounded">/submit-work</code></p>
        </div>
        <div v-else class="space-y-3">
          <div v-for="sb in subs" :key="sb.id" class="glass-card p-4">
            <div class="flex flex-wrap items-center gap-2 mb-2">
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', workTypeMeta(sb.work_type).bg, workTypeMeta(sb.work_type).text]">
                {{ workTypeMeta(sb.work_type).icon }} {{ workTypeMeta(sb.work_type).label }}
              </span>
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', workStatusMeta(sb.status).bg, workStatusMeta(sb.status).text]">
                {{ workStatusMeta(sb.status).label }}
              </span>
              <span class="text-xs text-slate-500">{{ fmtDate(sb.created_at) }}</span>
              <span v-if="sb.letter_verified" class="text-xs font-bold text-emerald-700 bg-emerald-50 px-2.5 py-0.5 rounded-full">
                ✓ ตรวจหนังสือแล้ว
              </span>
            </div>

            <h3 class="font-bold text-slate-800">{{ sb.title }}</h3>
            <p v-if="sb.description" class="text-xs text-slate-500 mt-0.5">{{ sb.description }}</p>

            <!-- ผู้ส่ง -->
            <div class="grid sm:grid-cols-2 gap-x-4 gap-y-1 mt-3 text-xs text-slate-600">
              <p><span class="text-slate-400">ผู้ส่ง:</span> <b>{{ sb.submitter_name }}</b>
                <span v-if="sb.submitter_position"> ({{ sb.submitter_position }})</span></p>
              <p><span class="text-slate-400">สังกัด:</span> {{ sb.submitter_org }}</p>
              <p><span class="text-slate-400">อีเมล:</span>
                <a :href="`mailto:${sb.submitter_email}`" class="text-primary hover:underline">{{ sb.submitter_email }}</a></p>
              <p v-if="sb.submitter_phone"><span class="text-slate-400">โทร:</span>
                <a :href="`tel:${sb.submitter_phone}`" class="text-primary hover:underline">{{ sb.submitter_phone }}</a></p>
            </div>

            <!-- หนังสือนำส่ง — จุดที่ใช้เทียบทะเบียนรับหนังสือ -->
            <div class="mt-3 rounded-xl px-3 py-2.5 text-xs"
              :class="sb.letter_url || sb.letter_no ? 'bg-slate-50' : 'bg-amber-50 border border-amber-200'">
              <p class="font-bold text-slate-600 mb-1">หนังสือนำส่ง</p>
              <template v-if="sb.letter_url || sb.letter_no || sb.letter_date">
                <p v-if="sb.letter_no" class="text-slate-600">เลขที่: <b>{{ sb.letter_no }}</b></p>
                <p v-if="sb.letter_date" class="text-slate-600">วันที่: {{ fmtDate(sb.letter_date) }}</p>
                <a v-if="sb.letter_url" :href="sb.letter_url" target="_blank" rel="noopener"
                  class="inline-flex items-center gap-1 mt-1 font-bold text-primary hover:underline">เปิดหนังสือนำส่ง →</a>
              </template>
              <p v-else class="text-amber-700">⚠️ ผู้ส่งไม่ได้แนบหนังสือนำส่ง — ต้องตรวจกับทะเบียนรับหนังสือเองก่อนอนุมัติ</p>
            </div>

            <!-- ปุ่ม -->
            <div class="flex flex-wrap items-center gap-2 mt-3 pt-3 border-t border-slate-100">
              <a :href="sb.work_url" target="_blank" rel="noopener"
                class="px-3 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-lg hover:bg-primary/20 transition-colors">
                เปิดผลงาน →
              </a>
              <label v-if="sb.status !== 'approved'"
                class="flex items-center gap-1.5 text-xs font-bold text-slate-600 cursor-pointer select-none px-2">
                <input type="checkbox" :checked="sb.letter_verified" :disabled="working === sb.id"
                  @change="toggleVerify(sb)" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
                ตรวจกับทะเบียนรับหนังสือแล้ว
              </label>

              <div class="flex gap-2 ml-auto">
                <button v-if="sb.status !== 'approved'" @click="reviewSub(sb, 'approved')" :disabled="working === sb.id"
                  class="px-3 py-1.5 text-xs font-bold text-white bg-emerald-600 rounded-lg hover:-translate-y-0.5 shadow-sm transition-all disabled:opacity-50">
                  อนุมัติและเผยแพร่
                </button>
                <button v-if="sb.status !== 'rejected'" @click="reviewSub(sb, 'rejected')" :disabled="working === sb.id"
                  class="px-3 py-1.5 text-xs font-bold text-red-600 bg-red-50 rounded-lg hover:bg-red-100 transition-colors disabled:opacity-50">
                  ตีกลับ
                </button>
              </div>
            </div>

            <p v-if="sb.status === 'rejected' && sb.reject_reason"
              class="text-xs text-red-600 bg-red-50 rounded-lg px-2.5 py-1.5 mt-2">เหตุผล: {{ sb.reject_reason }}</p>
            <p v-if="sb.status === 'approved'" class="text-xs text-emerald-700 mt-2">
              เผยแพร่แล้ว —
              <router-link v-if="sb.work_id" :to="`/works/${sb.work_id}`" class="font-bold hover:underline">ดูหน้าผลงาน →</router-link>
            </p>
          </div>
        </div>
      </template>

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
