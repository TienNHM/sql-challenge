import { cpSync, readdirSync, readFileSync } from 'node:fs'
import { join, posix, resolve } from 'node:path'
import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

const root = resolve(__dirname, '..')
const repo = 'https://github.com/TienNHM/sql-challenge'

// Tiêu đề lấy từ dòng "# ..." đầu tiên của mỗi bài, bỏ tiền tố "Ngày N: "
function lessonItems() {
  return readdirSync(join(root, 'lessons'))
    .filter((f) => f.endsWith('.md'))
    .sort()
    .map((file) => {
      const h1 = readFileSync(join(root, 'lessons', file), 'utf8').match(/^# (.+)$/m)?.[1] ?? file
      const day = Number(file.slice(0, 2))
      const text = h1.replace(/^Ngày \d+: /, '')
      return { day, text: day === 0 || day === 99 ? text : `${day}. ${text}`, link: `/lessons/${file.replace(/\.md$/, '')}` }
    })
}

function sidebar() {
  const items = lessonItems()
  const range = (from: number, to: number) => items.filter((i) => i.day >= from && i.day <= to)
  return [
    { text: 'Bắt đầu', items: [...range(0, 0), { text: 'Môi trường thực hành', link: '/setup/README' }] },
    { text: 'Chặng 1: Nền tảng', collapsed: false, items: range(1, 7) },
    { text: 'Chặng 2: Tổng hợp và kết hợp', collapsed: false, items: range(8, 14) },
    { text: 'Chặng 3: Index, transaction, đối tượng DB', collapsed: false, items: range(15, 21) },
    { text: 'Chặng 4: SQL trong thực tế', collapsed: false, items: range(22, 30) },
    { text: 'Kết thúc', items: range(99, 99) },
  ]
}

export default withMermaid(
  defineConfig({
    lang: 'vi-VN',
    title: '30 Days SQL Challenge',
    description: 'Khóa học SQL 30 ngày của HCMUTE Developer Student Club: PostgreSQL 16, bộ dữ liệu chung, bài tập có đáp án.',
    // GitHub Pages phục vụ ở /sql-challenge/; chạy local thì để BASE trống
    base: process.env.BASE ?? '/',
    cleanUrls: true,
    lastUpdated: true,
    srcExclude: ['review/**', 'diagrams/**', 'scripts/**', 'node_modules/**'],
    // Link "File gốc" của sơ đồ trỏ sang diagrams/*.html, được chép sang lúc build (xem buildEnd)
    // localhost:8080 là Adminer trên máy học viên
    ignoreDeadLinks: [/^https?:\/\/localhost/, /\/diagrams\//],
    head: [['link', { rel: 'icon', href: 'data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🗄️</text></svg>' }]],

    markdown: {
      lineNumbers: false,
      // Tắt cú pháp {...} gắn thuộc tính: các bảng kết quả có ô JSON như {"brand": "ASUS"}
      attrs: { disable: true },
      config(md) {
        // Link tới file không phải trang (.sql, LICENSE, thư mục setup/data) chỉ có trên GitHub:
        // đổi thành link xem file trên GitHub
        md.core.ruler.push('repo_file_links', (state) => {
          const page: string = state.env.relativePath ?? ''
          for (const block of state.tokens) {
            for (const tok of block.children ?? []) {
              if (tok.type !== 'link_open') continue
              const href = tok.attrGet('href') ?? ''
              // File HTML gốc của sơ đồ: mở tab mới để router của VitePress không chặn
              if (href.includes('/diagrams/')) {
                tok.attrSet('target', '_blank')
                continue
              }
              if (/^([a-z]+:|#|\/)/i.test(href) || /\.(md|html)(#.*)?$/.test(href)) continue
              const target = posix.normalize(posix.join(posix.dirname(page.replace(/\\/g, '/')), href))
              tok.attrSet('href', `${repo}/${/\.\w+$/.test(target) ? 'blob' : 'tree'}/main/${target}`)
              tok.attrSet('target', '_blank')
            }
          }
        })

        // Ảnh "x.png#gh-light-mode-only" / "#gh-dark-mode-only" (quy ước của GitHub):
        // bỏ fragment để Vite xử lý được ảnh, gắn class để CSS ẩn hiện theo giao diện
        md.core.ruler.push('gh_theme_images', (state) => {
          for (const block of state.tokens) {
            for (const tok of block.children ?? []) {
              if (tok.type !== 'image') continue
              const src = tok.attrGet('src') ?? ''
              const mode = src.match(/#gh-(light|dark)-mode-only$/)?.[1]
              if (!mode) continue
              tok.attrSet('src', src.replace(/#gh-(light|dark)-mode-only$/, ''))
              tok.attrJoin('class', `only-${mode}`)
            }
          }
        })
      },
    },

    themeConfig: {
      nav: [
        { text: 'Lộ trình', link: '/lessons/00-30-day-sql-learning-roadmap' },
        { text: 'Môi trường', link: '/setup/README' },
        { text: 'Dự án cuối khóa', link: '/lessons/99-summary' },
      ],
      sidebar: { '/lessons/': sidebar(), '/setup/': sidebar(), '/README': sidebar() },
      socialLinks: [{ icon: 'github', link: repo }],
      search: {
        provider: 'local',
        options: {
          translations: {
            button: { buttonText: 'Tìm kiếm', buttonAriaLabel: 'Tìm kiếm' },
            modal: {
              noResultsText: 'Không tìm thấy kết quả cho',
              resetButtonTitle: 'Xóa',
              footer: { selectText: 'chọn', navigateText: 'di chuyển', closeText: 'đóng' },
            },
          },
        },
      },
      editLink: { pattern: `${repo}/edit/main/:path`, text: 'Sửa trang này trên GitHub' },
      outline: { level: [2, 3], label: 'Trong bài này' },
      docFooter: { prev: 'Bài trước', next: 'Bài sau' },
      lastUpdated: { text: 'Cập nhật lần cuối' },
      returnToTopLabel: 'Lên đầu trang',
      sidebarMenuLabel: 'Danh sách bài',
      darkModeSwitchLabel: 'Giao diện',
      lightModeSwitchTitle: 'Chuyển sang nền sáng',
      darkModeSwitchTitle: 'Chuyển sang nền tối',
      notFound: { title: 'Không tìm thấy trang', quote: 'Có thể bài đã đổi tên.', linkText: 'Về trang chủ' },
      footer: {
        message: 'Phát hành theo giấy phép MIT.',
        copyright: 'HCMUTE Developer Student Club · Nội dung gốc của TienNHM',
      },
    },

    buildEnd(site) {
      cpSync(join(root, 'diagrams'), join(site.outDir, 'diagrams'), {
        recursive: true,
        filter: (src) => !src.includes('_palette'),
      })
    },

    mermaid: {},
  }),
)
