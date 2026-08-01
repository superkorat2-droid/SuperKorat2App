import { ref, watch, onMounted, onBeforeUnmount } from 'vue'

/**
 * useRevealOnScroll — ให้เนื้อหาค่อยๆ โผล่ตอนเลื่อนมาถึง
 *
 * ผูก containerRef กับกล่องนอกสุด แล้วใส่คลาส `reveal-item` ให้ลูกแต่ละใบ
 * พร้อม :style="{ '--i': index }" เพื่อไล่ทีละใบ (ดู .reveal-item ใน style.css)
 *
 * เล่นครั้งเดียวแล้ว unobserve — เลื่อนขึ้นลงไปมาไม่กระพริบซ้ำ
 *
 * ⚠️ ถ้าเบราว์เซอร์ไม่รองรับ IntersectionObserver ต้องโชว์ทันที
 * ห้ามปล่อยให้เนื้อหาค้างที่ opacity 0 — เนื้อหาหายสำคัญกว่าแอนิเมชันสวย
 */
export function useRevealOnScroll({ threshold = 0.12, rootMargin = '0px 0px -40px 0px' } = {}) {
  const containerRef = ref(null)
  const revealed = ref(false)
  let observer = null

  function reveal() {
    revealed.value = true
    if (observer) { observer.disconnect(); observer = null }
  }

  function observe(el) {
    if (revealed.value || observer) return
    if (!el) return
    if (typeof IntersectionObserver === 'undefined') { reveal(); return }

    observer = new IntersectionObserver(entries => {
      if (entries.some(e => e.isIntersecting)) reveal()
    }, { threshold, rootMargin })
    observer.observe(el)
  }

  // ⚠️ ตอน onMounted กล่องอาจยังไม่มี เพราะ parent ยังโชว์โครงร่างระหว่างโหลดอยู่
  // (v-if="loading" / v-else) ถ้าเช็คแค่ครั้งเดียวแล้ว reveal ทิ้ง แอนิเมชันจะไม่ทำงานเลย
  // — เคยพลาดตรงนี้มาแล้ว การ์ดโผล่ครบตั้งแต่ยังไม่เลื่อนถึง
  watch(containerRef, el => observe(el), { flush: 'post' })
  onMounted(() => observe(containerRef.value))

  onBeforeUnmount(() => { if (observer) { observer.disconnect(); observer = null } })

  return { containerRef, revealed }
}
