<script setup>
/**
 * AdminCertificatesView — จัดการคลังเกียรติบัตร
 *
 * ไม่มีคิวอนุมัติ (ต่างจากผลงาน/วีดิทัศน์) — เขต/แอดมิน 4 บทบาทจัดการเองได้เลย
 * ตรงตาม RLS ของ migration 0079 (แม่แบบจาก library_items 0068)
 *
 * ภาพปกเลือกได้ 2 โหมด: อัปโหลด+ครอบเอง (ครอบชิดขอบบนสำหรับต้นฉบับแนวตั้ง)
 * หรือวางลิงก์แชร์ Google Drive แล้วดึงธัมเนลมาเลย — ลิงก์ปลายทาง (link_url) ที่
 * คลิกการ์ดแล้วเปิดเป็นคนละฟิลด์กับปก เพราะอาจเป็นหน้า GAS ที่ครอบธัมเนลไม่ได้
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import { extractDriveId, driveViewUrl } from '../../composables/useGoogleDrive'
import { useAreaConfig } from '../../composables/useAreaConfig'
import { useExternalUpload, externalUploadEnabled } from '../../composables/useExternalUpload'
import { useUploadGc } from '../../composables/useUploadGc'
import { useGroupOptions, usePublisherOptions, personDisplayName } from '../../composables/useLibraryOptions'
import { certCoverSrc, fmtDate } from '../../composables/useCertificates'
import ImageCropperModal from '../../components/ImageCropperModal.vue'

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
const filterGroup = ref('all')

const showModal = ref(false)
const emptyForm = () => ({
  id: null, title: '', group_key: '', responsible_id: '',
  cert_date: '', link_url: '',
  cover_source: 'upload', cover_url: '', cover_drive_id: '',
  is_published: true,
})
const form = ref(emptyForm())
const driveCoverInput = ref('')   // ช่องพิมพ์ลิงก์แชร์ปก — เก็บ id ล้วนไว้ที่ form.cover_drive_id

const showCropper = ref(false)
const cropSrc     = ref('')

const isAdmin = computed(() => ['super_admin', 'admin'].includes(myRole.value))
function canEdit(it) { return isAdmin.value || (!!it.created_by && it.created_by === myId.value) }

async function load() {
  loading.value = true
  const { data: { user } } = await supabase.auth.getUser()
  myId.value = user?.id || null
  if (user) {
    const { data: p } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    myRole.value = p?.role || ''
  }
  const { data } = await supabase
    .from('certificates').select('*')
    .order('cert_date', { ascending: false, nullsFirst: false })
    .order('created_at', { ascending: false })
  items.value = data || []
  loading.value = false
}

onMounted(async () => {
  await Promise.all([fetchConfig(), fetchPublishers(), load()])
})

const filtered = computed(() => {
  let list = items.value
  if (filterGroup.value !== 'all') list = list.filter(i => i.group_key === filterGroup.value)
  const q = searchQ.value.trim().toLowerCase()
  if (q) list = list.filter(i => (i.title || '').toLowerCase().includes(q))
  return list
})

function publisherName(id) {
  const p = publisherById.value[id]
  return p ? personDisplayName(p) : ''
}

// ── ปก: อัปโหลด+ครอบ ─────────────────────────────────────────────────
function onCoverPick(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  const reader = new FileReader()
  reader.onload = ev => { cropSrc.value = ev.target.result; showCropper.value = true }
  reader.readAsDataURL(file)
}

async function onCropped({ blob }) {
  showCropper.value = false
  try {
    const url = await uploadImage(blob, 'certificates')
    if (form.value.cover_source === 'upload' && form.value.cover_url) gc.trackReplaced(form.value.cover_url)
    form.value.cover_source = 'upload'
    form.value.cover_url = url
    form.value.cover_drive_id = ''
    gc.trackUploaded(url)
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดปกไม่สำเร็จ', text: err.message })
  }
}

// ── ปก: ลิงก์ Drive ──────────────────────────────────────────────────
function onDriveCoverInput() {
  const id = extractDriveId(driveCoverInput.value)
  form.value.cover_drive_id = id
  form.value.cover_source = 'drive'
  if (form.value.cover_url) { gc.trackReplaced(form.value.cover_url); form.value.cover_url = '' }
}

function setCoverMode(mode) {
  form.value.cover_source = mode
  if (mode === 'drive' && !driveCoverInput.value && form.value.cover_drive_id) {
    driveCoverInput.value = driveViewUrl(form.value.cover_drive_id)
  }
}

// ── เพิ่ม/แก้/ลบ ───────────────────────────────────────────────────────
function openAdd() {
  form.value = emptyForm()
  driveCoverInput.value = ''
  const me = publisherById.value[myId.value]
  if (me) {
    form.value.responsible_id = myId.value
    form.value.group_key = keyFromLabel(me.department) || ''
  }
  showModal.value = true
}

function openEdit(it) {
  form.value = {
    ...emptyForm(), ...it,
    group_key: it.group_key || '',
    responsible_id: it.responsible_id || '',
    cert_date: it.cert_date || '',
    link_url: it.link_url || '',
    cover_source: it.cover_source || 'upload',
    cover_url: it.cover_url || '',
    cover_drive_id: it.cover_drive_id || '',
  }
  driveCoverInput.value = it.cover_drive_id ? driveViewUrl(it.cover_drive_id) : ''
  showModal.value = true
}

async function save() {
  if (!form.value.title.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณากรอกชื่อเรื่อง' }); return
  }
  if (!form.value.link_url.trim()) {
    Swal.fire({ icon: 'warning', title: 'กรุณาวางลิงก์เกียรติบัตร' }); return
  }
  if (form.value.cover_source === 'drive' && !form.value.cover_drive_id) {
    Swal.fire({ icon: 'warning', title: 'ลิงก์ปกไม่ถูกต้อง', text: 'หา File ID จากลิงก์ Drive นี้ไม่ได้' }); return
  }
  saving.value = true

  const payload = {
    title: form.value.title.trim(),
    group_key: form.value.group_key || null,
    responsible_id: form.value.responsible_id || null,
    cert_date: form.value.cert_date || null,
    link_url: form.value.link_url.trim(),
    cover_source: form.value.cover_source,
    cover_url: form.value.cover_source === 'upload' ? (form.value.cover_url || null) : null,
    cover_drive_id: form.value.cover_source === 'drive' ? (form.value.cover_drive_id || null) : null,
    is_published: form.value.is_published,
  }

  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('certificates').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('certificates').insert({ ...payload, created_by: myId.value }))
  }
  saving.value = false

  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return
  }
  showModal.value = false
  await load()
  await gc.commit(items.value.map(i => i.cover_url).filter(Boolean))
}

async function del(it) {
  const res = await Swal.fire({
    icon: 'warning', title: 'ลบรายการนี้?', text: it.title,
    showCancelButton: true, confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#dc2626',
  })
  if (!res.isConfirmed) return
  const { error } = await supabase.from('certificates').delete().eq('id', it.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  if (it.cover_url) gc.trackReplaced(it.cover_url)
  await load()
  await gc.commit(items.value.map(i => i.cover_url).filter(Boolean))
}

async function togglePublish(it) {
  if (!canEdit(it)) return
  const { error } = await supabase.from('certificates')
    .update({ is_published: !it.is_published })
    .eq('id', it.id)
  if (error) { Swal.fire({ icon: 'error', title: 'เปลี่ยนสถานะไม่สำเร็จ', text: error.message }); return }
  await load()
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">คลังเกียรติบัตร</h1>
        <span class="block text-xs text-slate-400 mt-0.5">ทั้งหมด {{ items.length }} รายการ</span>
      </div>
      <button @click="openAdd" type="button"
        class="flex items-center gap-1.5 px-4 py-2.5 bg-primary text-white text-sm font-bold rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        เพิ่มเกียรติบัตร
      </button>
    </div>

    <!-- ตัวกรอง -->
    <div class="glass-card p-3 flex flex-wrap items-center gap-2">
      <input v-model="searchQ" type="search" placeholder="ค้นหาชื่อเรื่อง"
        class="flex-1 min-w-[180px] px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <select v-model="filterGroup" class="px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกกลุ่มงาน</option>
        <option v-for="g in groupOptions" :key="g.key" :value="g.key">{{ g.label }}</option>
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
            <th class="px-4 py-3 font-bold">กลุ่มงาน</th>
            <th class="px-4 py-3 font-bold">ผู้รับผิดชอบ</th>
            <th class="px-4 py-3 font-bold">วันที่</th>
            <th class="px-4 py-3 font-bold">เปิดดู</th>
            <th class="px-4 py-3 font-bold">สถานะ</th>
            <th class="px-4 py-3 font-bold text-right">จัดการ</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="it in filtered" :key="it.id" class="border-b border-slate-50 hover:bg-slate-50/60">
            <td class="px-4 py-2.5">
              <div class="w-14 h-11 rounded-lg overflow-hidden bg-slate-100 flex-shrink-0 flex items-center justify-center">
                <img v-if="certCoverSrc(it)" :src="certCoverSrc(it)" class="w-full h-full object-cover"
                  :class="it.cover_source === 'drive' ? 'object-top' : 'object-center'"/>
                <span v-else class="text-slate-300 text-lg">📜</span>
              </div>
            </td>
            <td class="px-4 py-2.5 max-w-[240px]">
              <a :href="it.link_url" target="_blank" rel="noopener"
                class="font-bold text-slate-700 hover:text-primary line-clamp-2">{{ it.title }} ↗</a>
            </td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ groupLabel(it.group_key) || '—' }}</td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ publisherName(it.responsible_id) || '—' }}</td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ fmtDate(it.cert_date) || '—' }}</td>
            <td class="px-4 py-2.5 text-xs text-slate-500">{{ it.open_count || 0 }}</td>
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
              <h2 class="text-lg font-extrabold text-slate-800">{{ form.id ? 'แก้ไขเกียรติบัตร' : 'เพิ่มเกียรติบัตร' }}</h2>
              <button @click="showModal = false" class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>

            <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">

              <div>
                <label class="text-[11px] font-bold text-slate-500">ชื่อเรื่อง</label>
                <input v-model="form.title" type="text" placeholder="เช่น เกียรติบัตรครูดีเด่น ปีการศึกษา 2569"
                  class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
              </div>

              <div>
                <label class="text-[11px] font-bold text-slate-500">ลิงก์เกียรติบัตร (เปิดเมื่อคลิกการ์ด)</label>
                <input v-model="form.link_url" type="url" placeholder="https://..."
                  class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm font-mono bg-white focus:outline-none focus:border-primary"/>
              </div>

              <div class="grid sm:grid-cols-3 gap-3">
                <div>
                  <label class="text-[11px] font-bold text-slate-500">กลุ่มงาน</label>
                  <select v-model="form.group_key" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="">— ไม่ระบุ —</option>
                    <option v-for="g in groupOptions" :key="g.key" :value="g.key">{{ g.label }}</option>
                  </select>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">ผู้รับผิดชอบ</label>
                  <select v-model="form.responsible_id" class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary">
                    <option value="">— ไม่ระบุ —</option>
                    <option v-for="p in publishers" :key="p.id" :value="p.id">{{ p.display }}</option>
                  </select>
                </div>
                <div>
                  <label class="text-[11px] font-bold text-slate-500">วันที่</label>
                  <input v-model="form.cert_date" type="date"
                    class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
                </div>
              </div>

              <!-- ปก -->
              <div>
                <span class="block text-[11px] font-bold text-slate-500 mb-1.5">ภาพปก</span>
                <div class="flex items-start gap-3">
                  <div class="w-20 h-28 rounded-xl overflow-hidden bg-slate-100 border border-slate-200 flex-shrink-0 flex items-center justify-center">
                    <img v-if="certCoverSrc(form)" :src="certCoverSrc(form)" class="w-full h-full object-cover"
                      :class="form.cover_source === 'drive' ? 'object-top' : 'object-center'"/>
                    <span v-else class="text-slate-300 text-2xl">📜</span>
                  </div>
                  <div class="flex-1 space-y-2">
                    <div class="flex flex-wrap gap-1.5">
                      <button @click="setCoverMode('upload')" type="button"
                        :class="['px-3 py-1 text-xs font-bold rounded-lg transition-all border',
                          form.cover_source === 'upload' ? 'bg-primary text-white border-primary' : 'border-slate-200 text-slate-600 hover:border-primary hover:text-primary']">
                        อัปโหลดและครอบภาพ
                      </button>
                      <button @click="setCoverMode('drive')" type="button"
                        :class="['px-3 py-1 text-xs font-bold rounded-lg transition-all border',
                          form.cover_source === 'drive' ? 'bg-primary text-white border-primary' : 'border-slate-200 text-slate-600 hover:border-primary hover:text-primary']">
                        ลิงก์ Google Drive
                      </button>
                    </div>

                    <label v-if="form.cover_source === 'upload' && externalUploadEnabled"
                      class="inline-block px-3 py-1.5 rounded-xl text-xs font-bold border-2 border-dashed border-slate-300 text-slate-500 hover:border-primary hover:text-primary transition-all cursor-pointer">
                      {{ uploading ? 'กำลังอัป...' : 'เลือกไฟล์แล้วครอบภาพ' }}
                      <input type="file" accept="image/*" class="hidden" @change="onCoverPick"/>
                    </label>

                    <div v-if="form.cover_source === 'drive'">
                      <input v-model="driveCoverInput" @input="onDriveCoverInput" type="url"
                        placeholder="https://drive.google.com/file/d/..."
                        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm font-mono bg-white focus:outline-none focus:border-primary"/>
                      <span v-if="driveCoverInput && !form.cover_drive_id" class="block text-[11px] text-red-500 mt-1">
                        หา File ID จากลิงก์นี้ไม่ได้
                      </span>
                      <span class="block text-[10px] text-slate-400 mt-1">ครอบพิกเซลจริงไม่ได้ ระบบจะดันภาพให้เห็นส่วนบนแทน — เหมาะกับไฟล์ A4</span>
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

    <ImageCropperModal :show="showCropper" :src="cropSrc" :aspect-ratio="4/3" :bias-top="true"
      title="ครอบภาพปกเกียรติบัตร" @close="showCropper = false" @cropped="onCropped"/>
  </div>
</template>
