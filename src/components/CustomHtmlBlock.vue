<script setup>
/**
 * CustomHtmlBlock — แทรกโค้ด HTML/CSS/JS เองได้ ใช้ร่วมกันทั้งเซกชันหน้าแรกและบล็อกหน้า CMS
 *
 * 2 โหมดตามเนื้อโค้ดที่ใส่มา:
 *  • เอกสารเต็ม (มี <!DOCTYPE หรือ <html) → iframe sandbox + วัดความสูงจริงส่งกลับมา
 *    ทำให้ JS/CSS ข้างในไม่ชนกับเว็บหลัก และสูงพอดีเนื้อหาเสมอ (ไม่มี scrollbar ซ้อน)
 *  • ชิ้นส่วน (snippet) → v-html ธรรมดา ใช้สไตล์ของเว็บได้เลย
 *
 * ความ responsive: iframe กว้าง 100% เสมอ และความสูงคำนวณใหม่ทุกครั้งที่เนื้อหา
 * ข้างในเปลี่ยนขนาด (ResizeObserver) — ย่อ/ขยายจอแล้วความสูงปรับตามทันที
 */
import { ref, computed, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  code:    { type: String, default: '' },
  blockId: { type: [String, Number], default: 'html' },
  minHeight: { type: Number, default: 200 },
})

const height = ref(props.minHeight)
const isFullDoc = computed(() => /<!DOCTYPE|<html/i.test(props.code))

// สคริปต์ที่ฉีดเข้าไปในเอกสารเพื่อรายงานความสูงกลับมาหา parent
const srcdoc = computed(() => {
  const s = `<script>(function(){
    function r(){
      var h = Math.max(
        document.documentElement.scrollHeight, document.body.scrollHeight,
        document.documentElement.offsetHeight, document.body.offsetHeight
      );
      parent.postMessage({ type:'iframeHeight', id:'${props.blockId}', height:h }, '*');
    }
    window.addEventListener('load', r);
    window.addEventListener('resize', r);
    try { new ResizeObserver(r).observe(document.body) } catch(e) {}
    setTimeout(r, 300);
  })()<\/script>`
  const html = props.code
  return html.includes('</body>') ? html.replace('</body>', s + '</body>') : html + s
})

function onMsg(e) {
  if (e.data?.type === 'iframeHeight' && String(e.data.id) === String(props.blockId)) {
    height.value = Math.max(props.minHeight, Number(e.data.height) || props.minHeight)
  }
}
onMounted(() => window.addEventListener('message', onMsg))
onUnmounted(() => window.removeEventListener('message', onMsg))
</script>

<template>
  <div v-if="code">
    <!-- allow-same-origin จำเป็นเพื่อให้สคริปต์วัดความสูงอ่าน document ตัวเองได้
         ไม่ใส่ allow-top-navigation/allow-popups เพื่อไม่ให้โค้ดที่แทรกพาผู้ใช้ออกจากเว็บเอง -->
    <div v-if="isFullDoc" class="w-full overflow-hidden rounded-[1.25rem]">
      <iframe
        :srcdoc="srcdoc"
        sandbox="allow-scripts allow-same-origin allow-forms"
        class="w-full border-0 block"
        :style="`height:${height}px`"
        scrolling="no"
        loading="lazy"/>
    </div>
    <div v-else class="prose prose-slate max-w-none" v-html="code"/>
  </div>
</template>
