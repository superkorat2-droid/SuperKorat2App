<script setup>
/**
 * ทำเนียบครู (สาธารณะ) — ข้อมูลจากแบบสำรวจเครือข่ายวิชาชีพครู
 * อ่านผ่าน RPC public_teacher_directory เท่านั้น: ชื่อ รูป โรงเรียน อำเภอ/ศูนย์ ชั้นที่สอน เครือข่าย
 * (เบอร์/ไลน์/อีเมล/วุฒิ/คำตอบส่วนที่ 2 ไม่ออกมาจาก server เลย)
 * แบ่งหน้าที่ server ทีละ 60 คน — ครูทั้งเขต ~2,000 คน ไม่ต้องโหลดทีเดียว
 */
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import { useTeacherSurveyConfig, leafOptions, labelOf, fullName, initialsOf } from '../composables/useTeacherSurvey'
import PageHero from '../components/PageHero.vue'

const PAGE = 60
const { config: area, fetchConfig: fetchArea } = useAreaConfig()
const { config: cfg, fetchConfig } = useTeacherSurveyConfig()
const header = usePageHeader('teachers', { icon: 'users', title: 'ทำเนียบครู', align: 'center' })

const schools = ref([])
const rows    = ref([])
const total   = ref(0)
const loading = ref(true)
const more    = ref(false)

const q        = ref('')
const district = ref('')
const group    = ref('')
const schoolId = ref('')
const network  = ref('')
const grade    = ref('')

const districts = computed(() => [...new Set(schools.value.map(s => s.district).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))
const groups = computed(() => [...new Set(schools.value
  .filter(s => !district.value || s.district === district.value)
  .map(s => s.school_group).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))
const schoolsInFilter = computed(() => schools.value.filter(s =>
  (!district.value || s.district === district.value) && (!group.value || s.school_group === group.value)))
const networkOpts = computed(() => leafOptions(cfg.value?.options?.networks))
const gradeOpts   = computed(() => cfg.value?.options?.grades || [])
const isFiltered  = computed(() => !!(q.value.trim() || district.value || group.value || schoolId.value || network.value || grade.value))

function filters() {
  return {
    q: q.value.trim(), district: district.value, school_group: group.value,
    school_id: schoolId.value, network: network.value, grade: grade.value,
  }
}

let seq = 0
async function load(append = false) {
  const my = ++seq
  append ? (more.value = true) : (loading.value = true)
  const { data, error } = await supabase.rpc('public_teacher_directory', {
    p_filters: filters(), p_limit: PAGE, p_offset: append ? rows.value.length : 0,
  })
  if (my !== seq) return          // ผลของคำค้นเก่าที่มาช้า — ทิ้ง
  if (!error && data) {
    rows.value = append ? [...rows.value, ...data.rows] : data.rows
    total.value = data.total
  }
  loading.value = false
  more.value = false
}

onMounted(async () => {
  const [, , sch] = await Promise.all([fetchArea(), fetchConfig(), supabase.rpc('get_schools_public')])
  schools.value = sch.data || []
  await load()
})

// พิมพ์ค้นหา: รอหยุดพิมพ์ 350ms · ตัวกรองอื่น: โหลดทันที
let timer = null
watch(q, () => { clearTimeout(timer); timer = setTimeout(() => load(), 350) })
watch([district, group, schoolId, network, grade], () => load())

function onDistrictChange() { group.value = ''; schoolId.value = '' }
function onGroupChange()    { schoolId.value = '' }
function reset() { q.value = ''; district.value = ''; group.value = ''; schoolId.value = ''; network.value = ''; grade.value = '' }

function gradeText(keys) {
  const list = (keys || []).map(k => labelOf(cfg.value, 'grades', k)
    .replace('ประถมศึกษาปีที่ ', 'ป.').replace('มัธยมศึกษาปีที่ ', 'ม.'))
  return list.join(' ')
}

const selCls = 'px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary min-w-0'
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero v-if="!header.hidden"
      :title="header.title"
      :subtitle="header.subtitle || `เครือข่ายวิชาชีพครู ${area?.area_name || ''}`"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      :align="header.align" max-width="5xl"/>

    <div class="max-w-7xl mx-auto px-4 py-6 space-y-5">
      <div class="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center">
        <input :value="q" @input="q = $event.target.value" type="search" placeholder="ค้นหาชื่อครู หรือโรงเรียน..."
          class="flex-1 px-4 py-3 rounded-2xl border border-slate-200 bg-white/70 backdrop-blur text-sm focus:outline-none focus:border-primary"/>
        <router-link to="/teacher-survey"
          class="text-center px-5 py-3 rounded-2xl bg-primary text-white text-sm font-bold hover:opacity-90 whitespace-nowrap">
          ✍️ ลงทะเบียน / ตอบแบบสำรวจ
        </router-link>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2">
        <select v-model="district" @change="onDistrictChange" :class="selCls">
          <option value="">ทุกอำเภอ</option>
          <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
        </select>
        <select v-model="group" @change="onGroupChange" :class="selCls">
          <option value="">ทุกศูนย์เครือข่าย</option>
          <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
        </select>
        <select v-model="schoolId" :class="[selCls, 'col-span-2 sm:col-span-1']">
          <option value="">ทุกโรงเรียน</option>
          <option v-for="s in schoolsInFilter" :key="s.id" :value="s.id">{{ s.name }}</option>
        </select>
        <select v-model="network" :class="[selCls, 'col-span-2 sm:col-span-1 lg:col-span-2']">
          <option value="">ทุกเครือข่าย</option>
          <option v-for="n in networkOpts" :key="n.key" :value="n.key">{{ n.label }}</option>
        </select>
        <select v-model="grade" :class="[selCls, 'col-span-2 sm:col-span-1']">
          <option value="">ทุกระดับชั้น</option>
          <option v-for="g in gradeOpts" :key="g.key" :value="g.key">{{ g.label }}</option>
        </select>
      </div>

      <div class="flex items-center gap-3 text-sm">
        <span class="font-bold text-primary">{{ total.toLocaleString() }} คน</span>
        <button v-if="isFiltered" @click="reset" class="text-slate-400 hover:text-red-500">✕ ล้างตัวกรอง</button>
      </div>

      <div v-if="loading" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
        <div v-for="i in 8" :key="i" class="glass-card p-3 animate-pulse flex gap-3">
          <div class="w-14 h-14 rounded-full bg-slate-100 shrink-0"/>
          <div class="flex-1 space-y-2"><div class="h-3 bg-slate-100 rounded w-3/4"/><div class="h-2.5 bg-slate-100 rounded w-1/2"/></div>
        </div>
      </div>

      <div v-else-if="!rows.length" class="text-center py-16 text-slate-400">
        <p class="font-bold">ไม่พบข้อมูลครู</p>
        <button v-if="isFiltered" @click="reset" class="mt-2 text-sm text-primary hover:underline">ล้างตัวกรอง</button>
      </div>

      <template v-else>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
          <div v-for="t in rows" :key="t.id" class="glass-tile p-3 flex gap-3 items-start">
            <div class="w-14 h-14 rounded-full overflow-hidden bg-slate-100 flex items-center justify-center shrink-0 shadow-sm">
              <img v-if="t.photo_url" :src="t.photo_url" :alt="fullName(t)" loading="lazy" class="w-full h-full object-cover"/>
              <span v-else class="text-sm font-bold text-primary">{{ initialsOf(t) }}</span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="font-bold text-slate-800 text-sm leading-snug">{{ fullName(t) }}</p>
              <p class="text-[11px] text-slate-500 truncate">{{ t.school?.name }}</p>
              <p class="text-[10px] text-slate-400 truncate">อ.{{ t.school?.district }} · {{ t.school?.school_group }}</p>
              <div class="flex flex-wrap gap-1 mt-1">
                <span v-for="n in t.networks" :key="n"
                  class="text-[10px] bg-indigo-50 text-indigo-700 font-bold px-2 py-0.5 rounded-full">
                  {{ labelOf(cfg, 'networks', n).replace('เครือข่ายครู', '') }}
                </span>
              </div>
              <p v-if="t.grades?.length" class="text-[10px] text-slate-400 mt-1">สอน {{ gradeText(t.grades) }}</p>
            </div>
          </div>
        </div>

        <div v-if="rows.length < total" class="text-center">
          <button @click="load(true)" :disabled="more"
            class="px-6 py-2.5 rounded-xl bg-white/70 border border-slate-200 text-sm font-bold text-primary hover:bg-white disabled:opacity-50">
            {{ more ? 'กำลังโหลด...' : `แสดงเพิ่ม (${rows.length} / ${total})` }}
          </button>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
