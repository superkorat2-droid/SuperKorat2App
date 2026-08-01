<script setup>
/**
 * AdminLibraryView — จัดการคลังหนังสือและคู่มือ
 *
 * ศน./เจ้าหน้าที่ แก้ได้เฉพาะรายการที่ตัวเองเพิ่ม (RLS บังคับจริงในฐานข้อมูล
 * ส่วน canEdit() ที่นี่แค่ซ่อนปุ่มไม่ให้กดแล้วเงียบ) — ดู migration 0068
 *
 * ต่างจากจดหมายข่าวตรงมี "ตรวจสอบลิงก์" ที่ยิงไปถาม Drive จริงว่าแชร์สาธารณะแล้วหรือยัง
 * เดิมทั้งระบบไม่เคยตรวจ กว่าจะรู้ว่าลืมตั้งค่าแชร์ก็ตอนภาพปกไม่ขึ้นบนหน้าเว็บแล้ว
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import { extractDriveId } from '../../composables/useGoogleDrive'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { useExternalUpload, externalUploadEnabled } from '../../composables/useExternalUpload'
import { useUploadGc } from '../../composables/useUploadGc'
import DriveCover from '../../components/DriveCover.vue'
import {
  LIBRARY_KINDS, kindLabel, kindColor,
  useGroupOptions, usePublisherOptions, personDisplayName, CURRENT_BE_YEAR,
} from '../../composables/useLibraryOptions'

const { config, fetchConfig } = useAreaConfig()
const { groupOptions, groupLabel, keyFromLabel } = useGroupOptions(config)
const { publishers, fetchPublishers, publisherById } = usePublisherOptions()
const { uploadImage, uploading } = useExternalUpload()
const gc = useUploadGc()

const items   = ref([])
const loading = ref(true)
const myId    = ref(null)
const myRole  = ref('')
const saving  = ref(false)

const searchQ     = ref('')
const filterKind  = ref('all')
const filterGroup = ref('all')
const filterPub   = ref('all')

const showModal = ref(false)
const emptyForm = () => ({
  id: null, title: '', description: '', kind: 'book',
  drive_url: '', file_id: '', mime_type: '', cover_url: '',
  group_key: '', publisher_id: '', year: CURRENT_BE_YEAR,
  is_published: false, sort_order: 99,
})
const form = ref(emptyForm())

// ผลตรวจลิงก์ล่าสุด — null = ยังไม่ได้ตรวจ
const linkCheck = ref(null)
const checking  = ref(false)

const isAdmin  = computed(() => ['super_admin', 'admin'].includes(myRole.value))
function canEdit(it) { return isAdmin.value || (!!it.created_by && it.created_by === myId.value) }

const driveId = computed(() => extractDriveId(form.value.drive_url))

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  myId.value = user?.id || null
  if (user) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    myRole.value = p?.role || ''
  }
  const { data } = await supabase
    .from('library_items').select('*')
    .order('year', { ascending: false, nullsFirst: false })
    .order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
}

onMounted(async () => {
  await Promise.all([fetchConfig(), fetchPublishers(), load()])
})

const filtered = computed(() => {
  let list = items.value
  if (filterKind.value  !== 'all') list = list.filter(i => i.kind === filterKind.value)
  if (filterGroup.value !== 'all') list = list.filter(i => i.group_key === filterGroup.value)
  if (filterPub.value   !== 'all') list = list.filter(i => i.publisher_id === filterPub.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) list = list.filter(i => (i.title || '').toLowerCase().includes(q))
  return list
})

function publisherName(id) {
  const p = publisherById.value[id]
  return p ? personDisplayName(p) : ''
}

// ── ตรวจว่าลิงก์แชร์สาธารณะแล้วหรือยัง ────────────────────────────────
async function checkLink() {
  const id = driveId.value
  if (!id) { linkCheck.value = { ok: false, message: 'ยังหา File ID จากลิงก์ไม่ได้' }; return }
  checking.value = true
  linkCheck.value = null
  try {
    const { data: { session } } = await supabase.auth.getSession()
    const url = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/drive-check?fileId=${encodeURIComponent(id)}`
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${session?.access_token || ''}`,
        apikey: import.meta.env.VITE_SUPABASE_ANON_KEY || '',
      },
    })
    const d = await res.json().catch(() => ({}))
    linkCheck.value = d
    if (d.ok) {
      form.value.mime_type = d.mimeType || ''
      // เติมชื่อให้เมื่อยังว่าง — ไม่ทับของที่ผู้ใช้พิมพ์เอง
      if (!form.value.title.trim() && d.name) form.value.title = String(d.name).replace(/\.(pdf|jpe?g|png|webp)$/i, '')
    }
  } catch (e) {
    linkCheck.value = { ok: false, message: 'ตรวจไม่สำเร็จ: ' + e.message }
  } finally {
    checking.value = false
  }
}

const mimeWarning = computed(() => {
  const m = form.value.mime_type
  if (!m) return ''
  if (m === 'application/pdf' || m.startsWith('image/')) return ''
  return `ไฟล์นี้เป็น ${m} ซึ่งอาจไม่มีภาพปกให้ดึง แนะนำให้อัปโหลดปกเอง`
})

// ── ปกที่อัปเอง ────────────────────────────────────────────────────────
async function onCoverPick(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  try {
    const url = await uploadImage(file, 'library')
    if (form.value.cover_url) gc.trackReplaced(form.value.cover_url)
    form.value.cover_url = url
    gc.trackUploaded(url)
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดปกไม่สำเร็จ', text: err.message })
  }
}
function useAutoCover() {
  if (form.value.cover_url) gc.trackReplaced(form.value.cover_url)
  form.value.cover_url = ''
}

// ── เพิ่ม/แก้/ลบ ───────────────────────────────────────────────────────
function openAdd() {
  form.value = emptyForm()
  // เดากลุ่มงานจากโปรไฟล์ตัวเอง — profiles.department เก็บเป็น label ต้องแปลงเป็น key
  const me = publisherById.value[myId.value]
  if (me) {
    form.value.publisher_id = myId.value
    form.value.group_key = keyFromLabel(me.department) || ''
  }
  linkCheck.value = null
  showModal.value = true
}

function openEdit(it) {
  form.value = { ...emptyForm(), ...it }
  form.value.publisher_id = it.publisher_id || ''
  form.value.group_key    = it.group_key || ''
  form.value.cover_url    = it.cover_url || ''
  linkCheck.value = null
  showModal.value = true
}

async function save() {
  if (!form.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อเรื่อง' }); return
  }
  const fileId = driveId.value
  if (!fileId) {
    Swal.fire({ icon: 'error', title: 'ลิงก์ไม่ถูกต้อง', text: 'กรุณาวางลิงก์แชร์จาก Google Drive' }); return
  }
  saving.value = true

  // created_by อยู่เฉพาะตอนเพิ่ม — ใส่ตอนแก้จะเป็นการโอนเจ้าของ
  const payload = {
    title: form.value.title.trim(),
    description: form.value.description?.trim() || null,
    kind: form.value.kind,
    drive_url: form.value.drive_url.trim(),
    file_id: fileId,
    mime_type: form.value.mime_type || null,
    cover_url: form.value.cover_url || null,
    group_key: form.value.group_key || null,
    publisher_id: form.value.publisher_id || null,
    year: form.value.year ? Number(form.value.year) : null,
    is_published: form.value.is_published,
    sort_order: Number(form.value.sort_order) || 99,
    updated_at: new Date().toISOString(),
  }

  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('library_items').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('library_items').insert({ ...payload, created_by: myId.value }))
  }
  saving.value = false

  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return
  }
  showModal.value = false
  await load()
  // เก็บกวาดปกเก่าที่ถูกแทนที่ หลังบันทึกสำเร็จเท่านั้น
  await gc.commit(items.value.map(i => i.cover_url).filter(Boolean))
}

async function del(it) {
  const res = await Swal.fire({
    icon: 'warning', title: 'ลบรายการนี้?', text: it.title,
    showCancelButton: true, confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#dc2626',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('library_items').delete().eq('id', it.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  if (it.cover_url) gc.trackReplaced(it.cover_url)
  await load()
  await gc.commit(items.value.map(i => i.cover_url).filter(Boolean))
}

async function togglePublish(it) {
  if (!canEdit(it)) return
  const { error } = await supabase.from('library_items')
    .update({ is_published: !it.is_published, updated_at: new Date().toISOString() })
    .eq('id', it.id)
  if (error) { Swal.fire({ icon: 'error', title: 'เปลี่ยนสถานะไม่สำเร็จ', text: error.message }); return }
  await load()
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">คลังหนังสือและคู่มือ</h1>
        <span class="block text-xs text-slate-400 mt-0.5">
          วางลิงก์ Drive สาธารณะ ระบบดึงหน้าแรกมาทำภาพปกให้เอง · ทั้งหมด {{ items.length }} รายการ
        </span>
      </div>
      <button @click="openAdd" type="button"
        class="flex items-center gap-1.5 px-4 py-2.5 bg-primary text-white text-sm font-bold rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        เพิ่มรายการ
      </button>
    </div>

    <!-- ตัวกรอง -->
    <div class="glass-card p-3 flex flex-wrap items-center gap-2">
      <input v-model="searchQ" type="search" placeholder="ค้นหาชื่อเรื่อง"
        class="flex-1 min-w-[180px] px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <select v-model="filterKind" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกประเภท</option>
        <option v-for="k in LIBRARY_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
      </select>
      <select v-model="filterGroup" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกกลุ่มงาน</option>
        <option v-for="g in groupOptions" :key="g.key" :value="g.key">{{ g.label }}</option>
      </select>
      <select v-model="filterPub" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกผู้เผยแพร่</option>
        <option v-for="p in publishers" :key="p.id" :value="p.id">{{ p.display }}</option>
      </select>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400 text-sm">กำลังโหลด...</div>
    <div v-else-if="!filtered.length" class="glass-card text-center py-16 text-slate-400 text-sm">ยังไม่มีรายการ</div>

    <div v-else class="glass-card overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
            <th class="px-4 py-3 font-bold">ปก</th>
            <th class="px-4 py-3 font-bold">ชื่อเรื่อง</th>
            <th class="px-4 py-3 font-bold">ประเภท</th>
            <th class="px-4 py-3 font-bold">กลุ่มงาน</th>
            <th class="px-4 py-3 font-bold">ผู้เผยแพร่</th>
            <th class="px-4 py-3 font-bold">ปี</th>
            <th class="px-4 py-3 font-bold">สถานะ</th>
            <th class="px-4 py-3 font-bold text-right">จัดการ</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="it in filtered" :key="it.id" class="border-b border-slate-50 hover:bg-slate-50/60">
            <td class="px-4 py-2.5">
              <div class="group w-10 h-14 rounded-lg overflow-hidden bg-slate-100 flex-shrink-0">
                <DriveCover :file-id="it.file_id" :cover-url="it.cover_url" :title="it.title" :size="200"/>
              </div>
            </td>
            <td class="px-4 py-2.5 max-w-[280px]">
              <a :href="it.drive_url" target="_blank" rel="noopener"
                class="font-bold text-slate-700 hover:text-primary line-clamp-2">{{ it.title }} ↗</a>
              <span v-if="it.cover_url" class="block text-[10px] text-emerald-600 mt-0.5">ใช้ปกที่อัปเอง</span>
            </td>
            <td class="px-4 py-2.5">
              <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-full', kindColor(it.kind)]">{{ kindLabel(it.kind) }}</span>
            </td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ groupLabel(it.group_key) || '—' }}</td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ publisherName(it.publisher_id) || '—' }}</td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ it.year || '—' }}</td>
            <td class="px-4 py-2.5">
              <button @click="togglePublish(it)" type="button" :disabled="!canEdit(it)"
                :class="['text-[10px] font-bold px-2 py-1 rounded-full transition-colors disabled:cursor-not-allowed',
                  it.is_published ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500']">
                {{ it.is_published ? 'เผยแพร่' : 'ฉบับร่าง' }}
              </button>
            </td>
            <td class="px-4 py-2.5 text-right whitespace-nowrap">
              <template v-if="canEdit(it)">
                <button @click="openEdit(it)" type="button" class="text-xs font-bold text-primary hover:underline">แก้ไข</button>
                <button @click="del(it)" type="button" class="ml-3 text-xs font-bold text-red-500 hover:underline">ลบ</button>
              </template>
              <span v-else class="text-[11px] text-slate-400" title="แก้ไขได้เฉพาะรายการที่คุณเป็นผู้เพิ่ม">ไม่ใช่รายการของคุณ</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- ══ MODAL ══════════════════════════════════════════════════ -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0"
        leave-active-class="transition duration-150" leave-to-class="opacity-0">
        <div v-if="showModal" class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div class="glass-panel rounded-3xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h2 class="text-lg font-extrabold text-slate-800">{{ form.id ? 'แก้ไขรายการ' : 'เพิ่มหนังสือ / คู่มือ' }}</h2>
              <button @click="showModal = false" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>

            <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">

              <!-- ลิงก์ Drive + ตรวจสอบ -->
              <div>
                <label class="text-[11px] font-bold text-slate-500">ลิงก์ Google Drive (ไฟล์ PDF หรือรูปภาพ)</label>
                <div class="flex gap-2">
                  <input v-model="form.drive_url" type="url" placeholder="https://drive.google.com/file/d/..."
                    class="flex-1 px-3 py-2 rounded-xl border border-slate-200 text-sm font-mono bg-white focus:outline-none focus:border-primary"/>
                  <button @click="checkLink" type="button" :disabled="checking || !driveId"
                    class="px-3.5 py-2 rounded-xl text-xs font-bold border-2 border-primary text-primary hover:bg-slate-50 transition-all disabled:opacity-40 whitespace-nowrap">
                    {{ checking ? 'กำลังตรวจ...' : 'ตรวจสอบลิงก์' }}
                  </button>
                </div>
                <span v-if="form.drive_url && !driveId" class="block text-[11px] text-red-500 mt-1">
                  หา File ID จากลิงก์นี้ไม่ได้ — ต้องเป็นลิงก์แชร์จาก Google Drive
                </span>
                <span v-else-if="driveId" class="block text-[11px] text-slate-400 mt-1 font-mono">File ID: {{ driveId }}</span>

                <div v-if="linkCheck" :class="['mt-2 px-3 py-2 rounded-xl text-[11px] leading-relaxed border',
                  linkCheck.ok ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-red-50 border-red-200 text-red-700']">
                  <template v-if="linkCheck.ok">
                    ✓ เปิดสาธารณะแล้ว · <b>{{ linkCheck.name }}</b>
                    <span class="block text-emerald-700/70">{{ linkCheck.mimeType }}</span>
                  </template>
                  <template v-else>✗ {{ linkCheck.message || 'ตรวจไม่ผ่าน' }}</template>
                </div>
                <div v-if="mimeWarning" class="mt-2 px-3 py-2 rounded-xl text-[11px] bg-amber-50 border border-amber-200 text-amber-800">
                  {{ mimeWarning }}
                </div>
              </div>

              <div class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
                ไฟล์ต้องตั้งแชร์เป็น <b>"ทุกคนที่มีลิงก์"</b> ไม่งั้นผู้ชมทั่วไปจะเห็นเป็นกรอบว่าง ·
                PDF หลายหน้าใช้ได้เลย ระบบดึง<b>หน้าแรก</b>มาทำปกให้เอง และผู้ชมเปิดอ่านได้ครบทุกหน้า
              </div>

              <!-- ชื่อ + ประเภท -->
              <div>
                <label class="text-[11px] font-bold text-slate-500">ชื่อเรื่อง</label>
                <input v-model="form.title" type="text" placeholder="เช่น คู่มือการนิเทศภายในสถานศึกษา"
                  class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
              </div>

              <div class="grid sm:grid-cols-3 gap-3">
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ประเภท</label>
                  <select v-model="form.kind" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                    <option v-for="k in LIBRARY_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
                  </select>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ปี (พ.ศ.)</label>
                  <input v-model="form.year" inputmode="numeric" placeholder="2569"
                    class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ลำดับ</label>
                  <input v-model="form.sort_order" inputmode="numeric" placeholder="99"
                    class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
                </div>
              </div>

              <!-- กลุ่มงาน + ผู้เผยแพร่ -->
              <div class="grid sm:grid-cols-2 gap-3">
                <div>
                  <label class="text-[11px] font-bold text-slate-500">กลุ่มงาน</label>
                  <select v-model="form.group_key" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="">— ไม่ระบุ —</option>
                    <option v-for="g in groupOptions" :key="g.key" :value="g.key">{{ g.label }}</option>
                  </select>
                  <span class="block text-[10px] text-slate-400 mt-1">รายการมาจากกลุ่มงานในหน้าจัดการบุคลากร</span>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ผู้เผยแพร่</label>
                  <select v-model="form.publisher_id" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="">— ไม่ระบุ —</option>
                    <option v-for="p in publishers" :key="p.id" :value="p.id">{{ p.display }}</option>
                  </select>
                  <span class="block text-[10px] text-slate-400 mt-1">เลือกได้เฉพาะสมาชิก ศน./เจ้าหน้าที่/ผู้ดูแล</span>
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
                  <div class="group w-20 h-28 rounded-xl overflow-hidden bg-slate-100 border border-slate-200 flex-shrink-0">
                    <DriveCover :file-id="driveId" :cover-url="form.cover_url" :title="form.title" :size="300"/>
                  </div>
                  <div class="flex-1 space-y-2">
                    <span class="block text-[11px] text-slate-500 leading-relaxed">
                      ค่าเริ่มต้นใช้<b>หน้าแรกของไฟล์</b>อัตโนมัติ ถ้าหน้าแรกไม่สวยหรือไม่มีภาพ ให้อัปโหลดปกเองทับได้
                    </span>
                    <div class="flex flex-wrap gap-2">
                      <label v-if="externalUploadEnabled"
                        class="px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-dashed border-slate-300 text-slate-500 hover:border-primary hover:text-primary transition-all cursor-pointer">
                        {{ uploading ? 'กำลังอัป...' : 'อัปโหลดปกเอง' }}
                        <input type="file" accept="image/*" class="hidden" @change="onCoverPick"/>
                      </label>
                      <button v-if="form.cover_url" @click="useAutoCover" type="button"
                        class="px-3 py-1.5 rounded-xl text-xs font-bold text-slate-500 hover:text-primary transition-colors">
                        ใช้ปกอัตโนมัติ
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
                <input type="checkbox" v-model="form.is_published" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
                เผยแพร่บนหน้าเว็บสาธารณะ
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
