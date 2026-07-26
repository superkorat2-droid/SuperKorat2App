/*!
 * โค้ดฝังทำเนียบบุคลากร — กลุ่มนิเทศ ติดตามและประเมินผลฯ สพป.นครราชสีมา เขต 2
 *
 * วิธีใช้ (วางในบล็อก "HTML ที่กำหนดเอง" ของ WordPress):
 *   <script src="https://<โดเมนเว็บนิเทศ>/embed/personnel.js"></script>
 *
 * ตัวเลือก (ใส่เป็น attribute บนแท็ก script):
 *   data-contact="off"   ปิดช่องทางติดต่อ/โมดัล เหลือแค่รายชื่อ
 *   data-max-width="900" จำกัดความกว้างสูงสุด (px)
 *
 * สคริปต์นี้สร้าง iframe ให้เอง เพราะการ inject HTML ตรงๆ จะโดน CSS ของธีม
 * WordPress ทับจนหน้าตาเพี้ยน — iframe แยก style ขาดจากกัน
 * ข้อมูลอ่านสดจากฐานข้อมูลเดียวกับเว็บนิเทศ แก้ที่ต้นทางแล้วที่นี่เปลี่ยนตามทันที
 */
(function () {
  'use strict';

  // document.currentScript ใช้ไม่ได้ถ้าโดนโหลดแบบ async — เผื่อไว้ด้วยการหาจาก src
  var me = document.currentScript;
  if (!me) {
    var all = document.getElementsByTagName('script');
    for (var i = all.length - 1; i >= 0; i--) {
      if (all[i].src && all[i].src.indexOf('/embed/personnel.js') !== -1) { me = all[i]; break; }
    }
  }
  if (!me) return;

  // กันฝังซ้ำถ้ามีคนวางสคริปต์เดียวกัน 2 ครั้งในหน้าเดียว
  if (me.getAttribute('data-rendered') === '1') return;
  me.setAttribute('data-rendered', '1');

  var origin = me.src.replace(/\/embed\/personnel\.js.*$/, '');

  var params = [];
  if (me.getAttribute('data-contact') === 'off') params.push('contact=off');
  var qs = params.length ? '?' + params.join('&') : '';

  var wrap = document.createElement('div');
  wrap.style.width = '100%';
  wrap.style.margin = '0 auto';
  var maxW = me.getAttribute('data-max-width');
  if (maxW) wrap.style.maxWidth = /^\d+$/.test(maxW) ? maxW + 'px' : maxW;

  var frame = document.createElement('iframe');
  // hash router: ต้องเป็น /#/embed/personnel
  frame.src = origin + '/#/embed/personnel' + qs;
  frame.title = 'ทำเนียบบุคลากร';
  frame.loading = 'lazy';
  frame.setAttribute('scrolling', 'no');
  frame.style.width = '100%';
  frame.style.border = '0';
  frame.style.display = 'block';
  frame.style.height = '600px';   // ความสูงชั่วคราวก่อนหน้าในกรอบรายงานความสูงจริงมา
  frame.style.overflow = 'hidden';
  frame.style.colorScheme = 'light';

  wrap.appendChild(frame);
  me.parentNode.insertBefore(wrap, me.nextSibling);

  // รับความสูงจากหน้าในกรอบ → ปรับ iframe ไม่ให้มี scrollbar ซ้อน
  window.addEventListener('message', function (e) {
    if (e.source !== frame.contentWindow) return;               // รับเฉพาะของ iframe ตัวเอง
    if (e.origin !== origin) return;                            // และต้องมาจากโดเมนเว็บนิเทศเท่านั้น
    var d = e.data;
    if (!d || d.type !== 'superkorat-embed-height') return;
    var h = parseInt(d.height, 10);
    if (h > 0 && h < 20000) frame.style.height = h + 'px';
  });
})();
