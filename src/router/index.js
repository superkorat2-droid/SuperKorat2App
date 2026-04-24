import { createRouter, createWebHashHistory } from 'vue-router'
import { supabase } from '../supabase'

// ─── Core pages ───────────────────────────────────────────────────────────
import HomeView         from '../views/HomeView.vue'
import LoginView        from '../views/LoginView.vue'
import SupervisorView   from '../views/SupervisorView.vue'
import GroupNitetView   from '../views/GroupNitetView.vue'

// ─── Admin (nested layout) ────────────────────────────────────────────────
import AdminLayout            from '../views/admin/AdminLayout.vue'
import AdminHomeView          from '../views/admin/AdminHomeView.vue'
import AdminUsersView         from '../views/admin/AdminUsersView.vue'
import AdminAreaSettingsView  from '../views/admin/AdminAreaSettingsView.vue'
import AdminPlaceholderView   from '../views/admin/AdminPlaceholderView.vue'
import AdminProfileView       from '../views/admin/AdminProfileView.vue'
import AdminBannersView       from '../views/admin/AdminBannersView.vue'
import AdminNewsView          from '../views/admin/AdminNewsView.vue'
import AdminDocumentsView     from '../views/admin/AdminDocumentsView.vue'
import AdminStorageView       from '../views/admin/AdminStorageView.vue'

// ─── Reusable placeholder ─────────────────────────────────────────────────
import PlaceholderView  from '../views/PlaceholderView.vue'

// ─── Service pages (มีหน้าจริง) ──────────────────────────────────────────
import DownloadView     from '../views/DownloadView.vue'
import UrlShortView     from '../views/UrlShortView.vue'
import QrCodeView       from '../views/QrCodeView.vue'
import ContactView      from '../views/ContactView.vue'

const routes = [
  // ── หน้าหลัก ──────────────────────────────────────────────────────────
  { path: '/',           name: 'home',       component: HomeView },
  { path: '/login',      name: 'login',      component: LoginView },
  { path: '/supervisor/:id', name: 'supervisor', component: SupervisorView },
  { path: '/nithet',     name: 'nithet',     component: GroupNitetView },

  // ── Admin (nested) ─────────────────────────────────────────────────────
  {
    path: '/dashboard',
    component: AdminLayout,
    meta: { requiresAuth: true },
    children: [
      { path: '',         name: 'dashboard',      component: AdminHomeView,         meta: { title: 'แดชบอร์ด' } },
      { path: 'users',    name: 'adminUsers',     component: AdminUsersView,        meta: { title: 'จัดการผู้ใช้', icon: '👥' } },
      { path: 'settings', name: 'adminSettings',  component: AdminAreaSettingsView, meta: { title: 'ตั้งค่าเขต', icon: '⚙️' } },
      { path: 'schools',  name: 'adminSchools',   component: AdminPlaceholderView,  meta: { title: 'ทำเนียบโรงเรียน', icon: '🏫' } },
      { path: 'banners',  name: 'adminBanners',   component: AdminBannersView,      meta: { title: 'แบนเนอร์', icon: '🖼️' } },
      { path: 'news',     name: 'adminNews',      component: AdminNewsView,          meta: { title: 'จัดการข่าวสาร', icon: '📰' } },
      { path: 'pages',    name: 'adminPages',     component: AdminPlaceholderView,  meta: { title: 'หน้าเนื้อหา (CMS)', icon: '📄' } },
      { path: 'documents',name: 'adminDocuments', component: AdminDocumentsView,    meta: { title: 'เอกสารและดาวน์โหลด', icon: '📂' } },
      { path: 'works',    name: 'adminWorks',     component: AdminPlaceholderView,  meta: { title: 'ผลงานและนวัตกรรม', icon: '🏆' } },
      { path: 'works-approve', name: 'adminWorksApprove', component: AdminPlaceholderView, meta: { title: 'อนุมัติผลงาน', icon: '✅' } },
      { path: 'short-urls', name: 'adminShortUrls', component: AdminPlaceholderView, meta: { title: 'จัดการ URL ย่อ', icon: '🔗' } },
      { path: 'storage',  name: 'adminStorage',   component: AdminStorageView,      meta: { title: 'จัดการไฟล์ Storage', icon: '🗄️' } },
      { path: 'profile',  name: 'adminProfile',   component: AdminProfileView,      meta: { title: 'โปรไฟล์ของฉัน', icon: '👤' } },
    ]
  },

  // ── ข้อมูลทั่วไป ──────────────────────────────────────────────────────
  {
    path: '/vision', name: 'vision', component: PlaceholderView,
    meta: {
      title: 'วิสัยทัศน์และพันธกิจ', icon: '👁️',
      desc:  'วิสัยทัศน์ พันธกิจ และเป้าประสงค์ของกลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
    }
  },
  {
    path: '/org', name: 'org', component: PlaceholderView,
    meta: {
      title: 'โครงสร้างการบริหาร', icon: '🏢',
      desc:  'แผนผังการแบ่งงานและโครงสร้างการบริหารงานภายในกลุ่มนิเทศฯ',
    }
  },
  {
    path: '/personnel', name: 'personnel', component: PlaceholderView,
    meta: {
      title: 'ทำเนียบบุคลากร', icon: '👥',
      desc:  'รายชื่อศึกษานิเทศก์ แยกตามกลุ่มงานและกลุ่มสาระฯ พร้อมข้อมูลการติดต่อ',
    }
  },
  {
    path: '/site-info', name: 'siteInfo', component: PlaceholderView,
    meta: {
      title: 'ข้อมูลสารสนเทศ', icon: '📊',
      desc:  'สถิติจำนวนสถานศึกษา ครู และนักเรียนในสังกัด',
    }
  },

  // ── งานนิเทศติดตาม ────────────────────────────────────────────────────
  {
    path: '/curriculum', name: 'curriculum', component: PlaceholderView,
    meta: {
      title: 'พัฒนาหลักสูตรการศึกษา', icon: '📖',
      desc:  'หลักสูตรแกนกลาง หลักสูตรท้องถิ่น การศึกษาปฐมวัย และการศึกษาพิเศษ',
    }
  },
  {
    path: '/supervision-edu', name: 'supervisionEdu', component: PlaceholderView,
    meta: {
      title: 'นิเทศการศึกษา', icon: '🔍',
      desc:  'แผนการนิเทศ 8 กลุ่มสาระการเรียนรู้ Active Learning และระบบ Coaching & Mentoring',
    }
  },
  {
    path: '/evaluation', name: 'evaluation', component: PlaceholderView,
    meta: {
      title: 'วัดและประเมินผลการศึกษา', icon: '📊',
      desc:  'การทดสอบระดับชาติ RT NT O-NET PISA เกณฑ์การวัดผล และระบบรายงานผล',
    }
  },
  {
    path: '/quality', name: 'quality', component: PlaceholderView,
    meta: {
      title: 'ประกันคุณภาพการศึกษา', icon: '⭐',
      desc:  'ประกันคุณภาพภายใน (IQA) ภายนอก (EQA) และมาตรฐานการศึกษาขั้นพื้นฐาน',
    }
  },
  {
    path: '/research', name: 'research', component: PlaceholderView,
    meta: {
      title: 'วิจัย สื่อ และเทคโนโลยี', icon: '🔬',
      desc:  'คลังวิจัยชั้นเรียน สื่อดิจิทัล DLTV/DLIT และแนวทางวิทยฐานะ (PA)',
    }
  },
  {
    path: '/secretariat', name: 'secretariat', component: PlaceholderView,
    meta: {
      title: 'ส่งเสริมพัฒนาระบบการบริหารจัดการ', icon: '📋',
      desc:  'คณะกรรมการ ก.ต.ป.น. โครงการพิเศษตามนโยบาย และรายงานผลการดำเนินงาน',
    }
  },

  // ── บริการ ────────────────────────────────────────────────────────────
  { path: '/download',  name: 'download',  component: DownloadView  },
  { path: '/url-short', name: 'urlShort',  component: UrlShortView  },
  { path: '/qrcode',    name: 'qrcode',    component: QrCodeView    },

  // ── ติดต่อ ────────────────────────────────────────────────────────────
  { path: '/contact',   name: 'contact',   component: ContactView   },

  // ── 404 fallback ──────────────────────────────────────────────────────
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition
    return { top: 0, behavior: 'smooth' }
  }
})

router.beforeEach(async (to, from, next) => {
  const { data: { session } } = await supabase.auth.getSession()
  if (to.meta.requiresAuth && !session) {
    next({ name: 'login' })
  } else if (to.name === 'login' && session) {
    next({ name: 'dashboard' })
  } else {
    next()
  }
})

export default router
