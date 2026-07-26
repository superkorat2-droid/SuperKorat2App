<script setup>
/**
 * MonthCalendar — ปฏิทินรายเดือน ใช้ทั้งหน้าแรกและหน้ากลุ่มนิเทศ
 *
 * แนวทางหน้าตา (ตกลงกับ user): กริดสะอาด เข้าธีมกระจกของเว็บ
 * เดิมตีเส้น border-b + border-r ทุกช่อง ทำให้หน้าตาเหมือนตาราง Excel
 * ตัดกับธีมกระจกทั้งเว็บ → เปลี่ยนเป็นเส้นแบ่งแนวนอนบางๆ ระหว่างสัปดาห์เท่านั้น
 * แล้วแยกคอลัมน์ด้วย "พื้นเสาร์-อาทิตย์" กับระยะห่างแทน
 *
 * ⚠️ กับดัก: style.css มีกฎ `.glass-card p { color: revert !important }`
 * (กันข้อความในการ์ดจางหายเวลาพื้นหลังเป็นรูปเข้ม) ซึ่งจะล้างสีจาก Tailwind
 * ที่ใส่บน <p> ทิ้งทั้งหมด — เลขวันที่ "วันนี้" เคยกลายเป็นสีเข้มบนวงกลมสีเข้ม
 * จนมองไม่เห็น ในไฟล์นี้จึงใช้ <span class="block"> แทน <p> ทุกจุดที่ต้องคุมสีเอง
 */
import { computed } from 'vue'
import { buildMonthWeeks, toDateKey, WEEKDAY_LABELS, MONTH_LABELS } from '../../composables/useCalendarGrid'
import { TYPE_COLOR } from '../../composables/useNithetEventMeta'
import { buildHolidayIndex, holidayMeta } from '../../composables/useHolidays'

const props = defineProps({
  events:   { type: Array, default: () => [] }, // [{ id, type, title, start_date, end_date }]
  holidays: { type: Array, default: () => [] }, // [{ id, title, type, start_date, end_date }]
  year:     { type: Number, required: true },
  month:    { type: Number, required: true }, // 0-indexed
})
const emit = defineEmits(['update:year', 'update:month', 'select-event', 'select-day'])

// มือถือช่องเล็กกว่ามาก แสดง pill ได้น้อยกว่า ที่เหลือสรุปเป็น "+N"
const MAX_PILLS = 3

const weeks = computed(() => buildMonthWeeks(props.year, props.month))
const todayKey = toDateKey(new Date())

function eventsForDay(dateKey) {
  return props.events.filter(e => e.start_date <= dateKey && dateKey <= e.end_date)
}

// index วันที่ → วันหยุด สร้างครั้งเดียวต่อการเปลี่ยนข้อมูล เร็วกว่า filter ทุกช่อง
const holidayIndex = computed(() => buildHolidayIndex(props.holidays))
function holidayForDay(dateKey) { return holidayIndex.value[dateKey] || null }

/** สัปดาห์เริ่มวันอาทิตย์ (ดู WEEKDAY_LABELS) → คอลัมน์ 0 และ 6 คือเสาร์-อาทิตย์ */
function isWeekend(colIndex) { return colIndex === 0 || colIndex === 6 }

function goToday() {
  const now = new Date()
  emit('update:year', now.getFullYear())
  emit('update:month', now.getMonth())
}
function goPrev() {
  const m = props.month - 1
  if (m < 0) { emit('update:year', props.year - 1); emit('update:month', 11) }
  else emit('update:month', m)
}
function goNext() {
  const m = props.month + 1
  if (m > 11) { emit('update:year', props.year + 1); emit('update:month', 0) }
  else emit('update:month', m)
}
</script>

<template>
  <div class="glass-card overflow-hidden">

    <!-- ── หัวปฏิทิน ─────────────────────────────────────────────── -->
    <div class="flex items-center justify-between gap-2 px-4 sm:px-5 py-3.5">
      <div class="min-w-0">
        <span class="block text-lg sm:text-xl font-extrabold text-slate-800 leading-tight truncate">
          {{ MONTH_LABELS[month] }}
          <span class="text-slate-400 font-bold">{{ year + 543 }}</span>
        </span>
      </div>

      <div class="flex items-center gap-1 flex-shrink-0">
        <button @click="goToday" type="button"
          class="px-3 py-1.5 mr-1 text-xs font-bold rounded-xl text-slate-600 bg-white/60 ring-1 ring-slate-900/[0.06] hover:bg-white hover:text-primary transition-colors">
          วันนี้
        </button>
        <button @click="goPrev" type="button" aria-label="เดือนก่อนหน้า"
          class="w-9 h-9 flex items-center justify-center rounded-xl text-slate-500 hover:text-primary hover:bg-white/70 active:scale-95 transition-all">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/></svg>
        </button>
        <button @click="goNext" type="button" aria-label="เดือนถัดไป"
          class="w-9 h-9 flex items-center justify-center rounded-xl text-slate-500 hover:text-primary hover:bg-white/70 active:scale-95 transition-all">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5"/></svg>
        </button>
      </div>
    </div>

    <!-- ── แถวชื่อวัน ────────────────────────────────────────────── -->
    <div class="grid grid-cols-7 px-1.5 pb-1">
      <div v-for="(w, i) in WEEKDAY_LABELS" :key="w"
        :class="['text-center text-[11px] font-bold py-1.5 rounded-lg',
          isWeekend(i) ? 'text-primary/70' : 'text-slate-400']">
        {{ w }}
      </div>
    </div>

    <!-- ── ตารางวัน ──────────────────────────────────────────────── -->
    <div class="px-1.5 pb-1.5">
      <div v-for="(week, wi) in weeks" :key="wi"
        :class="['grid grid-cols-7', wi > 0 && 'border-t border-slate-900/[0.05]']">

        <div v-for="(cell, ci) in week" :key="toDateKey(cell.date)"
          @click="emit('select-day', toDateKey(cell.date))"
          :class="['group relative min-h-[74px] sm:min-h-[96px] p-1 sm:p-1.5 rounded-xl cursor-pointer transition-colors',
            'hover:bg-white/70',
            !cell.inMonth && 'opacity-40',
            cell.inMonth && isWeekend(ci) && !holidayForDay(toDateKey(cell.date)) && 'bg-slate-500/[0.035]',
            cell.inMonth && holidayForDay(toDateKey(cell.date)) && 'bg-amber-500/[0.09]']">

          <!-- เลขวันที่ -->
          <div class="flex items-center gap-1 mb-1">
            <span :class="['text-[13px] font-bold w-7 h-7 flex items-center justify-center rounded-full transition-colors',
              toDateKey(cell.date) === todayKey
                ? 'bg-primary text-white shadow-sm ring-2 ring-white'
                : holidayForDay(toDateKey(cell.date)) && cell.inMonth ? 'text-amber-700'
                : isWeekend(ci) && cell.inMonth ? 'text-slate-500'
                : 'text-slate-700']">
              {{ cell.date.getDate() }}
            </span>
            <!-- จุดสีบอกชนิดวันหยุด — บนมือถือใช้แทนชื่อที่ยาวเกินช่อง -->
            <span v-if="holidayForDay(toDateKey(cell.date)) && cell.inMonth"
              :class="['w-1.5 h-1.5 rounded-full flex-shrink-0 sm:hidden', holidayMeta(holidayForDay(toDateKey(cell.date)).type).dot]"
              :title="holidayForDay(toDateKey(cell.date)).title"></span>
          </div>

          <!-- ชื่อวันหยุด — จอใหญ่เท่านั้น ช่องมือถือแคบเกินไป -->
          <span v-if="holidayForDay(toDateKey(cell.date)) && cell.inMonth"
            class="hidden sm:block text-[10px] font-bold text-amber-700/90 truncate mb-1 px-0.5"
            :title="holidayForDay(toDateKey(cell.date)).title">
            {{ holidayForDay(toDateKey(cell.date)).title }}
          </span>

          <!-- กิจกรรม -->
          <div class="space-y-1">
            <button v-for="ev in eventsForDay(toDateKey(cell.date)).slice(0, MAX_PILLS)" :key="ev.id"
              @click.stop="emit('select-event', ev)" type="button" :title="ev.title"
              :class="['w-full flex items-center gap-1 px-1.5 py-[3px] rounded-md text-[11px] font-bold leading-tight',
                'hover:brightness-95 transition-all', TYPE_COLOR[ev.type]?.bg, TYPE_COLOR[ev.type]?.text]">
              <span :class="['w-1 h-1 rounded-full flex-shrink-0 hidden sm:block', TYPE_COLOR[ev.type]?.dot]"></span>
              <span class="truncate">{{ ev.title }}</span>
            </button>
            <span v-if="eventsForDay(toDateKey(cell.date)).length > MAX_PILLS"
              class="block text-[10px] font-bold text-slate-400 pl-1.5">
              +{{ eventsForDay(toDateKey(cell.date)).length - MAX_PILLS }} เพิ่มเติม
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
