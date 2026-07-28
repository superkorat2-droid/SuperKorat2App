import { createRouter, createWebHashHistory } from 'vue-router'
import { supabase } from '../supabase'
import { trackVisit } from '../composables/useVisitTracker'

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
import AdminContactMessagesView from '../views/admin/AdminContactMessagesView.vue'
import AdminStorageView       from '../views/admin/AdminStorageView.vue'
import AdminImageLibraryView  from '../views/admin/AdminImageLibraryView.vue'
import AdminHomeSectionsView  from '../views/admin/AdminHomeSectionsView.vue'
import AdminSchoolsView       from '../views/admin/AdminSchoolsView.vue'
import AdminPersonnelView     from '../views/admin/AdminPersonnelView.vue'
import AdminStudentsView      from '../views/admin/AdminStudentsView.vue'
import AdminEnrollmentView    from '../views/admin/AdminEnrollmentView.vue'
import AdminVisitStatsView   from '../views/admin/AdminVisitStatsView.vue'
import AdminPagesView         from '../views/admin/AdminPagesView.vue'
import AdminPageEditorView    from '../views/admin/AdminPageEditorView.vue'
import AdminPageHeadersView   from '../views/admin/AdminPageHeadersView.vue'
import AdminServicesView      from '../views/admin/AdminServicesView.vue'
import AdminSupervisionView       from '../views/admin/AdminSupervisionView.vue'
import AdminDmcPeriodsView        from '../views/admin/AdminDmcPeriodsView.vue'
import AdminPrincipalsView       from '../views/admin/AdminPrincipalsView.vue'
import PublicPrincipalsView      from '../views/PublicPrincipalsView.vue'
import PublicNewslettersView     from '../views/PublicNewslettersView.vue'
import AdminNewslettersView      from '../views/admin/AdminNewslettersView.vue'
import AdminMediaView           from '../views/admin/AdminMediaView.vue'
import AdminMediaEditorView     from '../views/admin/AdminMediaEditorView.vue'
import PublicMediaView          from '../views/PublicMediaView.vue'
import SchoolNewsletterView      from '../views/school/SchoolNewsletterView.vue'
import SchoolAdminsView          from '../views/school/SchoolAdminsView.vue'
import SchoolMediaView           from '../views/school/SchoolMediaView.vue'
import SchoolMediaEditorView     from '../views/school/SchoolMediaEditorView.vue'
import AdminDmcResultsView        from '../views/admin/AdminDmcResultsView.vue'
import PublicStudentStatsView     from '../views/PublicStudentStatsView.vue'
import AdminSupervisionFormView from '../views/admin/AdminSupervisionFormView.vue'
import AdminSupervisionResultsView from '../views/admin/AdminSupervisionResultsView.vue'
import AdminNitetCalendarView from '../views/admin/AdminNitetCalendarView.vue'
import AdminNitetReportView from '../views/admin/AdminNitetReportView.vue'

// ─── Dynamic CMS page (public) ───────────────────────────────────────────
import DynamicPageView        from '../views/DynamicPageView.vue'

// ─── Personnel ────────────────────────────────────────────────────────────
import PersonnelView          from '../views/PersonnelView.vue'
import OrgChartView           from '../views/OrgChartView.vue'

// ─── Supervision fill (public) ────────────────────────────────────────────
import SupervisionFillView    from '../views/SupervisionFillView.vue'

// ─── School portal (nested layout) ───────────────────────────────────────
import SchoolLayout                from '../views/school/SchoolLayout.vue'
import SchoolLoginView             from '../views/school/SchoolLoginView.vue'
import SchoolHomeView              from '../views/school/SchoolHomeView.vue'
import SchoolProfileView           from '../views/school/SchoolProfileView.vue'
import SchoolDmcView               from '../views/school/SchoolDmcView.vue'
import SchoolSupervisionFillView   from '../views/school/SchoolSupervisionFillView.vue'

// ─── Public school directory ──────────────────────────────────────────────
import PublicSchoolsView      from '../views/PublicSchoolsView.vue'
import PublicSchoolWebsitesView from '../views/PublicSchoolWebsitesView.vue'

// ─── News public pages ───────────────────────────────────────────────────
import NewsView              from '../views/NewsView.vue'
import NewsDetailView        from '../views/NewsDetailView.vue'
import EducationNewsView     from '../views/EducationNewsView.vue'

// ─── Service pages (มีหน้าจริง) ──────────────────────────────────────────
import DownloadView     from '../views/DownloadView.vue'
import SchoolDocumentsView from '../views/SchoolDocumentsView.vue'
import AdminDocumentTasksView from '../views/admin/AdminDocumentTasksView.vue'
import UrlShortView     from '../views/UrlShortView.vue'
import QrCodeView       from '../views/QrCodeView.vue'
import ShortRedirectView from '../views/ShortRedirectView.vue'
import ContactView      from '../views/ContactView.vue'
import AdminShortUrlsView from '../views/admin/AdminShortUrlsView.vue'
import AdminWorksView         from '../views/admin/AdminWorksView.vue'
import AdminWorkEditorView    from '../views/admin/AdminWorkEditorView.vue'
import AdminWorksApproveView  from '../views/admin/AdminWorksApproveView.vue'
import AdminAwardsView        from '../views/admin/AdminAwardsView.vue'
import AdminAwardEditorView   from '../views/admin/AdminAwardEditorView.vue'
import AdminAwardsApproveView from '../views/admin/AdminAwardsApproveView.vue'
import AdminAwardsDashboardView from '../views/admin/AdminAwardsDashboardView.vue'
import AdminAwardsReportView  from '../views/admin/AdminAwardsReportView.vue'

const routes = [
  // ── หน้าหลัก ──────────────────────────────────────────────────────────
  { path: '/',           name: 'home',       component: HomeView, meta: { title: 'หน้าแรก' } },
  { path: '/login',      name: 'login',      component: LoginView },
  { path: '/supervisor/:id', name: 'supervisor', component: SupervisorView, meta: { title: 'ประวัติศึกษานิเทศก์' } },
  { path: '/nithet',     name: 'nithet',     component: GroupNitetView, meta: { title: 'กลุ่มนิเทศ ติดตามและประเมินผล' } },

  // ── Admin (nested) ─────────────────────────────────────────────────────
  {
    path: '/dashboard',
    component: AdminLayout,
    meta: { requiresAuth: true },
    children: [
      { path: '',         name: 'dashboard',      component: AdminHomeView,         meta: { title: 'แดชบอร์ด' } },
      { path: 'users',      name: 'adminUsers',     component: AdminUsersView,      meta: { title: 'จัดการผู้ใช้', icon: '👥' } },
      { path: 'personnel',  name: 'adminPersonnel', component: AdminPersonnelView,  meta: { title: 'จัดการบุคลากร', icon: '👤' } },
      { path: 'settings', name: 'adminSettings',  component: AdminAreaSettingsView, meta: { title: 'ตั้งค่าเขต', icon: '⚙️' } },
      { path: 'schools',     name: 'adminSchools',     component: AdminSchoolsView,     meta: { title: 'ทำเนียบโรงเรียน', icon: '🏫' } },
      { path: 'students',    name: 'adminStudents',    component: AdminStudentsView,    meta: { title: 'ข้อมูลนักเรียน', icon: '👨‍🎓' } },
      { path: 'principals',    name: 'adminPrincipals',  component: AdminPrincipalsView,  meta: { title: 'ผู้บริหารโรงเรียน' } },
      { path: 'newsletters',   name: 'adminNewsletters',    component: AdminNewslettersView,    meta: { title: 'จดหมายข่าว' } },
      { path: 'media',         name: 'adminMedia',          component: AdminMediaView,          meta: { title: 'คลังสื่อ' } },
      { path: 'media/new',     name: 'adminMediaNew',       component: AdminMediaEditorView,    meta: { title: 'เพิ่มสื่อ' } },
      { path: 'media/:id/edit',name: 'adminMediaEdit',      component: AdminMediaEditorView,    meta: { title: 'แก้ไขสื่อ' } },
      { path: 'dmc',         name: 'adminDmc',         component: AdminDmcPeriodsView,  meta: { title: 'รอบ DMC', icon: '📊' } },
      { path: 'dmc/:id',     name: 'adminDmcResults',  component: AdminDmcResultsView,  meta: { title: 'สถิติ DMC' } },
      { path: 'enrollment',  name: 'adminEnrollment',  component: AdminEnrollmentView,  meta: { title: 'สถิติย้อนหลัง', icon: '📊' } },
      { path: 'visit-stats', name: 'adminVisitStats',  component: AdminVisitStatsView,  meta: { title: 'สถิติการเข้าชม', icon: '👁️' } },
      { path: 'image-library', name: 'adminImageLibrary', component: AdminImageLibraryView, meta: { title: 'คลังภาพ', icon: '🖼️' } },
      { path: 'home-sections', name: 'adminHomeSections', component: AdminHomeSectionsView, meta: { title: 'จัดการ Section หน้าแรก' } },
      { path: 'banners',   name: 'adminBanners',   component: AdminBannersView,   meta: { title: 'แบนเนอร์', icon: '🖼️' } },
      { path: 'services',  name: 'adminServices',  component: AdminServicesView,  meta: { title: 'บริการออนไลน์', icon: '🌐' } },
      { path: 'supervision',           name: 'adminSupervision',        component: AdminSupervisionView,        meta: { title: 'แบบนิเทศติดตาม' } },
      { path: 'supervision/new',       name: 'adminSupervisionNew',     component: AdminSupervisionFormView,    meta: { title: 'สร้างแบบนิเทศ' } },
      { path: 'supervision/:id/edit',  name: 'adminSupervisionEdit',    component: AdminSupervisionFormView,    meta: { title: 'แก้ไขแบบนิเทศ' } },
      { path: 'supervision/:id/results', name: 'adminSupervisionResults', component: AdminSupervisionResultsView, meta: { title: 'ผลลัพธ์แบบนิเทศ' } },
      { path: 'nithet-calendar',       name: 'adminNithetCalendar',     component: AdminNitetCalendarView,      meta: { title: 'ปฏิทินนิเทศ' } },
      { path: 'nithet-report',         name: 'adminNithetReport',       component: AdminNitetReportView,        meta: { title: 'รายงานผลการนิเทศ' } },
      { path: 'news',     name: 'adminNews',      component: AdminNewsView,          meta: { title: 'จัดการข่าวสาร', icon: '📰' } },
      { path: 'pages',          name: 'adminPages',      component: AdminPagesView,      meta: { title: 'จัดการหน้าเนื้อหา', icon: '📄' } },
      { path: 'pages/:id/edit', name: 'adminPageEditor', component: AdminPageEditorView, meta: { title: 'แก้ไขเนื้อหา' } },
      { path: 'page-headers',   name: 'adminPageHeaders', component: AdminPageHeadersView, meta: { title: 'จัดการหัวข้อหน้า', icon: '🖼️' } },
      { path: 'documents',name: 'adminDocuments', component: AdminDocumentsView,    meta: { title: 'เอกสารและดาวน์โหลด', icon: '📂' } },
      { path: 'document-tasks', name: 'adminDocumentTasks', component: AdminDocumentTasksView, meta: { title: 'ระบบธุรการ' } },
      { path: 'contact-messages', name: 'adminContactMessages', component: AdminContactMessagesView, meta: { title: 'ข้อความติดต่อ', icon: '📬' } },
      { path: 'works',              name: 'adminWorks',        component: AdminWorksView,       meta: { title: 'ผลงานและนวัตกรรม', icon: '🏆' } },
      { path: 'works/new',          name: 'adminWorkNew',      component: AdminWorkEditorView,  meta: { title: 'เพิ่มผลงาน' } },
      { path: 'works/:id/edit',     name: 'adminWorkEdit',     component: AdminWorkEditorView,  meta: { title: 'แก้ไขผลงาน' } },
      { path: 'works-approve',      name: 'adminWorksApprove', component: AdminWorksApproveView, meta: { title: 'อนุมัติผลงาน', icon: '✅' } },
      { path: 'awards',             name: 'adminAwards',       component: AdminAwardsView,       meta: { title: 'ผลงานและรางวัล', icon: '🏆' } },
      { path: 'awards/new',         name: 'adminAwardNew',     component: AdminAwardEditorView,  meta: { title: 'เพิ่มรางวัล' } },
      { path: 'awards/:id/edit',    name: 'adminAwardEdit',    component: AdminAwardEditorView,  meta: { title: 'แก้ไขรางวัล' } },
      { path: 'awards-approve',     name: 'adminAwardsApprove',component: AdminAwardsApproveView,meta: { title: 'อนุมัติรางวัล', icon: '✅' } },
      { path: 'awards-dashboard',   name: 'adminAwardsDash',   component: AdminAwardsDashboardView, meta: { title: 'สถิติรางวัล', icon: '📊' } },
      { path: 'awards-report',      name: 'adminAwardsReport', component: AdminAwardsReportView,    meta: { title: 'รายงานรางวัล', icon: '📄' } },
      { path: 'short-urls', name: 'adminShortUrls', component: AdminShortUrlsView, meta: { title: 'จัดการ URL ย่อ', icon: '🔗' } },
      { path: 'storage',  name: 'adminStorage',   component: AdminStorageView,      meta: { title: 'จัดการไฟล์ Storage', icon: '🗄️' } },
      { path: 'profile',  name: 'adminProfile',   component: AdminProfileView,      meta: { title: 'โปรไฟล์ของฉัน', icon: '👤' } },
    ]
  },

  // ── ข้อมูลทั่วไป ──────────────────────────────────────────────────────
  {
    path: '/personnel', name: 'personnel', component: PersonnelView,
    meta: {
      title: 'ทำเนียบบุคลากร', icon: '👥',
      desc:  'รายชื่อศึกษานิเทศก์ แยกตามกลุ่มงานและกลุ่มสาระฯ พร้อมข้อมูลการติดต่อ',
    }
  },

  // ── School portal ─────────────────────────────────────────────────────
  { path: '/school/login', redirect: '/login' },
  {
    path: '/school',
    component: SchoolLayout,
    children: [
      { path: '',                        name: 'schoolHome',           component: SchoolHomeView             },
      { path: 'profile',                 name: 'schoolProfile',        component: SchoolProfileView          },
      { path: 'dmc',                     name: 'schoolDmc',            component: SchoolDmcView              },
      { path: 'supervision/:formId',     name: 'schoolSupervisionFill', component: SchoolSupervisionFillView },
      { path: 'admins',                  name: 'schoolAdmins',          component: SchoolAdminsView },
      { path: 'newsletters',             name: 'schoolNewsletters',     component: SchoolNewsletterView },
      { path: 'media',                   name: 'schoolMedia',           component: SchoolMediaView },
      { path: 'media/new',               name: 'schoolMediaNew',        component: SchoolMediaEditorView },
      { path: 'media/:id/edit',          name: 'schoolMediaEdit',       component: SchoolMediaEditorView },
      // ผลงาน: ใช้ component เดียวกับหลังบ้านเขต (คิด path ปลายทางจาก route เอง)
      // role school ถูก guard เด้งออกจาก /dashboard จึงต้องมี route ใต้ /school
      { path: 'works',                   name: 'schoolWorks',           component: AdminWorksView },
      { path: 'works/new',               name: 'schoolWorkNew',         component: AdminWorkEditorView },
      { path: 'works/:id/edit',          name: 'schoolWorkEdit',        component: AdminWorkEditorView },
      { path: 'awards',                  name: 'schoolAwards',          component: AdminAwardsView },
      { path: 'awards/new',              name: 'schoolAwardNew',        component: AdminAwardEditorView },
      { path: 'awards/:id/edit',         name: 'schoolAwardEdit',       component: AdminAwardEditorView },
    ]
  },

  // ── ทำเนียบโรงเรียน (สาธารณะ) ─────────────────────────────────────────
  { path: '/schools',       name: 'schools',      component: PublicSchoolsView, meta: { title: 'ทำเนียบโรงเรียน' } },
  { path: '/schoolweb',     name: 'schoolWebsites', component: PublicSchoolWebsitesView, meta: { title: 'เว็บไซต์โรงเรียน' } },
  { path: '/principals',   name: 'principals',   component: PublicPrincipalsView, meta: { title: 'ผู้บริหารโรงเรียน' } },
  { path: '/newsletters',  name: 'newsletters',  component: PublicNewslettersView, meta: { title: 'จดหมายข่าว' } },
  { path: '/media',        name: 'media',        component: PublicMediaView, meta: { title: 'คลังสื่อการเรียนรู้' } },
  { path: '/media/:id',    name: 'mediaDetail',  component: () => import('../views/MediaDetailView.vue'), meta: { title: 'รายละเอียดสื่อ' } },
  { path: '/works',        name: 'works',        component: () => import('../views/PublicWorksView.vue'), meta: { title: 'ผลงาน/นวัตกรรม' } },
  { path: '/works/:id',    name: 'workDetail',   component: () => import('../views/WorkDetailView.vue'), meta: { title: 'รายละเอียดผลงาน' } },
  // ฟอร์มให้บุคคลภายนอกเขตส่งผลงาน (ไม่ต้องล็อกอิน — เขียนลง work_submissions)
  { path: '/submit-work',  name: 'submitWork',   component: () => import('../views/SubmitWorkView.vue'), meta: { title: 'ส่งผลงานเผยแพร่' } },
  { path: '/awards',       name: 'awards',       component: () => import('../views/PublicAwardsView.vue'), meta: { title: 'ผลงานและรางวัล' } },

  // ── โค้ดฝังสำหรับเว็บภายนอก (ไม่มี navbar/footer — ดู isSchoolRoute ใน App.vue) ──
  { path: '/embed/personnel', name: 'embedPersonnel', component: () => import('../views/EmbedPersonnelView.vue') },
  { path: '/student-stats', name: 'studentStats', component: PublicStudentStatsView, meta: { title: 'สถิตินักเรียน' } },

  // ── Dynamic CMS pages ────────────────────────────────────────────────
  // /page/org แทนที่ด้วยผังโครงสร้างที่ดึงข้อมูลจริง (ต้องมาก่อน /page/:slug ทั่วไป)
  { path: '/page/org', name: 'orgChart', component: OrgChartView, meta: { title: 'โครงสร้างการบริหาร' } },
  { path: '/page/:slug', name: 'dynamicPage', component: DynamicPageView },

  // ── Supervision fill (public link) ───────────────────────────────────
  { path: '/supervision/:token', name: 'supervisionFill', component: SupervisionFillView },

  // ── ข่าวสาร ──────────────────────────────────────────────────────────
  { path: '/news',            name: 'news',          component: NewsView, meta: { title: 'ข่าวสาร' }          },
  { path: '/news/:id',        name: 'newsDetail',    component: NewsDetailView, meta: { title: 'รายละเอียดข่าว' }    },
  { path: '/education-news',  name: 'educationNews', component: EducationNewsView, meta: { title: 'ข่าวการศึกษา' } },

  // ── บริการ ────────────────────────────────────────────────────────────
  { path: '/download',  name: 'download',  component: DownloadView, meta: { title: 'เอกสารดาวน์โหลด' }  },
  { path: '/school-documents', name: 'schoolDocuments', component: SchoolDocumentsView, meta: { title: 'เอกสารสำหรับโรงเรียน' } },
  { path: '/url-short', name: 'urlShort',  component: UrlShortView, meta: { title: 'ย่อลิงก์' }  },
  { path: '/qrcode',    name: 'qrcode',    component: QrCodeView, meta: { title: 'สร้าง QR Code' }    },
  { path: '/s/:slug',   name: 'shortRedirect', component: ShortRedirectView },

  // ── ติดต่อ ────────────────────────────────────────────────────────────
  { path: '/contact',   name: 'contact',   component: ContactView, meta: { title: 'ติดต่อเรา' }   },

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

// routes ที่ต้องการ admin เท่านั้น
const ADMIN_ONLY_PATHS = [
  '/dashboard/settings',
  '/dashboard/users',
  '/dashboard/personnel',
  '/dashboard/home-sections',
  '/dashboard/banners',
  '/dashboard/image-library',
]

router.beforeEach(async (to, from, next) => {
  const { data: { session } } = await supabase.auth.getSession()

  if (to.meta.requiresAuth && !session) {
    next({ name: 'login' })
    return
  }

  // School user ห้ามเข้า /dashboard → redirect ไป /school
  if (session && to.path.startsWith('/dashboard')) {
    const { data: p } = await supabase
      .from('profiles').select('role').eq('id', session.user.id).single()
    if (p?.role === 'school') {
      next({ name: 'schoolHome' })
      return
    }
  }

  // guard admin-only paths
  if (session && ADMIN_ONLY_PATHS.some(p => to.path.startsWith(p))) {
    const { data: profile } = await supabase
      .from('profiles').select('role').eq('id', session.user.id).single()
    if (!['super_admin','admin'].includes(profile?.role)) {
      next({ name: 'dashboard' })
      return
    }
  }

  // ถ้าล็อกอินแล้วพยายามเข้า /login ให้ redirect ตาม role
  if (to.name === 'login' && session) {
    const { data: profile } = await supabase
      .from('profiles').select('role').eq('id', session.user.id).single()
    if (profile?.role === 'school') {
      next({ name: 'schoolHome' })
    } else {
      next({ name: 'dashboard' })
    }
    return
  }

  next()
})

// สถิติการเข้าชม — ต้องอยู่ใน afterEach เท่านั้น ถ้าไปใส่ใน beforeEach จะหน่วง
// การเปลี่ยนหน้าให้ผู้ใช้ทุกครั้ง · ตัวมันเองไม่ await อยู่แล้ว
// เอา path จาก to.path ไม่ใช่ location.pathname เพราะ hash router ทำให้
// location.pathname เป็น "/" ตลอด ทุกหน้าจะถูกนับรวมกันหมด
router.afterEach((to) => {
  trackVisit(to.path, to.meta?.title)
})

export default router
