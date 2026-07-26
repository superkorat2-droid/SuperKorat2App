<script setup>
/**
 * BarChart — กราฟแท่งแนวนอน เขียนด้วย HTML/CSS ล้วน
 *
 * ตั้งใจไม่เพิ่ม dependency กราฟเข้าโปรเจค (ยังไม่มี component กราฟเลย)
 * แท่งแนวนอนอ่านง่ายกว่าแนวตั้งเมื่อป้ายกำกับเป็นภาษาไทยยาวๆ และไม่ต้องหมุนตัวอักษร
 *
 * items: [{ label, value, bar }] — bar = คลาสสี Tailwind แบบเต็ม (ห้ามประกอบจากตัวแปร)
 */
const props = defineProps({
  items:   { type: Array, default: () => [] },
  /** ขยายขนาดตัวอักษรสำหรับโหมดฉายขึ้นจอ */
  big:     { type: Boolean, default: false },
  emptyText: { type: String, default: 'ยังไม่มีข้อมูล' },
})

const max = () => Math.max(1, ...props.items.map(i => i.value || 0))
function pct(v) { return Math.round(((v || 0) / max()) * 100) }
</script>

<template>
  <div v-if="items.length" :class="big ? 'space-y-3' : 'space-y-2'">
    <div v-for="it in items" :key="it.label">
      <div class="flex items-baseline justify-between gap-2 mb-1">
        <span :class="['font-bold text-slate-600 truncate', big ? 'text-lg' : 'text-xs']">{{ it.label }}</span>
        <span :class="['font-extrabold text-slate-800 tabular-nums flex-shrink-0', big ? 'text-2xl' : 'text-sm']">
          {{ (it.value || 0).toLocaleString() }}
        </span>
      </div>
      <div :class="['w-full rounded-full bg-slate-900/[0.06] overflow-hidden', big ? 'h-4' : 'h-2.5']">
        <div :class="['h-full rounded-full transition-all duration-700', it.bar || 'bg-primary']"
          :style="{ width: pct(it.value) + '%' }"/>
      </div>
    </div>
  </div>
  <p v-else :class="['text-center text-slate-400', big ? 'text-lg py-8' : 'text-xs py-6']">{{ emptyText }}</p>
</template>
