<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'

const messages = ref([])
const loading  = ref(true)
const selected = ref(null)
const filterUnreadOnly = ref(false)

async function fetchMessages() {
  loading.value = true
  const { data, error } = await supabase
    .from('contact_messages')
    .select('*')
    .order('created_at', { ascending: false })
  if (!error) messages.value = data || []
  loading.value = false
}
onMounted(fetchMessages)

const filtered = computed(() =>
  filterUnreadOnly.value ? messages.value.filter(m => !m.is_read) : messages.value
)
const unreadCount = computed(() => messages.value.filter(m => !m.is_read).length)

async function openMessage(m) {
  selected.value = m
  if (!m.is_read) {
    const { error } = await supabase.from('contact_messages').update({ is_read: true }).eq('id', m.id)
    if (!error) m.is_read = true
  }
}

async function deleteMessage(m) {
  const res = await Swal.fire({
    title: 'ลบข้อความนี้?', icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('contact_messages').delete().eq('id', m.id)
  messages.value = messages.value.filter(x => x.id !== m.id)
  if (selected.value?.id === m.id) selected.value = null
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 800 })
}

function formatDate(iso) {
  return new Date(iso).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short' })
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">📬 ข้อความติดต่อ</h1>
        <p class="text-sm text-slate-500 mt-0.5">ข้อความที่ส่งเข้ามาจากหน้า "ติดต่อสอบถาม"</p>
      </div>
      <button @click="filterUnreadOnly = !filterUnreadOnly"
        :class="['flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-bold transition-all border-2',
          filterUnreadOnly ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-600']">
        📩 ยังไม่อ่าน ({{ unreadCount }})
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-2">
      <div v-for="i in 5" :key="i" class="h-16 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="filtered.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <div class="text-5xl mb-3">📭</div>
      <p class="font-bold text-slate-600 mb-1">ไม่มีข้อความ</p>
      <p class="text-sm text-slate-400">{{ filterUnreadOnly ? 'ไม่มีข้อความที่ยังไม่ได้อ่าน' : 'ยังไม่มีใครส่งข้อความเข้ามา' }}</p>
    </div>

    <!-- List -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-5 gap-4">
      <div class="lg:col-span-2 space-y-2 max-h-[70vh] overflow-y-auto pr-1">
        <button v-for="m in filtered" :key="m.id" @click="openMessage(m)"
          :class="['w-full text-left p-4 rounded-2xl border transition-all',
            selected?.id === m.id ? 'border-primary bg-primary/5' : 'border-slate-100 bg-white hover:border-primary/30']">
          <div class="flex items-center justify-between gap-2">
            <p class="font-bold text-sm text-slate-800 truncate flex items-center gap-1.5">
              <span v-if="!m.is_read" class="w-2 h-2 rounded-full bg-primary flex-shrink-0"></span>
              {{ m.name }}
            </p>
            <span class="text-[10px] text-slate-400 flex-shrink-0">{{ formatDate(m.created_at) }}</span>
          </div>
          <p class="text-xs font-bold text-primary mt-1 truncate">{{ m.subject }}</p>
          <p class="text-xs text-slate-500 truncate mt-0.5">{{ m.message }}</p>
        </button>
      </div>

      <!-- Detail -->
      <div class="lg:col-span-3 bg-white rounded-3xl border border-slate-100 shadow-sm p-6">
        <div v-if="!selected" class="flex flex-col items-center justify-center py-20 text-slate-400">
          <div class="text-4xl mb-3">👈</div>
          <p class="text-sm">เลือกข้อความทางซ้ายเพื่อดูรายละเอียด</p>
        </div>
        <div v-else class="space-y-4">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h2 class="font-extrabold text-lg text-slate-800">{{ selected.subject }}</h2>
              <p class="text-xs text-slate-400 mt-1">{{ formatDate(selected.created_at) }}</p>
            </div>
            <button @click="deleteMessage(selected)"
              class="px-3 py-1.5 bg-red-50 text-red-500 text-xs font-bold rounded-xl hover:bg-red-100 transition-all flex-shrink-0">
              🗑️ ลบ
            </button>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 bg-slate-50 rounded-2xl p-4">
            <div>
              <p class="text-[10px] font-bold text-slate-400 uppercase">ชื่อ-สกุล</p>
              <p class="text-sm font-bold text-slate-700">{{ selected.name }}</p>
            </div>
            <div v-if="selected.position">
              <p class="text-[10px] font-bold text-slate-400 uppercase">ตำแหน่ง/โรงเรียน</p>
              <p class="text-sm text-slate-700">{{ selected.position }}</p>
            </div>
            <div>
              <p class="text-[10px] font-bold text-slate-400 uppercase">อีเมล</p>
              <a :href="`mailto:${selected.email}`" class="text-sm text-primary font-bold hover:underline">{{ selected.email }}</a>
            </div>
            <div v-if="selected.phone">
              <p class="text-[10px] font-bold text-slate-400 uppercase">โทรศัพท์</p>
              <a :href="`tel:${selected.phone}`" class="text-sm text-primary font-bold hover:underline">{{ selected.phone }}</a>
            </div>
          </div>

          <div>
            <p class="text-[10px] font-bold text-slate-400 uppercase mb-1.5">ข้อความ</p>
            <p class="text-sm text-slate-700 leading-relaxed whitespace-pre-wrap bg-slate-50 rounded-2xl p-4">{{ selected.message }}</p>
          </div>

          <a :href="`mailto:${selected.email}?subject=${encodeURIComponent('Re: ' + selected.subject)}`"
            class="inline-flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all">
            ✉️ ตอบกลับทางอีเมล
          </a>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
