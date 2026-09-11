<script setup>
/**
 * MonthTrendChart — แท่งคู่ 12 เดือน เทียบปีการศึกษานี้กับปีก่อน
 *
 * BarChart.vue เดิมเป็นแท่งแนวนอนชุดเดียว เทียบสองปีไม่ได้ จึงทำตัวนี้เพิ่ม
 * เขียนด้วย HTML/CSS ล้วนเหมือนกัน ไม่เพิ่มไลบรารีกราฟเข้าโปรเจค
 *
 * เรียงเดือนตามปีการศึกษา (พ.ค. → เม.ย.) ไม่ใช่ปีปฏิทิน
 * ปีแรกของระบบยังไม่มีข้อมูลปีก่อน — ต้องบอกผู้ใช้ ไม่ใช่โชว์แท่งว่างเปล่า
 */
const props = defineProps({
  /** ตัวเลข 12 ช่อง เรียง พ.ค. → เม.ย. */
  current:  { type: Array, default: () => [] },
  previous: { type: Array, default: () => [] },
  currentLabel:  { type: String, default: 'ปีนี้' },
  previousLabel: { type: String, default: 'ปีก่อน' },
  big: { type: Boolean, default: false },
})

const MONTHS = ['พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.']

const hasPrev = () => props.previous.some(v => Number(v) > 0)
const max = () => Math.max(1, ...props.current.map(Number), ...props.previous.map(Number))
function h(v) { return Math.round((Number(v) || 0) / max() * 100) }
</script>

<template>
  <div>
    <div class="flex items-center gap-4 mb-2">
      <span class="flex items-center gap-1.5 text-xs font-bold text-slate-600">
        <span class="w-3 h-3 rounded-sm bg-primary"></span>{{ currentLabel }}
      </span>
      <span v-if="hasPrev()" class="flex items-center gap-1.5 text-xs font-bold text-slate-400">
        <span class="w-3 h-3 rounded-sm bg-slate-300"></span>{{ previousLabel }}
      </span>
    </div>

    <div :class="['flex items-end gap-1', big ? 'h-56' : 'h-36']">
      <div v-for="(m, i) in MONTHS" :key="m" class="flex-1 flex flex-col items-center gap-1 h-full">
        <div class="flex-1 w-full flex items-end justify-center gap-0.5">
          <div :title="`${currentLabel} ${m} = ${current[i] || 0}`"
            class="w-1/2 max-w-[14px] rounded-t bg-primary transition-all duration-700"
            :style="{ height: h(current[i]) + '%' }"/>
          <div v-if="hasPrev()" :title="`${previousLabel} ${m} = ${previous[i] || 0}`"
            class="w-1/2 max-w-[14px] rounded-t bg-slate-300 transition-all duration-700"
            :style="{ height: h(previous[i]) + '%' }"/>
        </div>
        <span :class="['text-slate-400 tabular-nums', big ? 'text-sm' : 'text-[10px]']">{{ m }}</span>
        <span :class="['font-bold text-slate-600 tabular-nums', big ? 'text-base' : 'text-[10px]']">{{ current[i] || 0 }}</span>
      </div>
    </div>

    <p v-if="!hasPrev()" :class="['text-center text-slate-400 mt-2', big ? 'text-base' : 'text-xs']">
      ยังไม่มีข้อมูลของปีก่อนไว้เทียบ — ปีหน้าจะเห็นแท่งคู่ในกราฟนี้
    </p>
  </div>
</template>
