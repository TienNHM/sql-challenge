<script setup lang="ts">
import { withBase } from 'vitepress'
import { data as lessons } from './lessons.data'
import erdLight from '../../lessons/img/erd-dsc-shop.png'
import erdDark from '../../lessons/img/erd-dsc-shop-dark.png'

const stages = [
  { name: 'Chặng 1', title: 'Nền tảng và truy vấn đơn giản', from: 1, to: 7 },
  { name: 'Chặng 2', title: 'Tổng hợp và kết hợp dữ liệu', from: 8, to: 14 },
  { name: 'Chặng 3', title: 'Index, transaction và đối tượng DB', from: 15, to: 21 },
  { name: 'Chặng 4', title: 'SQL trong thực tế', from: 22, to: 30 },
].map((s) => ({ ...s, lessons: lessons.filter((l) => l.day >= s.from && l.day <= s.to) }))

const steps = [
  { title: 'Lấy repo về', code: 'git clone https://github.com/hcmute-dsc/sql-challenge.git\ncd sql-challenge' },
  { title: 'Dựng database', code: 'docker compose up -d' },
  { title: 'Mở và gõ SQL', code: 'docker compose exec db psql -U postgres -d sql_challenge\n# hoặc Adminer: http://localhost:8080' },
]

const tables = [
  ['categories', 'Danh mục dạng cây'],
  ['products', 'Sản phẩm, thông số JSONB'],
  ['customers', 'Khách hàng, có NULL'],
  ['employees', 'Nhân viên dạng cây'],
  ['orders', '40 đơn, 01/2025 đến 10/2026'],
  ['order_items', 'Dòng hàng của đơn'],
  ['payments', 'Thanh toán, có trả góp'],
]
</script>

<template>
  <div class="home-content">
    <section class="section">
      <h2>Bắt đầu trong 3 bước</h2>
      <p class="lead">Cần cài sẵn Docker Desktop. Không dùng Docker? Xem <a :href="withBase('/setup/README')">cách cài PostgreSQL trực tiếp</a>.</p>
      <ol class="steps">
        <li v-for="(s, i) in steps" :key="s.title" class="step">
          <span class="num">{{ i + 1 }}</span>
          <h3>{{ s.title }}</h3>
          <pre><code>{{ s.code }}</code></pre>
        </li>
      </ol>
    </section>

    <section class="section">
      <h2>Lộ trình 30 ngày</h2>
      <p class="lead">
        Học theo thứ tự, mỗi ngày một bài. Bắt đầu từ
        <a :href="withBase('/lessons/00-30-day-sql-learning-roadmap')">lộ trình tổng quan</a>,
        kết thúc bằng <a :href="withBase('/lessons/99-summary')">dự án cuối khóa</a>.
      </p>
      <div class="stages">
        <div v-for="s in stages" :key="s.name" class="stage">
          <div class="stage-head">
            <span class="badge">{{ s.name }} · Ngày {{ s.from }}–{{ s.to }}</span>
            <h3>{{ s.title }}</h3>
          </div>
          <ul>
            <li v-for="l in s.lessons" :key="l.day">
              <a :href="withBase(l.link)" :title="l.summary">
                <span class="day">{{ String(l.day).padStart(2, '0') }}</span>
                <span>{{ l.title }}</span>
              </a>
            </li>
          </ul>
        </div>
      </div>
    </section>

    <section class="section dataset">
      <div class="dataset-text">
        <h2>Bộ dữ liệu DSC Shop</h2>
        <p class="lead">
          Một cửa hàng đồ công nghệ với 7 bảng, dùng xuyên suốt 30 ngày. Dữ liệu cố ý có NULL, tên thành phố viết lộn xộn,
          khách trùng tên, khách chưa mua lần nào, để bạn gặp đúng những cái bẫy của dữ liệu thật.
        </p>
        <ul class="tables">
          <li v-for="t in tables" :key="t[0]"><code>{{ t[0] }}</code><span>{{ t[1] }}</span></li>
        </ul>
        <a class="link" :href="withBase('/setup/README')">Xem chi tiết bộ dữ liệu →</a>
      </div>
      <div class="dataset-img">
        <img :src="erdLight" class="only-light" alt="Sơ đồ ERD của DSC Shop: 7 bảng categories, products, customers, employees, orders, order_items, payments và các khóa ngoại nối chúng" />
        <img :src="erdDark" class="only-dark" alt="" />
      </div>
    </section>

    <section class="section cta">
      <h2>Học xong, tự xây một database thật</h2>
      <p class="lead">
        Dự án cuối khóa: thiết kế ERD, dựng schema chuẩn 3NF, viết truy vấn báo cáo, transaction, view, trigger,
        tối ưu bằng EXPLAIN và một API nhỏ an toàn trước SQL injection. Chấm theo rubric 100 điểm.
      </p>
      <a class="button" :href="withBase('/lessons/99-summary')">Xem đề dự án</a>
    </section>
  </div>
</template>

<style scoped>
.home-content {
  max-width: 1152px;
  margin: 0 auto;
  padding: 0 24px 48px;
}
.section { margin-top: 80px; }
/* Trang home vẫn nằm trong .vp-doc: bỏ đường kẻ và khoảng cách mặc định của tiêu đề, danh sách */
.home-content h2 {
  border-top: none;
  padding-top: 0;
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.3;
  margin: 0 0 12px;
}
h3 { font-size: 17px; font-weight: 600; margin: 0; line-height: 1.4; }
.lead { color: var(--vp-c-text-2); max-width: 720px; margin: 0 0 28px; line-height: 1.7; }
a { color: var(--vp-c-brand-1); font-weight: 500; text-decoration: none; }
a:hover { text-decoration: underline; }

.steps {
  list-style: none;
  padding: 0;
  margin: 0;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}
.home-content li { margin: 0; }
.step {
  position: relative;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
  padding: 20px;
}
.num {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: var(--vp-c-brand-soft);
  color: var(--vp-c-brand-1);
  font-weight: 700;
  font-size: 14px;
  margin-bottom: 10px;
}
.step pre {
  margin: 12px 0 0;
  padding: 12px 14px;
  border-radius: 8px;
  background: var(--vp-code-block-bg);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  font-size: 13px;
  line-height: 1.6;
}
.step code { font-family: var(--vp-font-family-mono); color: var(--vp-c-text-1); }

.stages {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}
.stage {
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  padding: 20px 16px 12px;
  background: var(--vp-c-bg-soft);
}
.stage-head { padding: 0 4px 12px; border-bottom: 1px solid var(--vp-c-divider); margin-bottom: 8px; }
.badge {
  display: inline-block;
  font-size: 12px;
  font-weight: 600;
  color: var(--vp-c-brand-1);
  margin-bottom: 6px;
}
.stage ul { list-style: none; padding: 0; margin: 0; }
.stage li a {
  display: flex;
  gap: 10px;
  padding: 6px 4px;
  border-radius: 6px;
  color: var(--vp-c-text-1);
  font-weight: 400;
  font-size: 14px;
  line-height: 1.5;
}
.stage li a:hover { background: var(--vp-c-default-soft); text-decoration: none; color: var(--vp-c-brand-1); }
.day {
  flex: none;
  font-family: var(--vp-font-family-mono);
  font-size: 12px;
  color: var(--vp-c-text-3);
  padding-top: 2px;
}

.dataset {
  display: grid;
  grid-template-columns: minmax(0, 5fr) minmax(0, 7fr);
  gap: 40px;
  align-items: center;
}
.tables { list-style: none; padding: 0; margin: 0 0 24px; display: grid; gap: 8px; }
.tables li { display: flex; gap: 12px; align-items: baseline; font-size: 14px; color: var(--vp-c-text-2); }
.tables code {
  flex: none;
  min-width: 108px;
  font-size: 13px;
  color: var(--vp-c-text-1);
  background: var(--vp-c-default-soft);
  padding: 2px 8px;
  border-radius: 4px;
}
.dataset-img img {
  width: 100%;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
}

.cta {
  border-radius: 16px;
  padding: 48px 40px;
  background: var(--vp-c-brand-soft);
  text-align: center;
}
.cta .lead { margin: 0 auto 24px; }
.button {
  display: inline-block;
  padding: 10px 22px;
  border-radius: 20px;
  background: var(--vp-button-brand-bg);
  color: var(--vp-button-brand-text);
  font-weight: 600;
}
.button:hover { background: var(--vp-button-brand-hover-bg); text-decoration: none; }

@media (max-width: 960px) {
  .stages { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .dataset { grid-template-columns: 1fr; }
}
@media (max-width: 640px) {
  .home-content { padding: 0 16px 64px; }
  .section { margin-top: 56px; }
  h2 { font-size: 24px; }
  .steps, .stages { grid-template-columns: 1fr; }
  .cta { padding: 32px 20px; }
}
</style>
