<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../../supabase'
import { Cropper } from 'vue-advanced-cropper'
import 'vue-advanced-cropper/dist/style.css'
import Swal from 'sweetalert2'

const router = useRouter()
const route  = useRoute()
const isNew  = computed(() => !route.params.id)

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})

const saving  = ref(false)
const loading = ref(false)
const cropModal  = ref({ open: false, src: '' })
const cropperRef = ref(null)
const cropping   = ref(false)
const thumbPreview = ref(null)
onUnmounted(() => { cropModal.value.open = false })

const MEDIA_TYPES = [
  { value:'book',       label:'หนังสือ',      color:'bg-blue-500',   icon:'M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25' },
  { value:'video',      label:'วิดีโอ',       color:'bg-red-500',    icon:'M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125V6.75A1.125 1.125 0 013.375 5.625h17.25A1.125 1.125 0 0121.75 6.75v11.625c0 .621-.504 1.125-1.125 1.125' },
  { value:'image',      label:'รูปภาพ',       color:'bg-green-500',  icon:'M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z' },
  { value:'audio',      label:'เสียง',        color:'bg-purple-500', icon:'M9 9l10.5-3m0 6.553v3.75a2.25 2.25 0 01-1.632 2.163l-1.32.377a1.803 1.803 0 11-.99-3.467l2.31-.66a2.25 2.25 0 001.632-2.163zm0 0V2.25L9 5.25v10.303' },
  { value:'app',        label:'แอปฯ',         color:'bg-teal-500',   icon:'M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6z' },
  { value:'exam',       label:'ข้อสอบ',       color:'bg-amber-500',  icon:'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z' },
  { value:'template',   label:'เทมเพลต',      color:'bg-indigo-500', icon:'M8.25 6.75h12M8.25 12h12m-12 5.25h12' },
  { value:'multimedia', label:'มัลติมีเดีย',  color:'bg-rose-500',   icon:'M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25' },
]

const SUBJECT_GROUPS = ['ภาษาไทย','คณิตศาสตร์','วิทยาศาสตร์และเทคโนโลยี','สังคมศึกษาฯ','สุขศึกษาและพลศึกษา','ศิลปะ','การงานอาชีพ','ภาษาต่างประเทศ','กิจกรรมพัฒนาผู้เรียน','อื่นๆ/ข้ามสาระ']
const GRADE_OPTIONS = ['ป.1','ป.2','ป.3','ป.4','ป.5','ป.6','ม.1','ม.2','ม.3','ม.4','ม.5','ม.6']

const meta = ref({
  title: '', description: '', media_type: 'book',
  drive_url: '', embed_url: '', thumbnail_url: '',
  subject_group: '', grade_levels: [],
  tags: '', author_name: '', is_published: false,
})

function extractFileId(url) {
  const patterns = [/\/file\/d\/([a-zA-Z0-9_-]+)/, /id=([a-zA-Z0-9_-]+)/]
  for (const p of patterns) { const m = url?.match(p); if (m) return m[1] }
  return null
}

// ─── Blocks ───────────────────────────────────────────────────────────────────
const blocks = ref([])

watch(() => blocks.value, (newBlocks) => {
  const driveBlock = newBlocks.find(b => b.type === 'drive' && b.url?.trim())
  const embedBlock = newBlocks.find(b => b.type === 'embed' && b.url?.trim())
  if (driveBlock) { meta.value.drive_url = driveBlock.url } else { meta.value.drive_url = '' }
  if (embedBlock) { meta.value.embed_url = embedBlock.url } else { meta.value.embed_url = '' }
}, { deep: true })

const firstDriveFileId = computed(() => {
  const b = blocks.value.find(bl => bl.type === 'drive' && bl.url?.trim())
  return b ? extractFileId(b.url) : null
})

const BLOCK_TYPES = [
  { type:'heading', label:'หัวข้อ', icon:'H1' },
  { type:'text',    label:'ข้อความ', icon:'¶' },
  { type:'image',   label:'รูปภาพ', icon:'🖼' },
  { type:'drive',   label:'Drive',  icon:'📄' },
  { type:'embed',   label:'Embed',  icon:'🔗' },
  { type:'html',    label:'HTML',   icon:'<>' },
  { type:'divider', label:'เส้นแบ่ง', icon:'—' },
]

function addBlock(type) {
  const defaults = {
    heading:{ type:'heading', text:'', level:2 },
    text:   { type:'text', text:'' },
    image:  { type:'image', url:'', caption:'' },
    drive:  { type:'drive', url:'', label:'' },
    embed:  { type:'embed', url:'', label:'' },
    html:   { type:'html', code:'' },
    divider:{ type:'divider' },
  }
  blocks.value.push({ ...defaults[type], _key: Date.now() })
}
function removeBlock(i) { blocks.value.splice(i,1) }
function moveUp(i)   { if(i>0) { const t=blocks.value[i-1]; blocks.value[i-1]=blocks.value[i]; blocks.value[i]=t } }
function moveDown(i) { if(i<blocks.value.length-1) { const t=blocks.value[i+1]; blocks.value[i+1]=blocks.value[i]; blocks.value[i]=t } }

function toggleGrade(g) {
  const i = meta.value.grade_levels.indexOf(g)
  if (i>=0) meta.value.grade_levels.splice(i,1)
  else meta.value.grade_levels.push(g)
}

// ─── Load ─────────────────────────────────────────────────────────────────────
async function load() {
  if (isNew.value) return
  loading.value = true
  const { data } = await supabase.from('media').select('*').eq('id', route.params.id).single()
  if (!data || data.school_id !== props.school?.id) { router.push('/school/media'); return }
  meta.value = {
    title: data.title, description: data.description || '',
    media_type: data.media_type, drive_url: data.drive_url || '',
    embed_url: data.embed_url || '', thumbnail_url: data.thumbnail_url || '',
    subject_group: data.subject_group || '', grade_levels: data.grade_levels || [],
    tags: (data.tags||[]).join(', '), author_name: data.author_name || '', is_published: data.is_published,
  }
  blocks.value = (data.content_blocks||[]).map(b => ({ ...b, _key: Date.now()+Math.random() }))
  loading.value = false
}

// ─── Save ─────────────────────────────────────────────────────────────────────
async function save() {
  if (!meta.value.title.trim()) { Swal.fire({ icon:'warning', title:'กรุณาใส่ชื่อสื่อ' }); return }
  saving.value = true
  const driveFileId = extractFileId(meta.value.drive_url)
  const payload = {
    school_id:      props.school?.id,
    created_by:     props.profile?.id,
    author_name:    meta.value.author_name.trim() || props.school?.name || '',
    title:          meta.value.title.trim(),
    description:    meta.value.description.trim() || null,
    content_blocks: blocks.value.map(({ _key, ...b }) => b),
    media_type:     meta.value.media_type,
    drive_url:      meta.value.drive_url.trim() || null,
    file_id:        driveFileId,
    embed_url:      meta.value.embed_url.trim() || null,
    thumbnail_url:  meta.value.thumbnail_url.trim() || null,
    subject_group:  meta.value.subject_group || null,
    grade_levels:   meta.value.grade_levels,
    tags:           meta.value.tags.split(',').map(t=>t.trim()).filter(Boolean),
    is_published:   meta.value.is_published,
    is_approved:    true,
    updated_at:     new Date().toISOString(),
  }
  let error, data
  if (isNew.value) {
    ;({ data, error } = await supabase.from('media').insert(payload).select().single())
  } else {
    ;({ error } = await supabase.from('media').update(payload).eq('id', route.params.id))
  }
  saving.value = false
  if (error) { Swal.fire({ icon:'error', title:'บันทึกไม่สำเร็จ', text:error.message }); return }
  await Swal.fire({ icon:'success', title:'บันทึกแล้ว', showConfirmButton:false, timer:1200 })
  if (isNew.value && data?.id) router.replace(`/school/media/${data.id}/edit`)
}

// ─── Thumbnail crop ───────────────────────────────────────────────────────────
const thumbSource = ref('crop')  // default crop เสมอ
function onThumbChange(e) {
  const file = e.target.files?.[0]; if (!file) return
  e.target.value = ''
  const reader = new FileReader()
  reader.onload = ev => { cropModal.value = { open:true, src:ev.target.result } }
  reader.readAsDataURL(file)
}
async function confirmCrop() {
  const { canvas } = cropperRef.value?.getResult() || {}; if (!canvas) return
  cropping.value = true
  const c = document.createElement('canvas'); c.width=400; c.height=300
  c.getContext('2d').drawImage(canvas,0,0,400,300)
  thumbPreview.value = c.toDataURL('image/jpeg',0.8)
  c.toBlob(async blob => {
    const path = `thumbnails/${Date.now()}.jpg`
    const { error } = await supabase.storage.from('images').upload(path, blob, { upsert:true, contentType:'image/jpeg' })
    if (!error) {
      const { data:{ publicUrl } } = supabase.storage.from('images').getPublicUrl(path)
      meta.value.thumbnail_url = publicUrl
    }
    cropModal.value.open = false; cropping.value = false
  }, 'image/jpeg', 0.8)
}

onMounted(load)
</script>

<template>
  <div class="space-y-5 max-w-4xl font-sarabun">

    <!-- Header -->
    <div class="flex items-center justify-between gap-3 flex-wrap">
      <div>
        <button @click="router.push('/school/media')"
          class="flex items-center gap-1 text-sm text-slate-400 hover:text-slate-600 mb-1">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/></svg>
          กลับรายการสื่อ
        </button>
        <h1 class="text-xl font-extrabold text-slate-800">{{ isNew ? 'เพิ่มสื่อใหม่' : 'แก้ไขสื่อ' }}</h1>
      </div>
      <button @click="save" :disabled="saving"
        class="flex items-center gap-2 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
        <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
        {{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}
      </button>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">

      <!-- Left: Block Editor -->
      <div class="lg:col-span-2 space-y-4">
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5">
          <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-1.5">ชื่อสื่อ <span class="text-red-500">*</span></label>
          <input v-model="meta.title" type="text" placeholder="ชื่อสื่อการเรียนรู้..."
            class="w-full px-4 py-3 border border-slate-200 rounded-xl text-base font-bold focus:outline-none focus:border-primary"/>
          <textarea v-model="meta.description" rows="2" placeholder="คำอธิบาย..."
            class="w-full mt-3 px-4 py-2.5 border border-slate-200 rounded-xl text-sm resize-none focus:outline-none focus:border-primary"/>
        </div>

        <!-- Block Editor -->
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5 space-y-4">
          <h2 class="font-bold text-slate-700 text-sm">เนื้อหาสื่อ (Block Editor)</h2>
          <div class="space-y-3">
            <div v-for="(block, i) in blocks" :key="block._key"
              class="border border-slate-200 rounded-xl p-3 space-y-2 hover:border-primary/40 transition-colors">
              <div class="flex items-center justify-between gap-2">
                <span class="text-[10px] font-bold text-slate-400 uppercase bg-slate-100 px-2 py-0.5 rounded">{{ block.type }}</span>
                <div class="flex gap-1 flex-shrink-0">
                  <button @click="moveUp(i)" :disabled="i===0" class="w-6 h-6 flex items-center justify-center text-slate-400 hover:bg-slate-100 rounded disabled:opacity-20">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/></svg>
                  </button>
                  <button @click="moveDown(i)" :disabled="i===blocks.length-1" class="w-6 h-6 flex items-center justify-center text-slate-400 hover:bg-slate-100 rounded disabled:opacity-20">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/></svg>
                  </button>
                  <button @click="removeBlock(i)" class="w-6 h-6 flex items-center justify-center text-slate-400 hover:text-red-500 hover:bg-red-50 rounded transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
                  </button>
                </div>
              </div>
              <div v-if="block.type==='heading'" class="flex gap-2">
                <select v-model="block.level" class="px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white">
                  <option :value="2">H2</option><option :value="3">H3</option><option :value="4">H4</option>
                </select>
                <input v-model="block.text" type="text" placeholder="หัวข้อ..." class="flex-1 px-3 py-1.5 border border-slate-200 rounded-lg text-sm font-bold focus:outline-none focus:border-primary"/>
              </div>
              <textarea v-else-if="block.type==='text'" v-model="block.text" rows="3" placeholder="ข้อความ..."
                class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm resize-none focus:outline-none focus:border-primary"/>
              <div v-else-if="block.type==='image'" class="space-y-1.5">
                <input v-model="block.url" type="url" placeholder="URL รูปภาพ https://..." class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:border-primary"/>
                <input v-model="block.caption" type="text" placeholder="คำอธิบายรูป (ไม่บังคับ)" class="w-full px-3 py-1.5 border border-slate-100 bg-slate-50 rounded-lg text-xs focus:outline-none focus:border-primary"/>
              </div>
              <div v-else-if="block.type==='drive'" class="space-y-1.5">
                <div class="text-[10px] text-amber-600 bg-amber-50 rounded-lg px-3 py-1.5">⚠️ ต้องตั้งค่า "ทุกคนที่มีลิงก์" ใน Google Drive ก่อน</div>
                <input v-model="block.url" type="url" placeholder="https://drive.google.com/file/d/..." class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm font-mono focus:outline-none focus:border-primary"/>
                <input v-model="block.label" type="text" placeholder="ชื่อที่แสดง (ไม่บังคับ)" class="w-full px-3 py-1.5 border border-slate-100 bg-slate-50 rounded-lg text-xs focus:outline-none focus:border-primary"/>
              </div>
              <div v-else-if="block.type==='embed'" class="space-y-1.5">
                <input v-model="block.url" type="url" placeholder="https://youtu.be/..." class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm font-mono focus:outline-none focus:border-primary"/>
                <input v-model="block.label" type="text" placeholder="ชื่อที่แสดง (ไม่บังคับ)" class="w-full px-3 py-1.5 border border-slate-100 bg-slate-50 rounded-lg text-xs focus:outline-none focus:border-primary"/>
              </div>
              <div v-else-if="block.type==='html'" class="space-y-1.5">
                <p class="text-[10px] text-slate-400">HTML (รองรับ full document &lt;!DOCTYPE&gt;)</p>
                <textarea v-model="block.code" rows="5" placeholder="<!DOCTYPE html>..." class="w-full px-3 py-2 border border-slate-200 rounded-lg text-xs font-mono resize-y focus:outline-none focus:border-primary"/>
              </div>
              <hr v-else-if="block.type==='divider'" class="border-slate-200"/>
            </div>
          </div>
          <div class="flex flex-wrap gap-2 pt-2 border-t border-slate-100">
            <button v-for="bt in BLOCK_TYPES" :key="bt.type" @click="addBlock(bt.type)"
              class="flex items-center gap-1 px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-600 rounded-xl hover:bg-primary/10 hover:text-primary transition-colors">
              <span>{{ bt.icon }}</span> {{ bt.label }}
            </button>
          </div>
        </div>
      </div>

      <!-- Right: Meta -->
      <div class="space-y-4">
        <!-- Media Type -->
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
          <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">ประเภทสื่อ</label>
          <div class="grid grid-cols-2 gap-2">
            <label v-for="mt in MEDIA_TYPES" :key="mt.value"
              :class="['flex items-center gap-2 px-3 py-2 rounded-xl border-2 cursor-pointer transition-all text-xs font-bold',
                meta.media_type===mt.value ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-600 hover:border-slate-300']">
              <input type="radio" v-model="meta.media_type" :value="mt.value" class="sr-only"/>
              <div :class="['w-5 h-5 rounded-lg flex items-center justify-center flex-shrink-0', mt.color]">
                <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="mt.icon"/>
                </svg>
              </div>
              {{ mt.label }}
            </label>
          </div>
        </div>

        <!-- Media source indicator -->
        <div v-if="meta.drive_url || meta.embed_url" class="bg-blue-50 border border-blue-200 rounded-2xl p-3">
          <p class="text-xs font-bold text-blue-700">สื่อหลัก (จาก Block)</p>
          <p v-if="meta.drive_url" class="text-[10px] text-blue-600 mt-1 truncate">📄 Drive: {{ extractFileId(meta.drive_url) }}</p>
          <p v-if="meta.embed_url" class="text-[10px] text-blue-600 mt-0.5 truncate">🎬 {{ meta.embed_url.slice(0,30) }}...</p>
        </div>
        <div v-else class="bg-slate-50 border border-dashed border-slate-300 rounded-2xl p-3 text-center">
          <p class="text-xs text-slate-400">เพิ่ม Block <strong>Drive</strong> หรือ <strong>Embed</strong> เป็นสื่อหลัก</p>
        </div>

        <!-- Thumbnail -->
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 space-y-3">
          <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider">ภาพตัวอย่าง</label>

          <!-- Preview current -->
          <div v-if="thumbPreview || meta.thumbnail_url" class="flex items-center gap-3">
            <img :src="thumbPreview || meta.thumbnail_url" class="w-20 h-15 object-cover rounded-xl border border-slate-200 flex-shrink-0" style="height:60px"/>
            <button @click="thumbPreview=null; meta.thumbnail_url=''" class="text-xs text-slate-400 hover:text-red-500">ลบ</button>
          </div>

          <!-- Drive option (only if Drive block exists) -->
          <div v-if="firstDriveFileId">
            <label :class="['flex items-center gap-3 p-2.5 rounded-xl border-2 cursor-pointer transition-all mb-2',
              thumbSource==='drive' ? 'border-primary bg-primary/5' : 'border-slate-200 hover:border-slate-300']"
              @click="thumbSource='drive'; thumbPreview=null; meta.thumbnail_url=''">
              <div class="w-12 rounded-lg overflow-hidden bg-slate-900 flex-shrink-0" style="height:36px;position:relative">
                <div style="overflow:hidden;position:absolute;inset:0">
                  <iframe :src="`https://drive.google.com/file/d/${firstDriveFileId}/preview`"
                    style="position:absolute;top:-44px;height:calc(100% + 44px);width:100%;border:none;pointer-events:none"
                    sandbox="allow-scripts allow-same-origin"/>
                </div>
              </div>
              <div>
                <p class="text-xs font-bold text-slate-700">ใช้ Drive embed (แนะนำ)</p>
                <p class="text-[10px] text-slate-400">แสดงส่วนบนของเอกสาร</p>
              </div>
            </label>
          </div>

          <!-- Upload + Crop (always visible) -->
          <div class="space-y-2">
            <input type="file" id="sthumb" accept="image/*" class="sr-only" @change="onThumbChange"/>
            <label for="sthumb"
              class="flex items-center justify-center gap-2 w-full py-3 border-2 border-dashed border-slate-300 rounded-xl text-xs font-bold text-slate-500 hover:border-primary hover:text-primary cursor-pointer transition-all">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
              </svg>
              {{ thumbPreview || meta.thumbnail_url ? 'เปลี่ยนรูป + ครอบ' : 'อัปโหลดรูปปก + ครอบ (4:3)' }}
            </label>
          </div>
        </div>

        <!-- Author name -->
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
          <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">เจ้าของสื่อ (แสดงสาธารณะ)</label>
          <input v-model="meta.author_name" type="text"
            :placeholder="school?.name || 'ชื่อครู/ทีมงาน/โรงเรียน'"
            class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
          <p class="text-[10px] text-slate-400 mt-1">ปล่อยว่าง = แสดงชื่อโรงเรียนอัตโนมัติ</p>
        </div>

        <!-- Classification -->
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 space-y-3">
          <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider">หมวดหมู่</label>
          <select v-model="meta.subject_group" class="w-full px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
            <option value="">-- กลุ่มสาระ --</option>
            <option v-for="s in SUBJECT_GROUPS" :key="s" :value="s">{{ s }}</option>
          </select>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="g in GRADE_OPTIONS" :key="g" type="button" @click="toggleGrade(g)"
              :class="['px-2.5 py-1 text-xs font-bold rounded-lg border-2 transition-colors',
                meta.grade_levels.includes(g) ? 'border-primary bg-primary/10 text-primary' : 'border-slate-200 text-slate-500 hover:border-slate-300']">
              {{ g }}
            </button>
          </div>
          <input v-model="meta.tags" type="text" placeholder="Tags คั่นด้วย , ..."
            class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
        </div>

        <!-- Status -->
        <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4">
          <label class="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" v-model="meta.is_published" class="w-4 h-4 accent-primary"/>
            <span class="text-sm font-medium text-slate-700">เผยแพร่สาธารณะ</span>
          </label>
        </div>
      </div>
    </div>
  </div>

  <!-- Crop Modal -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="cropModal.open" class="fixed inset-0 z-[60] flex items-center justify-center bg-black/75 p-4 font-sarabun">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm flex flex-col overflow-hidden">
          <div class="px-5 py-3 border-b border-slate-100">
            <p class="text-sm font-extrabold text-slate-700">ครอบรูป Thumbnail (4:3)</p>
          </div>
          <div class="bg-slate-900 overflow-hidden" style="height:280px">
            <Cropper ref="cropperRef" :src="cropModal.src" :stencil-props="{ aspectRatio: 4/3 }" class="w-full h-full" style="height:100%"/>
          </div>
          <div class="px-5 py-4 border-t border-slate-100 flex gap-3 justify-end">
            <button @click="cropModal.open=false" class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="confirmCrop" :disabled="cropping" class="px-5 py-2 text-sm font-bold bg-primary text-white rounded-xl disabled:opacity-50 shadow-md">
              {{ cropping ? 'กำลังอัปโหลด...' : 'ยืนยัน' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
