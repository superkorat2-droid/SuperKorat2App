<script setup>
import { onMounted, ref, nextTick } from 'vue'
import { supabase } from '../supabase'
import Cropper from 'cropperjs'
import 'cropperjs/dist/cropper.css'
import Swal from 'sweetalert2'

// --- Profile State ---
const user = ref(null)
const profile = ref({ full_name: '', position: '', avatar_url: '', is_admin: false })
const loadingProfile = ref(true)
const saving = ref(false)

// --- Banners State ---
const banners = ref([])
const loadingBanners = ref(true)
const showBannerModal = ref(false)
const editingBanner = ref(null)
const bannerForm = ref({ image_url: '', title: '', banner_type: 'image', order_index: 0, storage_path: '' })

// --- Upload & Crop State ---
const fileInput = ref(null)
const imageToCrop = ref(null)
const cropper = ref(null)
const showCropper = ref(false)
const uploading = ref(false)

onMounted(async () => {
  const { data: { session } } = await supabase.auth.getSession()
  if (session) {
    user.value = session.user
    await fetchProfile()
    if (profile.value.is_admin) await fetchBanners()
  }
})

const fetchProfile = async () => {
  const { data } = await supabase.from('profiles').select('*').eq('id', user.value.id).single()
  if (data) profile.value = data
  loadingProfile.value = false
}

const fetchBanners = async () => {
  loadingBanners.value = true
  const { data } = await supabase.from('banners').select('*').order('order_index', { ascending: true })
  banners.value = data || []
  loadingBanners.value = false
}

// --- Image/Video Handling ---
const onFileChange = (e) => {
  const file = e.target.files[0]
  if (!file) return

  if (file.size > 50 * 1024 * 1024) {
    Swal.fire({ icon: 'warning', title: 'ไฟล์ใหญ่เกินไป', text: 'จำกัดขนาดไม่เกิน 50MB', confirmButtonColor: '#3b82f6' })
    return
  }

  if (bannerForm.value.banner_type === 'image') {
    if (!file.type.startsWith('image/')) {
      Swal.fire({ icon: 'error', title: 'ผิดพลาด', text: 'กรุณาเลือกไฟล์รูปภาพเท่านั้น' })
      return
    }
    const reader = new FileReader()
    reader.onload = (event) => {
      showCropper.value = true
      nextTick(() => {
        if (cropper.value) cropper.value.destroy()
        imageToCrop.value.src = event.target.result
        cropper.value = new Cropper(imageToCrop.value, {
          aspectRatio: 16 / 9,
          viewMode: 1,
          autoCropArea: 1,
        })
      })
    }
    reader.readAsDataURL(file)
  } else {
    if (!file.type.startsWith('video/')) {
      Swal.fire({ icon: 'error', title: 'ผิดพลาด', text: 'กรุณาเลือกไฟล์วิดีโอ (MP4)' })
      return
    }
    uploadFile(file)
  }
}

const cropAndUpload = () => {
  if (!cropper.value) return
  const canvas = cropper.value.getCroppedCanvas({ width: 1280, height: 720 })
  canvas.toBlob((blob) => {
    uploadFile(blob)
    showCropper.value = false
  }, 'image/jpeg', 0.8)
}

const uploadFile = async (fileBlob) => {
  try {
    uploading.value = true
    const fileExt = bannerForm.value.banner_type === 'image' ? 'jpg' : 'mp4'
    const fileName = `${Date.now()}.${fileExt}`
    const filePath = `${fileName}`

    if (bannerForm.value.storage_path) {
      await supabase.storage.from('banners').remove([bannerForm.value.storage_path])
    }

    const { error: uploadError } = await supabase.storage.from('banners').upload(filePath, fileBlob)
    if (uploadError) throw uploadError

    const { data: { publicUrl } } = supabase.storage.from('banners').getPublicUrl(filePath)
    
    bannerForm.value.image_url = publicUrl
    bannerForm.value.storage_path = filePath
    
    Swal.fire({ icon: 'success', title: 'อัปโหลดสำเร็จ!', showConfirmButton: false, timer: 1500 })
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปโหลดไม่สำเร็จ', text: err.message })
  } finally {
    uploading.value = false
    if (fileInput.value) fileInput.value.value = ''
  }
}

const saveBanner = async () => {
  try {
    saving.value = true
    const { error } = editingBanner.value 
      ? await supabase.from('banners').update(bannerForm.value).eq('id', editingBanner.value.id)
      : await supabase.from('banners').insert(bannerForm.value)
    
    if (error) throw error
    
    Swal.fire({ icon: 'success', title: 'บันทึกสำเร็จ!', showConfirmButton: false, timer: 1500 })
    showBannerModal.value = false
    fetchBanners()
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'ไม่สามารถบันทึกได้', text: err.message })
  } finally {
    saving.value = false
  }
}

const deleteBanner = async (banner) => {
  const result = await Swal.fire({
    title: 'ยืนยันการลบ?',
    text: "ไฟล์และข้อมูลจะถูกลบถาวร!",
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#ef4444',
    cancelButtonColor: '#64748b',
    confirmButtonText: 'ใช่, ลบเลย!',
    cancelButtonText: 'ยกเลิก',
    reverseButtons: true
  })

  if (result.isConfirmed) {
    try {
      if (banner.storage_path) await supabase.storage.from('banners').remove([banner.storage_path])
      await supabase.from('banners').delete().eq('id', banner.id)
      Swal.fire({ icon: 'success', title: 'ลบเรียบร้อย!', showConfirmButton: false, timer: 1500 })
      fetchBanners()
    } catch (err) {
      Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: err.message })
    }
  }
}

const updateProfile = async () => {
  try {
    saving.value = true
    await supabase.from('profiles').upsert({ id: user.value.id, ...profile.value })
    Swal.fire({ icon: 'success', title: 'อัปเดตโปรไฟล์สำเร็จ!', showConfirmButton: false, timer: 1500 })
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อัปเดตไม่สำเร็จ', text: err.message })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 font-sarabun p-4 md:p-8">
    <div class="max-w-6xl mx-auto space-y-8">
      
      <!-- Header -->
      <header class="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white p-6 rounded-3xl shadow-sm border border-slate-100">
        <div class="flex items-center gap-4">
          <div class="w-16 h-16 rounded-2xl bg-blue-600 flex items-center justify-center text-white text-2xl shadow-lg">👤</div>
          <div>
            <h1 class="text-2xl font-black text-slate-900 leading-tight">{{ profile.full_name || 'Admin' }}</h1>
            <p class="text-slate-500 font-medium">{{ profile.position || 'ผู้จัดการระบบ' }}</p>
          </div>
        </div>
        <div v-if="profile.is_admin" class="bg-blue-50 text-blue-600 px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest border border-blue-100">Administrator</div>
      </header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Profile Form -->
        <aside class="lg:col-span-1">
          <div class="bg-white p-8 rounded-[2.5rem] shadow-xl shadow-slate-200/50 border border-slate-50">
            <h2 class="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">ตั้งค่าโปรไฟล์</h2>
            <form @submit.prevent="updateProfile" class="space-y-4">
              <input v-model="profile.full_name" type="text" placeholder="ชื่อ-นามสกุล" class="w-full px-5 py-3 rounded-2xl border border-slate-200 focus:ring-4 focus:ring-blue-50 outline-none transition-all" />
              <input v-model="profile.position" type="text" placeholder="ตำแหน่ง" class="w-full px-5 py-3 rounded-2xl border border-slate-200 focus:ring-4 focus:ring-blue-50 outline-none transition-all" />
              <button :disabled="saving" class="w-full bg-slate-900 text-white font-bold py-4 rounded-2xl hover:bg-blue-600 shadow-xl transition-all">บันทึกข้อมูล</button>
            </form>
          </div>
        </aside>

        <!-- Banner Management -->
        <main v-if="profile.is_admin" class="lg:col-span-2">
          <div class="bg-white p-8 rounded-[2.5rem] shadow-xl shadow-slate-200/50 border border-slate-50">
            <div class="flex flex-col sm:flex-row justify-between items-center mb-8 gap-4">
              <h2 class="text-lg font-bold text-slate-800">🖼️ จัดการแบนเนอร์ (16:9)</h2>
              <button @click="openBannerModal()" class="w-full sm:w-auto bg-emerald-500 hover:bg-emerald-600 text-white font-black px-8 py-3 rounded-2xl shadow-lg transition-all">+ เพิ่มใหม่</button>
            </div>

            <div v-if="loadingBanners" class="py-20 text-center"><div class="animate-spin h-10 w-10 border-4 border-blue-600 border-t-transparent mx-auto rounded-full"></div></div>
            <div v-else-if="banners.length === 0" class="py-20 text-center border-2 border-dashed border-slate-100 rounded-[2rem]">
              <p class="text-slate-400 font-bold">ยังไม่มีแบนเนอร์ในระบบ</p>
            </div>
            <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div v-for="banner in banners" :key="banner.id" class="group relative rounded-3xl overflow-hidden aspect-video bg-slate-100 border border-slate-100">
                <img v-if="banner.banner_type === 'image'" :src="banner.image_url" class="w-full h-full object-cover" />
                <video v-else :src="banner.image_url" class="w-full h-full object-cover" muted></video>
                <div class="absolute inset-0 bg-slate-900/60 opacity-0 group-hover:opacity-100 transition-all flex items-center justify-center gap-3 backdrop-blur-sm">
                  <button @click="openBannerModal(banner)" class="bg-white text-slate-900 px-6 py-2.5 rounded-xl text-xs font-black hover:bg-blue-600 hover:text-white transition-all">แก้ไข</button>
                  <button @click="deleteBanner(banner)" class="bg-red-500 text-white px-6 py-2.5 rounded-xl text-xs font-black hover:bg-red-600 transition-all">ลบ</button>
                </div>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>

    <!-- Modals -->
    <div v-if="showBannerModal" class="fixed inset-0 bg-slate-900/80 backdrop-blur-md flex items-center justify-center z-[100] p-4">
      <div class="bg-white rounded-[3rem] w-full max-w-xl p-8 md:p-10 shadow-2xl animate-in zoom-in-95">
        <h3 class="text-2xl font-black text-slate-900 mb-6">{{ editingBanner ? 'แก้ไขแบนเนอร์' : 'เพิ่มแบนเนอร์ใหม่' }}</h3>
        <div v-if="uploading" class="py-12 text-center"><div class="animate-spin h-12 w-12 border-4 border-blue-600 border-t-transparent mx-auto rounded-full mb-6"></div><p class="text-slate-900 font-black">กำลังอัปโหลดไฟล์...</p></div>
        <form v-else @submit.prevent="saveBanner" class="space-y-6">
          <div class="flex gap-4 p-2 bg-slate-100 rounded-[1.5rem]">
            <button type="button" @click="bannerForm.banner_type = 'image'" :class="bannerForm.banner_type === 'image' ? 'bg-white shadow text-blue-600' : 'text-slate-500'" class="flex-1 py-3 rounded-xl text-sm font-black transition-all">📸 รูปภาพ</button>
            <button type="button" @click="bannerForm.banner_type = 'video'" :class="bannerForm.banner_type === 'video' ? 'bg-white shadow text-blue-600' : 'text-slate-500'" class="flex-1 py-3 rounded-xl text-sm font-black transition-all">🎥 วิดีโอ</button>
          </div>
          <div class="p-6 bg-slate-50 rounded-[2rem] border-2 border-dashed border-slate-200">
            <input type="file" ref="fileInput" @change="onFileChange" :accept="bannerForm.banner_type === 'image' ? 'image/*' : 'video/mp4'" class="w-full text-sm file:mr-4 file:py-3 file:px-6 file:rounded-xl file:border-0 file:bg-blue-600 file:text-white font-black" />
          </div>
          <input v-model="bannerForm.title" type="text" placeholder="หัวข้อแบนเนอร์" class="w-full px-6 py-4 rounded-2xl border border-slate-200 outline-none" />
          <input v-model="bannerForm.order_index" type="number" placeholder="ลำดับการแสดง" class="w-full px-6 py-4 rounded-2xl border border-slate-200 outline-none" />
          <div class="flex gap-4">
            <button @click="showBannerModal = false" type="button" class="flex-1 bg-slate-100 text-slate-600 font-black py-4 rounded-2xl">ยกเลิก</button>
            <button :disabled="saving || !bannerForm.image_url" type="submit" class="flex-2 bg-blue-600 text-white font-black py-4 px-12 rounded-2xl shadow-xl">บันทึกข้อมูล</button>
          </div>
        </form>
      </div>
    </div>

    <!-- Cropper Modal -->
    <div v-if="showCropper" class="fixed inset-0 bg-slate-900 z-[200] flex flex-col items-center justify-center p-4">
      <div class="w-full max-w-5xl bg-white rounded-[3rem] overflow-hidden flex flex-col h-full max-h-[90vh]">
        <div class="p-6 border-b flex justify-between items-center"><h4 class="text-xl font-black">ครอบภาพและปรับขนาด (16:9)</h4><button @click="showCropper = false">✕</button></div>
        <div class="flex-grow bg-slate-100 relative overflow-hidden"><img ref="imageToCrop" class="max-w-full block" /></div>
        <div class="p-8 bg-slate-50 flex justify-center gap-4">
          <button @click="showCropper = false" class="px-10 py-4 bg-white font-black rounded-2xl">ยกเลิก</button>
          <button @click="cropAndUpload" class="px-16 py-4 bg-blue-600 text-white font-black rounded-2xl shadow-2xl">ตกลง ครอบภาพนี้</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style>
.swal2-popup { border-radius: 2rem !important; font-family: 'Sarabun', sans-serif !important; }
.swal2-title { font-weight: 800 !important; }
.swal2-confirm { border-radius: 1rem !important; font-weight: 800 !important; }
.swal2-cancel { border-radius: 1rem !important; font-weight: 800 !important; }
</style>
