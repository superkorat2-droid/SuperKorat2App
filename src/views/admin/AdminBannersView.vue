<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import StorageBrowser from '../../components/StorageBrowser.vue'
import ImageCropperModal from '../../components/ImageCropperModal.vue'

// ── State ───────────────────────────────────────────────────────
const banners     = ref([])
const loading     = ref(true)
const saving      = ref(false)
const showModal   = ref(false)
const showStorage = ref(false)
const showCropper = ref(false)
const uploading   = ref(false)

const emptyForm = () => ({
  id:          null,
  title:       '',
  subtitle:    '',
  image_url:   '',
  banner_type: 'image',
  link_url:    '',
  is_active:   true,
  sort_order:  0,
})
const form = ref(emptyForm())

// ── Fetch ────────────────────────────────────────────────────────
async function fetchBanners() {
  loading.value = true
  const { data, error } = await supabase
    .from('banners')
    .select('*')
    .order('sort_order', { ascending: true })
  if (!error) banners.value = data || []
  loading.value = false
}
onMounted(fetchBanners)

// ── Open modal ───────────────────────────────────────────────────
function openAdd() {
  form.value = emptyForm()
  form.value.sort_order = banners.value.length
  showModal.value = true
}
function openEdit(b) {
  form.value = { ...b }
  showModal.value = true
}

// ── Save ─────────────────────────────────────────────────────────
async function saveBanner() {
  if (!form.value.image_url.trim()) {
    return Swal.fire({ icon: 'warning', title: 'กรุณาใส่ URL รูปภาพ', confirmButtonColor: '#3b82f6' })
  }
  saving.value = true
  const payload = {
    title:       form.value.title,
    subtitle:    form.value.subtitle,
    image_url:   form.value.image_url,
    banner_type: form.value.banner_type,
    link_url:    form.value.link_url,
    is_active:   form.value.is_active,
    sort_order:  Number(form.value.sort_order) || 0,
  }

  let error
  if (form.value.id) {
    ;({ error } = await supabase.from('banners').update(payload).eq('id', form.value.id))
  } else {
    ;({ error } = await supabase.from('banners').insert(payload))
  }

  if (error) {
    Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ', showConfirmButton: false, timer: 1000 })
    showModal.value = false
    await fetchBanners()
  }
  saving.value = false
}

// ── Toggle active ─────────────────────────────────────────────────
async function toggleActive(b) {
  const { error } = await supabase
    .from('banners').update({ is_active: !b.is_active }).eq('id', b.id)
  if (!error) b.is_active = !b.is_active
}

// ── Delete ────────────────────────────────────────────────────────
async function deleteBanner(b) {
  const res = await Swal.fire({
    title: 'ลบแบนเนอร์นี้?', icon: 'warning',
    showCancelButton: true, confirmButtonColor: '#ef4444',
    confirmButtonText: 'ลบ', cancelButtonText: 'ยกเลิก',
  })
  if (!res.isConfirmed) return
  await supabase.from('banners').delete().eq('id', b.id)
  banners.value = banners.value.filter(x => x.id !== b.id)
  Swal.fire({ icon: 'success', title: 'ลบแล้ว', showConfirmButton: false, timer: 800 })
}

// ── Reorder ───────────────────────────────────────────────────────
async function moveUp(i) {
  if (i === 0) return
  await swapOrder(i, i - 1)
}
async function moveDown(i) {
  if (i >= banners.value.length - 1) return
  await swapOrder(i, i + 1)
}
async function swapOrder(i, j) {
  const a = banners.value[i]
  const b = banners.value[j]
  const tmp = a.sort_order; a.sort_order = b.sort_order; b.sort_order = tmp
  ;[banners.value[i], banners.value[j]] = [banners.value[j], banners.value[i]]
  await supabase.from('banners').update({ sort_order: a.sort_order }).eq('id', a.id)
  await supabase.from('banners').update({ sort_order: b.sort_order }).eq('id', b.id)
}

// ── Storage / Cropper ─────────────────────────────────────────────
function onStorageSelect({ url }) {
  form.value.image_url = url
  showStorage.value = false
}

async function onCropped({ blob }) {
  showCropper.value = false
  uploading.value = true
  const ext  = 'png'
  const name = `banner-${Date.now()}.${ext}`
  const { error } = await supabase.storage.from('banners').upload(name, blob, { contentType: 'image/png', upsert: false })
  if (error) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: error.message, confirmButtonColor: '#3b82f6' })
  } else {
    const { data } = supabase.storage.from('banners').getPublicUrl(name)
    form.value.image_url = data.publicUrl
  }
  uploading.value = false
}

// ── Computed stats ────────────────────────────────────────────────
const activeCount   = computed(() => banners.value.filter(b => b.is_active).length)
const inactiveCount = computed(() => banners.value.filter(b => !b.is_active).length)
</script>

<template>
  <div class="font-sarabun space-y-6">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800">🖼️ จัดการแบนเนอร์</h1>
        <p class="text-sm text-slate-500 mt-0.5">สไลด์รูปภาพหน้าแรกของเว็บไซต์</p>
      </div>
      <button @click="openAdd"
        class="flex items-center gap-2 px-5 py-2.5 bg-primary hover:bg-primary-dark text-white font-bold rounded-2xl shadow-md transition-all hover:-translate-y-0.5">
        ➕ เพิ่มแบนเนอร์ใหม่
      </button>
    </div>

    <!-- Stats pills -->
    <div class="flex gap-3 flex-wrap">
      <span class="px-4 py-1.5 bg-slate-100 text-slate-600 rounded-full text-sm font-bold">
        📊 ทั้งหมด {{ banners.length }} รายการ
      </span>
      <span class="px-4 py-1.5 bg-emerald-100 text-emerald-700 rounded-full text-sm font-bold">
        ✅ ใช้งาน {{ activeCount }}
      </span>
      <span class="px-4 py-1.5 bg-slate-100 text-slate-500 rounded-full text-sm font-bold">
        🚫 ซ่อน {{ inactiveCount }}
      </span>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="i in 3" :key="i" class="aspect-video bg-slate-100 rounded-2xl animate-pulse"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="banners.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border-2 border-dashed border-slate-200">
      <div class="text-6xl mb-4">🖼️</div>
      <p class="font-bold text-slate-600 text-lg mb-1">ยังไม่มีแบนเนอร์</p>
      <p class="text-sm text-slate-400 mb-6">เพิ่มแบนเนอร์แรกเพื่อแสดงบนหน้าแรกของเว็บ</p>
      <button @click="openAdd"
        class="px-6 py-2.5 bg-primary text-white font-bold rounded-2xl shadow hover:bg-primary-dark transition-all">
        ➕ เพิ่มแบนเนอร์
      </button>
    </div>

    <!-- Banner cards -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
      <div v-for="(b, i) in banners" :key="b.id"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden hover:shadow-md transition-all group">

        <!-- Thumbnail -->
        <div class="relative aspect-video bg-slate-900 overflow-hidden">
          <img v-if="b.banner_type !== 'video'" :src="b.image_url" class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" loading="lazy"/>
          <video v-else :src="b.image_url" class="w-full h-full object-cover" muted loop playsinline/>

          <!-- Badge -->
          <div class="absolute top-2 left-2 flex gap-1.5">
            <span :class="['px-2 py-0.5 text-[10px] font-bold rounded-full',
              b.is_active ? 'bg-emerald-500 text-white' : 'bg-slate-500 text-white']">
              {{ b.is_active ? '✅ แสดง' : '🚫 ซ่อน' }}
            </span>
            <span class="px-2 py-0.5 bg-black/50 text-white text-[10px] font-bold rounded-full">
              #{{ i + 1 }}
            </span>
          </div>
        </div>

        <!-- Info -->
        <div class="p-4">
          <p class="font-extrabold text-slate-800 truncate">{{ b.title || '(ไม่มีชื่อ)' }}</p>
          <p v-if="b.subtitle" class="text-xs text-slate-500 truncate mt-0.5">{{ b.subtitle }}</p>
          <p v-if="b.link_url" class="text-[10px] text-blue-500 truncate mt-1">🔗 {{ b.link_url }}</p>

          <!-- Actions -->
          <div class="flex items-center gap-1.5 mt-3">
            <!-- Toggle -->
            <button @click="toggleActive(b)"
              :class="['px-3 py-1.5 text-xs font-bold rounded-xl transition-all',
                b.is_active ? 'bg-amber-100 text-amber-700 hover:bg-amber-200' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200']">
              {{ b.is_active ? '🚫 ซ่อน' : '✅ แสดง' }}
            </button>
            <!-- Edit -->
            <button @click="openEdit(b)"
              class="px-3 py-1.5 bg-blue-50 text-blue-600 text-xs font-bold rounded-xl hover:bg-blue-100 transition-all">
              ✏️ แก้ไข
            </button>
            <!-- Move -->
            <button @click="moveUp(i)" :disabled="i===0"
              class="px-2 py-1.5 bg-slate-50 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-100 transition-all disabled:opacity-30">↑</button>
            <button @click="moveDown(i)" :disabled="i===banners.length-1"
              class="px-2 py-1.5 bg-slate-50 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-100 transition-all disabled:opacity-30">↓</button>
            <!-- Delete -->
            <button @click="deleteBanner(b)"
              class="ml-auto px-3 py-1.5 bg-red-50 text-red-500 text-xs font-bold rounded-xl hover:bg-red-100 transition-all">
              🗑️
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ── MODAL ADD/EDIT ─────────────────────────────────────── -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showModal"
          class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showModal = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden">

            <!-- Header -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800 text-lg">
                {{ form.id ? '✏️ แก้ไขแบนเนอร์' : '➕ เพิ่มแบนเนอร์ใหม่' }}
              </h3>
              <button @click="showModal = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 hover:text-slate-600 transition-colors text-lg">✕</button>
            </div>

            <!-- Body -->
            <div class="flex-1 overflow-y-auto p-6 space-y-4">

              <!-- Preview -->
              <div v-if="form.image_url" class="aspect-video rounded-2xl overflow-hidden bg-slate-900">
                <img v-if="form.banner_type !== 'video'" :src="form.image_url" class="w-full h-full object-cover"/>
                <video v-else :src="form.image_url" class="w-full h-full object-cover" muted loop playsinline/>
              </div>

              <!-- Image URL -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">📸 URL รูปภาพ / วิดีโอ <span class="text-red-400">*</span></label>
                <div class="flex gap-2">
                  <input v-model="form.image_url" type="text" placeholder="https://..."
                    class="flex-1 px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                  <button @click="showStorage = true"
                    class="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition-colors">
                    🗂️ เลือก
                  </button>
                  <button @click="showCropper = true" :disabled="uploading"
                    class="px-3 py-2 bg-primary text-white text-xs font-bold rounded-xl hover:bg-primary-dark transition-colors disabled:opacity-50">
                    {{ uploading ? '⏳' : '⬆️' }}
                  </button>
                </div>
              </div>

              <!-- Banner type -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ประเภท</label>
                <div class="flex gap-2">
                  <button v-for="t in [{v:'image',l:'🖼️ รูปภาพ'},{v:'video',l:'🎬 วิดีโอ'}]" :key="t.v"
                    @click="form.banner_type = t.v"
                    :class="['flex-1 py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.banner_type===t.v ? 'border-primary bg-primary/5 text-primary' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                    {{ t.l }}
                  </button>
                </div>
              </div>

              <!-- Title -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">ชื่อ / หัวข้อ</label>
                <input v-model="form.title" type="text" placeholder="ชื่อแบนเนอร์ (ไม่บังคับ)"
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>

              <!-- Subtitle -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">คำบรรยาย</label>
                <input v-model="form.subtitle" type="text" placeholder="คำบรรยายใต้หัวข้อ (ไม่บังคับ)"
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>

              <!-- Link -->
              <div>
                <label class="block text-xs font-bold text-slate-600 mb-1">🔗 ลิงค์เมื่อคลิก</label>
                <input v-model="form.link_url" type="text" placeholder="https://... หรือ #/page"
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
              </div>

              <!-- Sort + Active -->
              <div class="flex gap-3">
                <div class="flex-1">
                  <label class="block text-xs font-bold text-slate-600 mb-1">ลำดับ</label>
                  <input v-model.number="form.sort_order" type="number" min="0"
                    class="w-full px-3 py-2 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30"/>
                </div>
                <div class="flex-1">
                  <label class="block text-xs font-bold text-slate-600 mb-1">สถานะ</label>
                  <button @click="form.is_active = !form.is_active"
                    :class="['w-full py-2 text-sm font-bold rounded-xl border-2 transition-all',
                      form.is_active ? 'border-emerald-400 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-400']">
                    {{ form.is_active ? '✅ แสดง' : '🚫 ซ่อน' }}
                  </button>
                </div>
              </div>
            </div>

            <!-- Footer -->
            <div class="flex items-center justify-between px-6 py-4 border-t border-slate-100 flex-shrink-0">
              <button @click="showModal = false"
                class="px-5 py-2.5 text-sm font-bold text-slate-600 border border-slate-200 rounded-2xl hover:bg-slate-50 transition-colors">
                ยกเลิก
              </button>
              <button @click="saveBanner" :disabled="saving"
                class="flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-2xl shadow-md transition-all disabled:opacity-50">
                <svg v-if="saving" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"/>
                </svg>
                💾 บันทึก
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Storage Browser Modal -->
    <Teleport to="body">
      <Transition enter-active-class="transition duration-200" enter-from-class="opacity-0" enter-to-class="opacity-100"
        leave-active-class="transition duration-150" leave-from-class="opacity-100" leave-to-class="opacity-0">
        <div v-if="showStorage"
          class="fixed inset-0 z-[150] flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          @click.self="showStorage = false">
          <div class="bg-white rounded-3xl shadow-2xl w-full max-w-4xl max-h-[85vh] flex flex-col overflow-hidden">
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 flex-shrink-0">
              <h3 class="font-extrabold text-slate-800">🗂️ เลือกรูปภาพจาก Storage</h3>
              <button @click="showStorage = false"
                class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 text-lg">✕</button>
            </div>
            <div class="flex-1 overflow-y-auto p-6">
              <StorageBrowser bucket="banners" title="ภาพแบนเนอร์" :selectable="true" @select="onStorageSelect"/>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Image Cropper -->
    <ImageCropperModal
      :show="showCropper"
      :aspect-ratio="16/9"
      title="ครอบรูปแบนเนอร์ (16:9)"
      @close="showCropper = false"
      @cropped="onCropped"/>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
