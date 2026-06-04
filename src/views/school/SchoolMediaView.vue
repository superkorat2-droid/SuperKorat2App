<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const props = defineProps({
  school:  { type: Object, default: null },
  profile: { type: Object, default: null },
})

const router = useRouter()
const items   = ref([])
const loading = ref(true)
const searchQ = ref('')
const filterType = ref('all')

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
  if (!props.school?.id) return
  loading.value = true
  const { data } = await supabase
    .from('media').select('id,title,media_type,is_published,view_count,like_count,created_at,subject_group')
    .eq('school_id', props.school.id)
    .order('created_at', { ascending: false })
  items.value   = data || []
  loading.value = false
}
onMounted(load)

const filtered = computed(() => {
  let list = items.value
  if (filterType.value !== 'all') list = list.filter(i => i.media_type === filterType.value)
  if (searchQ.value.trim()) {
    const q = searchQ.value.trim().toLowerCase()
    list = list.filter(i => i.title.toLowerCase().includes(q))
  }
  return list
})

async function togglePublish(item) {
  await supabase.from('media').update({ is_published: !item.is_published }).eq('id', item.id)
  await load()
}

async function del(item) {
  const r = await Swal.fire({
    title: 'ลบสื่อนี้?', text: item.title,
    icon: 'warning', showCancelButton: true,
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', confirmButtonColor: '#ef4444',
  })
  if (!r.isConfirmed) return
  await supabase.from('media').delete().eq('id', item.id)
  await load()
}

function typeInfo(type) { return MEDIA_TYPES.find(t => t.value === type) || { label: type, color: 'bg-slate-400' } }
function fmtDate(d) { return new Date(d).toLocaleDateString('th-TH', { year:'numeric', month:'short', day:'numeric' }) }
</script>

<template>
  <div class="space-y-5 max-w-3xl font-sarabun">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-extrabold text-slate-800">สื่อการเรียนรู้ของโรงเรียน</h1>
        <p class="text-sm text-slate-500 mt-0.5">สร้างและจัดการสื่อเพื่อเผยแพร่สู่สาธารณะ</p>
      </div>
      <button @click="router.push('/school/media/new')"
        class="flex items-center gap-1.5 px-4 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        เพิ่มสื่อใหม่
      </button>
    </div>

    <!-- Filter -->
    <div class="flex flex-wrap gap-2">
      <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อสื่อ..."
        class="flex-1 min-w-[180px] px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:outline-none focus:border-primary bg-white"/>
      <select v-model="filterType" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm bg-white focus:outline-none focus:border-primary">
        <option value="all">ทุกประเภท</option>
        <option v-for="t in MEDIA_TYPES" :key="t.value" :value="t.value">{{ t.label }}</option>
      </select>
    </div>

    <div v-if="loading" class="flex justify-center py-12">
      <div class="w-7 h-7 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <div v-else-if="items.length === 0"
      class="text-center py-14 bg-slate-50 rounded-2xl border border-slate-200">
      <svg class="w-12 h-12 mx-auto mb-3 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 9.776c.112-.017.227-.026.344-.026h15.812c.117 0 .232.009.344.026m-16.5 0a2.25 2.25 0 00-1.883 2.542l.857 6a2.25 2.25 0 002.227 1.932H19.05a2.25 2.25 0 002.227-1.932l.857-6a2.25 2.25 0 00-1.883-2.542m-16.5 0V6A2.25 2.25 0 016 3.75h3.879a1.5 1.5 0 011.06.44l2.122 2.12a1.5 1.5 0 001.06.44H18A2.25 2.25 0 0120.25 6v.776"/>
      </svg>
      <p class="font-bold text-slate-500">ยังไม่มีสื่อ</p>
      <p class="text-sm text-slate-400 mt-1">กด "เพิ่มสื่อใหม่" เพื่อเริ่มต้น</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="item in filtered" :key="item.id"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-4 hover:shadow-md transition-shadow">
        <!-- Type badge -->
        <div :class="['w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0', typeInfo(item.media_type).color]">
          <span class="text-white text-xs font-bold">{{ typeInfo(item.media_type).label.slice(0,2) }}</span>
        </div>
        <!-- Info -->
        <div class="flex-1 min-w-0">
          <p class="font-bold text-slate-800 text-sm truncate">{{ item.title }}</p>
          <div class="flex flex-wrap gap-2 mt-0.5">
            <span v-if="item.subject_group" class="text-[10px] text-slate-400">{{ item.subject_group }}</span>
            <span class="text-[10px] text-slate-400">{{ fmtDate(item.created_at) }}</span>
            <span class="text-[10px] flex items-center gap-0.5 text-slate-400">👁 {{ item.view_count }} · ❤️ {{ item.like_count }}</span>
          </div>
        </div>
        <!-- Actions -->
        <div class="flex gap-2 flex-shrink-0">
          <button @click="togglePublish(item)"
            :class="['text-xs font-bold px-2.5 py-1.5 rounded-xl transition-colors',
              item.is_published ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200' : 'bg-slate-100 text-slate-500 hover:bg-slate-200']">
            {{ item.is_published ? 'เผยแพร่' : 'ร่าง' }}
          </button>
          <button @click="router.push(`/school/media/${item.id}/edit`)"
            class="px-2.5 py-1.5 text-xs font-bold text-primary bg-primary/10 rounded-xl hover:bg-primary/20 transition-colors">
            แก้ไข
          </button>
          <button @click="del(item)"
            class="px-2.5 py-1.5 text-xs font-bold text-red-500 bg-red-50 rounded-xl hover:bg-red-100 transition-colors">
            ลบ
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
