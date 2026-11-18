<script setup>
/**
 * SchoolPicker — เลือกโรงเรียนแบบกรอง อำเภอ → ศูนย์เครือข่าย → ค้นชื่อ → โรงเรียน
 * ใช้ในหน้ากรอกแบบนิเทศ (ลิงก์สาธารณะ + โรงเรียนล็อกอิน) แทน dropdown ยาว 173 โรง
 *
 * v-model = school id (ค่าที่ส่งเข้าฐานข้อมูลเหมือน dropdown เดิมทุกอย่าง)
 * ตัวกรองไม่บังคับ — ว่าง = ทุกโรง · โรงเรียนที่เลือกไว้แล้วยังอยู่ในรายการแม้ไม่ผ่านตัวกรอง (ไม่ล้างค่าให้เอง)
 * โรงเรียนน้อย (แบบเป้าหมายเฉพาะโรง) ≤ 15 โรง ไม่ต้องแสดงตัวกรอง
 */
import { ref, computed, watch } from 'vue'

const props = defineProps({
  modelValue: { type: [String, null], default: null },
  schools:    { type: Array,   default: () => [] },   // [{ id, name, district, school_group }]
  allowNone:  { type: Boolean, default: false },      // มีตัวเลือก "— ไม่ระบุ —" (ช่องโรงเรียนของโหมดบุคคล)
  compact:    { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue'])

const district = ref('')
const group    = ref('')
const search   = ref('')

const showFilters = computed(() => props.schools.length > 15)
const districts = computed(() => [...new Set(props.schools.map(s => s.district).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))
const groups = computed(() => [...new Set(props.schools
  .filter(s => !district.value || s.district === district.value)
  .map(s => s.school_group).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'th')))
watch(district, () => { if (group.value && !groups.value.includes(group.value)) group.value = '' })

const filtered = computed(() => {
  const q = search.value.trim()
  return props.schools.filter(s =>
    (!district.value || s.district === district.value) &&
    (!group.value || s.school_group === group.value) &&
    (!q || s.name.includes(q)) ||
    s.id === props.modelValue)
})
const filteredDistricts = computed(() => [...new Set(filtered.value.map(s => s.district))].sort((a, b) => (a || '').localeCompare(b || '', 'th')))
const isFiltered = computed(() => !!(district.value || group.value || search.value.trim()))

const selected = computed({
  get: () => props.modelValue ?? (props.allowNone ? null : ''),
  set: v => emit('update:modelValue', v === '' ? null : v),
})

const inputCls = computed(() => props.compact
  ? 'px-3 py-2.5 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary'
  : 'px-4 py-3 border border-white/80 bg-white/70 backdrop-blur rounded-xl text-sm focus:outline-none focus:border-primary')
</script>

<template>
  <div class="space-y-2">
    <div v-if="showFilters" class="grid grid-cols-1 sm:grid-cols-3 gap-2">
      <select v-model="district" :class="[inputCls, 'w-full']" aria-label="กรองอำเภอ">
        <option value="">ทุกอำเภอ</option>
        <option v-for="d in districts" :key="d" :value="d">อ.{{ d }}</option>
      </select>
      <select v-model="group" :class="[inputCls, 'w-full']" aria-label="กรองศูนย์เครือข่าย">
        <option value="">ทุกศูนย์เครือข่าย</option>
        <option v-for="g in groups" :key="g" :value="g">{{ g }}</option>
      </select>
      <input v-model="search" type="text" placeholder="พิมพ์ค้นชื่อโรงเรียน..." :class="[inputCls, 'w-full']"/>
    </div>

    <select v-model="selected" :class="[inputCls, 'w-full']">
      <option v-if="allowNone" :value="null">— ไม่ระบุ —</option>
      <option v-else value="" disabled>-- เลือกโรงเรียน{{ isFiltered ? ` (${filtered.length} โรง)` : '' }} --</option>
      <optgroup v-for="dist in filteredDistricts" :key="dist" :label="`อ.${dist}`">
        <option v-for="s in filtered.filter(x => x.district === dist)" :key="s.id" :value="s.id">
          {{ s.name }}{{ s.school_group && !group ? ` (${s.school_group})` : '' }}
        </option>
      </optgroup>
    </select>
    <p v-if="isFiltered && !filtered.length" class="text-xs text-amber-600">ไม่พบโรงเรียนตามตัวกรอง</p>
  </div>
</template>
