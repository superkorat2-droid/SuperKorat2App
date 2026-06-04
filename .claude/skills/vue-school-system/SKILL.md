---
name: vue-school-system
description: >
  Patterns and architecture decisions for building Thai school management systems
  with Vue 3 + Supabase. Use this skill whenever working on this project or
  starting a similar school system — covers DMC import, two-system student data
  architecture, Supabase RLS, SECURITY DEFINER RPC for public pages, SVG bar charts
  with trend lines, public/private visibility toggles, API keys, admin sidebar
  grouping, personnel page patterns (responsive tabs, search, auto-detect small school),
  and large-dataset pagination. Trigger on any question about adding features,
  fixing bugs, or replicating patterns from this codebase.
---

# Vue School Management System — Patterns & Decisions

## Stack
- **Frontend**: Vue 3 (Composition API, `<script setup>`) + Vite + Tailwind CSS
- **Backend**: Supabase (PostgreSQL + RLS + RPC functions)
- **Auth**: Supabase Auth + `profiles` table (role: `admin` | `teacher`)
- **Layouts**: `AdminLayout.vue`, `PublicLayout.vue`

---

## 1. Database Key Tables

```
students            — นักเรียนปัจจุบัน (is_active, grade_level, room smallint)
student_snapshots   — snapshot per import (FK → import_sessions.id)
import_sessions     — รอบการนำเข้า (checkpoint smallint, checkpoint_label, total_rows)
teacher_profiles    — บุคลากร/ครู
school_config       — ค่าตั้งค่าโรงเรียน (id=1 เสมอ, JSONB fields)
api_keys            — API key สำหรับส่งออกข้อมูล
```

### Critical column names (เคยสับสน)
| ❌ ชื่อเก่า/ผิด | ✅ ชื่อจริงใน DB |
|---|---|
| `import_id` | `import_session_id` (FK ใน student_snapshots) |
| `dmc_imports` | `import_sessions` (ตารางจริงที่ FK ชี้ถึง) |
| `semester` | `checkpoint` (smallint, NOT NULL) |
| `label` | `checkpoint_label` |
| `total_count` | `total_rows` |
| `notes` (เดิม) | `notes` (ยังใช้ได้, optional) |

### students NOT NULL fields
```js
// ต้องใส่ fallback เสมอ — ห้าม null
first_name: r.first_name || ''
last_name:  r.last_name  || ''
room:       r.room ? (parseInt(r.room) || null) : null  // smallint
```

---

## 2. DMC Import Pattern

### ลำดับการ insert
```js
// 1. สร้าง import_session ก่อน
const { data: imp } = await supabase.from('import_sessions').insert({
  academic_year: year,
  checkpoint: semester,          // smallint
  checkpoint_label: label,
  total_rows: rows.length,
  imported_by: user.id,
}).select().single()

// 2. insert student_snapshots พร้อม FK
await supabase.from('student_snapshots').insert(
  rows.map(r => ({ ...r, import_session_id: imp.id }))
)

// 3. upsert students (current roster)
await supabase.from('students').upsert(rows, { onConflict: 'student_code' })
```

### Map import_sessions → legacy field names (ใน JS)
```js
const mapped = raw.map(imp => ({
  ...imp,
  label:       imp.checkpoint_label || `ภาคเรียนที่ ${imp.checkpoint}/${imp.academic_year}`,
  semester:    imp.checkpoint,
  total_count: imp.total_rows || 0,
  note:        imp.notes,
}))
```

### Duplicate Excel column headers
DMC files มีคอลัมน์ชื่อซ้ำ — แก้ด้วย Excel letter suffix:
```js
function colLetter(idx) {
  let s = '', n = idx
  do { s = String.fromCharCode(65 + (n % 26)) + s; n = Math.floor(n / 26) - 1 } while (n >= 0)
  return s
}

const nameCount = {}
rawHeaderRow.forEach(h => { const n = String(h).trim(); if (n) nameCount[n] = (nameCount[n]||0)+1 })
const allH = rawHeaderRow.map((h, i) => {
  const n = String(h).trim()
  if (!n) return ''
  return nameCount[n] > 1 ? `${n} [${colLetter(i)}]` : n
})
// auto-detect ตัด suffix ออก: h.replace(/\s*\[.*?\]$/, '').trim()
```

---

## 3. Supabase RLS & Public Page Pattern

### ปัญหา: anon ไม่มีสิทธิ์อ่าน table โดยตรง
หน้าสาธารณะ (`PublicLayout`) ใช้ anon key → RLS บล็อก `import_sessions`, `student_snapshots`

### แก้ด้วย SECURITY DEFINER RPC
```sql
CREATE OR REPLACE FUNCTION public.get_public_bmi_stats()
RETURNS TABLE (grade_level text, weight text, height text)
LANGUAGE sql
SECURITY DEFINER   -- รัน as owner ข้าม RLS ได้
STABLE
AS $$
  SELECT COALESCE(s.grade_level, ss.grade_level)::text, ss.weight::text, ss.height::text
  FROM student_snapshots ss
  INNER JOIN (SELECT id FROM import_sessions ORDER BY imported_at DESC LIMIT 1) latest
    ON ss.import_session_id = latest.id
  INNER JOIN students s ON s.student_code = ss.student_code
  WHERE s.is_active = true AND ss.weight IS NOT NULL AND ss.height IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_bmi_stats() TO anon, authenticated;
```

### หลักการ: Public pages ใช้ RPC เสมอ
- ❌ ไม่ query table โดยตรงจาก public page
- ✅ สร้าง RPC ที่ SECURITY DEFINER และ GRANT TO anon

---

## 4. Pagination Pattern (Large Datasets)

PostgREST default limit = **1000 rows** — โรงเรียนใหญ่มีนักเรียน 3000-5000 คน

```js
// Pattern มาตรฐาน: ใช้กับทุก query ที่อาจมีข้อมูลมาก
const all = []
let from = 0
while (true) {
  const { data, error } = await supabase
    .from('student_snapshots')
    .select('...')
    .eq('import_session_id', id)
    .range(from, from + 999)
  if (error || !data?.length) break
  all.push(...data)
  if (data.length < 1000) break
  from += 1000
}

// RPC ก็ paginate ได้เหมือนกัน
const { data } = await supabase.rpc('get_public_bmi_stats').range(from, from + 999)
```

### Progressive loading (ไม่บล็อก UI)
```js
// Phase 1: โหลด sessions ก่อน ปล่อย spinner
imports.value = sessions; loading.value = false

// Phase 2: โหลด gender counts background (ไม่ await)
for (const imp of imports.value) {
  let from = 0
  while (true) {
    const { data } = await supabase.from('student_snapshots')
      .select('gender, prefix').eq('import_session_id', imp.id).range(from, from + 999)
    // update ref ทีละ batch
    if (data.length < 1000) break; from += 1000
  }
}
```

---

## 5. school_config Pattern

ตาราง `school_config` มี **1 row** (id=1) เก็บค่า config ทั้งหมด

```js
// Composable: src/composables/useSchoolConfig.js
const { config, fetchConfig, updateConfig } = useSchoolConfig()

// อ่านค่า
await fetchConfig()
const showBMI = config.value?.show_public_bmi ?? false

// บันทึกค่า (ใช้ fetch โดยตรงเพราะ supabase client มีปัญหา lock)
await updateConfig({ show_public_bmi: true })
```

### เพิ่ม column ใหม่ใน school_config
```sql
ALTER TABLE public.school_config
  ADD COLUMN IF NOT EXISTS show_public_bmi BOOLEAN DEFAULT false;
```

### Toggle pattern (admin → public visibility)
```vue
<!-- Admin: toggle card -->
<button @click="showPublicBMI = !showPublicBMI" ...>
<button @click="savePublicBMIToggle">บันทึก</button>

<!-- Public: conditional render -->
<div v-if="showPublicBMI" class="mt-8">
  <!-- BMI section -->
</div>
```

```js
// Public page: check config ก่อน render
onMounted(async () => {
  await fetchConfig()
  showPublicBMI.value = config.value?.show_public_bmi ?? false
  if (showPublicBMI.value) loadPublicBMI()  // โหลดเฉพาะเมื่อเปิด
})
```

---

## 6. Admin Sidebar Grouped Navigation

```js
// AdminLayout.vue — แก้ที่ array เดียว
const adminNavGroups = [
  { label: '',              items: [{ to: '/admin', icon: '📊', label: 'แดชบอร์ด' }] },
  { label: 'บุคลากร',      items: [{ to: '/admin/users', icon: '👥', label: 'จัดการผู้ใช้' }, ...] },
  { label: 'นักเรียน',     items: [{ to: '/admin/students', icon: '🎓', label: 'จัดการนักเรียน' }, ...] },
  { label: 'เนื้อหาสาธารณะ', items: [...] },
  { label: 'ระบบ',         items: [...] },
]
```

```vue
<!-- Template: group label + divider เมื่อ sidebar ย่อ -->
<template v-for="group in navGroups" :key="group.label">
  <div v-if="sidebarOpen && group.label" class="px-4 pt-4 pb-1 text-[10px] ... uppercase">
    {{ group.label }}
  </div>
  <div v-else-if="!sidebarOpen && group.label" class="my-2 mx-3 border-t border-blue-700/60"></div>
  <router-link v-for="item in group.items" .../>
</template>
```

**เพิ่มระบบใหม่**: แค่ push item เข้า group ที่ต้องการ + เพิ่ม route ใน `router/index.js`

---

## 7. API Keys (On-demand Export)

### Pattern การใช้งาน
```
Admin สร้าง key → copy URL → เปิดใน Sheets/script → ได้ JSON → ปิด
```
- key เก็บแบบ **plain text** ใน `api_keys.api_key` (ควบคุมด้วย RLS admin-only)
- URL จริงแสดง **ครั้งเดียวตอนสร้าง** เท่านั้น
- ไม่มีจำกัดจำนวนการสร้าง/ลบ

### RPC get_api_data
```sql
-- เรียกผ่าน GET /rest/v1/rpc/get_api_data?p_api_key=sk_xxx&apikey=<anon_key>
-- ตรวจ key ใน api_keys table แล้ว dynamic query ตาม resource + fields
GRANT EXECUTE ON FUNCTION public.get_api_data(text) TO anon;
```

### URL format
```
{SUPABASE_URL}/rest/v1/rpc/get_api_data?p_api_key={KEY}&apikey={ANON_KEY}
```

---

## 8. Thai Date Parsing (DMC Files)

```js
function parseDateThai(v) {
  if (!v) return null
  // Excel serial number
  if (typeof v === 'number') {
    const d = new Date((v - 25569) * 86400000)
    return d.toISOString().split('T')[0]
  }
  const s = String(v).trim()
  // พ.ศ. format: d/m/yyyy หรือ dd/mm/yyyy
  const m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/)
  if (m) {
    let y = parseInt(m[3])
    if (y > 2400) y -= 543  // แปลง พ.ศ. → ค.ศ.
    return `${y}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`
  }
  return s
}
```

---

## 9. Gender Classification

```js
function classifyGender(gender, prefix) {
  if (gender === 'ชาย' || gender === 'male') return 'ชาย'
  if (gender === 'หญิง' || gender === 'female') return 'หญิง'
  if (['เด็กชาย','นาย'].includes(prefix)) return 'ชาย'
  if (['เด็กหญิง','นางสาว','นาง'].includes(prefix)) return 'หญิง'
  return 'อื่น'
}
```

---

## 10. Two-System Student Data Architecture

### หลักการ (สำคัญมาก — ห้ามสับสน)

```
System 1: ทะเบียนนักเรียน (students table)
  → ข้อมูล "ปัจจุบัน" ของนักเรียนที่กำลังศึกษา
  → upsert ทุก import (onConflict: student_code)
  → เก็บ weight, height, nationality, religion ฯลฯ

System 2: สถิติ DMC (import_sessions.stats_json)
  → เก็บแค่ aggregate stats เป็น JSONB
  → ไม่เขียนลง student_snapshots อีกต่อไป
  → ใช้สำหรับกราฟประวัติย้อนหลัง
```

### stats_json JSONB format
```js
// เก็บใน import_sessions.stats_json
const stats = {
  total: rows.length,
  male:  rows.filter(r => classifyGender(r.gender, r.prefix) === 'ชาย').length,
  female: rows.filter(r => classifyGender(r.gender, r.prefix) === 'หญิง').length,
  byLevel: {
    'ม.1': { total: N, male: N, female: N },
    'ม.2': { ... },
    // ...
  }
}

// บันทึกพร้อม import_session
await supabase.from('import_sessions')
  .update({ stats_json: stats })
  .eq('id', imp.id)
```

### BMI Data Source
```
❌ อย่าอ่าน weight/height จาก student_snapshots (ไม่มีข้อมูลแล้ว)
✅ อ่านจาก students table โดยตรง
```

```js
// loadBMIData — อ่านจาก students
const all = []
let from = 0
while (true) {
  const { data } = await supabase.from('students')
    .select('student_code, weight, height, grade_level, room, gender, prefix')
    .eq('is_active', true).range(from, from + 999)
  if (!data?.length) break
  all.push(...data)
  if (data.length < 1000) break
  from += 1000
}
bmiData.value = all.filter(s => parseFloat(s.weight) > 0 && parseFloat(s.height) > 50)
```

### get_current_student_stats() RPC
```sql
-- ใช้ในหน้า public แทนการ query students โดยตรง
CREATE OR REPLACE FUNCTION public.get_current_student_stats()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT jsonb_build_object(
    'total',  COUNT(*),
    'male',   COUNT(*) FILTER (WHERE gender='ชาย' OR prefix IN ('เด็กชาย','นาย')),
    'female', COUNT(*) FILTER (WHERE gender='หญิง' OR prefix IN ('เด็กหญิง','นางสาว','นาง')),
    'byLevel', jsonb_object_agg(grade_level, cnt) FILTER (WHERE grade_level IS NOT NULL)
  ) FROM students WHERE is_active = true ...
$$;
GRANT EXECUTE ON FUNCTION public.get_current_student_stats() TO anon, authenticated;
```

---

## 11. SVG Interactive Bar Chart + Trend Line

Pattern มาตรฐานสำหรับแสดงสถิติย้อนหลัง (SisPage, StudentsDashboardPage)

### Constants
```js
const C = { W:720, H:260, PL:52, PR:20, PT:20, PB:50 }
// PL=left padding (Y-axis), PB=bottom padding (X-axis labels)
```

### Computed
```js
// เรียงข้อมูลเก่า→ใหม่ (ซ้าย→ขวา)
const chartSessions = computed(() =>
  [...sessions.value].sort((a,b) => {
    if (a.academic_year !== b.academic_year) return a.academic_year - b.academic_year
    return a.checkpoint - b.checkpoint
  })
)

const chartMax = computed(() => Math.max(...chartSessions.value.map(s => s.stats_json?.total || 0), 1))

// Y-axis ticks (4 เส้น)
const chartYTicks = computed(() => {
  const max = chartMax.value
  const step = Math.ceil(max / 4 / 100) * 100 || 100
  return Array.from({ length: 5 }, (_, i) => i * step)
})

function tyAt(v) {
  // แปลง value → Y pixel (กลับด้าน: ค่าสูง = Y น้อย)
  const chartH = C.H - C.PT - C.PB
  return C.PT + chartH - (v / chartMax.value) * chartH
}

// bars
const chartBars = computed(() => {
  const n = chartSessions.value.length
  const chartW = C.W - C.PL - C.PR
  const bw = Math.min(60, chartW / (n || 1) * 0.6)
  const gap = chartW / (n || 1)
  return chartSessions.value.map((s, i) => {
    const total = s.stats_json?.total || 0
    const x = C.PL + gap * i + gap / 2
    const y = tyAt(total)
    const h = C.H - C.PB - y
    return { s, x, y, h: Math.max(h, 0), bw, total }
  })
})

// trend line (เส้นสีส้ม)
const trendPath = computed(() => {
  if (chartBars.value.length < 2) return ''
  return chartBars.value.map((b, i) =>
    `${i === 0 ? 'M' : 'L'}${b.x},${tyAt(b.total)}`
  ).join(' ')
})
```

### Template SVG
```vue
<svg :viewBox="`0 0 ${C.W} ${C.H}`" class="w-full" style="max-height:260px">
  <!-- Y-axis grid lines -->
  <line v-for="t in chartYTicks" :key="t"
    :x1="C.PL" :y1="tyAt(t)" :x2="C.W - C.PR" :y2="tyAt(t)"
    stroke="#e5e7eb" stroke-width="1" />
  <!-- Y-axis labels -->
  <text v-for="t in chartYTicks" :key="'y'+t"
    :x="C.PL - 6" :y="tyAt(t) + 4"
    text-anchor="end" font-size="11" fill="#9ca3af">{{ t.toLocaleString() }}</text>

  <!-- Bars -->
  <g v-for="bar in chartBars" :key="bar.s.id"
    @mouseenter="hoveredBar = bar" @mouseleave="hoveredBar = null"
    class="cursor-pointer">
    <rect :x="bar.x - bar.bw/2" :y="bar.y" :width="bar.bw" :height="bar.h"
      rx="4" fill="#6366f1" :opacity="hoveredBar?.s.id === bar.s.id ? 1 : 0.75" />
    <!-- Value text — ซ่อนเมื่อ hover (tooltip แสดงแทน) -->
    <text v-if="bar.h > 20 && hoveredBar?.s.id !== bar.s.id"
      :x="bar.x" :y="bar.y - 5"
      text-anchor="middle" font-size="12" fill="#4f46e5" font-weight="600">
      {{ bar.total.toLocaleString() }}
    </text>
    <!-- X-axis label -->
    <text :x="bar.x" :y="C.H - C.PB + 16"
      text-anchor="middle" font-size="11" fill="#6b7280">
      {{ bar.s.checkpoint_label.length > 14
        ? bar.s.checkpoint_label.slice(0,13) + '…'
        : bar.s.checkpoint_label }}
    </text>
  </g>

  <!-- Trend line (สีส้ม) -->
  <path v-if="trendPath" :d="trendPath"
    fill="none" stroke="#f97316" stroke-width="2.5"
    stroke-linejoin="round" stroke-linecap="round" />
  <!-- Trend dots -->
  <circle v-for="bar in chartBars" :key="'d'+bar.s.id"
    :cx="bar.x" :cy="tyAt(bar.total)" r="4"
    fill="#f97316" stroke="white" stroke-width="2" />

  <!-- Tooltip -->
  <g v-if="hoveredBar">
    <rect :x="hoveredBar.x - 60" :y="hoveredBar.y - 44"
      width="120" height="38" rx="6" fill="#1e1b4b" opacity="0.92" />
    <text :x="hoveredBar.x" :y="hoveredBar.y - 28"
      text-anchor="middle" font-size="11" fill="white">
      {{ hoveredBar.s.checkpoint_label }}
    </text>
    <text :x="hoveredBar.x" :y="hoveredBar.y - 13"
      text-anchor="middle" font-size="14" fill="#a5b4fc" font-weight="700">
      {{ hoveredBar.total.toLocaleString() }} คน
    </text>
  </g>
</svg>
```

### ตาราง (newest-on-top)
```js
// chart เรียงเก่า→ใหม่, ตารางเรียงใหม่→เก่า
const tableSessions = computed(() => [...chartSessions.value].reverse())

// คอลัมน์ "เปลี่ยน" — ต้องใช้ chartSessions (ไม่ใช่ tableSessions) เพื่อหา prev
function getDelta(session) {
  const idx = chartSessions.value.findIndex(s => s.id === session.id)
  if (idx <= 0) return null
  const prev = chartSessions.value[idx - 1]
  return (session.stats_json?.total || 0) - (prev.stats_json?.total || 0)
}
```

---

## 12. Public Visibility Toggle Pattern

### school_config columns
```sql
-- เพิ่มทีละ feature
ALTER TABLE public.school_config
  ADD COLUMN IF NOT EXISTS show_public_bmi             BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS show_public_sis_comparison  BOOLEAN DEFAULT false;
```

### Admin page — toggle + save
```js
// refs
const showPublicSIS  = ref(false)
const savingSIS      = ref(false)
const sisSaved       = ref(false)

// load
onMounted(async () => {
  await fetchConfig()
  showPublicSIS.value = config.value?.show_public_sis_comparison ?? false
})

// save
async function saveToggle() {
  savingSIS.value = true
  await updateConfig({ show_public_sis_comparison: showPublicSIS.value })
  savingSIS.value = false
  sisSaved.value = true
  setTimeout(() => sisSaved.value = false, 2000)
}
```

### Public page — conditional load
```js
onMounted(async () => {
  await fetchConfig()
  showPublicSIS.value  = config.value?.show_public_sis_comparison ?? false
  showPublicBMI.value  = config.value?.show_public_bmi ?? false
  // โหลดข้อมูลเฉพาะ feature ที่เปิดใช้
  if (showPublicBMI.value)  loadPublicBMI()
  if (showPublicSIS.value)  loadSisSessions()
})
```

### get_public_sis_sessions() RPC
```sql
-- anon ไม่สามารถอ่าน import_sessions ตรง ๆ → ใช้ RPC
CREATE OR REPLACE FUNCTION public.get_public_sis_sessions()
RETURNS TABLE (
  id uuid, academic_year int, checkpoint smallint,
  checkpoint_label text, total_rows int, stats_json jsonb, imported_at timestamptz
)
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT id, academic_year, checkpoint, checkpoint_label,
         total_rows, stats_json, imported_at
  FROM import_sessions
  WHERE stats_json IS NOT NULL
  ORDER BY academic_year, checkpoint;
$$;
GRANT EXECUTE ON FUNCTION public.get_public_sis_sessions() TO anon, authenticated;
```

---

## 13. Personnel Page Patterns

### Responsive Level-1 Tabs (Mobile)
```vue
<!-- ❌ ไม่ดี: inline-flex ไม่ตัดบรรทัดบนมือถือ -->
<div class="inline-flex gap-1 p-1 bg-gray-100 rounded-2xl">

<!-- ✅ ดี: flex-wrap ตัดบรรทัดได้ -->
<div class="flex flex-wrap justify-center gap-1 p-1 bg-gray-100 rounded-2xl">
```

### "ทั้งหมด" Tab + Auto-detect Small School
```js
const AUTO_ALL_THRESHOLD = 20  // โรงเรียนเล็ก ≤ 20 คน → default "ทั้งหมด"

// groupTabs: เพิ่ม 'all' เป็น tab แรกเสมอ
const groupTabs = computed(() => [
  { key: 'all',         icon: '👥', label: 'ทั้งหมด',       count: allTeachers.value.length },
  { key: 'executives',  icon: '🏫', label: 'ผู้บริหาร',     count: ... },
  { key: 'departments', icon: '🏢', label: 'กลุ่มบริหารงาน', count: ... },
  { key: 'subjects',    icon: '📚', label: 'กลุ่มสาระฯ',    count: ... },
].filter(t => t.count > 0))

// หลังโหลดข้อมูล: auto-select 'all' ถ้าโรงเรียนเล็ก
allTeachers.value = teachers
if (allTeachers.value.length <= AUTO_ALL_THRESHOLD) {
  activeGroup.value = 'all'
}

// nonExecTeachers สำหรับแสดงใน 'all' section
const nonExecTeachers = computed(() =>
  sortTeachers(allTeachers.value.filter(t => !EXEC_POSITIONS.includes(t.position)))
)

// extraLabel ใน 'all' — แสดงกลุ่มสาระโดยไม่ซ้ำกับ position
function allTabLabel(t) {
  if (t.group_role === 'หัวหน้ากลุ่มสาระ')    return `⭐ หัวหน้า ${t.subject_group}`
  if (t.group_role === 'รองหัวหน้ากลุ่มสาระ') return `★ รองหัวหน้า ${t.subject_group}`
  if (t.subject_group) return `${groupIcon(t.subject_group)} ${t.subject_group}`
  return ''
}
```

### Search Filter ในกลุ่มสาระ
```js
const searchQuery = ref('')

// auto-clear เมื่อเปลี่ยน tab
watch(activeSubject, () => { searchQuery.value = '' })
watch(activeGroup,   () => { searchQuery.value = '' })

// filter computed
const filteredSubjectGroup = computed(() => {
  const g = currentSubjectGroup.value
  if (!g) return null
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return g
  const match = t =>
    (t.first_name || '').toLowerCase().includes(q) ||
    (t.last_name  || '').toLowerCase().includes(q) ||
    (t.prefix     || '').toLowerCase().includes(q)
  return { ...g, head: g.head && match(g.head) ? g.head : null, members: g.members.filter(match) }
})
```

---

## 14. Custom Emoji Input (Unicode-safe)

```vue
<!-- ช่องพิมพ์ emoji เองนอกจาก grid -->
<input v-model="form.icon" type="text" maxlength="8"
  placeholder="วาง emoji ที่นี่ 🏅"
  @input="e => { form.icon = [...(e.target.value||'')].slice(0,2).join('') }" />
```

```js
// ✅ [...str].slice(0,2) — ปลอดภัยกับ emoji ที่ใช้ surrogate pairs
// ❌ str.slice(0,2)     — ตัด code unit อาจพังกับ emoji บางตัว (🏅 = 2 code units)
```

---

## 15. Migration Files Convention

```
database/
├── setup.sql                    — ตารางหลัก
├── patch_existing_install.sql   — patch รวมทุกอย่างสำหรับ install เก่า
├── migration_config.sql         — เพิ่ม column ใน school_config
├── migration_api_keys.sql       — api_keys table + RLS
├── migration_api_rpc.sql        — get_api_data RPC
├── migration_bmi_toggle.sql     — show_public_bmi column
├── migration_bmi_rpc.sql        — get_public_bmi_stats RPC (อ่านจาก students)
└── migration_sis_stats.sql      — stats_json + show_public_sis_comparison + RPCs
```

รันใน **Supabase SQL Editor** ทุกครั้งที่มี migration ใหม่
