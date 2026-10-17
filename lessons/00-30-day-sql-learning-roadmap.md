# Lộ trình 30 ngày học SQL

> **Tóm tắt:** Trang này là bản đồ của cả khóa: 30 bài chia thành 4 chặng, từ câu `SELECT` đầu tiên đến index, transaction, window function, tối ưu truy vấn và bảo mật, kết thúc bằng một dự án cuối khóa. Cả khóa dùng một hệ quản trị duy nhất là PostgreSQL 16 và một bộ dữ liệu chung là cửa hàng DSC Shop, nên mọi ví dụ đều chạy được trên máy bạn.

**Sau bài này bạn có thể:**

- Biết mỗi ngày học gì, ngày nào phụ thuộc ngày nào.
- Dựng xong môi trường thực hành (PostgreSQL 16 + dữ liệu DSC Shop) trước khi vào Ngày 1.
- Biết cách học một bài: đọc, chạy lại ví dụ, tự làm bài tập rồi mới mở đáp án.

## Khóa học này dùng gì

| Thành phần | Lựa chọn | Vì sao |
| --- | --- | --- |
| Hệ quản trị CSDL | PostgreSQL 16 | Miễn phí, bám sát chuẩn SQL, có đủ mọi thứ khóa học cần: CTE, window function, `FULL JOIN`, `INTERSECT`/`EXCEPT`, JSONB, partition, `EXPLAIN ANALYZE` |
| Dữ liệu | DSC Shop, cửa hàng đồ công nghệ: 7 bảng `categories`, `products`, `customers`, `employees`, `orders`, `order_items`, `payments` | Một bộ dữ liệu cho cả khóa, nên bài sau dùng lại được những gì bài trước đã khám phá |
| Dữ liệu lớn | Schema `perf`: 100.000 khách, 1.000.000 đơn hàng | Dùng cho các bài hiệu năng (Ngày 15, 20, 25, 28) |
| Công cụ | `psql` (dòng lệnh) và Adminer (web), tùy chọn DBeaver/pgAdmin/VS Code | `psql` có sẵn trong mọi bản cài PostgreSQL |

Khi cú pháp PostgreSQL khác hẳn MySQL hoặc SQL Server (ví dụ `LIMIT` và `TOP`, `IDENTITY` và `AUTO_INCREMENT`), bài học có một hộp **Ghi chú dialect** ngắn để bạn không bỡ ngỡ khi gặp hệ khác ngoài đời.

## Chuẩn bị môi trường

Làm phần này trước Ngày 1. Hướng dẫn đầy đủ nằm ở [setup/README.md](../setup/README.md); tóm tắt như sau.

**Cách 1: Docker (khuyến nghị).** Cài [Docker Desktop](https://www.docker.com/products/docker-desktop/), rồi ở thư mục gốc của repo chạy:

```sh
docker compose up -d
```

Bạn có PostgreSQL 16 ở `localhost:5432` (user `postgres`, mật khẩu `postgres`, database `sql_challenge`) đã nạp sẵn dữ liệu DSC Shop, và giao diện web Adminer ở <http://localhost:8080>.

**Cách 2: cài PostgreSQL trực tiếp.** Cài PostgreSQL 16 trở lên từ <https://www.postgresql.org/download/>, tạo database `sql_challenge` rồi nạp hai file `setup/init/01_schema.sql` và `setup/init/02_seed.sql` (lệnh cụ thể ở [setup/README.md](../setup/README.md#cách-2-cài-postgresql-trực-tiếp)).

Kiểm tra nhanh: mở `psql` và chạy

```sh
docker compose exec db psql -U postgres -d sql_challenge
```

```sql
SELECT version();
```

Nếu dòng kết quả bắt đầu bằng `PostgreSQL 16` là xong. Ngày 1 sẽ đi kỹ từng bước và giải thích các công cụ.

Hai việc sẽ cần về sau, chưa phải làm ngay:

- Trước Ngày 15: nạp dữ liệu lớn bằng `setup/perf_seed.sql` (xem mục "Dữ liệu lớn cho các bài hiệu năng" trong [setup/README.md](../setup/README.md#dữ-liệu-lớn-cho-các-bài-hiệu-năng)).
- Bất cứ khi nào lỡ sửa hỏng dữ liệu: chạy lại script init theo mục "Làm lại từ đầu" trong [setup/README.md](../setup/README.md#làm-lại-từ-đầu).

## Cách học mỗi bài

Mọi bài (trừ bài ôn tập và bài đọc) có cùng khung:

1. **Tóm tắt** và **Sau bài này bạn có thể**: đọc để biết đích đến.
2. **Cần biết trước**: các bài phải học xong trước. Học theo thứ tự là đủ.
3. **Phần lý thuyết**: mỗi khái niệm đi từ trực giác, đến cú pháp, đến ví dụ trên DSC Shop, kèm kết quả thật. Hãy gõ lại và chạy từng ví dụ, so với bảng kết quả trong bài.
4. **Lỗi thường gặp**: các bẫy hay gặp, có ví dụ sai và cách sửa.
5. **Bài tập** chia ba mức Cơ bản, Vận dụng, Thử thách. Tự làm trước, sau đó mới bấm "Đáp án".
6. **Tóm tắt** và **Đọc thêm**.

Khoảng 1 đến 2 giờ mỗi ngày là vừa. Không cần học liền 30 ngày; quan trọng là làm hết bài tập và bài ôn tập trước khi sang chặng mới.

## Chặng 1: Nền tảng và truy vấn đơn giản (Ngày 1-7)

| Ngày | Bài | Nội dung chính |
| --- | --- | --- |
| 1 | [Giới thiệu SQL, RDBMS và môi trường thực hành](01-intro-to-sql-and-dbms.md) | SQL, RDBMS, PostgreSQL; dựng môi trường bằng Docker (hoặc cài trực tiếp); `psql` và Adminer; khám phá DSC Shop (`\dt`, `\d customers`, `SELECT` đầu tiên); các nhóm lệnh DDL, DML, DCL, TCL |
| 2 | [Bảng, kiểu dữ liệu và ràng buộc](02-table-structure-and-data-types.md) | Bảng, cột, dòng; kiểu dữ liệu PostgreSQL (`INT`/`BIGINT`, `NUMERIC` và `FLOAT` cho tiền, `VARCHAR`/`TEXT`, `DATE`/`TIMESTAMP`/`TIMESTAMPTZ`, `BOOLEAN`, `JSONB`); `IDENTITY`; ràng buộc `PRIMARY KEY`, `FOREIGN KEY` (`ON DELETE CASCADE`/`SET NULL`/`RESTRICT`), `UNIQUE`, `NOT NULL`, `CHECK`, `DEFAULT`; `ALTER TABLE`, `DROP TABLE`; đọc schema DSC Shop |
| 3 | [SELECT, WHERE và NULL](03-select-where.md) | `SELECT`, cột tính toán, bí danh `AS`, `DISTINCT`; `WHERE` với `=`, `<>`, `>`, `<`, `AND`/`OR`/`NOT`, `IN`, `BETWEEN`, `LIKE`/`ILIKE`; `IS NULL`/`IS NOT NULL`, logic ba trị, vì sao `= NULL` sai; thứ tự thực thi `FROM` → `WHERE` → `SELECT` |
| 4 | [Sắp xếp và giới hạn kết quả](04-order-by-limit.md) | `ORDER BY` nhiều cột, `ASC`/`DESC`, `NULLS FIRST`/`LAST`; `LIMIT`/`OFFSET`, `FETCH FIRST`; phân trang và vấn đề `OFFSET` lớn |
| 5 | [Toán tử, hàm chuỗi, ngày giờ và xử lý NULL](05-operators-expressions.md) | Số học (chia nguyên, `%`), nối chuỗi `\|\|`; `UPPER`, `LOWER`, `TRIM`, `LENGTH`, `SUBSTRING`, `REPLACE`, `CONCAT`; `CURRENT_DATE`, `now()`, `EXTRACT`, `DATE_TRUNC`, `AGE`, `INTERVAL`; `CAST`/`::`, `ROUND`; `COALESCE`, `NULLIF`; làm sạch `customers.city` |
| 6 | [Thêm, sửa, xóa dữ liệu](06-insert-update-delete.md) | `INSERT` (nhiều dòng, `RETURNING`, `INSERT ... SELECT`), `UPDATE` (có điều kiện, `UPDATE ... FROM`), `DELETE`, UPSERT `ON CONFLICT`, `TRUNCATE`; quy trình an toàn: `SELECT` xem trước, chạy trong `BEGIN ... ROLLBACK`/`COMMIT`; lỗi vi phạm ràng buộc |
| 7 | [Ôn tập 1](07-review-1.md) | Bài tập tổng hợp Ngày 1-6 |

## Chặng 2: Tổng hợp và kết hợp dữ liệu (Ngày 8-14)

| Ngày | Bài | Nội dung chính |
| --- | --- | --- |
| 8 | [Hàm tổng hợp](08-aggregate-functions.md) | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`; `COUNT(*)`, `COUNT(cột)` và `COUNT(DISTINCT ...)`; NULL trong hàm tổng hợp; tính tổng tiền đơn từ `order_items` |
| 9 | [GROUP BY và HAVING](09-group-by-having.md) | Nhóm theo một và nhiều cột, `HAVING` khác `WHERE`, thứ tự thực thi logic đầy đủ; `ROLLUP` nhắc qua |
| 10 | [JOIN](10-join.md) | `INNER`/`LEFT`/`RIGHT`/`FULL`/`CROSS JOIN`, SELF JOIN (`employees`), JOIN 3-4 bảng, alias bảng, điều kiện ở `ON` và ở `WHERE` với `LEFT JOIN`, anti-join, nhân dòng khi JOIN rồi `SUM` |
| 11 | [Truy vấn con và CTE](11-subquery.md) | Subquery vô hướng, `IN`, `EXISTS`/`NOT EXISTS`, bẫy `NOT IN` với NULL, subquery tương quan, subquery trong `FROM`, CTE `WITH` (không đệ quy) |
| 12 | [Toán tử tập hợp](12-union-intersect.md) | `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT` (và bản `ALL`), quy tắc số cột và kiểu, `ORDER BY` ở cuối |
| 13 | [CASE và tổng hợp có điều kiện](13-case-when.md) | `CASE` simple/searched, `CASE` trong `SELECT`/`ORDER BY`/`UPDATE`, `SUM(CASE ...)`, `FILTER (WHERE ...)`, pivot đơn giản |
| 14 | [Ôn tập 2](14-review-2.md) | Bài tập tổng hợp Ngày 8-13 (chưa dùng window function) |

## Chặng 3: Index, transaction và các đối tượng database (Ngày 15-21)

| Ngày | Bài | Nội dung chính |
| --- | --- | --- |
| 15 | [Chỉ mục (index)](15-index.md) | B-tree, đo trước/sau trên schema `perf`, index nhiều cột và quy tắc tiền tố trái, `UNIQUE` index, partial index, expression index, selectivity, chi phí ghi, index cho khóa ngoại |
| 16 | [Transaction và ACID](16-transactions-acid.md) | ACID, `BEGIN`/`COMMIT`/`ROLLBACK`, `SAVEPOINT`, autocommit; isolation level và các hiện tượng (dirty/non-repeatable/phantom read, lost update) có demo hai phiên `psql`; `SELECT ... FOR UPDATE`; deadlock; chuyển tiền an toàn |
| 17 | [Function và procedure](17-stored-procedures-functions.md) | Function và procedure bằng SQL và PL/pgSQL, tham số, `RETURNS TABLE`, `CALL`, xử lý lỗi (`RAISE`, `EXCEPTION`), transaction trong procedure |
| 18 | [Trigger](18-triggers.md) | Trigger PL/pgSQL: `BEFORE`/`AFTER`, `ROW`/`STATEMENT`, `NEW`/`OLD`; trừ tồn kho, audit log, chặn dữ liệu sai; khi nào không nên dùng trigger |
| 19 | [View](19-views.md) | View, view cập nhật được và giới hạn, `WITH CHECK OPTION`, materialized view và `REFRESH`, dùng view để giới hạn những gì người khác được xem |
| 20 | [Đọc kế hoạch thực thi](20-query-performance.md) | `EXPLAIN`, `EXPLAIN ANALYZE`, `BUFFERS`: cost, số dòng ước lượng và thực tế, Seq/Index/Index Only/Bitmap Scan, Nested Loop/Hash/Merge Join, Sort; `ANALYZE` và thống kê; số liệu đo thật trên `perf` |
| 21 | [Ôn tập 3](21-review-3.md) | Bài tập tổng hợp Ngày 15-20 |

## Chặng 4: SQL trong thực tế (Ngày 22-30)

| Ngày | Bài | Nội dung chính |
| --- | --- | --- |
| 22 | [JSON và JSONB](22-sql-json-practice.md) | `->`, `->>`, `@>`, `?`, `jsonb_array_elements`, `jsonb_set`, GIN index; khi nào dùng JSONB, khi nào tách bảng (`products.attributes`) |
| 23 | [Kết nối từ ứng dụng](23-sql-connect-apps.md) | Python (psycopg 3) và Node.js (pg); truy vấn tham số hóa và vì sao chặn được SQL injection; connection pool; transaction từ code; xử lý lỗi; ORM và vấn đề N+1 |
| 24 | [Import và export dữ liệu](24-import-export-data.md) | `COPY` và `\copy`, CSV (header, delimiter, encoding), xử lý dòng lỗi qua bảng staging, xuất kết quả truy vấn; file mẫu trong `setup/data` |
| 25 | [SQL và dữ liệu lớn](25-big-data.md) | Partition `RANGE`/`LIST`/`HASH`, partition pruning; replication, sharding, kho dữ liệu dạng cột ở mức tổng quan |
| 26 | [SQL và NoSQL](26-sql-nosql.md) | So sánh mô hình dữ liệu, khi nào chọn gì (bài đọc) |
| 27 | [Thiết kế cơ sở dữ liệu](27-database-design-best-practices.md) | ERD, quan hệ 1-1/1-n/n-n và bảng trung gian, phụ thuộc hàm, chuẩn hóa 1NF/2NF/3NF/BCNF, khi nào phi chuẩn hóa; vì sao DSC Shop được thiết kế như vậy |
| 28 | [Tối ưu truy vấn](28-sql-query-optimization.md) | Sargability, viết lại truy vấn, `EXISTS`/`IN`/`JOIN`, phân trang keyset, tránh `SELECT *`, N+1, đo bằng `EXPLAIN ANALYZE` trên `perf` |
| 29 | [Window function và truy vấn đệ quy](29-recursive-queries-window-functions.md) | `ROW_NUMBER`/`RANK`/`DENSE_RANK`/`NTILE`, `SUM`/`AVG OVER`, `PARTITION BY`, frame `ROWS`/`RANGE`, `LAG`/`LEAD`, top-N mỗi nhóm; CTE đệ quy trên cây `categories` và `employees`, chống vòng lặp |
| 30 | [Bảo mật và sao lưu](30-database-security.md) | Role/user, `GRANT`/`REVOKE`, quyền tối thiểu, row-level security nhắc qua, demo SQL injection trong code, lưu mật khẩu bằng hash, sao lưu `pg_dump`/`pg_restore` |
| 🎯 | [Tổng kết và dự án cuối khóa](99-summary.md) | Đề dự án có rubric: ERD, schema 3NF có ràng buộc, seed, 15-20 truy vấn báo cáo, transaction, view, function/trigger, `EXPLAIN` trước/sau index, API nhỏ dùng truy vấn tham số hóa, backup; lộ trình học tiếp |

## Các chủ đề xuyên suốt

Vài chủ đề không nằm gọn trong một ngày mà được học dần:

| Chủ đề | Học ở |
| --- | --- |
| NULL | Ngày 2 (`NOT NULL`), Ngày 3 (`IS NULL`, logic ba trị), Ngày 5 (`COALESCE`, `NULLIF`), Ngày 8 (NULL trong hàm tổng hợp), Ngày 10 (`LEFT JOIN` sinh NULL), Ngày 11 (bẫy `NOT IN`) |
| Thứ tự thực thi logic của câu `SELECT` | Ngày 3 (`FROM` → `WHERE` → `SELECT`), Ngày 4 (`ORDER BY`, `LIMIT`), Ngày 9 (đầy đủ với `GROUP BY`, `HAVING`) |
| Hiệu năng | Ngày 15 (index) → Ngày 20 (đọc plan) → Ngày 28 (tối ưu), cùng đo trên schema `perf` |
| Ràng buộc và thiết kế | Ngày 2 (ràng buộc) → Ngày 18 (trigger) → Ngày 27 (chuẩn hóa) → dự án cuối khóa |
| An toàn dữ liệu | Ngày 6 (`BEGIN ... ROLLBACK`) → Ngày 16 (transaction) → Ngày 23 (truy vấn tham số hóa) → Ngày 30 (quyền, injection, backup) |

## Tóm tắt

- 30 bài, 4 chặng, 3 bài ôn tập (Ngày 7, 14, 21) và một dự án cuối khóa.
- Chỉ dùng PostgreSQL 16 và bộ dữ liệu DSC Shop; khác biệt với MySQL/SQL Server được ghi trong hộp "Ghi chú dialect".
- Dựng môi trường trước Ngày 1 theo [setup/README.md](../setup/README.md); Docker là cách nhanh nhất.
- Mỗi bài: chạy lại ví dụ, tự làm bài tập rồi mới xem đáp án.

## Đọc thêm

- [setup/README.md](../setup/README.md): cài đặt, sơ đồ dữ liệu DSC Shop và các điểm "chưa sạch" cố ý trong dữ liệu.
- [Tài liệu chính thức PostgreSQL 16](https://www.postgresql.org/docs/16/index.html), đặc biệt phần [Tutorial](https://www.postgresql.org/docs/16/tutorial.html).

---

[📚 Mục lục](../README.md) | [Ngày 1: Giới thiệu SQL, RDBMS và môi trường thực hành ➡️](01-intro-to-sql-and-dbms.md)
