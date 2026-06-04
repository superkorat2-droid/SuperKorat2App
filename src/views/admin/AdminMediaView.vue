<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const router = useRouter()
const items   = ref([])
const loading = ref(true)
const searchQ = ref('')
const filterType    = ref('all')
const filterStatus  = ref('all')

const MEDIA_TYPES = [
  { value:'book',       label:'หนังสือ',      color:'bg-blue-500' },
  { value:'video',      label:'วิดีโอ',       color:'bg-red-500' },
  { value:'image',      label:'รูปภาพ',       color:'bg-green-500' },
  { value:'audio',      label:'เสียง',        color:'bg-purple-500' },
  { value:'app',        label:'แอปฯ',         color:'bg-teal-500' },
  { value:'exam',       label:'ข้อสอบ',       color:'bg-amber-500' },
  { value:'template',   label:'เทมเพลต',      color:'bg-indigo-500' },
  { value:'multimedia', label:'มัลติมีเดีย',  color:'bg-rose-500' },
]

async function load() {
  loading.value = true
  const { data } = await supabase.from('media').select('id,title,media_type,is_published,is_featured,is_approved,view_count,like_count,download_count,created_at,author_name,subject_group')
    .order('created_at', { ascending: false })
  items.value   = data || []
  loading.value = false
}
onMounted(load)

const stats = computed(() => ({
  total:     items.value.length,
  published: items.value.filter(i=>i.is_published).length,
  pending:   items.value.filter(i=>!i.is_approved).length,
  views:     items.value.reduce((s,i)=>s+i.view_count,0),
}))

const typeStats = computed(() =>
  MEDIA_TYPES.map(t => ({ ...t, count: items.value.filter(i=>i.media_type===t.value).length }))
)

const filtered = computed(() => {
  let list = items.value
  if (filterType.value !== 'all')   list = list.filter(i=>i.media_type===filterType.value)
  if (filterStatus.value === 'published') list = list.filter(i=>i.is_published)
  if (filterStatus.value === 'draft')     list = list.filter(i=>!i.is_published)
  if (filterStatus.value === 'pending')   list = list.filter(i=>!i.is_approved)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(i=>i.title.toLowerCase().includes(q) || i.author_name?.toLowerCase().includes(q))
  }
  return list
})

async function del(item) {
  const r = await Swal.fire({ title:'ลบสื่อนี้?', text:item.title, icon:'warning', showCancelButton:true, confirmButtonText:'ลบ', cancelButtonText:'ยกเลิก', confirmButtonColor:'#ef4444' })
  if (!r.isConfirmed) return
  await supabase.from('media').delete().eq('id', item.id)
  await load()
}

async function togglePublish(item) {
  await supabase.from('media').update({ is_published: !item.is_published }).eq('id', item.id)
  await load()
}

async function toggleApprove(item) {
  await supabase.from('media').update({ is_approved: !item.is_approved }).eq('id', item.id)
  await load()
}

function typeInfo(type) { return MEDIA_TYPES.find(t=>t.value===type) || { label:type, color:'bg-slate-400' } }
function fmtDate(d) { return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'short', day:'numeric' }) }
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800">คลังสื่อการเรียนรู้</h1>
        <p class="text-sm text-slate-500 mt-0.5">จัดการและเผยแพร่สื่อการเรียนรู้</p>
      </div>
      <button @click="router.push('/dashboard/media/new')"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        เพิ่มสื่อใหม่
      </button>
    </div>

    <!-- Stats cards -->
    <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 text-center">
        <p class="text-3xl font-extrabold text-primary">{{ stats.total }}</p>
        <p class="text-xs text-slate-500 mt-1">สื่อทั้งหมด</p>
      </div>
      <div class="bg-emerald-50 rounded-2xl border border-emerald-200 shadow-sm p-4 text-center">
        <p class="text-3xl font-extrabold text-emerald-600">{{ stats.published }}</p>
        <p class="text-xs text-slate-500 mt-1">เผยแพร่แล้ว</p>
      </div>
      <div class="bg-amber-50 rounded-2xl border border-amber-200 shadow-sm p-4 text-center">
        <p class="text-3xl font-extrabold text-amber-600">{{ stats.pending }}</p>
        <p class="text-xs text-slate-500 mt-1">รออนุมัติ</p>
      </div>
      <div class="bg-blue-50 rounded-2xl border border-blue-200 shadow-sm p-4 text-center">
        <p class="text-3xl font-extrabold text-blue-600">{{ stats.views.toLocaleString() }}</p>
        <p class="text-xs text-slate-500 mt-1">ยอดชมรวม</p>
      </div>
    </div>

    <!-- Type breakdown -->
    <div class="flex flex-wrap gap-2">
      <button @click="filterType='all'"
        :class="['px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-colors',
          filterType==='all' ? 'border-primary bg-primary/10 text-primary' : 'border-slate-200 text-slate-500 bg-white hover:border-slate-300']">
        ทั้งหมด ({{ stats.total }})
      </button>
      <button v-for="t in typeStats" :key="t.value" @click="filterType=t.value"
        :class="['flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-xl border-2 transition-colors',
          filterType===t.value ? 'border-primary bg-primary/10 text-primary' : 'border-slate-200 text-slate-500 bg-white hover:border-slate-300']">
        <div :class="['w-2 h-2 rounded-full', t.color]"/>
        {{ t.label }} ({{ t.count }})
      </button>
    </div>

    <!-- Filter + Search -->
    <div class="flex flex-wrap gap-3">
      <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อสื่อ ผู้สร้าง..."
        class="flex-1 min-w-[200px] px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white"/>
      <select v-model="filterStatus" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกสถานะ</option>
        <option value="published">เผยแพร่แล้ว</option>
        <option value="draft">ร่าง</option>
        <option value="pending">รออนุมัติ</option>
      </select>
    </div>

    <!-- Table -->
    <div v-if="loading" class="flex justify-center py-12">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>
    <div v-else class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <div v-if="filtered.length===0" class="text-center py-12 text-slate-400 text-sm">ยังไม่มีสื่อ</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-100">
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ประเภท</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ชื่อสื่อ</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">ผู้สร้าง</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500">👁 ❤️ ⬇️</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500">สถานะ</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-slate-500">วันที่</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-slate-500">จัดการ</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-50">
            <tr v-for="item in filtered" :key="item.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-4 py-3">
                <div :class="['w-7 h-7 rounded-lg flex items-center justify-center', typeInfo(item.media_type).color]">
                  <span class="text-white text-[10px] font-bold">{{ typeInfo(item.media_type).label.slice(0,2) }}</span>
                </div>
              </td>
              <td class="px-4 py-3">
                <p class="font-bold text-slate-800 text-xs max-w-[200px] truncate">{{ item.title }}</p>
                <p v-if="item.subject_group" class="text-[10px] text-slate-400">{{ item.subject_group }}</p>
              </td>
              <td class="px-4 py-3 text-xs text-slate-500">{{ item.author_name || '—' }}</td>
              <td class="px-4 py-3 text-center text-xs text-slate-500 font-mono">
                {{ item.view_count }} / {{ item.like_count }} / {{ item.download_count }}
              </td>
              <td class="px-4 py-3 text-center">
                <div class="flex items-center justify-center gap-1">
                  <button @click="toggleApprove(item)"
                    :class="['text-[10px] font-bold px-2 py-0.5 rounded-full',
                      item.is_approved ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700']">
                    {{ item.is_approved ? '✓อนุมัติ' : '⏳รอ' }}
                  </button>
                  <button @click="togglePublish(item)"
                    :class="['text-[10px] font-bold px-2 py-0.5 rounded-full',
                      item.is_published ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-500']">
                    {{ item.is_published ? 'เผยแพร่' : 'ร่าง' }}
                  </button>
                </div>
              </td>
              <td class="px-4 py-3 text-xs text-slate-400">{{ fmtDate(item.created_at) }}</td>
              <td class="px-4 py-3 text-center">
                <div class="flex items-center justify-center gap-2">
                  <button @click="router.push(`/dashboard/media/${item.id}/edit`)"
                    class="px-2.5 py-1 text-xs font-bold text-primary bg-primary/10 rounded-lg hover:bg-primary/20 transition-colors">แก้ไข</button>
                  <button @click="del(item)"
                    class="px-2.5 py-1 text-xs font-bold text-red-500 bg-red-50 rounded-lg hover:bg-red-100 transition-colors">ลบ</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
