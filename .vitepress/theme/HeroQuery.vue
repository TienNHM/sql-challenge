<script setup lang="ts">
// Truy vấn và kết quả thật trên DSC Shop (doanh thu theo danh mục, Ngày 10)
const rows = [
  ['Điện thoại', '135.492.500'],
  ['Laptop gaming', '135.151.000'],
  ['Laptop văn phòng', '104.700.500'],
]
</script>

<template>
  <div class="hero-query" aria-label="Ví dụ một truy vấn SQL trên bộ dữ liệu DSC Shop">
    <div class="bar">
      <span class="dot" /><span class="dot" /><span class="dot" />
      <span class="name">sql_challenge=#</span>
    </div>
    <pre class="sql"><code><span class="k">SELECT</span> c.name <span class="k">AS</span> danh_muc,
       <span class="f">SUM</span>(oi.quantity * oi.unit_price
           * (1 - oi.discount)) <span class="k">AS</span> doanh_thu
<span class="k">FROM</span> order_items oi
<span class="k">JOIN</span> orders o     <span class="k">USING</span> (order_id)
<span class="k">JOIN</span> products p   <span class="k">USING</span> (product_id)
<span class="k">JOIN</span> categories c <span class="k">USING</span> (category_id)
<span class="k">WHERE</span> o.status <span class="k">NOT IN</span> (<span class="s">'pending'</span>, <span class="s">'cancelled'</span>)
<span class="k">GROUP BY</span> c.name
<span class="k">ORDER BY</span> doanh_thu <span class="k">DESC</span>
<span class="k">LIMIT</span> 3;</code></pre>
    <table class="result">
      <thead>
        <tr><th>danh_muc</th><th>doanh_thu</th></tr>
      </thead>
      <tbody>
        <tr v-for="r in rows" :key="r[0]"><td>{{ r[0] }}</td><td>{{ r[1] }}</td></tr>
      </tbody>
    </table>
    <div class="meta">(3 rows) · Ngày 10: Kết hợp nhiều bảng với JOIN</div>
  </div>
</template>

<style scoped>
.hero-query {
  width: 100%;
  max-width: 460px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 12px;
  background: var(--vp-c-bg-soft);
  box-shadow: var(--vp-shadow-3);
  overflow: hidden;
  font-family: var(--vp-font-family-mono);
  font-size: 12.5px;
  line-height: 1.6;
  text-align: left;
}
.bar {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 14px;
  border-bottom: 1px solid var(--vp-c-divider);
}
.dot { width: 10px; height: 10px; border-radius: 50%; background: var(--vp-c-default-3); }
.name { margin-left: 8px; color: var(--vp-c-text-3); }
.sql { margin: 0; padding: 14px 16px; overflow-x: auto; color: var(--vp-c-text-1); }
.k { color: var(--vp-c-brand-1); font-weight: 600; }
.f { color: var(--vp-c-text-2); font-weight: 600; }
.s { color: var(--vp-c-warning-1); }
.result {
  display: table;
  width: calc(100% - 32px);
  margin: 0 16px;
  border-collapse: collapse;
  font-size: 12.5px;
}
.result th, .result td {
  border: none;
  border-bottom: 1px solid var(--vp-c-divider);
  padding: 4px 8px;
  background: transparent;
}
.result th { color: var(--vp-c-text-2); font-weight: 500; text-align: left; }
.result td:last-child, .result th:last-child { text-align: right; font-variant-numeric: tabular-nums; }
.meta { padding: 10px 16px 14px; color: var(--vp-c-text-3); }
</style>
