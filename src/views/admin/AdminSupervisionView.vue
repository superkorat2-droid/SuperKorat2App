<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import { useAreaConfig } from '../../composables/useAreaConfig'
import QRCode from 'qrcode'
import Swal from 'sweetalert2'

const router = useRouter()
const { config: areaConfig, fetchConfig } = useAreaConfig()

const forms          = ref([])
const loading        = ref(true)
const search         = ref('')
const myFormsOnly    = ref(false)
const currentProfile = ref(null)
const currentUserId  = ref(null)
const profilesById   = ref({})

function groupLabel(key) { return areaConfig.value?.personnel_groups?.find(g => g.key === key)?.label || key }
function displayName(p) {
  if (!p) return '-'
  if (p.first_name || p.last_name) return `${p.title || ''} ${p.first_name || ''} ${p.last_name || ''}`.trim()
  return p.full_name || p.email || '-'
}
function responsibleFor(form) {
  return (form.responsible_ids || []).map(id => profilesById.value[id]).filter(Boolean)
}

const isAdmin = computed(() =>
  ['super_admin','admin'].includes(currentProfile.value?.role)
)
const canPublish = computed(() =>
  isAdmin.value
  || currentProfile.value?.role === 'supervisor'
  || currentProfile.value?.can_publish_supervision === true
)

const filtered = computed(() =>
  forms.value.filter(f =>
    f.title.toLowerCase().includes(search.value.toLowerCase())
  )
)

const STATUS_LABEL = { draft: 'ร่าง', published: 'เผยแพร่แล้ว', closed: 'ปิดแล้ว' }
const STATUS_COLOR = {
  draft:     'bg-slate-100 text-slate-500',
  published: 'bg-emerald-100 text-emerald-700',
  closed:    'bg-red-100 text-red-500',
}

async function load() {
  loading.value = true
  const { data, error } = await supabase
    .from('supervision_forms').select('*').order('created_at', { ascending: false })
  let list = data || []
  if (!isAdmin.value || myFormsOnly.value) {
    list = list.filter(f => f.created_by === currentUserId.value || f.responsible_ids?.includes(currentUserId.value))
  }
  if (!error) forms.value = list
  loading.value = false
}

async function deleteForm(form) {
  const result = await Swal.fire({
    title: 'ลบแบบนิเทศ?',
    text: `"${form.title}" จะถูกลบถาวรพร้อมคำถามและคำตอบทั้งหมด`,
    icon: 'warning',
    showCancelButton: true,
    confirmButtonText: 'ลบ',
    cancelButtonText: 'ยกเลิก',
    confirmButtonColor: '#ef4444',
  })
  if (!result.isConfirmed) return
  const { error } = await supabase.from('supervision_forms').delete().eq('id', form.id)
  if (error) Swal.fire({ icon: 'error', title: 'ลบไม่สำเร็จ', text: error.message })
  else load()
}

async function changeStatus(form, status) {
  const { error } = await supabase
    .from('supervision_forms')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', form.id)
  if (error) Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message })
  else load()
}

function copyPublicLink(form) {
  if (!form.allow_public) {
    Swal.fire({ icon: 'warning', title: 'ยังไม่ได้เปิดลิงค์สาธารณะ', text: 'แก้ไขฟอร์มและเปิด "อนุญาตลิงค์สาธารณะ" ก่อน' })
    return
  }
  const url = `${window.location.origin}${window.location.pathname}#/supervision/${form.public_token}`
  navigator.clipboard.writeText(url)
  Swal.fire({ icon: 'success', title: 'คัดลอกแล้ว', text: url, showConfirmButton: false, timer: 2000 })
}

async function downloadQR(form) {
  if (!form.allow_public) {
    Swal.fire({ icon: 'warning', title: 'ยังไม่ได้เปิดลิงค์สาธารณะ', text: 'แก้ไขฟอร์มและเปิด "อนุญาตลิงค์สาธารณะ" ก่อน' })
    return
  }
  const url = `${window.location.origin}${window.location.pathname}#/supervision/${form.public_token}`
  const dataUrl = await QRCode.toDataURL(url, {
    width: 400, margin: 2, errorCorrectionLevel: 'M',
    color: { dark: '#000000', light: '#ffffff' },
  })
  const a = document.createElement('a')
  a.href = dataUrl
  a.download = `qrcode-supervision-${form.public_token}.png`
  a.click()
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}

onMounted(async () => {
  await fetchConfig()
  const { data: { user } } = await supabase.auth.getUser()
  currentUserId.value = user?.id
  if (user?.id) {
    const { data: p } = await supabase
      .from('profiles').select('role, can_publish_supervision').eq('id', user.id).single()
    currentProfile.value = p
  }
  const { data: pp } = await supabase.from('profiles')
    .select('id, title, first_name, last_name, full_name, avatar_url')
  profilesById.value = Object.fromEntries((pp || []).map(p => [p.id, p]))
  await load()
})
</script>

<template>
  <div class="font-sarabun space-y-5">

    <!-- Header -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-2xl font-extrabold text-slate-800 flex items-center gap-2">
          <SvgIcon name="clipboard" class="w-6 h-6 text-primary"/>
          แบบนิเทศติดตาม
        </h1>
        <p class="text-sm text-slate-500 mt-0.5">สร้างและจัดการแบบนิเทศ — โรงเรียนกรอกผ่านระบบหรือลิงค์สาธารณะ</p>
      </div>
      <button @click="router.push('/dashboard/supervision/new')"
        class="flex items-center gap-1.5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
        <SvgIcon name="plus" class="w-4 h-4"/>
        สร้างแบบนิเทศใหม่
      </button>
    </div>

    <!-- Admin tabs: ของฉัน / ทั้งหมด -->
    <div v-if="isAdmin" class="flex gap-1 bg-slate-100 p-1 rounded-xl w-fit">
      <button @click="myFormsOnly = false; load()"
        :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
          !myFormsOnly ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        ทั้งหมด
      </button>
      <button @click="myFormsOnly = true; load()"
        :class="['px-4 py-1.5 text-sm font-bold rounded-lg transition-colors',
          myFormsOnly ? 'bg-white text-slate-800 shadow-sm' : 'text-slate-500 hover:text-slate-700']">
        ของฉัน
      </button>
    </div>

    <!-- Search -->
    <div class="relative max-w-sm">
      <SvgIcon name="magnify" class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"/>
      <input v-model="search" type="text" placeholder="ค้นหาชื่อแบบนิเทศ..."
        class="w-full pl-9 pr-4 py-2.5 text-sm border border-slate-200 rounded-2xl focus:outline-none focus:border-primary"/>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <!-- Empty -->
    <div v-else-if="filtered.length === 0"
      class="text-center py-16 bg-white rounded-2xl border border-slate-100 text-slate-400">
      <SvgIcon name="clipboard" class="w-12 h-12 mx-auto mb-3 opacity-30"/>
      <p class="font-medium">ยังไม่มีแบบนิเทศ</p>
      <p class="text-sm mt-1">กด "สร้างแบบนิเทศใหม่" เพื่อเริ่มต้น</p>
    </div>

    <!-- List -->
    <div v-else class="space-y-3">
      <div v-for="form in filtered" :key="form.id"
        class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5 hover:shadow-md transition-shadow">

        <div class="flex flex-wrap items-start justify-between gap-4">
          <!-- Info -->
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <span :class="['text-xs font-bold px-2.5 py-0.5 rounded-full', STATUS_COLOR[form.status]]">
                {{ STATUS_LABEL[form.status] }}
              </span>
              <span v-if="form.allow_public" class="text-xs bg-blue-100 text-blue-700 font-bold px-2.5 py-0.5 rounded-full">
                🔗 ลิงค์สาธารณะ
              </span>
              <span v-if="form.deadline && new Date(form.deadline) < new Date()"
                class="text-xs bg-amber-100 text-amber-700 font-bold px-2.5 py-0.5 rounded-full">
                หมดเวลา
              </span>
            </div>
            <h2 class="font-bold text-slate-800 text-lg leading-snug">{{ form.title }}</h2>
            <p v-if="form.description" class="text-sm text-slate-500 mt-0.5 line-clamp-2">{{ form.description }}</p>
            <div class="flex flex-wrap gap-4 mt-2 text-xs text-slate-400">
              <span>สร้างเมื่อ: {{ formatDate(form.created_at) }}</span>
              <span v-if="form.deadline">กำหนดส่ง: {{ formatDate(form.deadline) }}</span>
              <span>เป้าหมาย: {{ form.target === 'all' ? 'ทุกโรงเรียน' : `${form.target_schools?.length || 0} โรงเรียน` }}</span>
            </div>
            <div v-if="form.responsible_group || responsibleFor(form).length" class="flex items-center gap-1.5 mt-2">
              <span class="text-xs text-slate-400">ผู้รับผิดชอบ:</span>
              <span v-if="form.responsible_group" class="text-xs bg-slate-100 text-slate-600 font-bold px-2 py-0.5 rounded-full">
                {{ groupLabel(form.responsible_group) }}
              </span>
              <div v-for="p in responsibleFor(form)" :key="p.id" class="flex items-center gap-1 bg-slate-50 rounded-full pl-0.5 pr-2 py-0.5">
                <div class="w-4 h-4 rounded-full overflow-hidden bg-slate-200 flex items-center justify-center flex-shrink-0">
                  <img v-if="p.avatar_url" :src="p.avatar_url" class="w-full h-full object-cover object-top"/>
                  <span v-else class="text-[8px] font-extrabold text-primary">{{ displayName(p)[0] || '?' }}</span>
                </div>
                <span class="text-xs text-slate-600">{{ displayName(p) }}</span>
              </div>
            </div>
          </div>

          <!-- Actions -->
          <div class="flex flex-wrap gap-2 flex-shrink-0">
            <!-- View results -->
            <button @click="router.push(`/dashboard/supervision/${form.id}/results`)"
              class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-primary/10 text-primary rounded-xl hover:bg-primary/20 transition-colors">
              <SvgIcon name="chart-bar" class="w-3.5 h-3.5"/>
              ดูผล
            </button>
            <!-- Copy link -->
            <button @click="copyPublicLink(form)"
              :class="['flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-xl transition-colors',
                form.allow_public ? 'bg-blue-100 text-blue-700 hover:bg-blue-200' : 'bg-slate-100 text-slate-400 hover:bg-slate-200']">
              <SvgIcon name="link" class="w-3.5 h-3.5"/>
              ลิงค์
            </button>
            <!-- Download QR -->
            <button @click="downloadQR(form)"
              :class="['flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-xl transition-colors',
                form.allow_public ? 'bg-blue-100 text-blue-700 hover:bg-blue-200' : 'bg-slate-100 text-slate-400 hover:bg-slate-200']">
              <SvgIcon name="qrcode" class="w-3.5 h-3.5"/>
              QR
            </button>
            <!-- Edit -->
            <button @click="router.push(`/dashboard/supervision/${form.id}/edit`)"
              class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
              <SvgIcon name="wrench" class="w-3.5 h-3.5"/>
              แก้ไข
            </button>

            <!-- Status toggle -->
            <div class="relative group">
              <button class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-slate-100 text-slate-600 rounded-xl hover:bg-slate-200 transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5"/>
                </svg>
                สถานะ
              </button>
              <div class="absolute right-0 mt-1 bg-white rounded-2xl shadow-xl border border-slate-100 py-1 z-10 min-w-[130px] hidden group-hover:block">
                <button v-for="s in ['draft','published','closed']" :key="s"
                  @click="changeStatus(form, s)"
                  :class="['w-full text-left px-4 py-2 text-xs font-bold transition-colors',
                    form.status === s ? 'text-primary bg-primary/5' : 'text-slate-600 hover:bg-slate-50',
                    STATUS_COLOR[s].includes('emerald') ? 'hover:text-emerald-700' : '']">
                  {{ STATUS_LABEL[s] }}
                </button>
              </div>
            </div>

            <!-- Delete -->
            <button @click="deleteForm(form)"
              class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-slate-50 text-slate-400 rounded-xl hover:text-red-500 hover:bg-red-50 transition-colors">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
              ลบ
            </button>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
