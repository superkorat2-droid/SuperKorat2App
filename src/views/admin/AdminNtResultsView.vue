<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../../supabase'
import Swal from 'sweetalert2'
import { parseNtLocal03File, QUALITY_LEVELS, QUALITY_COLOR } from '../../composables/useNtParser'

const route  = useRoute()
const router = useRouter()

const period  = ref(null)
const schools = ref([])          // { id, school_code, name, district, school_group, is_active }
const scores  = ref([])          // nt_school_scores rows joined with school info
const loading = ref(true)
const importing = ref(false)

const schoolByCode = computed(() => {
  const m = new Map()
  schools.value.forEach(s => m.set(s.school_code, s))
  return m
})

async function load() {
  loading.value = true
  const [{ data: p }, { data: sc }] = await Promise.all([
    supabase.from('nt_periods').select('*').eq('id', route.params.id).single(),
    supabase.from('schools').select('id, school_code, name, district, school_group, is_active'),
  ])
  period.value  = p
  schools.value = sc || []
  await loadScores()
  loading.value = false
}
onMounted(load)

async function loadScores() {
  const all = []
  let from = 0
  while (true) {
    const { data, error } = await supabase
      .from('nt_school_scores')
      .select('id, school_id, scores, raw')
      .eq('period_id', route.params.id)
      .range(from, from + 999)
    if (error || !data?.length) break
    all.push(...data)
    if (data.length < 1000) break
    from += 1000
  }
  const schoolById = new Map(schools.value.map(s => [s.id, s]))
  scores.value = all.map(r => ({ ...r, school: schoolById.get(r.school_id) }))
}

// ── Upload & preview ─────────────────────────────────────────────────────────
const fileInput  = ref(null)
const preview    = ref(null)     // { meta, subjects, matched:[], unmatched:[] }
const showPreview = ref(false)

function triggerUpload() { fileInput.value?.click() }

async function handleFile(e) {
  const file = e.target.files?.[0]
  e.target.value = ''
  if (!file) return
  try {
    const result = await parseNtLocal03File(file)
    const matched = []
    const unmatched = []
    result.rows.forEach(r => {
      const school = schoolByCode.value.get(r.school_code)
      if (school) matched.push({ ...r, school })
      else unmatched.push(r)
    })
    preview.value = { ...result, matched, unmatched }
    showPreview.value = true
  } catch (err) {
    Swal.fire({ icon: 'error', title: 'อ่านไฟล์ไม่สำเร็จ', text: err.message })
  }
}

async function confirmImport() {
  if (!preview.value?.matched?.length) return
  importing.value = true
  const { data: { user } } = await supabase.auth.getUser()
  const payload = preview.value.matched.map(r => ({
    period_id: route.params.id,
    school_id: r.school.id,
    scores: r.scores,
    raw: { school_name: r.school_name, district: r.district, school_size: r.school_size },
    uploaded_by: user?.id || null,
    uploaded_at: new Date().toISOString(),
  }))
  const { error } = await supabase.from('nt_school_scores').upsert(payload, { onConflict: 'period_id,school_id' })
  importing.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'นำเข้าไม่สำเร็จ', text: error.message }); return }
  showPreview.value = false
  preview.value = null
  await loadScores()
  Swal.fire({ icon: 'success', title: 'นำเข้าสำเร็จ', text: `บันทึกคะแนน ${payload.length} โรงเรียน`, showConfirmButton: false, timer: 1800 })
}

// ── Filters + table ───────────────────────────────────────────────────────────
const filterDistrict = ref('')
const filterGroup     = ref('')
const sortKey  = ref('name')
const sortDesc = ref(false)

const districtOptions = computed(() => [...new Set(scores.value.map(r => r.school?.district).filter(Boolean))].sort())
const groupOptions = computed(() => {
  const list = scores.value.filter(r => !filterDistrict.value || r.school?.district === filterDistrict.value)
  return [...new Set(list.map(r => r.school?.school_group).filter(Boolean))].sort()
})

const filteredScores = computed(() => {
  let list = scores.value.filter(r => r.school)
  if (filterDistrict.value) list = list.filter(r => r.school.district === filterDistrict.value)
  if (filterGroup.value)    list = list.filter(r => r.school.school_group === filterGroup.value)
  const dir = sortDesc.value ? -1 : 1
  return [...list].sort((a, b) => {
    const av = sortKey.value === 'name' ? a.school.name : (a.scores?.[sortKey.value]?.pct ?? -1)
    const bv = sortKey.value === 'name' ? b.school.name : (b.scores?.[sortKey.value]?.pct ?? -1)
    if (av < bv) return -1 * dir
    if (av > bv) return 1 * dir
    return 0
  })
})

function toggleSort(key) {
  if (sortKey.value === key) sortDesc.value = !sortDesc.value
  else { sortKey.value = key; sortDesc.value = key !== 'name' }
}

// ── Summary stats ─────────────────────────────────────────────────────────────
const subjectKeys = computed(() => [...(period.value?.subjects || []).map(s => s.key), 'overall'])
const subjectLabels = computed(() => {
  const m = {}
  ;(period.value?.subjects || []).forEach(s => { m[s.key] = s.label })
  m.overall = 'รวม 2 ด้าน'
  return m
})

function avgOf(key) {
  const vals = filteredScores.value.map(r => r.scores?.[key]?.pct).filter(v => typeof v === 'number')
  if (!vals.length) return null
  return vals.reduce((a, b) => a + b, 0) / vals.length
}

function levelDistribution(key) {
  const counts = Object.fromEntries(QUALITY_LEVELS.map(l => [l, 0]))
  filteredScores.value.forEach(r => {
    const lvl = r.scores?.[key]?.level
    if (lvl && counts[lvl] !== undefined) counts[lvl]++
  })
  const total = filteredScores.value.length || 1
  return QUALITY_LEVELS.map(l => ({ level: l, count: counts[l], pct: Math.round((counts[l] / total) * 100) }))
}

// ── Benchmarks (จังหวัด/ประเทศ) ────────────────────────────────────────────────
const benchmarks = ref({ province: {}, national: {} })
const savingBenchmark = ref(false)

async function loadBenchmarks() {
  const { data } = await supabase.from('nt_benchmarks').select('scope, scores').eq('period_id', route.params.id)
  const map = { province: {}, national: {} }
  ;(data || []).forEach(b => { map[b.scope] = b.scores || {} })
  benchmarks.value = map
}

async function saveBenchmark(scope) {
  savingBenchmark.value = true
  const scoresPayload = {}
  subjectKeys.value.forEach(k => {
    const pct = benchmarks.value[scope]?.[k]?.pct
    if (pct !== '' && pct !== undefined && pct !== null) scoresPayload[k] = { pct: parseFloat(pct) }
  })
  const { error } = await supabase.from('nt_benchmarks')
    .upsert({ period_id: route.params.id, scope, scores: scoresPayload }, { onConflict: 'period_id,scope' })
  savingBenchmark.value = false
  if (error) { Swal.fire({ icon: 'error', title: 'บันทึกไม่สำเร็จ', text: error.message }); return }
  Swal.fire({ icon: 'success', title: 'บันทึกแล้ว', showConfirmButton: false, timer: 1000 })
}

onMounted(loadBenchmarks)
</script>

<template>
  <div class="font-sarabun space-y-6">
    <button @click="router.push('/dashboard/nt-scores')" class="text-sm text-slate-500 hover:text-primary">← กลับไปรายการรอบ</button>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
    </div>

    <template v-else-if="period">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 class="text-2xl font-extrabold text-slate-800">{{ period.title }}</h1>
          <p class="text-sm text-slate-500 mt-0.5">{{ period.exam_type }} · {{ period.grade_level }} · ปีการศึกษา {{ period.academic_year }} · นำเข้าแล้ว {{ scores.length }} โรงเรียน</p>
        </div>
        <div>
          <input ref="fileInput" type="file" accept=".xlsx,.xls" class="hidden" @change="handleFile"/>
          <button @click="triggerUpload"
            class="px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
            อัปโหลดไฟล์ Local03
          </button>
        </div>
      </div>

      <!-- Summary cards -->
      <div v-if="scores.length" class="grid gap-4" :class="subjectKeys.length === 3 ? 'md:grid-cols-3' : 'md:grid-cols-2'">
        <div v-for="key in subjectKeys" :key="key" class="glass-card p-5">
          <p class="text-xs font-bold text-slate-500 uppercase tracking-wider">{{ subjectLabels[key] }}</p>
          <p class="text-3xl font-extrabold text-slate-800 mt-1">{{ avgOf(key) !== null ? avgOf(key).toFixed(2) : '—' }}<span class="text-sm text-slate-400 font-medium"> %</span></p>
          <p class="text-xs text-slate-400">ค่าเฉลี่ยร้อยละของโรงเรียน (ที่แสดงตามตัวกรอง)</p>
          <div class="mt-3 space-y-1.5">
            <div v-for="d in levelDistribution(key)" :key="d.level" class="flex items-center gap-2 text-xs">
              <span class="w-16 flex-shrink-0 text-slate-500">{{ d.level }}</span>
              <div class="flex-1 h-2.5 bg-slate-100 rounded-full overflow-hidden">
                <div class="h-full rounded-full" :style="`width:${d.pct}%; background:${QUALITY_COLOR[d.level]}`"/>
              </div>
              <span class="w-14 flex-shrink-0 text-right font-bold text-slate-600">{{ d.count }} ({{ d.pct }}%)</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Filters -->
      <div v-if="scores.length" class="flex flex-wrap gap-3 items-center">
        <select v-model="filterDistrict" @change="filterGroup = ''" class="px-3 py-2 text-sm border border-slate-200 rounded-xl">
          <option value="">ทุกอำเภอ</option>
          <option v-for="d in districtOptions" :key="d" :value="d">{{ d }}</option>
        </select>
        <select v-model="filterGroup" class="px-3 py-2 text-sm border border-slate-200 rounded-xl">
          <option value="">ทุกศูนย์เครือข่าย</option>
          <option v-for="g in groupOptions" :key="g" :value="g">{{ g }}</option>
        </select>
        <button v-if="filterDistrict || filterGroup" @click="filterDistrict=''; filterGroup=''"
          class="text-xs font-bold text-slate-500 hover:text-red-500">ล้างตัวกรอง</button>
        <span class="text-xs text-slate-400 ml-auto">แสดง {{ filteredScores.length }} / {{ scores.length }} โรงเรียน</span>
      </div>

      <!-- Table -->
      <div v-if="scores.length" class="glass-card overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-xs text-slate-500 uppercase tracking-wider border-b border-slate-100">
              <th class="px-4 py-3 cursor-pointer" @click="toggleSort('name')">โรงเรียน</th>
              <th class="px-4 py-3">อำเภอ</th>
              <th class="px-4 py-3">ศูนย์เครือข่าย</th>
              <th v-for="key in subjectKeys" :key="key" class="px-4 py-3 text-right cursor-pointer" @click="toggleSort(key)">
                {{ subjectLabels[key] }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in filteredScores" :key="r.id" class="border-b border-slate-50 hover:bg-slate-50">
              <td class="px-4 py-2.5 font-medium text-slate-700">{{ r.school.name }}</td>
              <td class="px-4 py-2.5 text-slate-500">{{ r.school.district }}</td>
              <td class="px-4 py-2.5 text-slate-500">{{ r.school.school_group }}</td>
              <td v-for="key in subjectKeys" :key="key" class="px-4 py-2.5 text-right">
                <span class="font-bold text-slate-700">{{ r.scores?.[key]?.pct ?? '—' }}</span>
                <span v-if="r.scores?.[key]?.level" class="ml-1.5 text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                  :style="`background:${QUALITY_COLOR[r.scores[key].level]}22; color:${QUALITY_COLOR[r.scores[key].level]}`">
                  {{ r.scores[key].level }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-else class="text-center py-12 glass-card text-slate-400">
        <p class="font-medium">ยังไม่มีข้อมูลคะแนนในรอบนี้</p>
        <p class="text-sm mt-1">กด "อัปโหลดไฟล์ Local03" เพื่อนำเข้า</p>
      </div>

      <!-- Benchmarks -->
      <div class="glass-card p-5">
        <h3 class="font-bold text-slate-700 mb-1">ค่าเฉลี่ยอ้างอิง (ไม่บังคับ)</h3>
        <p class="text-xs text-slate-400 mb-4">กรอกเองสำหรับเทียบกับระดับจังหวัด/ประเทศในกราฟแนวโน้ม — รายงาน Local03 ไม่มีตัวเลขนี้ให้อัตโนมัติ</p>
        <div class="grid md:grid-cols-2 gap-4">
          <div v-for="scope in ['province','national']" :key="scope" class="p-4 bg-slate-50 rounded-2xl">
            <p class="text-sm font-bold text-slate-600 mb-2">{{ scope === 'province' ? 'ระดับจังหวัด' : 'ระดับประเทศ' }}</p>
            <div class="grid grid-cols-2 gap-2">
              <div v-for="key in subjectKeys" :key="key">
                <label class="block text-[11px] text-slate-400 mb-0.5">{{ subjectLabels[key] }} (ร้อยละ)</label>
                <input type="number" step="0.01"
                  :value="benchmarks[scope]?.[key]?.pct ?? ''"
                  @input="benchmarks[scope][key] = { pct: $event.target.value }"
                  class="w-full px-2.5 py-1.5 text-sm border border-slate-200 rounded-lg"/>
              </div>
            </div>
            <button @click="saveBenchmark(scope)" :disabled="savingBenchmark"
              class="mt-3 px-4 py-1.5 text-xs font-bold bg-primary text-white rounded-xl disabled:opacity-50">บันทึก</button>
          </div>
        </div>
      </div>
    </template>
  </div>

  <!-- Preview modal -->
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="showPreview && preview" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 font-sarabun">
        <div class="glass-panel rounded-[1.25rem] w-full max-w-2xl max-h-[85vh] flex flex-col overflow-hidden">
          <div class="px-6 py-4 border-b border-slate-100 flex items-center justify-between flex-shrink-0">
            <h2 class="font-extrabold text-slate-800">พรีวิวก่อนนำเข้า</h2>
            <button @click="showPreview=false" class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-slate-100 text-slate-400">✕</button>
          </div>
          <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">
            <div class="flex gap-3">
              <div class="flex-1 p-3 bg-emerald-50 rounded-xl text-center">
                <p class="text-2xl font-extrabold text-emerald-700">{{ preview.matched.length }}</p>
                <p class="text-xs text-emerald-600">จับคู่โรงเรียนสำเร็จ</p>
              </div>
              <div class="flex-1 p-3 bg-red-50 rounded-xl text-center">
                <p class="text-2xl font-extrabold text-red-600">{{ preview.unmatched.length }}</p>
                <p class="text-xs text-red-500">ไม่พบโรงเรียนในระบบ</p>
              </div>
            </div>
            <p v-if="preview.meta?.academicYear && period && preview.meta.academicYear !== period.academic_year"
              class="text-xs text-amber-600 bg-amber-50 rounded-xl px-3 py-2">
              ⚠️ ไฟล์นี้ระบุปีการศึกษา {{ preview.meta.academicYear }} แต่รอบปัจจุบันคือปี {{ period.academic_year }} — ตรวจสอบให้แน่ใจก่อนนำเข้า
            </p>
            <div v-if="preview.unmatched.length" class="text-xs text-slate-500 bg-slate-50 rounded-xl p-3 max-h-32 overflow-y-auto">
              <p class="font-bold mb-1">รหัสที่ไม่พบในทำเนียบโรงเรียน:</p>
              <p v-for="u in preview.unmatched" :key="u.school_code">{{ u.school_code }} — {{ u.school_name }}</p>
            </div>
          </div>
          <div class="px-6 py-4 border-t border-slate-100 flex gap-3 justify-end flex-shrink-0">
            <button @click="showPreview=false" class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 rounded-xl hover:bg-slate-200">ยกเลิก</button>
            <button @click="confirmImport" :disabled="importing || !preview.matched.length"
              class="px-6 py-2 text-sm font-bold bg-primary text-white rounded-xl hover:-translate-y-0.5 shadow-md transition-all disabled:opacity-50">
              {{ importing ? 'กำลังนำเข้า...' : `ยืนยันนำเข้า ${preview.matched.length} โรงเรียน` }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
