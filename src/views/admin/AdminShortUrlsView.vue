<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import QRCode from 'qrcode'

const BASE = `${location.origin}/#/s/`

const list    = ref([])
const loading = ref(true)
const saving  = ref(false)
const searchQ = ref('')
const showModal = ref(false)
const qrThumbs  = ref({})

const emptyForm = () => ({
  id: null, slug: '', title: '', target_url: '', expires_at: '', is_active: true,
})
const form = ref(emptyForm())

async function fetchList() {
  loading.value = true
  const { data, error } = await supabase
    .from('short_urls')
    .select('*')
    .order('created_at', { ascending: false })
  if (!error) list.value = data || []
  loading.value = false
  for (const h of list.value) thumbFor(h)
}
onMounted(fetchList)

const filtered = computed(() => {
  if (!searchQ.value) return list.value
  const q = searchQ.value.toLowerCase()
  return list.value.filter(h =>
    h.slug.toLowerCase().includes(q) ||
    (h.title || '').toLowerCase().includes(q) ||
    h.target_url.toLowerCase().includes(q))
})

const totalClicks = computed(() => list.value.reduce((s, h) => s + (h.click_count || 0), 0))

async function thumbFor(h) {
  if (qrThumbs.value[h.id]) return
  qrThumbs.value[h.id] = await QRCode.toDataURL(BASE + h.slug, { width: 160, margin: 1 })
}

function openEdit(h) {
  form.value = {
    id: h.id, slug: h.slug, title: h.title || '', target_url: h.target_url,
    expires_at: h.expires_at ? h.expires_at.slice(0, 10) : '', is_active: h.is_active,
  }
  showModal.value = true
}

async function saveEdit() {
  if (!form.value.target_url.trim())
    return Swal.fire({ icon: 'warning', title: 'กรุณาใส่ URL ปลายทาง', confirmButtonColor: '#4f46e5' })

  saving.value = true
  const { error } = await supabase.from('short_urls').update({
    title:       form.value.title.trim() || null,
    target_url:  form.value.target_url.trim(),
    expires_at:  form.value.expires_at || null,
    is_active:   form.value.is_active,
  }).eq('id', form.value.id)
  saving.value = false

  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#4f46e5' })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
    showModal.value = false
    await fetchList()
  }
}

async function toggleActive(h) {
  const { error } = await supabase.from('short_urls').update({ is_active: !h.is_active }).eq('id', h.id)
  if (!error) h.is_active = !h.is_active
}

async function deleteLink(h) {
  const res = await Swal.fire({
    title: 'ลบลิงค์นี้?', icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('short_urls').delete().eq('id', h.id)
  list.value = list.value.filter(x => x.id !== h.id)
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 800 })
}

function copyLink(h) {
  navigator.clipboard.writeText(BASE + h.slug).catch(() => {})
  Swal.fire({ icon: 'success', title: 'คัดลอกแล้ว', showConfirmButton: false, timer: 700 })
}

async function downloadQr(h) {
  await thumbFor(h)
  const a = document.createElement('a')
  a.href = qrThumbs.value[h.id]
  a.download = `qrcode-${h.slug}.png`
  a.click()
}

function isExpired(h) {
  return h.expires_at && new Date(h.expires_at) < new Date()
}

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('th-TH', { dateStyle: 'short' })
}
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">🔗 จัดการ URL ย่อ</h1>
        <p class="text-sm text-slate-500 mt-0.5">ลิงค์ย่อทั้งหมดที่สมาชิกสร้างไว้ในระบบ</p>
      </div>
      <input v-model="searchQ" type="text" placeholder="ค้นหาชื่อเรื่อง / slug / ลิงค์..."
        class="px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 w-64"/>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
        <div class="text-2xl">🔗</div>
        <div><p class="text-xl font-extrabold text-slate-800">{{ list.length }}</p><p class="text-xs text-slate-500">ลิงค์ทั้งหมด</p></div>
      </div>
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
        <div class="text-2xl">✅</div>
        <div><p class="text-xl font-extrabold text-emerald-600">{{ list.filter(h=>h.is_active).length }}</p><p class="text-xs text-slate-500">ใช้งานอยู่</p></div>
      </div>
      <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-4 flex items-center gap-3">
        <div class="text-2xl">📊</div>
        <div><p class="text-xl font-extrabold text-blue-600">{{ totalClicks.toLocaleString() }}</p><p class="text-xs text-slate-500">คลิกรวม</p></div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="space-y-2">
      <div v-for="i in 6" :key="i" class="h-16 bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="filtered.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <div class="text-5xl mb-3">🔗</div>
      <p class="font-bold text-slate-600 mb-1">ไม่มีลิงค์ย่อ</p>
      <p class="text-sm text-slate-400">{{ searchQ ? 'ไม่พบลิงค์ที่ค้นหา' : 'สมาชิกสามารถสร้างได้ที่หน้า "ย่อลิงค์"' }}</p>
    </div>

    <!-- List -->
    <div v-else class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-slate-100 bg-slate-50">
            <th class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ลิงค์</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider hidden sm:table-cell">QR</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider hidden lg:table-cell">คลิก</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider hidden md:table-cell">สร้างเมื่อ</th>
            <th class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider">สถานะ</th>
            <th class="px-4 py-3 text-right text-xs font-bold text-slate-500 uppercase tracking-wider">จัดการ</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
          <tr v-for="h in filtered" :key="h.id" class="hover:bg-slate-50 transition-colors">
            <td class="px-4 py-3">
              <p v-if="h.title" class="font-bold text-slate-800 truncate max-w-[200px]">{{ h.title }}</p>
              <p class="font-mono text-xs font-bold text-indigo-600 truncate max-w-[200px]">{{ BASE }}{{ h.slug }}</p>
              <p class="text-xs text-slate-400 truncate max-w-[200px] mt-0.5">→ {{ h.target_url }}</p>
            </td>
            <td class="px-4 py-3 text-center hidden sm:table-cell">
              <img v-if="qrThumbs[h.id]" :src="qrThumbs[h.id]" class="w-10 h-10 rounded-lg border border-slate-200 mx-auto"/>
            </td>
            <td class="px-4 py-3 text-center text-xs text-slate-600 font-bold hidden lg:table-cell">{{ (h.click_count||0).toLocaleString() }}</td>
            <td class="px-4 py-3 text-center text-xs text-slate-500 hidden md:table-cell">{{ formatDate(h.created_at) }}</td>
            <td class="px-4 py-3 text-center">
              <button @click="toggleActive(h)"
                :class="['px-2.5 py-1 rounded-full text-xs font-bold transition-all',
                  !h.is_active ? 'bg-slate-100 text-slate-500 hover:bg-slate-200'
                  : isExpired(h) ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200']">
                {{ !h.is_active ? '🚫 ปิด' : isExpired(h) ? '⏰ หมดอายุ' : '✅ ใช้งาน' }}
              </button>
            </td>
            <td class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-1.5">
                <button @click="copyLink(h)" title="คัดลอกลิงค์" class="px-3 py-1.5 bg-slate-50 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-100 transition-all">📋</button>
                <button @click="downloadQr(h)" title="ดาวน์โหลด QR" class="px-3 py-1.5 bg-emerald-50 text-emerald-600 text-xs font-bold rounded-xl hover:bg-emerald-100 transition-all">📥</button>
                <button @click="openEdit(h)" title="แก้ไข" class="px-3 py-1.5 bg-blue-50 text-blue-600 text-xs font-bold rounded-xl hover:bg-blue-100 transition-all">✏️</button>
                <button @click="deleteLink(h)" title="ลบ" class="px-3 py-1.5 bg-red-50 text-red-500 text-xs font-bold rounded-xl hover:bg-red-100 transition-all">🗑️</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- ── MODAL EDIT ──────────────────────────────────────── -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showModal"
          class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showModal = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-lg max-h-[92vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 text-lg">✏️ แก้ไขลิงค์ย่อ</h3>
              <button @click="showModal = false" class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 text-lg">✕</button>
            </div>
            <div class="flex-1 overflow-y-auto p-6 space-y-4">
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ลิงค์สั้น</label>
                <p class="font-mono text-sm font-bold text-indigo-600">{{ BASE }}{{ form.slug }}</p>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ชื่อเรื่อง</label>
                <input v-model="form.title" type="text" class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">URL ปลายทาง <span class="text-red-400">*</span></label>
                <input v-model="form.target_url" type="text" class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">วันหมดอายุ</label>
                  <input v-model="form.expires_at" type="date" class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                </div>
                <div>
                  <label class="block text-xs font-bold text-slate-600 mb-1">สถานะ</label>
                  <button @click="form.is_active = !form.is_active"
                    :class="['w-full py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.is_active ? 'border-emerald-400 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-400']">
                    {{ form.is_active ? '✅ ใช้งาน' : '🚫 ปิด' }}
                  </button>
                </div>
              </div>
            </div>
            <div class="flex items-center justify-between px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false" class="px-5 py-2.5 text-sm font-bold text-slate-600 border border-slate-200 rounded-2xl hover:bg-slate-50 transition-colors">ยกเลิก</button>
              <button @click="saveEdit" :disabled="saving"
                class="flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all disabled:opacity-50">
                💾 บันทึก
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
