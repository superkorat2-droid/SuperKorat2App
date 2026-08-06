<script setup>
/**
 * AdminVideosApproveView — คิวอนุมัติวีดิทัศน์
 *
 * ใช้ RPC review_video เท่านั้น ไม่ UPDATE ตรง — trigger videos_guard_update
 * freeze คอลัมน์สถานะไว้กับ client ทุกคน การ update ตรงจะเงียบ ๆ ไม่มีอะไรเกิดขึ้น
 *
 * ต่างจากคิวอนุมัติผลงาน: ที่นี่ดูคลิปได้เลยในโมดัลก่อนตัดสิน ไม่ต้องเปิดแท็บใหม่
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import VideoPlayerModal from '../../components/VideoPlayerModal.vue'
import {
  REVIEWER_ROLES, categoryLabel, categoryColor, videoStatusMeta,
  ownerTypeLabel, videoThumb, fmtDateTime,
} from '../../composables/useVideos'

const items   = ref([])
const loading = ref(true)
const myRole  = ref('')
const working = ref('')
const tab     = ref('pending')
const playing = ref(null)
const ownerNames = ref({})

const canReview = computed(() => REVIEWER_ROLES.includes(myRole.value))

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    myRole.value = p?.role || ''
  }
  const { data } = await supabase.from('videos').select('*').order('created_at', { ascending: false })
  items.value = data || []

  // ชื่อผู้ส่ง — ดึงทีเดียวทั้งชุด ไม่ยิงทีละแถว
  const ids = [...new Set(items.value.map(i => i.owner_id).filter(Boolean))]
  if (ids.length) {
    const { data: profs } = await supabase.from('profiles')
      .select('id, full_name, title, first_name, last_name, school_name').in('id', ids)
    ownerNames.value = Object.fromEntries((profs || []).map(p => [
      p.id,
      (p.full_name || '').trim() || [p.title, p.first_name, p.last_name].filter(Boolean).join(' ') || '—',
    ]))
  }
  loading.value = false
}

onMounted(load)

const counts = computed(() => ({
  pending:  items.value.filter(i => i.status === 'pending').length,
  approved: items.value.filter(i => i.status === 'approved').length,
  rejected: items.value.filter(i => i.status === 'rejected').length,
}))

const filtered = computed(() =>
  tab.value === 'all' ? items.value : items.value.filter(i => i.status === tab.value)
)

async function review(v, status) {
  let reason = ''
  if (status === 'rejected') {
    const res = await Swal.fire({
      title: 'ตีกลับคลิปนี้?',
      input: 'textarea',
      inputLabel: 'เหตุผล (ผู้ส่งจะเห็นข้อความนี้)',
      inputPlaceholder: 'เช่น ภาพไม่ชัด / ยังไม่ได้ตั้งแชร์เป็นสาธารณะ',
      showCancelButton: true, confirmButtonText: 'ตีกลับ', cancelButtonText: 'ยกเลิก',
      confirmButtonColor: '#ef4444',
      inputValidator: val => !val?.trim() && 'กรุณาระบุเหตุผลเพื่อให้ผู้ส่งแก้ไขได้ถูก',
    })
    if (!res.isConfirmed) return
    reason = res.value
  }

  working.value = v.id
  const { error } = await supabase.rpc('review_video', { p_id: v.id, p_status: status, p_reason: reason })
  working.value = ''
  if (error) { Swal.fire({ icon: 'error', title: 'ทำรายการไม่สำเร็จ', text: error.message }); return }

  await load()
  Swal.fire({
    icon: 'success',
    title: status === 'approved' ? 'อนุมัติแล้ว' : status === 'rejected' ? 'ตีกลับแล้ว' : 'ย้ายกลับคิวรออนุมัติแล้ว',
    timer: 1000, showConfirmButton: false,
  })
}
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-extrabold text-slate-800">อนุมัติวีดิทัศน์</h1>
      <span class="block text-xs text-slate-400 mt-0.5">
        คลิปจากโรงเรียน ครู และสมาชิก ต้องผ่านการอนุมัติก่อนขึ้นหน้าเว็บ
      </span>
    </div>

    <div v-if="!loading && !canReview" class="glass-card text-center py-16">
      <p class="text-4xl mb-3">🔒</p>
      <p class="text-sm font-bold text-slate-600">คุณไม่มีสิทธิ์อนุมัติวีดิทัศน์</p>
      <p class="text-xs text-slate-400 mt-1">เฉพาะผู้ดูแลระบบและศึกษานิเทศก์เท่านั้น</p>
    </div>

    <template v-else>
      <div class="flex gap-1 bg-white/70 backdrop-blur border border-white/80 p-1 rounded-xl w-fit">
        <button v-for="t in [
            { k: 'pending',  l: `รออนุมัติ (${counts.pending})` },
            { k: 'approved', l: `เผยแพร่ (${counts.approved})` },
            { k: 'rejected', l: `ตีกลับ (${counts.rejected})` },
            { k: 'all',      l: 'ทั้งหมด' }]"
          :key="t.k" @click="tab = t.k" type="button"
          :class="['px-3 py-1.5 text-sm font-bold rounded-lg transition-colors',
            tab === t.k ? 'bg-primary text-white shadow-sm' : 'text-slate-500 hover:text-slate-700']">
          {{ t.l }}
        </button>
      </div>

      <div v-if="loading" class="text-center py-16 text-slate-400 text-sm">กำลังโหลด...</div>
      <div v-else-if="!filtered.length" class="glass-card text-center py-16 text-slate-400 text-sm">
        ไม่มีรายการในหมวดนี้
      </div>

      <div v-else class="space-y-3">
        <div v-for="v in filtered" :key="v.id" class="glass-card p-4 flex flex-col sm:flex-row gap-4">
          <!-- ดูคลิปได้เลยก่อนตัดสิน -->
          <button @click="playing = v" type="button"
            class="relative w-full sm:w-52 aspect-video rounded-xl overflow-hidden bg-slate-900 flex-shrink-0 group">
            <img v-if="videoThumb(v, 400)" :src="videoThumb(v, 400)" :alt="v.title"
              class="w-full h-full object-cover group-hover:opacity-70 transition-opacity" loading="lazy"/>
            <span class="absolute inset-0 flex items-center justify-center text-white text-3xl">▶</span>
            <span v-if="v.duration_text"
              class="absolute bottom-1.5 right-1.5 text-[10px] font-bold text-white bg-black/70 px-1.5 py-0.5 rounded">
              {{ v.duration_text }}
            </span>
          </button>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', categoryColor(v.category)]">{{ categoryLabel(v.category) }}</span>
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', videoStatusMeta(v.status).bg, videoStatusMeta(v.status).text]">
                {{ videoStatusMeta(v.status).label }}
              </span>
              <span class="text-[10px] text-slate-400">{{ v.source === 'drive' ? 'Google Drive' : 'YouTube' }}</span>
            </div>

            <h3 class="font-bold text-slate-800 mt-1.5 leading-snug">{{ v.title }}</h3>
            <p v-if="v.description" class="text-xs text-slate-500 mt-1 line-clamp-2">{{ v.description }}</p>

            <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-slate-400 mt-2">
              <span>ผู้ส่ง: {{ ownerNames[v.owner_id] || '—' }} ({{ ownerTypeLabel(v.owner_type) }})</span>
              <span v-if="v.academic_year">ปีการศึกษา {{ v.academic_year }}</span>
              <span>ส่งเมื่อ {{ fmtDateTime(v.created_at) }}</span>
            </div>

            <p v-if="v.status === 'rejected' && v.reject_reason"
              class="text-xs text-red-600 bg-red-50 rounded-lg px-2.5 py-1.5 mt-2">เหตุผล: {{ v.reject_reason }}</p>

            <div class="flex flex-wrap gap-2 mt-3">
              <button v-if="v.status !== 'approved'" @click="review(v, 'approved')" :disabled="working === v.id" type="button"
                class="px-4 py-1.5 rounded-xl bg-emerald-600 text-white text-xs font-bold shadow-sm hover:bg-emerald-700 transition-colors disabled:opacity-50">
                อนุมัติ
              </button>
              <button v-if="v.status !== 'rejected'" @click="review(v, 'rejected')" :disabled="working === v.id" type="button"
                class="px-4 py-1.5 rounded-xl bg-red-50 text-red-600 text-xs font-bold hover:bg-red-100 transition-colors disabled:opacity-50">
                ตีกลับ
              </button>
              <button v-if="v.status !== 'pending'" @click="review(v, 'pending')" :disabled="working === v.id" type="button"
                class="px-4 py-1.5 rounded-xl text-slate-500 text-xs font-bold hover:bg-slate-100 transition-colors disabled:opacity-50">
                ย้ายกลับคิวรอ
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>

    <VideoPlayerModal :item="playing" @close="playing = null"/>
  </div>
</template>
