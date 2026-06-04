<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const route  = useRoute()
const router = useRouter()

const page    = ref(null)
const blocks  = ref([])
const saving  = ref(false)
const loading = ref(true)
const myProfile = ref(null)

// permission: admin เต็ม, supervisor ต้องอยู่ใน assigned_users
const canEdit = computed(() => {
  if (!myProfile.value || !page.value) return false
  if (['super_admin','admin'].includes(myProfile.value.role)) return true
  return (page.value.assigned_users || []).includes(myProfile.value.id)
})

const BLOCK_TYPES = [
  { type: 'heading', label: 'หัวข้อ',    iconName: 'document'  },
  { type: 'text',    label: 'ข้อความ',   iconName: 'clipboard' },
  { type: 'image',   label: 'รูปภาพ',   iconName: 'folder'    },
  { type: 'embed',   label: 'Embed URL', iconName: 'globe'     },
  { type: 'html',    label: 'HTML',      iconName: 'beaker'    },
  { type: 'divider', label: 'เส้นแบ่ง', iconName: 'plus'      },
]

function newBlock(type) {
  const base = { id: crypto.randomUUID(), type }
  switch (type) {
    case 'heading':  return { ...base, level: 'h2', text: '' }
    case 'text':     return { ...base, text: '' }
    case 'image':    return { ...base, url: '', caption: '', align: 'center' }
    case 'embed':    return { ...base, url: '', embed_type: 'youtube', aspect: '16/9' }
    case 'html':     return { ...base, code: '' }
    case 'divider':  return { ...base }
    default:         return base
  }
}

onMounted(async () => {
  // โหลด profile + page พร้อมกัน
  const [{ data: { user } }, { data }] = await Promise.all([
    supabase.auth.getUser(),
    supabase.from('pages').select('*').eq('id', route.params.id).single(),
  ])
  if (!data) { router.push('/dashboard/pages'); return }
  page.value   = data
  blocks.value = Array.isArray(data.blocks) ? data.blocks : []

  if (user) {
    const { data: profile } = await supabase.from('profiles').select('id, role').eq('id', user.id).single()
    myProfile.value = profile
  }
  loading.value = false
})

function addBlock(type) { blocks.value.push(newBlock(type)) }

function removeBlock(idx) { blocks.value.splice(idx, 1) }

function moveUp(idx) {
  if (idx === 0) return
  ;[blocks.value[idx - 1], blocks.value[idx]] = [blocks.value[idx], blocks.value[idx - 1]]
}

function moveDown(idx) {
  if (idx === blocks.value.length - 1) return
  ;[blocks.value[idx], blocks.value[idx + 1]] = [blocks.value[idx + 1], blocks.value[idx]]
}

async function save(publish = null) {
  if (!canEdit.value) return Swal.fire({ icon: 'error', title: 'ไม่มีสิทธิ์', text: 'คุณไม่ได้รับมอบหมายให้ดูแลหน้านี้' })
  saving.value = true
  const payload = { blocks: blocks.value }
  if (publish !== null) payload.is_published = publish
  const { error } = await supabase.from('pages').update(payload).eq('id', page.value.id)
  saving.value = false
  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  } else {
    if (publish !== null) page.value.is_published = publish
    Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 900 })
  }
}

// ── Embed type detection ──────────────────────────────────────────
function detectEmbedType(url) {
  if (!url) return 'iframe'
  if (/youtube\.com|youtu\.be/.test(url)) return 'youtube'
  if (/drive\.google\.com/.test(url))     return 'drive'
  if (/docs\.google\.com\/presentation/.test(url)) return 'slides'
  if (/canva\.com/.test(url))             return 'canva'
  return 'iframe'
}

const EMBED_LABELS = { youtube:'YouTube', drive:'Google Drive', slides:'Slides', canva:'Canva', iframe:'Iframe' }
</script>

<template>
  <div class="font-sarabun">

    <!-- Loading -->
    <div v-if="loading" class="space-y-3 animate-pulse">
      <div class="h-8 bg-slate-100 rounded-xl w-1/3"></div>
      <div class="h-40 bg-slate-100 rounded-2xl"></div>
    </div>

    <template v-else>

      <!-- No permission banner -->
      <div v-if="!canEdit" class="mb-5 flex items-center gap-3 p-4 bg-amber-50 border border-amber-200 rounded-2xl">
        <SvgIcon name="star" class="w-5 h-5 text-amber-500 flex-shrink-0"/>
        <div>
          <p class="text-sm font-bold text-amber-800">คุณมีสิทธิ์ดูเท่านั้น</p>
          <p class="text-xs text-amber-600 mt-0.5">หน้านี้ยังไม่ได้รับมอบหมายให้คุณ — ติดต่อ admin เพื่อขอสิทธิ์แก้ไข</p>
        </div>
      </div>

      <!-- Header -->
      <div class="flex flex-wrap items-center justify-between gap-3 mb-6">
        <div class="flex items-center gap-3">
          <button @click="router.push('/dashboard/pages')"
            class="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 hover:bg-slate-50 transition-colors">
            <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"/>
            </svg>
          </button>
          <div>
            <h1 class="text-xl font-extrabold text-slate-800">{{ page.nav_icon }} {{ page.title }}</h1>
            <p class="text-xs text-slate-400 font-mono">/page/{{ page.slug }}</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <span :class="['text-xs font-bold px-2.5 py-1 rounded-full',
            page.is_published ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700']">
            {{ page.is_published ? '✅ เผยแพร่' : '⏸ ฉบับร่าง' }}
          </span>
          <button @click="save()" :disabled="saving"
            class="px-4 py-2 bg-slate-100 text-slate-700 font-bold text-sm rounded-xl hover:bg-slate-200 transition-colors disabled:opacity-50">
            {{ saving ? '...' : '💾 บันทึก' }}
          </button>
          <button @click="save(!page.is_published)" :disabled="saving"
            :class="['px-4 py-2 font-bold text-sm rounded-xl transition-colors disabled:opacity-50',
              page.is_published ? 'bg-amber-500 hover:bg-amber-600 text-white' : 'bg-emerald-600 hover:bg-emerald-700 text-white']">
            {{ page.is_published ? '⏸ ยกเลิกเผยแพร่' : '🚀 เผยแพร่' }}
          </button>
        </div>
      </div>

      <!-- Add block toolbar (แสดงเฉพาะมีสิทธิ์) -->
      <div v-if="canEdit" class="bg-white rounded-2xl border border-slate-100 shadow-sm p-3 mb-5">
        <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2.5">เพิ่ม Block</p>
        <div class="flex flex-wrap gap-2">
          <button v-for="bt in BLOCK_TYPES" :key="bt.type"
            @click="addBlock(bt.type)"
            class="flex items-center gap-1.5 px-3 py-1.5 bg-slate-50 hover:bg-primary-light hover:text-primary border border-slate-200 rounded-xl text-xs font-bold transition-colors">
            <SvgIcon :name="bt.iconName" class="w-3.5 h-3.5"/>
            {{ bt.label }}
          </button>
        </div>
      </div>

      <!-- Blocks list -->
      <div v-if="blocks.length === 0"
        class="text-center py-16 text-slate-400 border-2 border-dashed border-slate-200 rounded-2xl">
        <p class="text-3xl mb-2">📭</p>
        <p class="text-sm font-bold">ยังไม่มีเนื้อหา — กด "+ เพิ่ม Block" ด้านบน</p>
      </div>

      <div class="space-y-3">
        <div v-for="(block, idx) in blocks" :key="block.id"
          class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">

          <!-- Block toolbar -->
          <div class="flex items-center gap-2 px-4 py-2 bg-slate-50 border-b border-slate-100">
            <span class="flex items-center gap-1.5 text-xs font-bold text-slate-500 uppercase tracking-wider">
              <SvgIcon :name="BLOCK_TYPES.find(b=>b.type===block.type)?.iconName || 'document'" class="w-3.5 h-3.5"/>
              {{ BLOCK_TYPES.find(b=>b.type===block.type)?.label }}
            </span>
            <div class="flex items-center gap-1 ml-auto">
              <button @click="moveUp(idx)" :disabled="idx===0"
                class="w-7 h-7 rounded-lg hover:bg-slate-200 flex items-center justify-center disabled:opacity-30 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5"/>
                </svg>
              </button>
              <button @click="moveDown(idx)" :disabled="idx===blocks.length-1"
                class="w-7 h-7 rounded-lg hover:bg-slate-200 flex items-center justify-center disabled:opacity-30 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                </svg>
              </button>
              <button @click="removeBlock(idx)"
                class="w-7 h-7 rounded-lg hover:bg-red-100 text-slate-400 hover:text-red-500 flex items-center justify-center transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Block content editor -->
          <div class="p-4">

            <!-- HEADING -->
            <template v-if="block.type === 'heading'">
              <div class="flex gap-2 mb-2">
                <select v-model="block.level"
                  class="px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white">
                  <option value="h2">H2 — หัวใหญ่</option>
                  <option value="h3">H3 — หัวกลาง</option>
                  <option value="h4">H4 — หัวเล็ก</option>
                </select>
              </div>
              <input v-model="block.text" type="text" placeholder="ข้อความหัวข้อ..."
                :class="['w-full px-3 py-2 border border-slate-200 rounded-xl focus:outline-none focus:border-primary',
                  block.level==='h2' ? 'text-2xl font-extrabold' : block.level==='h3' ? 'text-xl font-bold' : 'text-lg font-semibold']"/>
            </template>

            <!-- TEXT -->
            <template v-else-if="block.type === 'text'">
              <textarea v-model="block.text" rows="4" placeholder="พิมพ์เนื้อหาที่นี่..."
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary resize-y leading-relaxed"/>
            </template>

            <!-- IMAGE -->
            <template v-else-if="block.type === 'image'">
              <input v-model="block.url" type="url" placeholder="URL รูปภาพ..."
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono mb-2"/>
              <div class="flex gap-2 mb-2">
                <input v-model="block.caption" type="text" placeholder="คำบรรยายใต้ภาพ (optional)"
                  class="flex-1 px-3 py-1.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary"/>
                <select v-model="block.align"
                  class="px-2 py-1 border border-slate-200 rounded-xl text-xs bg-white">
                  <option value="left">ซ้าย</option>
                  <option value="center">กลาง</option>
                  <option value="right">ขวา</option>
                </select>
              </div>
              <img v-if="block.url" :src="block.url" :class="['max-h-48 rounded-xl border border-slate-200',
                block.align==='center' ? 'mx-auto' : block.align==='right' ? 'ml-auto' : '']"/>
            </template>

            <!-- EMBED -->
            <template v-else-if="block.type === 'embed'">
              <input v-model="block.url" @input="block.embed_type = detectEmbedType(block.url)"
                type="url" placeholder="วาง URL (YouTube, Google Slides, Canva, Drive...)"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary font-mono mb-2"/>
              <div class="flex gap-2 items-center">
                <span class="text-xs font-bold text-slate-500">ตรวจพบ:</span>
                <span class="text-xs font-bold px-2 py-0.5 bg-blue-100 text-blue-700 rounded-full">
                  {{ EMBED_LABELS[block.embed_type] || block.embed_type }}
                </span>
                <select v-model="block.aspect" class="ml-auto px-2 py-1 border border-slate-200 rounded-lg text-xs bg-white">
                  <option value="16/9">16:9</option>
                  <option value="4/3">4:3</option>
                  <option value="1/1">1:1</option>
                </select>
              </div>
            </template>

            <!-- HTML -->
            <template v-else-if="block.type === 'html'">
              <textarea v-model="block.code" rows="6" placeholder="<div>HTML Code...</div>"
                class="w-full px-3 py-2 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:border-primary resize-y bg-slate-50"/>
            </template>

            <!-- DIVIDER -->
            <template v-else-if="block.type === 'divider'">
              <div class="flex items-center gap-3 py-2">
                <div class="flex-1 h-px bg-slate-200"></div>
                <span class="text-xs text-slate-400">เส้นแบ่งส่วน</span>
                <div class="flex-1 h-px bg-slate-200"></div>
              </div>
            </template>

          </div>
        </div>
      </div>

      <!-- Bottom save (เฉพาะมีสิทธิ์) -->
      <div v-if="canEdit && blocks.length > 0" class="mt-6 flex justify-end gap-3">
        <button @click="save()" :disabled="saving"
          class="flex items-center gap-2 px-6 py-2.5 bg-primary text-white font-bold text-sm rounded-2xl hover:bg-primary-dark transition-colors disabled:opacity-50">
          <SvgIcon name="document" class="w-4 h-4"/>
          {{ saving ? 'กำลังบันทึก...' : 'บันทึกทั้งหมด' }}
        </button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
