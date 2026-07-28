<script setup>
/**
 * AdminImageLibraryView — คลังภาพสำหรับ admin
 *
 * ใช้ฝากรูปไว้บน PHP host ของเขต แล้วคัดลอกลิงก์ไปป้อนให้ AI ทำเว็บ
 *
 * ไฟล์จริงอยู่บน host · สารบัญอยู่ในตาราง image_library ที่เปิดให้เฉพาะ
 * super_admin/admin (RLS ใน migration 0067) · การอัป/ลบไฟล์วิ่งผ่าน Edge
 * Function media-upload ที่ถือความลับของ host ไว้ฝั่งเซิร์ฟเวอร์
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import { useExternalUpload, externalUploadEnabled, deleteUploadedFile } from '../../composables/useExternalUpload'
import Swal from 'sweetalert2'

const { uploadFile, uploading } = useExternalUpload()

const items    = ref([])
const loading  = ref(true)
const q        = ref('')
const progress = ref(0)
const busyText = ref('')
const copiedId = ref(null)
let copyTimer  = null

async function fetchItems() {
  loading.value = true
  const { data, error } = await supabase
    .from('image_library').select('*').order('created_at', { ascending: false })
  if (error) {
    Swal.fire({ icon: 'error', title: 'โหลดคลังภาพไม่สำเร็จ', text: error.message })
    items.value = []
  } else items.value = data || []
  loading.value = false
}
onMounted(fetchItems)

const filtered = computed(() => {
  const s = q.value.trim().toLowerCase()
  if (!s) return items.value
  return items.value.filter(i =>
    (i.title || '').toLowerCase().includes(s) ||
    (i.filename || '').toLowerCase().includes(s) ||
    (i.tags || []).some(t => t.toLowerCase().includes(s)))
})

const totalSize = computed(() =>
  items.value.reduce((sum, i) => sum + (i.size_bytes || 0), 0))

function fmtSize(b) {
  if (!b) return '—'
  if (b < 1024) return b + ' B'
  if (b < 1024 * 1024) return (b / 1024).toFixed(0) + ' KB'
  return (b / 1024 / 1024).toFixed(1) + ' MB'
}
function fmtDate(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  return `${d.getDate()} ${['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'][d.getMonth()]} ${d.getFullYear() + 543}`
}

/** อ่านขนาดภาพจริงก่อนอัป — เก็บไว้โชว์ให้รู้ว่ารูปไหนใหญ่พอใช้เป็นแบนเนอร์ */
function readDimensions(file) {
  return new Promise(resolve => {
    const img = new Image()
    const url = URL.createObjectURL(file)
    img.onload  = () => { URL.revokeObjectURL(url); resolve({ width: img.naturalWidth, height: img.naturalHeight }) }
    img.onerror = () => { URL.revokeObjectURL(url); resolve({ width: null, height: null }) }
    img.src = url
  })
}

async function onPick(ev) {
  const files = [...(ev.target.files || [])]
  ev.target.value = ''
  if (!files.length) return

  const { data: { user } } = await supabase.auth.getUser()
  let ok = 0, fail = []

  for (let i = 0; i < files.length; i++) {
    const f = files[i]
    busyText.value = `กำลังอัปโหลด ${i + 1}/${files.length} — ${f.name}`
    progress.value = 0
    try {
      const dim = await readDimensions(f)
      const url = await uploadFile(f, 'gallery', p => { progress.value = p })
      const { error } = await supabase.from('image_library').insert({
        url, filename: f.name, title: f.name.replace(/\.[^.]+$/, ''),
        size_bytes: f.size, mime: f.type, width: dim.width, height: dim.height,
        uploaded_by: user?.id || null,
      })
      if (error) throw new Error(error.message)
      ok++
    } catch (e) {
      fail.push(`${f.name}: ${e.message}`)
    }
  }
  busyText.value = ''
  progress.value = 0
  await fetchItems()

  if (fail.length) {
    Swal.fire({ icon: ok ? 'warning' : 'error',
      title: ok ? `อัปสำเร็จ ${ok} รูป · ไม่สำเร็จ ${fail.length} รูป` : 'อัปโหลดไม่สำเร็จ',
      html: `<div style="text-align:left;font-size:13px">${fail.join('<br>')}</div>` })
  } else {
    Swal.fire({ icon: 'success', title: `อัปโหลด ${ok} รูปสำเร็จ`, showConfirmButton: false, timer: 1200 })
  }
}

async function copyUrl(item) {
  try {
    await navigator.clipboard.writeText(item.url)
  } catch {
    // เบราว์เซอร์บางตัวบล็อก clipboard API เมื่อไม่ใช่ https — ใช้วิธีเดิมสำรอง
    const ta = document.createElement('textarea')
    ta.value = item.url; document.body.appendChild(ta); ta.select()
    document.execCommand('copy'); ta.remove()
  }
  copiedId.value = item.id
  clearTimeout(copyTimer)
  copyTimer = setTimeout(() => { copiedId.value = null }, 1500)
}

async function saveTitle(item) {
  const { error } = await supabase.from('image_library')
    .update({ title: (item.title || '').trim(), tags: item.tags || [] }).eq('id', item.id)
  if (error) Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
}

async function editTags(item) {
  const res = await Swal.fire({
    title: 'แท็กของรูปนี้', input: 'text', inputValue: (item.tags || []).join(', '),
    inputPlaceholder: 'คั่นด้วยจุลภาค เช่น โลโก้, พื้นหลัง, ปกข่าว',
    showCancelButton: true, confirmButtonText: 'บันทึก', cancelButtonText: 'ยกเลิก',
    confirmButtonColor: 'var(--color-primary)',
  })
  if (!res.isConfirmed) return
  item.tags = (res.value || '').split(',').map(t => t.trim()).filter(Boolean)
  await saveTitle(item)
}

async function removeItem(item) {
  const res = await Swal.fire({
    title: 'ลบรูปนี้?', text: item.title || item.filename, icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก', reverseButtons: true,
  })
  if (!res.isConfirmed) return

  // ลบไฟล์จริงก่อน แล้วค่อยลบแถว — ถ้าสลับกันจะเหลือไฟล์กำพร้าบนเซิร์ฟเวอร์
  // ที่ไม่มีใครรู้ว่ามีอยู่และลบไม่ได้อีกเลย
  let fileErr = ''
  try { await deleteUploadedFile(item.url) } catch (e) { fileErr = e.message }

  if (fileErr) {
    const go = await Swal.fire({
      icon: 'warning', title: 'ลบไฟล์บนเซิร์ฟเวอร์ไม่สำเร็จ',
      html: `${fileErr}<br><br>จะลบรายการออกจากคลังอยู่ไหม? (ไฟล์จะค้างบนเซิร์ฟเวอร์)`,
      showCancelButton: true, confirmButtonText: 'ลบรายการ', cancelButtonText: 'ยกเลิก',
      confirmButtonColor: '#ef4444', reverseButtons: true,
    })
    if (!go.isConfirmed) return
  }

  const { error } = await supabase.from('image_library').delete().eq('id', item.id)
  if (error) { Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message }); return }
  await fetchItems()
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800">คลังภาพ</h1>
        <p class="text-sm text-slate-500">
          ฝากรูปไว้บนเซิร์ฟเวอร์ของเขต แล้วคัดลอกลิงก์ไปใช้งานต่อ · เห็นเฉพาะผู้ดูแลระบบ
        </p>
      </div>
      <label :class="['px-4 py-2.5 rounded-xl text-sm font-bold text-white cursor-pointer transition-all flex items-center gap-2',
        uploading ? 'bg-slate-400 cursor-wait' : 'bg-primary hover:opacity-90']">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15"/>
        </svg>
        {{ uploading ? 'กำลังอัปโหลด…' : 'อัปโหลดรูป' }}
        <input type="file" accept="image/*" multiple class="hidden" :disabled="uploading" @change="onPick"/>
      </label>
    </div>

    <div v-if="!externalUploadEnabled"
      class="glass-card p-4 text-sm text-amber-700 bg-amber-50/70 border border-amber-200">
      ยังไม่ได้ตั้งค่าเซิร์ฟเวอร์ฝากไฟล์ (<b>VITE_UPLOAD_API_URL</b>) — อัปโหลดไม่ได้
    </div>

    <!-- ความคืบหน้า -->
    <div v-if="busyText" class="glass-card p-4">
      <span class="block text-xs font-bold text-slate-500 mb-2">{{ busyText }}</span>
      <div class="w-full h-2 rounded-full bg-slate-200 overflow-hidden">
        <div class="h-full bg-primary transition-all duration-200" :style="{ width: progress + '%' }"/>
      </div>
    </div>

    <!-- สรุป + ค้นหา -->
    <div class="glass-card p-4 flex flex-wrap items-center gap-3">
      <span class="text-xs font-bold text-slate-500">
        {{ items.length }} รูป · {{ fmtSize(totalSize) }}
      </span>
      <input v-model="q" type="text" placeholder="ค้นหาชื่อรูปหรือแท็ก…"
        class="ml-auto w-full sm:w-72 px-3 py-2 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-primary"/>
    </div>

    <div v-if="loading" class="text-center py-16 text-slate-400">กำลังโหลด…</div>

    <div v-else-if="!filtered.length"
      class="text-center py-16 text-slate-400 border-2 border-dashed border-slate-200 rounded-2xl">
      <span class="block text-3xl mb-2">🖼️</span>
      <span class="block text-sm font-bold">
        {{ items.length ? 'ไม่พบรูปที่ค้นหา' : 'ยังไม่มีรูป — กด "อัปโหลดรูป" ด้านบน' }}
      </span>
    </div>

    <div v-else class="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-4">
      <div v-for="it in filtered" :key="it.id"
        class="glass-card overflow-hidden flex flex-col">
        <!-- ภาพ -->
        <a :href="it.url" target="_blank" rel="noopener"
          class="block aspect-[4/3] bg-slate-100 overflow-hidden group">
          <img :src="it.url" :alt="it.title" loading="lazy"
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"/>
        </a>

        <div class="p-3 flex flex-col gap-2 flex-1">
          <input v-model="it.title" @change="saveTitle(it)" type="text" placeholder="ตั้งชื่อรูป"
            class="w-full px-2 py-1.5 rounded-lg border border-transparent hover:border-slate-200 focus:border-primary text-sm font-bold text-slate-700 focus:outline-none transition-colors"/>

          <div class="flex flex-wrap gap-1">
            <button v-for="t in (it.tags || [])" :key="t" @click="q = t"
              class="px-2 py-0.5 rounded-lg bg-slate-100 text-[10px] font-bold text-slate-500 hover:bg-primary-light hover:text-primary transition-colors">
              {{ t }}
            </button>
            <button @click="editTags(it)"
              class="px-2 py-0.5 rounded-lg border border-dashed border-slate-300 text-[10px] font-bold text-slate-400 hover:border-primary hover:text-primary transition-colors">
              + แท็ก
            </button>
          </div>

          <span class="block text-[10px] text-slate-400 mt-auto">
            {{ it.width && it.height ? `${it.width}×${it.height}` : '' }}
            {{ it.size_bytes ? ' · ' + fmtSize(it.size_bytes) : '' }}
            · {{ fmtDate(it.created_at) }}
          </span>

          <div class="flex items-center gap-1.5">
            <!-- ปุ่มคัดลอกลิงก์ — ตัวหลักของหน้านี้ -->
            <button @click="copyUrl(it)"
              :class="['flex-1 flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-xl text-xs font-bold transition-all',
                copiedId === it.id
                  ? 'bg-emerald-500 text-white'
                  : 'bg-primary text-white hover:opacity-90']">
              <svg v-if="copiedId === it.id" class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5"/>
              </svg>
              <svg v-else class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.8">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 011.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 00-3.375-3.375h-1.5a1.125 1.125 0 01-1.125-1.125v-1.5a3.375 3.375 0 00-3.375-3.375H9.75"/>
              </svg>
              {{ copiedId === it.id ? 'คัดลอกแล้ว' : 'คัดลอกลิงก์' }}
            </button>
            <button @click="removeItem(it)" title="ลบรูปนี้"
              class="px-2 py-1.5 rounded-xl bg-red-50 text-red-500 hover:bg-red-100 transition-colors">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.8">
                <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
