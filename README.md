# 30 Days SQL Challenge

Lộ trình học SQL trong 30 ngày, mỗi ngày một bài, từ `SELECT` cơ bản đến index, transaction, window function, tối ưu truy vấn và bảo mật database. Có ba bài ôn tập giữa chặng và một dự án cuối khóa.

Cả khóa dùng **PostgreSQL 16** và một bộ dữ liệu chung, cửa hàng đồ công nghệ **DSC Shop**: mọi ví dụ và bài tập đều chạy được, kết quả in trong bài là kết quả thật.

👉 Bắt đầu tại [Lộ trình học SQL](lessons/00-30-day-sql-learning-roadmap.md), hoặc đọc trên website: <https://tiennhm.io.vn/sql-challenge/>.

## Chuẩn bị môi trường

Cần [Docker Desktop](https://www.docker.com/products/docker-desktop/). Ở thư mục gốc của repo:

```sh
docker compose up -d
```

Sau vài giây bạn có PostgreSQL ở `localhost:5432` (user `postgres`, mật khẩu `postgres`, database `sql_challenge`) đã nạp sẵn dữ liệu, và giao diện web Adminer ở <http://localhost:8080>. Cách cài không cần Docker, sơ đồ dữ liệu và cách làm lại từ đầu: xem [setup/README.md](setup/README.md).

## Cách học

- Học theo thứ tự, mỗi ngày một bài. Mỗi bài ghi rõ cần biết trước những bài nào, cuối bài có liên kết sang bài trước/sau.
- Gõ lại và chạy từng ví dụ, so kết quả với bảng trong bài.
- Tự làm bài tập trước khi mở đáp án (bấm "Đáp án" để xem).
- Làm hết bài ôn tập (ngày 7, 14, 21) trước khi sang chặng tiếp theo.

## Mục lục

### Chặng 1: Nền tảng và truy vấn đơn giản

| Ngày | Bài học |
| --- | --- |
| 0 | [Lộ trình 30 ngày học SQL](lessons/00-30-day-sql-learning-roadmap.md) |
| 1 | [Giới thiệu SQL, RDBMS và môi trường thực hành](lessons/01-intro-to-sql-and-dbms.md) |
| 2 | [Bảng, kiểu dữ liệu và ràng buộc](lessons/02-table-structure-and-data-types.md) |
| 3 | [SELECT và WHERE, truy vấn và lọc dữ liệu](lessons/03-select-where.md) |
| 4 | [ORDER BY và LIMIT, sắp xếp và phân trang](lessons/04-order-by-limit.md) |
| 5 | [Toán tử, biểu thức và hàm thường dùng](lessons/05-operators-expressions.md) |
| 6 | [Thêm, sửa, xóa dữ liệu (INSERT, UPDATE, DELETE)](lessons/06-insert-update-delete.md) |
| 7 | [Ôn tập 1 (Ngày 1 đến 6)](lessons/07-review-1.md) |

### Chặng 2: Tổng hợp và kết hợp dữ liệu

| Ngày | Bài học |
| --- | --- |
| 8 | [Hàm tổng hợp (COUNT, SUM, AVG, MIN, MAX)](lessons/08-aggregate-functions.md) |
| 9 | [Nhóm dữ liệu với GROUP BY và HAVING](lessons/09-group-by-having.md) |
| 10 | [Kết hợp nhiều bảng với JOIN](lessons/10-join.md) |
| 11 | [Truy vấn con (subquery) và CTE](lessons/11-subquery.md) |
| 12 | [UNION, INTERSECT và EXCEPT](lessons/12-union-intersect.md) |
| 13 | [CASE và tổng hợp có điều kiện](lessons/13-case-when.md) |
| 14 | [Ôn tập 2 - Báo cáo trên DSC Shop](lessons/14-review-2.md) |

### Chặng 3: Index, transaction và các đối tượng database

| Ngày | Bài học |
| --- | --- |
| 15 | [Chỉ mục (index)](lessons/15-index.md) |
| 16 | [Transaction và ACID](lessons/16-transactions-acid.md) |
| 17 | [Function và Stored Procedure](lessons/17-stored-procedures-functions.md) |
| 18 | [Trigger](lessons/18-triggers.md) |
| 19 | [View và materialized view](lessons/19-views.md) |
| 20 | [Đọc kế hoạch thực thi với EXPLAIN](lessons/20-query-performance.md) |
| 21 | [Ôn tập 3 (Ngày 15-20)](lessons/21-review-3.md) |

### Chặng 4: SQL trong thực tế

| Ngày | Bài học |
| --- | --- |
| 22 | [Làm việc với JSON và JSONB](lessons/22-sql-json-practice.md) |
| 23 | [Kết nối SQL từ ứng dụng](lessons/23-sql-connect-apps.md) |
| 24 | [Nhập và xuất dữ liệu với CSV](lessons/24-import-export-data.md) |
| 25 | [SQL và dữ liệu lớn](lessons/25-big-data.md) |
| 26 | [SQL và NoSQL](lessons/26-sql-nosql.md) |
| 27 | [Thiết kế cơ sở dữ liệu](lessons/27-database-design-best-practices.md) |
| 28 | [Tối ưu truy vấn](lessons/28-sql-query-optimization.md) |
| 29 | [Window function và truy vấn đệ quy](lessons/29-recursive-queries-window-functions.md) |
| 30 | [Bảo mật cơ sở dữ liệu](lessons/30-database-security.md) |
| 🎯 | [Tổng kết và dự án cuối khóa](lessons/99-summary.md) |

## Cấu trúc repo

```text
lessons/            bài học, ảnh sơ đồ ở lessons/img/
diagrams/           file HTML nguồn của các sơ đồ (bản sáng và bản tối)
setup/init/         schema và dữ liệu mẫu, tự nạp khi chạy docker compose
setup/perf_seed.sql dữ liệu lớn cho các bài hiệu năng
setup/data/         file CSV cho bài import/export
scripts/            script xuất sơ đồ HTML ra PNG
review/             báo cáo review nội dung khóa học
```

## Website

Repo được dựng thành website bằng [VitePress](https://vitepress.dev/). Mỗi lần push lên `main`, GitHub Actions ([deploy-pages.yml](.github/workflows/deploy-pages.yml)) tự build và publish lên GitHub Pages.

Chạy thử trên máy (cần Node.js 20 trở lên):

```sh
npm install
npm run docs:dev      # http://localhost:5173, tự tải lại khi sửa bài
npm run docs:build    # build ra .vitepress/dist
```

Trang chủ là [index.md](index.md), phần giao diện riêng nằm trong [.vitepress/theme/](.vitepress/theme/). Sidebar tự sinh từ tiêu đề `# ...` của các bài trong `lessons/`.

## Sửa sơ đồ

Sơ đồ chính của mỗi bài được vẽ bằng HTML/SVG trong `diagrams/`, rồi xuất ra PNG (bản sáng và tối) để nhúng vào bài:

```sh
pip install playwright && python -m playwright install chromium   # một lần
python scripts/export-diagram.py diagrams/join/cac-loai-join.html lessons/img/cac-loai-join.png
```

Sơ đồ nhỏ, đi kèm một đoạn thì viết thẳng bằng Mermaid trong bài; GitHub tự hiển thị.

## Nguồn

Nội dung được chuyển từ series [Học SQL trong 30 ngày](https://tiennhm.io.vn/docs/database/learn-sql-in-30-days) của [TienNHM](https://github.com/TienNHM).

## Giấy phép

Toàn bộ repo, gồm cả nội dung bài học và hình ảnh trong `lessons/`, được phát hành theo giấy phép [MIT](LICENSE).
