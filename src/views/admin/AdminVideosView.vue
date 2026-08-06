<script setup>
/**
 * AdminVideosView — จัดการวีดิทัศน์การศึกษา
 *
 * ใช้ไฟล์เดียวทั้ง /dashboard/videos และ /school/videos (role school ถูก guard
 * เด้งออกจาก /dashboard ทุกกรณี) — แบบเดียวกับ AdminWorksView
 *
 * สถานะเปลี่ยนที่นี่ไม่ได้เลย: trigger videos_guard_update freeze ไว้
 * ต้องผ่าน RPC review_video ในหน้าคิวอนุมัติเท่านั้น ที่นี่จึงแสดงเป็น badge อ่านอย่างเดียว
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import { useExternalUpload, externalUploadEnabled } from '../../composables/useExternalUpload'
import { useUploadGc } from '../../composables/useUploadGc'
import VideoPlayerModal from '../../components/VideoPlayerModal.vue'
import {
  VIDEO_CATEGORIES, categoryLabel, categoryColor, videoStatusMeta,
  ownerTypeLabel, parseVideoSource, videoThumb, CURRENT_BE_YEAR,
} from '../../composables/useVideos'

const { uploadImage, uploading } = useExternalUpload()
const gc = useUploadGc()

const items   = ref([])
const loading = ref(true)
const saving  = ref(false)
const myId    = ref(null)
const myRole  = ref('')
const mySchool = ref(null)
const playing = ref(null)

const searchQ      = ref('')
const filterCat    = ref('all')
const filterStatus = ref('all')

const showModal = ref(false)
const emptyForm = () => ({
  id: null, title: '', description: '', category: 'learning',
  video_url: '', thumb_url: '', duration_text: '',
  academic_year: CURRENT_BE_YEAR, sort_order: 99, is_featured: false,
})
const form = ref(emptyForm())

const linkCheck = ref(null)
const checking  = ref(false)

const canManageAll = computed(() => ['super_admin', 'admin'].includes(myRole.value))
const autoApprove  = computed(() => ['super_admin', 'admin', 'supervisor', 'staff'].includes(myRole.value))

function canEdit(it) {
  return canManageAll.value
    || it.owner_id === myId.value
    || (!!mySchool.value && it.school_id === mySchool.value)
}

/** แหล่งวิดีโอที่เดาได้จากลิงก์ที่พิมพ์อยู่ตอนนี้ */
const parsed = computed(() => parseVideoSource(form.value.video_url))
const previewItem = computed(() => ({
  source: parsed.value.source, video_id: parsed.value.videoId,
  thumb_url: form.value.thumb_url, title: form.value.title,
  category: form.value.category, description: form.value.description,
  view_count: 0, owner_type: 'member',
}))

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  myId.value = user?.id || null
  if (user) {
    const { data: p } = await supabase.from('profiles').select('role, school_id').eq('id', user.id).single()
    myRole.value  = p?.role || ''
    mySchool.value = p?.school_id || null
  }
  // RLS คัดให้แล้วว่าใครเห็นแถวไหน ที่นี่ไม่ต้องใส่เงื่อนไขซ้ำ
  const { data } = await supabase.from('videos').select('*')
    .order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
}

onMounted(load)

const filtered = computed(() => {
  let list = items.value
  if (filterCat.value    !== 'all') list = list.filter(i => i.category === filterCat.value)
  if (filterStatus.value !== 'all') list = list.filter(i => i.status === filterStatus.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) list = list.filter(i => (i.title || '').toLowerCase().includes(q))
  return list
})

const counts = computed(() => ({
  pending:  items.value.filter(i => i.status === 'pending').length,
  rejected: items.value.filter(i => i.status === 'rejected').length,
}))

// ── ตรวจว่าคลิป Drive แชร์สาธารณะแล้วหรือยัง ─────────────────────────
// YouTube ไม่ต้องตรวจ (ลิงก์สาธารณะอยู่แล้ว) ตรวจเฉพาะ Drive ที่ลืมตั้งแชร์บ่อย
async function checkLink() {
  if (parsed.value.source !== 'drive') return
  checking.value = true
  linkCheck.value = null
  try {
    const { data: { session } } = await supabase.auth.getSession()
    const url = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/drive-check?fileId=${encodeURIComponent(parsed.value.videoId)}`
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${session?.access_token || ''}`,
        apikey: import.meta.env.VITE_SUPABASE_ANON_KEY || '',
      },
    })
    const d = await res.json().catch(() => ({}))
    linkCheck.value = d
    if (d.ok && !form.value.title.trim() && d.name) {
      form.value.title = String(d.name).replace(/\.(mp4|mov|avi|mkv|webm)$/i, '')
    }
  } catch (e) {
    linkCheck.value = { ok: false, message: 'ตรวจไม่สำเร็จ: ' + e.message }
  } finally {
    checking.value = false
  }
}

async function onThumbPick(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  try {
    const url = await uploadImage(file, 'videos')
    if (form.value.thumb_url) gc.trackReplaced(form.value.thumb_url)
    form.value.thumb_url = url
    gc.trackUploaded(url)
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดปกไม่สำเร็จ', text: err.message })
  }
}
function useAutoThumb() {
  if (form.value.thumb_url) gc.trackReplaced(form.value.thumb_url)
  form.value.thumb_url = ''
}

function openAdd() {
  form.value = emptyForm()
  linkCheck.value = null
  showModal.value = true
}
function openEdit(it) {
  form.value = { ...emptyForm(), ...it }
  form.value.thumb_url = it.thumb_url || ''
  form.value.description = it.description || ''
  linkCheck.value = null
  showModal.value = true
}

async function save() {
  if (!form.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อคลิป' }); return
  }
  const { source, videoId } = parsed.value
  if (!source || !videoId) {
    Swal.fire({
      icon: 'error', title: 'ลิงก์ไม่ถูกต้อง',
      text: 'รองรับลิงก์ YouTube (watch / youtu.be / shorts) และลิงก์ไฟล์วิดีโอจาก Google Drive',
    })
    return
  }

  // เตือนคลิปซ้ำแต่ไม่บล็อก — ไม่ได้ทำ UNIQUE ใน DB ไว้ เพราะ error จาก constraint อ่านไม่รู้เรื่อง
  if (!form.value.id) {
    const dup = items.value.find(i => i.video_id === videoId)
    if (dup) {
      const res = await Swal.fire({
        icon: 'warning', title: 'คลิปนี้มีอยู่แล้ว', text: `ซ้ำกับ "${dup.title}" — จะเพิ่มซ้ำหรือไม่?`,
        showCancelButton: true, confirmButtonText: 'เพิ่มซ้ำ', cancelButtonText: 'ยกเลิก',
      })
      if (!res.isConfirmed) return
    }
  }

  saving.value = true
  // ไม่ส่ง status/approved_* มาเลย — trigger freeze ไว้อยู่แล้ว ส่งมาก็โดนทับ
  const payload = {
    title: form.value.title.trim(),
    description: form.value.description?.trim() || '',
    category: form.value.category,
    source,
    video_url: form.value.video_url.trim(),
    video_id: videoId,
    thumb_url: form.value.thumb_url || null,
    duration_text: form.value.duration_text?.trim() || '',
    academic_year: form.value.academic_year ? Number(form.value.academic_year) : null,
    sort_order: Number(form.value.sort_order) || 99,
  }
  if (canManageAll.value) payload.is_featured = !!form.value.is_featured

  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('videos').update(payload).eq('id', form.value.id))
  } else {
    // owner_id ต้องส่งให้ผ่าน RLS WITH CHECK — trigger จะเขียนทับด้วย auth.uid() อีกที
    ;({ error } = await supabase.from('videos').insert({ ...payload, owner_id: myId.value }))
  }
  saving.value = false

  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }

  showModal.value = false
  const isNew = !form.value.id
  await load()
  await gc.commit(items.value.map(i => i.thumb_url).filter(Boolean))
  Swal.fire({
    icon: 'success', title: 'บันทึกแล้ว',
    text: isNew && !autoApprove.value ? 'คลิปถูกส่งเข้าคิวรออนุมัติแล้ว' : '',
    timer: isNew && !autoApprove.value ? undefined : 1200,
    showConfirmButton: !!(isNew && !autoApprove.value),
  })
}

async function del(it) {
  const res = await Swal.fire({
    icon: 'warning', title: 'ลบคลิปนี้?', text: it.title,
    showCancelButton: true, confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#dc2626',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('videos').delete().eq('id', it.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  if (it.thumb_url) gc.trackReplaced(it.thumb_url)
  await load()
  await gc.commit(items.value.map(i => i.thumb_url).filter(Boolean))
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">วีดิทัศน์การศึกษา</h1>
        <span class="block text-xs text-slate-400 mt-0.5">
          วางลิงก์ YouTube หรือวิดีโอจาก Google Drive · ทั้งหมด {{ items.length }} คลิป
          <template v-if="counts.pending"> · <b class="text-amber-600">รออนุมัติ {{ counts.pending }}</b></template>
        </span>
      </div>
      <button @click="openAdd" type="button"
        class="flex items-center gap-1.5 px-4 py-2.5 bg-primary text-white text-sm font-bold rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        เพิ่มคลิป
      </button>
    </div>

    <div v-if="!autoApprove" class="glass-inset px-4 py-3 text-xs text-slate-600 leading-relaxed">
      คลิปที่ส่งเข้ามาจะ<b>ยังไม่แสดงบนหน้าเว็บ</b>จนกว่าผู้ดูแลจะตรวจสอบและอนุมัติ
    </div>

    <!-- ตัวกรอง -->
    <div class="glass-card p-3 flex flex-wrap items-center gap-2">
      <input v-model="searchQ" type="search" placeholder="ค้นหาชื่อคลิป"
        class="flex-1 min-w-[180px] px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <select v-model="filterCat" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกหมวดหมู่</option>
        <option v-for="c in VIDEO_CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</option>
      </select>
      <select v-model="filterStatus" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกสถานะ</option>
        <option value="pending">รออนุมัติ</option>
        <option value="approved">เผยแพร่</option>
        <option value="rejected">ถูกตีกลับ</option>
      </select>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400 text-sm">กำลังโหลด...</div>
    <div v-else-if="!filtered.length" class="glass-card text-center py-16 text-slate-400 text-sm">ยังไม่มีคลิป</div>

    <div v-else class="glass-card overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
            <th class="px-4 py-3 font-bold">ปก</th>
            <th class="px-4 py-3 font-bold">ชื่อคลิป</th>
            <th class="px-4 py-3 font-bold">หมวดหมู่</th>
            <th class="px-4 py-3 font-bold">ผู้ส่ง</th>
            <th class="px-4 py-3 font-bold">ปี</th>
            <th class="px-4 py-3 font-bold">ยอดชม</th>
            <th class="px-4 py-3 font-bold">สถานะ</th>
            <th class="px-4 py-3 font-bold text-right">จัดการ</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="it in filtered" :key="it.id" class="border-b border-slate-50 hover:bg-slate-50/60">
            <td class="px-4 py-2.5">
              <button @click="playing = it" type="button" title="ทดสอบเล่น"
                class="relative block w-24 aspect-video rounded-lg overflow-hidden bg-slate-900 group">
                <img v-if="videoThumb(it, 300)" :src="videoThumb(it, 300)" :alt="it.title"
                  class="w-full h-full object-cover group-hover:opacity-70 transition-opacity" loading="lazy"/>
                <span class="absolute inset-0 flex items-center justify-center text-white/90 text-lg">▶</span>
              </button>
            </td>
            <td class="px-4 py-2.5 max-w-[280px]">
              <p class="font-bold text-slate-700 line-clamp-2">{{ it.title }}</p>
              <span class="block text-[10px] text-slate-400 mt-0.5">
                {{ it.source === 'drive' ? 'Google Drive' : 'YouTube' }}
                <template v-if="it.duration_text"> · {{ it.duration_text }}</template>
              </span>
              <p v-if="it.status === 'rejected' && it.reject_reason"
                class="text-[11px] text-red-600 bg-red-50 rounded-lg px-2 py-1 mt-1">เหตุผล: {{ it.reject_reason }}</p>
            </td>
            <td class="px-4 py-2.5">
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', categoryColor(it.category)]">{{ categoryLabel(it.category) }}</span>
            </td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ ownerTypeLabel(it.owner_type) }}</td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ it.academic_year || '—' }}</td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ it.view_count }}</td>
            <td class="px-4 py-2.5">
              <span :class="['text-[10px] font-bold px-2 py-1 rounded-full', videoStatusMeta(it.status).bg, videoStatusMeta(it.status).text]">
                {{ videoStatusMeta(it.status).label }}
              </span>
              <span v-if="it.is_featured" class="block text-[10px] text-amber-600 mt-0.5">★ แนะนำ</span>
            </td>
            <td class="px-4 py-2.5 text-right whitespace-nowrap">
              <template v-if="canEdit(it)">
                <button @click="openEdit(it)" type="button" class="text-xs font-bold text-primary hover:underline">แก้ไข</button>
                <button @click="del(it)" type="button" class="ml-3 text-xs font-bold text-red-500 hover:underline">ลบ</button>
              </template>
              <span v-else class="text-[11px] text-slate-400">ไม่ใช่คลิปของคุณ</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <VideoPlayerModal :item="playing" @close="playing = null"/>

    <!-- ══ MODAL ══════════════════════════════════════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0"
        leave-active-class="transition duration-150" leave-to-class="opacity-0">
        <div v-if="showModal" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="glass-panel rounded-3xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h2 class="text-lg font-extrabold text-slate-800">{{ form.id ? 'แก้ไขคลิป' : 'เพิ่มวีดิทัศน์' }}</h2>
              <button @click="showModal = false" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>

            <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">

              <!-- ลิงก์วิดีโอ -->
              <div>
                <label class="text-[11px] font-bold text-slate-500">ลิงก์วิดีโอ (YouTube หรือ Google Drive)</label>
                <div class="flex gap-2">
                  <input v-model="form.video_url" type="url" placeholder="https://youtu.be/... หรือ https://drive.google.com/file/d/..."
                    class="flex-1 px-3 py-2 rounded-xl border border-slate-200 text-sm font-mono bg-white focus:outline-none focus:border-primary"/>
                  <button v-if="parsed.source === 'drive'" @click="checkLink" type="button" :disabled="checking"
                    class="px-3.5 py-2 rounded-xl text-xs font-bold border-2 border-primary text-primary hover:bg-slate-50 transition-all disabled:opacity-40 whitespace-nowrap">
                    {{ checking ? 'กำลังตรวจ...' : 'ตรวจสอบลิงก์' }}
                  </button>
                </div>
                <span v-if="form.video_url && !parsed.source" class="block text-[11px] text-red-500 mt-1">
                  อ่านลิงก์นี้ไม่ออก — รองรับ YouTube (watch / youtu.be / shorts / live) และไฟล์วิดีโอจาก Google Drive
                </span>
                <span v-else-if="parsed.source" class="block text-[11px] text-slate-400 mt-1 font-mono">
                  {{ parsed.source === 'drive' ? 'Google Drive' : 'YouTube' }} · {{ parsed.videoId }}
                </span>

                <div v-if="linkCheck" :class="['mt-2 px-3 py-2 rounded-xl text-[11px] leading-relaxed border',
                  linkCheck.ok ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-red-50 border-red-200 text-red-700']">
                  <template v-if="linkCheck.ok">✓ เปิดสาธารณะแล้ว · <b>{{ linkCheck.name }}</b></template>
                  <template v-else>✗ {{ linkCheck.message || 'ตรวจไม่ผ่าน' }}</template>
                </div>
              </div>

              <div v-if="parsed.source === 'drive'" class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
                ไฟล์ต้องตั้งแชร์เป็น <b>"ทุกคนที่มีลิงก์"</b> ไม่งั้นผู้ชมทั่วไปจะเห็นเป็นกรอบว่างเปล่า
              </div>

              <div>
                <label class="text-[11px] font-bold text-slate-500">ชื่อคลิป</label>
                <input v-model="form.title" type="text" placeholder="เช่น การจัดการเรียนรู้เชิงรุก ชั้น ป.4"
                  class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
              </div>

              <div class="grid sm:grid-cols-2 gap-3">
                <div>
                  <label class="text-[11px] font-bold text-slate-500">หมวดหมู่</label>
                  <select v-model="form.category" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                    <option v-for="c in VIDEO_CATEGORIES" :key="c.value" :value="c.value">{{ c.icon }} {{ c.label }}</option>
                  </select>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ปีการศึกษา (พ.ศ.)</label>
                  <input v-model="form.academic_year" inputmode="numeric" placeholder="2569"
                    class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
                </div>
              </div>

              <div class="grid sm:grid-cols-2 gap-3">
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ความยาว (เว้นว่างได้)</label>
                  <input v-model="form.duration_text" type="text" placeholder="12:34"
                    class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ลำดับการแสดง</label>
                  <input v-model="form.sort_order" inputmode="numeric" placeholder="99"
                    class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
                </div>
              </div>

              <div>
                <label class="text-[11px] font-bold text-slate-500">คำอธิบาย (เว้นว่างได้)</label>
                <textarea v-model="form.description" rows="2"
                  class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"></textarea>
              </div>

              <!-- ปก -->
              <div>
                <span class="block text-[11px] font-bold text-slate-500 mb-1.5">ภาพปก</span>
                <div class="flex items-start gap-3">
                  <div class="w-32 aspect-video rounded-xl overflow-hidden bg-slate-900 border border-slate-200 flex-shrink-0">
                    <img v-if="videoThumb(previewItem, 400)" :src="videoThumb(previewItem, 400)" alt=""
                      class="w-full h-full object-cover"/>
                  </div>
                  <div class="flex-1 space-y-2">
                    <span class="block text-[11px] text-slate-500 leading-relaxed">
                      ค่าเริ่มต้นดึงภาพปกจากต้นทางให้อัตโนมัติ ถ้าไม่สวยให้อัปโหลดทับได้
                    </span>
                    <div class="flex flex-wrap gap-2">
                      <label v-if="externalUploadEnabled"
                        class="px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-dashed border-slate-300 text-slate-500 hover:border-primary hover:text-primary transition-all cursor-pointer">
                        {{ uploading ? 'กำลังอัป...' : 'อัปโหลดปกเอง' }}
                        <input type="file" accept="image/*" class="hidden" @change="onThumbPick"/>
                      </label>
                      <button v-if="form.thumb_url" @click="useAutoThumb" type="button"
                        class="px-3 py-1.5 rounded-xl text-xs font-bold text-slate-500 hover:text-primary transition-colors">
                        ใช้ปกอัตโนมัติ
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <label v-if="canManageAll" class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
                <input type="checkbox" v-model="form.is_featured" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
                ตั้งเป็นคลิปแนะนำ (ขึ้นก่อนใครในหน้ารวมและหน้าแรก)
              </label>
            </div>

            <div class="flex gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false" type="button" class="flex-1 py-2.5 rounded-2xl border border-slate-200 text-sm font-bold text-slate-600 hover:bg-slate-50">ยกเลิก</button>
              <button @click="save" :disabled="saving" type="button"
                class="flex-1 py-2.5 rounded-2xl bg-primary text-white text-sm font-bold shadow-md disabled:opacity-50">
                {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
