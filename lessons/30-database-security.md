# Ngày 30: Bảo mật cơ sở dữ liệu

> **Tóm tắt:** Một database an toàn phải trả lời được ba câu hỏi: ai được vào, vào rồi được làm gì, và nếu có chuyện thì dữ liệu có bị lộ hoặc mất không. Bài này dùng DSC Shop để tạo role và phân quyền tối thiểu bằng GRANT/REVOKE, xem SQL injection xảy ra thế nào trong code và cách chặn, lưu mật khẩu bằng hash thay vì dạng rõ, và sao lưu, khôi phục bằng pg_dump/pg_restore.

**Sau bài này bạn có thể:**

- Tạo role đăng nhập và role nhóm, cấp và thu hồi quyền ở từng tầng: database, schema, bảng, cột.
- Thiết kế bộ quyền tối thiểu cho một ứng dụng và cho người làm báo cáo, rồi tự kiểm chứng quyền bằng `SET ROLE`.
- Chỉ ra vì sao code nối chuỗi bị SQL injection và sửa bằng truy vấn tham số hóa.
- Lưu và kiểm tra mật khẩu bằng hash có salt (bcrypt), không bao giờ so sánh mật khẩu dạng rõ.
- Sao lưu schema `shop` bằng `pg_dump`, khôi phục vào một database mới bằng `pg_restore` và kiểm tra lại.

**Cần biết trước:** [Ngày 19](19-views.md) (view), [Ngày 17](17-stored-procedures-functions.md) (PL/pgSQL), [Ngày 23](23-sql-connect-apps.md) (kết nối từ ứng dụng, truy vấn tham số hóa).

Bài này tạo role (cấp cluster, dùng chung cho mọi database trên server) và sửa quyền của database `sql_challenge`. Cuối bài có mục dọn dẹp. Muốn đưa dữ liệu `shop` về như cũ, chạy lại hai file init (mục "Làm lại từ đầu" trong [setup/README.md](../setup/README.md)).

## Role: user và nhóm quyền

PostgreSQL chỉ có một khái niệm là role. Role có thuộc tính `LOGIN` thì dùng để đăng nhập (thường gọi là user). Role không có `LOGIN` dùng làm nhóm quyền: cấp quyền cho nhóm, rồi cho user làm thành viên của nhóm. Khi có người mới hoặc người nghỉ, bạn chỉ thêm/bớt thành viên chứ không phải cấp lại từng quyền.

Role thuộc về cả cluster (cả server PostgreSQL), không thuộc riêng database nào. Còn quyền trên bảng thì gắn với từng database.

```sql
-- Nhóm quyền chỉ đọc, không đăng nhập được
CREATE ROLE shop_readonly NOLOGIN;

-- User đăng nhập, là thành viên của nhóm
CREATE ROLE report_user LOGIN PASSWORD 'Bao-cao#2026';
GRANT shop_readonly TO report_user;
```

`CREATE USER ten ...` là cách viết tắt của `CREATE ROLE ten LOGIN ...`. Xem danh sách role bằng lệnh psql `\du`:

```sql
\du report_user|shop_readonly
```

```text
          List of roles
   Role name   |  Attributes
---------------+--------------
 report_user   |
 shop_readonly | Cannot login
```

Mật khẩu trong `CREATE ROLE` được PostgreSQL lưu dạng hash SCRAM-SHA-256, không lưu dạng rõ.

> **Ghi chú dialect:** MySQL định danh user theo cặp `'ten'@'host'` (`CREATE USER 'report_user'@'%' IDENTIFIED BY '...'`), và role được GRANT cho user chưa tự có hiệu lực khi đăng nhập: phải chạy thêm `SET DEFAULT ROLE ... TO ...`. SQL Server tách hai cấp: `CREATE LOGIN` ở cấp server, rồi `CREATE USER ... FOR LOGIN ...` trong từng database, và thêm vào role bằng `ALTER ROLE ten_role ADD MEMBER ten_user`.

## GRANT và REVOKE theo từng tầng

Để đọc được một bảng, role cần quyền ở cả ba tầng:

| Tầng | Quyền | Câu lệnh |
| --- | --- | --- |
| Database | `CONNECT`: được kết nối | `GRANT CONNECT ON DATABASE sql_challenge TO ...` |
| Schema | `USAGE`: được "nhìn thấy" đối tượng trong schema | `GRANT USAGE ON SCHEMA shop TO ...` |
| Bảng / cột | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`... | `GRANT SELECT ON products TO ...` |

Superuser có thể "đóng vai" một role khác bằng `SET ROLE` để thử quyền mà không cần đăng nhập lại. `RESET ROLE` để quay về. Thử với `report_user` vừa tạo:

```sql
SET ROLE report_user;
SELECT count(*) FROM products;
RESET ROLE;
```

```text
ERROR:  relation "products" does not exist
LINE 1: SELECT count(*) FROM products;
                             ^
```

Bảng vẫn còn đó. Nhưng `report_user` chưa có quyền `USAGE` trên schema `shop`, nên với nó schema này như không tồn tại, `search_path` bỏ qua `shop`. Cấp quyền schema cho nhóm:

```sql
GRANT USAGE ON SCHEMA shop TO shop_readonly;

SET ROLE report_user;
SELECT count(*) FROM products;
RESET ROLE;
```

```text
ERROR:  permission denied for table products
```

Đã thấy bảng, nhưng chưa được đọc. Cấp `SELECT` trên những bảng người làm báo cáo cần. Bảng `customers` (có email, số điện thoại) và `employees` (có lương) cố ý không cấp:

```sql
GRANT SELECT ON categories, products, orders, order_items TO shop_readonly;

SET ROLE report_user;
SELECT category_id, count(*) AS so_san_pham
FROM products
GROUP BY category_id
ORDER BY so_san_pham DESC, category_id
LIMIT 3;
RESET ROLE;
```

| category_id | so_san_pham |
| --- | --- |
| 7 | 4 |
| 10 | 4 |
| 3 | 3 |

```sql
SET ROLE report_user;
UPDATE products SET price = 0 WHERE product_id = 1;
RESET ROLE;
```

```text
ERROR:  permission denied for table products
```

```sql
SET ROLE report_user;
SELECT full_name FROM customers LIMIT 1;
RESET ROLE;
```

```text
ERROR:  permission denied for table customers
```

`report_user` có quyền vì là thành viên của `shop_readonly` (thành viên thừa hưởng quyền của nhóm).

### Quyền mặc định của PUBLIC

`PUBLIC` là nhóm ngầm chứa mọi role. Mặc định PostgreSQL cấp cho `PUBLIC` quyền `CONNECT` vào mọi database mới tạo. Nghĩa là bất kỳ user nào cũng kết nối được tới `sql_challenge` (dù vào rồi chưa đọc được bảng nào). Theo nguyên tắc quyền tối thiểu, hãy thu hồi và chỉ cấp cho ai cần:

```sql
REVOKE CONNECT ON DATABASE sql_challenge FROM PUBLIC;
GRANT CONNECT ON DATABASE sql_challenge TO shop_readonly;
```

Từ PostgreSQL 15, `PUBLIC` không còn được tạo bảng trong schema `public` nữa. Bản cũ hơn thì nên chạy thêm `REVOKE CREATE ON SCHEMA public FROM PUBLIC;`.

### Thử đăng nhập thật

`SET ROLE` chỉ giả lập. Muốn đăng nhập thật bằng mật khẩu từ trong container, kết nối qua tên host `db` (kết nối qua `localhost` bên trong container được cấu hình tin cậy, không hỏi mật khẩu):

```sh
docker compose exec db psql -h db -U report_user -d sql_challenge
```

Từ máy bạn (Python, DBeaver...), dùng connection string `postgresql://report_user:Bao-cao%232026@localhost:5432/sql_challenge`. Ký tự `#` trong mật khẩu phải viết thành `%23` trong URL.

## Quyền tối thiểu cho ứng dụng

Ở [Ngày 23](23-sql-connect-apps.md) code kết nối bằng `postgres`, một superuser. Nếu ứng dụng bị khai thác (injection, lộ mật khẩu trong file cấu hình), kẻ tấn công có toàn quyền: xóa bảng, đọc lương nhân viên, thậm chí chạy lệnh hệ điều hành qua `COPY ... PROGRAM`. Ứng dụng thật phải dùng user riêng, chỉ có đúng quyền nghiệp vụ cần.

Ứng dụng bán hàng của DSC Shop cần: đọc danh mục, sản phẩm, khách, đơn; tạo khách, đơn, dòng hàng, thanh toán; trừ tồn kho; đổi trạng thái đơn. Không cần xóa gì, không cần đọc `employees`, không cần đổi giá:

```sql
CREATE ROLE app_user LOGIN PASSWORD 'App-DSC#2026' CONNECTION LIMIT 20;
GRANT CONNECT ON DATABASE sql_challenge TO app_user;
GRANT USAGE ON SCHEMA shop TO app_user;
GRANT SELECT ON categories, products, customers, orders, order_items, payments TO app_user;
GRANT INSERT ON customers, orders, order_items, payments TO app_user;
GRANT UPDATE (stock_quantity) ON products TO app_user;   -- chỉ cột tồn kho
GRANT UPDATE (status) ON orders TO app_user;             -- chỉ cột trạng thái
```

`GRANT UPDATE (cot) ON bang` là quyền ở mức cột. Không cần cấp quyền trên sequence: cột `GENERATED ALWAYS AS IDENTITY` tự sinh giá trị khi INSERT. `CONNECTION LIMIT 20` chặn ứng dụng lỡ mở quá nhiều kết nối.

Kiểm chứng (bọc trong `BEGIN ... ROLLBACK` để không để lại dữ liệu):

```sql
BEGIN;
SET ROLE app_user;
INSERT INTO orders (customer_id, order_date, channel) VALUES (16, now(), 'online') RETURNING order_id;
UPDATE products SET stock_quantity = stock_quantity - 1 WHERE product_id = 16 RETURNING stock_quantity;
ROLLBACK;
```

| order_id |
| --- |
| 41 |

| stock_quantity |
| --- |
| 59 |

Những việc ứng dụng không được làm (mỗi lệnh chạy riêng trong `BEGIN; SET ROLE app_user; ...; ROLLBACK;`):

| Lệnh | Kết quả |
| --- | --- |
| `UPDATE products SET price = 1 WHERE product_id = 16;` | `ERROR: permission denied for table products` |
| `DELETE FROM orders WHERE order_id = 1;` | `ERROR: permission denied for table orders` |
| `TRUNCATE order_items;` | `ERROR: permission denied for table order_items` |
| `DROP TABLE payments;` | `ERROR: must be owner of table payments` |
| `CREATE TABLE shop.hack (id int);` | `ERROR: permission denied for schema shop` |
| `SELECT * FROM employees;` | `ERROR: permission denied for table employees` |

Hủy đơn trong ứng dụng là đổi `status` thành `cancelled`, không phải xóa dòng. Thiết kế "không xóa, chỉ đánh dấu" như vậy vừa giữ lịch sử vừa cho phép bỏ hẳn quyền `DELETE`.

`GRANT ... ON` chỉ áp dụng cho bảng **đang có**. Bảng tạo sau sẽ không tự có quyền. Muốn mọi bảng mới trong `shop` tự cấp `SELECT` cho nhóm chỉ đọc:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA shop GRANT SELECT ON TABLES TO shop_readonly;
```

Lệnh này áp dụng cho bảng do chính role chạy lệnh (ở đây là `postgres`) tạo ra sau này.

## Chỉ cho xem một số cột

Nhân viên chăm sóc khách hàng cần gọi điện cho khách, nhưng không cần email hay ngày sinh. Có hai cách: quyền mức cột, hoặc một view chỉ chứa các cột được phép (Ngày 19) rồi cấp quyền trên view.

```sql
CREATE ROLE support_staff NOLOGIN;
GRANT USAGE ON SCHEMA shop TO support_staff;
GRANT SELECT (customer_id, full_name, phone) ON customers TO support_staff;

SET ROLE support_staff;
SELECT customer_id, full_name, phone FROM customers WHERE customer_id <= 3 ORDER BY customer_id;
RESET ROLE;
```

| customer_id | full_name | phone |
| --- | --- | --- |
| 1 | Nguyễn Văn An | 0901234567 |
| 2 | Trần Thị Bình | 0912345678 |
| 3 | Lê Hoàng Cường | NULL |

`SELECT *` thì bị chặn, vì `*` gồm cả cột không được phép:

```sql
SET ROLE support_staff;
SELECT * FROM customers LIMIT 1;
RESET ROLE;
```

```text
ERROR:  permission denied for table customers
```

## Kiểm tra ai có quyền gì

```sql
SELECT has_table_privilege('report_user', 'shop.orders', 'SELECT')              AS doc_orders,
       has_table_privilege('report_user', 'shop.orders', 'DELETE')              AS xoa_orders,
       has_column_privilege('support_staff', 'shop.customers', 'email', 'SELECT') AS xem_email;
```

| doc_orders | xoa_orders | xem_email |
| --- | --- | --- |
| t | f | f |

Liệt kê quyền mức bảng của các role:

```sql
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS quyen
FROM information_schema.role_table_grants
WHERE grantee IN ('app_user', 'shop_readonly')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;
```

| grantee | table_name | quyen |
| --- | --- | --- |
| app_user | categories | SELECT |
| app_user | customers | INSERT, SELECT |
| app_user | order_items | INSERT, SELECT |
| app_user | orders | INSERT, SELECT |
| app_user | payments | INSERT, SELECT |
| app_user | products | SELECT |
| shop_readonly | categories | SELECT |
| shop_readonly | order_items | SELECT |
| shop_readonly | orders | SELECT |
| shop_readonly | products | SELECT |

View này chỉ hiện quyền cấp cho cả bảng. Quyền mức cột (như `UPDATE (stock_quantity)`) xem trong `information_schema.column_privileges` hoặc bằng lệnh psql `\dp ten_bang`.

## Row-level security (nhắc qua)

GRANT quyết định được đọc bảng nào, cột nào. Row-level security (RLS) quyết định được thấy **dòng** nào. Ví dụ: nhân viên bán hàng chỉ xem được đơn offline do chính mình bán. Ứng dụng đặt mã nhân viên vào một biến của phiên (`app.employee_id`), policy so sánh với cột `employee_id`:

```sql
CREATE ROLE sales_staff NOLOGIN;
GRANT USAGE ON SCHEMA shop TO sales_staff;
GRANT SELECT ON orders TO sales_staff;

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY sales_own_orders ON orders
    FOR SELECT
    TO sales_staff
    USING (employee_id = NULLIF(current_setting('app.employee_id', true), '')::int);

SET ROLE sales_staff;
SET app.employee_id = '6';
SELECT order_id, customer_id, order_date::date AS ngay, status FROM orders ORDER BY order_id;
RESET ROLE;
```

| order_id | customer_id | ngay | status |
| --- | --- | --- | --- |
| 11 | 9 | 2025-06-15 | delivered |
| 19 | 6 | 2025-09-06 | delivered |
| 27 | 10 | 2026-01-20 | delivered |
| 36 | 18 | 2026-08-08 | delivered |

Cùng câu `SELECT ... FROM orders` nhưng `sales_staff` chỉ thấy 4 đơn của nhân viên 6. Không đặt `app.employee_id` thì điều kiện thành NULL và không thấy đơn nào. Chủ bảng và superuser mặc định không bị RLS giới hạn. Gỡ RLS để không ảnh hưởng các bài khác:

```sql
DROP POLICY sales_own_orders ON orders;
ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
```

RLS thường dùng cho ứng dụng nhiều khách hàng (multi-tenant) chung một bảng. Tìm hiểu thêm ở mục Đọc thêm.

## SQL injection

SQL injection xảy ra khi ứng dụng ghép dữ liệu người dùng vào câu SQL, khiến dữ liệu đó trở thành một phần câu lệnh. Đây vẫn là một trong những lỗ hổng web phổ biến và nguy hiểm nhất.

### Demo trong code

Trang "Tra cứu đơn hàng theo email" viết bằng Python, phiên bản có lỗi:

```python
import os
import psycopg

def find_orders_unsafe(conn, email):
    # SAI: ghép thẳng dữ liệu người dùng vào câu SQL
    sql = (
        "SELECT o.order_id, o.order_date::date AS ngay, o.status "
        "FROM orders o JOIN customers c ON c.customer_id = o.customer_id "
        f"WHERE c.email = '{email}' ORDER BY o.order_id"
    )
    return conn.execute(sql).fetchall()

def find_orders_safe(conn, email):
    return conn.execute(
        """
        SELECT o.order_id, o.order_date::date AS ngay, o.status
        FROM orders o JOIN customers c ON c.customer_id = o.customer_id
        WHERE c.email = %s
        ORDER BY o.order_id
        """,
        (email,),
    ).fetchall()

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    print(len(find_orders_unsafe(conn, "binh.tran@gmail.com")))   # 4 đơn của chị Bình
    print(len(find_orders_unsafe(conn, "' OR '1'='1")))           # 40: lộ toàn bộ đơn
    print(len(find_orders_safe(conn, "' OR '1'='1")))             # 0
```

```text
4
40
0
```

**Tấn công 1: lấy mọi dòng.** Người dùng gõ `' OR '1'='1`. Câu SQL thật sự gửi tới PostgreSQL là:

```sql
SELECT o.order_id, o.order_date::date AS ngay, o.status FROM orders o JOIN customers c ON c.customer_id = o.customer_id WHERE c.email = '' OR '1'='1' ORDER BY o.order_id;
```

Dấu `'` đầu tiên của input đóng chuỗi email, phần còn lại thành code. Điều kiện `c.email = '' OR '1'='1'` luôn đúng nên trả về cả 40 đơn (3 dòng đầu):

| order_id | ngay | status |
| --- | --- | --- |
| 1 | 2025-01-12 | delivered |
| 2 | 2025-01-20 | delivered |
| 3 | 2025-02-03 | delivered |

(... tổng 40 dòng)

Nếu câu có thêm điều kiện `AND`, kẻ tấn công vẫn thắng vì `AND` được tính trước `OR`: `WHERE a = 'x' AND b = 'y' OR '1'='1'` nghĩa là `(a = 'x' AND b = 'y') OR TRUE`, vẫn luôn đúng.

**Tấn công 2: đọc bảng khác.** Kẻ tấn công thấy trang hiện 3 cột (số, ngày, chữ), bèn gõ:

```text
' UNION SELECT employee_id, hire_date, full_name || ': ' || salary FROM employees ORDER BY 1 --
```

Câu SQL thành (`--` biến phần còn lại thành chú thích):

```sql
SELECT o.order_id, o.order_date::date AS ngay, o.status FROM orders o JOIN customers c ON c.customer_id = o.customer_id WHERE c.email = '' UNION SELECT employee_id, hire_date, full_name || ': ' || salary FROM employees ORDER BY 1 --' ORDER BY o.order_id
;
```

| order_id | ngay | status |
| --- | --- | --- |
| 1 | 2020-01-15 | Nguyễn Thành Long: 45000000 |
| 2 | 2021-03-01 | Lê Thị Hạnh: 28000000 |
| 3 | 2021-06-15 | Trần Quốc Bảo: 27000000 |
| 4 | 2022-02-10 | Phạm Thị Thu: 12000000 |
| 5 | 2023-07-01 | Đỗ Minh Tuấn: 11000000 |
| 6 | 2024-09-01 | Vũ Hoài Nam: 10000000 |
| 7 | 2022-11-20 | Lâm Gia Huy: 13000000 |
| 8 | 2026-06-01 | Kiều Anh Thư: 5000000 |

Lương của toàn bộ nhân viên hiện lên trang tra cứu đơn hàng. Nếu ứng dụng kết nối bằng `app_user` ở trên (không có quyền đọc `employees`), tấn công này chỉ nhận về lỗi `permission denied`: quyền tối thiểu là lớp phòng thủ thứ hai, giới hạn thiệt hại khi lớp thứ nhất bị thủng.

### Vì sao tham số hóa chặn được

![Hai cách xử lý cùng input ' OR '1'='1 nhập vào ô email. Cách 1, nối chuỗi: ứng dụng dán input vào câu SQL, PostgreSQL nhận được WHERE c.email = '' OR '1'='1', hiểu OR '1'='1' là điều kiện luôn đúng và trả về 40 trên 40 đơn của mọi khách. Cách 2, truy vấn tham số hóa: ứng dụng gửi câu SQL có $1 và giá trị riêng, PostgreSQL phân tích và chốt cấu trúc câu lệnh trước, $1 chỉ là một ô giá trị, sau đó điền chuỗi ' OR '1'='1 vào như dữ liệu thường, kết quả 0 dòng vì không có email đó.](img/sql-injection-va-tham-so-hoa.png#gh-light-mode-only)
![Hai cách xử lý cùng input ' OR '1'='1 nhập vào ô email. Cách 1, nối chuỗi: ứng dụng dán input vào câu SQL, PostgreSQL nhận được WHERE c.email = '' OR '1'='1', hiểu OR '1'='1' là điều kiện luôn đúng và trả về 40 trên 40 đơn của mọi khách. Cách 2, truy vấn tham số hóa: ứng dụng gửi câu SQL có $1 và giá trị riêng, PostgreSQL phân tích và chốt cấu trúc câu lệnh trước, $1 chỉ là một ô giá trị, sau đó điền chuỗi ' OR '1'='1 vào như dữ liệu thường, kết quả 0 dòng vì không có email đó.](img/sql-injection-va-tham-so-hoa-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/database-security/sql-injection-va-tham-so-hoa.html) · [nền tối](../diagrams/database-security/sql-injection-va-tham-so-hoa-dark.html)</small>

Với truy vấn tham số hóa, câu SQL (có `$1`) và giá trị được gửi tách rời. PostgreSQL phân tích câu lệnh khi chưa có giá trị, nên cấu trúc (bảng nào, điều kiện gì) đã cố định. Giá trị điền vào sau chỉ có thể là dữ liệu. Bạn có thể thấy cơ chế này ngay trong psql với lệnh `PREPARE`:

```sql
PREPARE find_orders(text) AS
    SELECT o.order_id, o.status
    FROM orders o JOIN customers c ON c.customer_id = o.customer_id
    WHERE c.email = $1;

EXECUTE find_orders('binh.tran@gmail.com');
EXECUTE find_orders(''' OR ''1''=''1');
DEALLOCATE find_orders;
```

| order_id | status |
| --- | --- |
| 2 | delivered |
| 8 | delivered |
| 22 | delivered |
| 34 | delivered |

Lần `EXECUTE` thứ hai trả về 0 dòng: chuỗi `' OR '1'='1` chỉ là một email lạ. Driver như psycopg và pg làm đúng việc này cho bạn mỗi khi dùng `%s` hay `$1` (xem [Ngày 23](23-sql-connect-apps.md)), nên trong code ứng dụng bạn không cần tự viết `PREPARE`.

> **Ghi chú dialect:** MySQL viết `PREPARE stmt FROM 'SELECT ... WHERE email = ?'; SET @e = '...'; EXECUTE stmt USING @e;`. PostgreSQL không dùng cú pháp này mà dùng `PREPARE ten(kieu) AS ... $1` và `EXECUTE ten(gia_tri)` như trên.

### Stored procedure có an toàn không?

Chỉ an toàn khi bên trong không ghép chuỗi. Function PL/pgSQL dùng SQL động (`EXECUTE` một chuỗi) mà ghép tham số vào thì lỗ hổng y như code ứng dụng. Cách đúng: tên bảng/cột đưa qua `format('%I', ...)` (tự đặt trong nháy kép như một tên), giá trị đưa qua `USING`:

```sql
CREATE OR REPLACE FUNCTION count_rows_where(p_table TEXT, p_city TEXT)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    result BIGINT;
BEGIN
    EXECUTE format('SELECT count(*) FROM %I WHERE city = $1', p_table)
    INTO result
    USING p_city;
    RETURN result;
END;
$$;

SELECT count_rows_where('customers', 'Hà Nội') AS ha_noi,
       count_rows_where('customers', ''' OR ''1''=''1') AS tan_cong;
```

| ha_noi | tan_cong |
| --- | --- |
| 4 | 0 |

```sql
SELECT count_rows_where('customers; DROP TABLE orders', 'x');
```

```text
ERROR:  relation "customers; DROP TABLE orders" does not exist
LINE 1: SELECT count(*) FROM "customers; DROP TABLE orders" WHERE ci...
                             ^
QUERY:  SELECT count(*) FROM "customers; DROP TABLE orders" WHERE city = $1
CONTEXT:  PL/pgSQL function count_rows_where(text,text) line 5 at EXECUTE
```

`%I` biến cả chuỗi thành một tên bảng (không tồn tại), không có lệnh `DROP` nào chạy.

```sql
DROP FUNCTION count_rows_where;
```

## Lưu mật khẩu người dùng của ứng dụng

Đây là mật khẩu của người dùng **ứng dụng** (khách đăng nhập web), khác với mật khẩu role của PostgreSQL.

Quy tắc số một: **không bao giờ lưu mật khẩu dạng rõ**, và không bao giờ kiểm tra đăng nhập kiểu `WHERE username = ? AND password = ?`. Nếu database bị lộ (bản backup bị rò, injection, nhân viên tò mò), mọi mật khẩu lộ theo. Mà người dùng hay dùng chung một mật khẩu cho nhiều trang.

Lưu hash thay cho mật khẩu. Hàm hash biến mật khẩu thành một chuỗi không thể dịch ngược. Đăng nhập thì hash mật khẩu vừa gõ rồi so với hash đã lưu. Nhưng không phải hàm hash nào cũng dùng được:

- `md5`, `sha256` quá nhanh: máy có GPU thử được hàng tỷ mật khẩu mỗi giây. Chúng cũng không có salt nên cùng mật khẩu luôn ra cùng hash:

```sql
SELECT md5('matkhau123') AS lan_1, md5('matkhau123') AS lan_2;
```

| lan_1 | lan_2 |
| --- | --- |
| 1a24b2c4b17016486c67773b974181bc | 1a24b2c4b17016486c67773b974181bc |

- Dùng thuật toán được thiết kế riêng cho mật khẩu: **bcrypt**, **argon2** hoặc scrypt. Chúng cố ý chậm (có tham số "cost" để tăng độ chậm theo thời gian) và tự sinh **salt** ngẫu nhiên cho mỗi mật khẩu, nên hai người dùng cùng mật khẩu vẫn có hash khác nhau.

### Cách 1: hash ở tầng ứng dụng (khuyến nghị)

Ứng dụng dùng thư viện bcrypt/argon2, database chỉ lưu chuỗi hash. Mật khẩu dạng rõ không bao giờ đi tới database, nên không thể lọt vào log của database.

Bảng lưu tài khoản (cột lưu hash, không có cột `password`):

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- dùng ở cách 2 bên dưới

DROP TABLE IF EXISTS app_users;
CREATE TABLE app_users (
    user_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      VARCHAR(50) NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL
);
```

Python (`pip install bcrypt "psycopg[binary]"`):

```python
import os
import bcrypt
import psycopg

def register(conn, username, password):
    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12)).decode()
    conn.execute(
        "INSERT INTO app_users (username, password_hash) VALUES (%s, %s)",
        (username, password_hash),
    )

def login(conn, username, password):
    row = conn.execute(
        "SELECT user_id, password_hash FROM app_users WHERE username = %s",
        (username,),
    ).fetchone()
    if row is None:
        return None                      # không nói rõ "sai tên" hay "sai mật khẩu"
    user_id, password_hash = row
    if bcrypt.checkpw(password.encode(), password_hash.encode()):
        return user_id
    return None

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    register(conn, "cuong", "Cuong@2026")
    print(login(conn, "cuong", "Cuong@2026"))
    print(login(conn, "cuong", "cuong@2026"))
    print(login(conn, "' OR '1'='1", "x"))
```

```text
1
None
None
```

Truy vấn chỉ tìm theo `username` (tham số hóa), việc so mật khẩu do `bcrypt.checkpw` làm. Node.js tương tự với thư viện `bcrypt` (`npm install bcrypt`):

```js
const bcrypt = require('bcrypt');

// Đăng ký
const passwordHash = await bcrypt.hash(password, 12);
await pool.query('INSERT INTO app_users (username, password_hash) VALUES ($1, $2)', [username, passwordHash]);

// Đăng nhập
const { rows } = await pool.query('SELECT user_id, password_hash FROM app_users WHERE username = $1', [username]);
const ok = rows.length > 0 && (await bcrypt.compare(password, rows[0].password_hash));
```

### Cách 2: hash trong PostgreSQL bằng pgcrypto

Extension `pgcrypto` (có sẵn trong PostgreSQL) có hàm `crypt()` và `gen_salt()` tạo hash bcrypt ngay trong SQL. Tiện khi bạn chỉ có SQL, ví dụ trong function hoặc script nạp dữ liệu:

```sql
INSERT INTO app_users (username, password_hash) VALUES
    ('binh', crypt('matkhau123', gen_salt('bf', 10))),
    ('an',   crypt('matkhau123', gen_salt('bf', 10)));

SELECT username, password_hash FROM app_users WHERE username IN ('binh', 'an') ORDER BY user_id;
```

| username | password_hash |
| --- | --- |
| binh | $2a$10$f5g9O6qNn0h0sTsyi/PY2OUplEkYWlnh2MFjfuT4stYaiAagLpIwq |
| an | $2a$10$gxk0XtF9bf.oOYPmd5tjsehgrb/ZnmAqZiRYtlkmCw5P2gAv5Ct76 |

Cùng mật khẩu `matkhau123` nhưng hai hash khác nhau nhờ salt ngẫu nhiên (hash trên máy bạn cũng sẽ khác). `$2a$` là bcrypt, `10` là cost, 22 ký tự tiếp theo là salt. Kiểm tra mật khẩu: đưa hash đã lưu làm tham số thứ hai cho `crypt()`, nó lấy lại đúng salt và cost, rồi so kết quả:

```sql
SELECT username,
       password_hash = crypt('matkhau123', password_hash) AS dung_mat_khau,
       password_hash = crypt('MatKhau123', password_hash) AS sai_hoa_thuong
FROM app_users
WHERE username = 'binh';
```

| username | dung_mat_khau | sai_hoa_thuong |
| --- | --- | --- |
| binh | t | f |

Hash do pgcrypto tạo là bcrypt chuẩn, thư viện bcrypt của Python hay Node đọc được và ngược lại. Nhược điểm của cách 2: mật khẩu dạng rõ nằm trong câu SQL gửi tới server, có thể bị ghi vào log nếu server bật ghi log câu lệnh. Vì vậy với ứng dụng, cách 1 vẫn được ưu tiên.

## Giữ bí mật thông tin kết nối

- Không viết mật khẩu database vào code. Dùng biến môi trường hoặc file `.env` đã thêm vào `.gitignore`. Lỡ push mật khẩu lên GitHub thì đổi mật khẩu ngay (`ALTER ROLE app_user PASSWORD '...'`), xóa commit không đủ.
- Mỗi ứng dụng, mỗi người một role riêng, để còn biết ai làm gì và thu hồi được từng người.
- Mật khẩu role đủ dài, ngẫu nhiên; superuser `postgres` không dùng cho ứng dụng và không mở ra Internet.
- Database trên server thật nên chỉ nhận kết nối từ máy chủ ứng dụng (cấu hình `pg_hba.conf`, firewall) và dùng SSL.

## Sao lưu và khôi phục

Quyền tốt đến đâu cũng không chống được ổ cứng hỏng, lệnh `DELETE` quên `WHERE` hay mã độc tống tiền. Phải có bản sao lưu, và phải **thử khôi phục** định kỳ: bản backup chưa từng khôi phục thử thì chưa chắc dùng được.

`pg_dump` xuất một database (hoặc một phần) thành file. Hai định dạng hay dùng:

| Định dạng | Lệnh | Khôi phục bằng | Ưu điểm |
| --- | --- | --- | --- |
| SQL thuần | `pg_dump ... -f shop.sql` | `psql -f shop.sql` | Đọc được bằng mắt, sửa tay được |
| Custom (`-Fc`) | `pg_dump ... -Fc -f shop.dump` | `pg_restore` | Nén, khôi phục chọn lọc từng bảng, khôi phục song song |

`pg_dump` chạy trong lúc database vẫn hoạt động và cho ra một bản chụp nhất quán tại thời điểm bắt đầu, không cần dừng ứng dụng.

Sao lưu schema `shop` của DSC Shop (thư mục `/data` trong container chính là `setup/data` trên máy bạn):

```sh
docker compose exec db pg_dump -U postgres -d sql_challenge -n shop -Fc -f /data/shop.dump
```

`-n shop` chỉ lấy schema `shop` (bỏ schema `perf` lớn), nên file chỉ vài chục KB. Khôi phục vào một database **mới** để kiểm tra, không đè lên database đang chạy:

```sh
docker compose exec db createdb -U postgres shop_restore
docker compose exec db pg_restore -U postgres -d shop_restore /data/shop.dump
docker compose exec db psql -U postgres -d shop_restore -c "SELECT (SELECT count(*) FROM shop.orders) AS orders, (SELECT count(*) FROM shop.order_items) AS order_items, (SELECT count(*) FROM shop.payments) AS payments"
```

```text
 orders | order_items | payments
--------+-------------+----------
     40 |          60 |       37
```

Khớp với database gốc. Ba điều hay bị bỏ sót:

- **Thiết lập của database không nằm trong dump.** `ALTER DATABASE ... SET search_path` không đi theo `pg_dump -n`, nên trong `shop_restore` phải viết `shop.orders` hoặc đặt lại: `ALTER DATABASE shop_restore SET search_path = shop, public;`.
- **Role không nằm trong dump.** `pg_dump` chỉ lưu lệnh `GRANT`, không lưu bản thân các role. Sao lưu role riêng bằng `pg_dumpall -U postgres --globals-only -f /data/roles.sql`.
- **Khôi phục một bảng bằng `pg_restore -t` không kèm khóa chính, khóa ngoại, index.** Thử xóa `payments` trong `shop_restore` rồi chỉ khôi phục bảng đó: dữ liệu về đủ 37 dòng nhưng `\d payments` không còn PRIMARY KEY, FOREIGN KEY và cột cũng mất IDENTITY. Muốn khôi phục đầy đủ, khôi phục cả schema vào database mới rồi chép dữ liệu cần sang.

Dọn database thử nghiệm và file dump khi xong:

```sh
docker compose exec db dropdb -U postgres shop_restore
docker compose exec db rm /data/shop.dump
```

> **Ghi chú dialect:** MySQL dùng `mysqldump --single-transaction ten_db > backup.sql` (nên có `--single-transaction` để có bản chụp nhất quán với InnoDB), khôi phục bằng `mysql ten_db < backup.sql` vào một database đã tạo sẵn. SQL Server dùng `BACKUP DATABASE ... TO DISK = '...'` và `RESTORE DATABASE ... FROM DISK = '...'`.

Nguyên tắc 3-2-1 cho dữ liệu quan trọng: 3 bản sao, trên 2 loại lưu trữ khác nhau, 1 bản để ở nơi khác (khác máy, khác tòa nhà hoặc trên cloud). Hệ thống lớn còn dùng sao lưu liên tục WAL (point-in-time recovery) để khôi phục về đúng một thời điểm, ngoài phạm vi bài này.

## Dọn dẹp

Role không xóa được khi còn được cấp quyền ở đâu đó:

```sql
DROP ROLE shop_readonly;
```

```text
ERROR:  role "shop_readonly" cannot be dropped because some objects depend on it
DETAIL:  privileges for database sql_challenge
privileges for schema shop
privileges for table categories
privileges for table products
privileges for table orders
privileges for table order_items
privileges for default privileges on new relations belonging to role postgres in schema shop
privileges for table app_users
```

Dòng cuối cho thấy `ALTER DEFAULT PRIVILEGES` đã có tác dụng: bảng `app_users` tạo sau đó tự được cấp `SELECT` cho `shop_readonly`.

`DROP OWNED BY` thu hồi mọi quyền của role trong database hiện tại (và trên chính database), rồi mới `DROP ROLE` được. Trả lại quyền `CONNECT` mặc định cho `PUBLIC`:

```sql
DROP OWNED BY shop_readonly, report_user, app_user, support_staff, sales_staff;
DROP ROLE report_user, shop_readonly, app_user, support_staff, sales_staff;
GRANT CONNECT ON DATABASE sql_challenge TO PUBLIC;
DROP TABLE IF EXISTS app_users;
```

## Lỗi thường gặp

**1. Ứng dụng kết nối bằng superuser.** Mọi lỗ hổng của ứng dụng thành lỗ hổng toàn quyền. Tạo user riêng với quyền tối thiểu.

**2. `GRANT ALL` cho tiện.** `GRANT ALL ON ALL TABLES IN SCHEMA shop TO app_user` cho cả `DELETE`, `TRUNCATE`. Liệt kê đúng quyền cần.

**3. Cấp quyền bảng mà quên `USAGE` trên schema.** Triệu chứng là lỗi khó hiểu `relation "products" does not exist` dù bảng vẫn còn. Kiểm tra `GRANT USAGE ON SCHEMA`.

**4. Quên bảng tạo sau.** `GRANT SELECT ON ALL TABLES IN SCHEMA shop` chỉ tác dụng với bảng đang có. Dùng thêm `ALTER DEFAULT PRIVILEGES`.

**5. Nối chuỗi tạo SQL, hoặc tự escape dấu nháy.** Luôn tham số hóa; tên cột/bảng động thì whitelist hoặc `format('%I')`.

**6. So sánh mật khẩu dạng rõ, hoặc dùng md5/sha256.** Lưu hash bcrypt/argon2, so bằng hàm của thư viện.

**7. Trả lỗi database thô cho người dùng.** Thông báo như `column "password" does not exist` giúp kẻ tấn công dò cấu trúc. Ghi log ở server, trả thông báo chung cho client.

**8. Có backup nhưng chưa bao giờ khôi phục thử,** hoặc backup nằm cùng ổ đĩa với database. Thử khôi phục định kỳ và giữ bản sao ở nơi khác.

## Bài tập

Chạy lại hai file init trước khi làm. Các role tạo trong bài tập nhớ dọn bằng `DROP OWNED BY ...; DROP ROLE ...;` khi xong.

### Cơ bản

**Bài 1.** Tạo nhóm `catalog_reader` chỉ được đọc `categories` và `products`, và user `intern_user` (đăng nhập được, mật khẩu tùy bạn) thuộc nhóm đó. Dùng `SET ROLE` để chứng minh: đọc được số sản phẩm đang hết hàng, nhưng không đọc được `orders`.

<details>
<summary>Đáp án</summary>

```sql
CREATE ROLE catalog_reader NOLOGIN;
CREATE ROLE intern_user LOGIN PASSWORD 'Thuc-tap#2026';
GRANT catalog_reader TO intern_user;
GRANT CONNECT ON DATABASE sql_challenge TO catalog_reader;
GRANT USAGE ON SCHEMA shop TO catalog_reader;
GRANT SELECT ON categories, products TO catalog_reader;

SET ROLE intern_user;
SELECT count(*) AS het_hang FROM products WHERE stock_quantity = 0;
RESET ROLE;
```

| het_hang |
| --- |
| 3 |

```sql
SET ROLE intern_user;
SELECT count(*) FROM orders;
RESET ROLE;
```

```text
ERROR:  permission denied for table orders
```
</details>

**Bài 2.** Kế toán cần đọc toàn bộ bảng `payments` và chỉ hai cột `order_id`, `status` của `orders`. Tạo role `accountant` (NOLOGIN) với đúng các quyền đó, rồi dùng `has_table_privilege` / `has_column_privilege` kiểm tra: đọc `payments` được, đọc `orders.status` được, đọc `orders.customer_id` không được.

<details>
<summary>Đáp án</summary>

```sql
CREATE ROLE accountant NOLOGIN;
GRANT USAGE ON SCHEMA shop TO accountant;
GRANT SELECT ON payments TO accountant;
GRANT SELECT (order_id, status) ON orders TO accountant;

SELECT has_table_privilege('accountant', 'shop.payments', 'SELECT')                AS payments,
       has_column_privilege('accountant', 'shop.orders', 'status', 'SELECT')       AS orders_status,
       has_column_privilege('accountant', 'shop.orders', 'customer_id', 'SELECT')  AS orders_customer;
```

| payments | orders_status | orders_customer |
| --- | --- | --- |
| t | t | f |
</details>

**Bài 3.** Thu hồi quyền đọc `products` của nhóm `catalog_reader` ở Bài 1, kiểm tra lại bằng `SET ROLE`, sau đó dọn hết role đã tạo ở Bài 1 và Bài 2.

<details>
<summary>Đáp án</summary>

```sql
REVOKE SELECT ON products FROM catalog_reader;

SET ROLE intern_user;
SELECT count(*) FROM products;
RESET ROLE;
```

```text
ERROR:  permission denied for table products
```

```sql
DROP OWNED BY catalog_reader, intern_user, accountant;
DROP ROLE intern_user, catalog_reader, accountant;
```
</details>

### Vận dụng

**Bài 4.** Đoạn Node.js sau xem chi tiết đơn hàng theo id lấy từ URL. Viết một giá trị `id` khiến API trả về mọi dòng hàng của mọi đơn, giải thích vì sao, rồi sửa lại.

```js
app.get('/orders/:id/items', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT product_id, quantity, unit_price FROM order_items WHERE order_id = ' + req.params.id
  );
  res.json(rows);
});
```

<details>
<summary>Đáp án</summary>

Gọi `/orders/0%20OR%201=1/items` (dấu cách mã hóa thành `%20` trong URL). `req.params.id` là `0 OR 1=1`, câu SQL thành:

```sql
SELECT product_id, quantity, unit_price FROM order_items WHERE order_id = 0 OR 1=1;
```

Ở đây không cần dấu nháy vì giá trị là số: ghép số vào SQL cũng nguy hiểm như ghép chuỗi. Truy vấn trả về đủ 60 dòng hàng. Sửa:

```js
app.get('/orders/:id/items', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT product_id, quantity, unit_price FROM order_items WHERE order_id = $1 ORDER BY product_id',
      [req.params.id]
    );
    res.json(rows);
  } catch (err) {
    next(err); // id không phải số => lỗi 22P02, middleware trả 400
  }
});
```

Với `id = "0 OR 1=1"`, PostgreSQL báo `invalid input syntax for type integer: "0 OR 1=1"` thay vì chạy câu lệnh.
</details>

**Bài 5.** Dùng pgcrypto, viết function `check_login(p_username TEXT, p_password TEXT) RETURNS BOOLEAN` trả `true` khi đúng tên và mật khẩu. Tạo bảng `app_users` như trong bài, đăng ký `binh` / `matkhau123`, rồi thử: đúng mật khẩu, sai mật khẩu, tên không tồn tại, và tên là `binh' --`.

<details>
<summary>Đáp án</summary>

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS app_users;
CREATE TABLE app_users (
    user_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      VARCHAR(50) NOT NULL UNIQUE,
    password_hash TEXT        NOT NULL
);
INSERT INTO app_users (username, password_hash)
VALUES ('binh', crypt('matkhau123', gen_salt('bf', 10)));

CREATE OR REPLACE FUNCTION check_login(p_username TEXT, p_password TEXT)
RETURNS BOOLEAN
LANGUAGE sql AS $$
    SELECT EXISTS (
        SELECT 1
        FROM app_users
        WHERE username = p_username
          AND password_hash = crypt(p_password, password_hash)
    );
$$;

SELECT check_login('binh', 'matkhau123')  AS dung,
       check_login('binh', 'sai')         AS sai_mat_khau,
       check_login('khong-co', 'x')       AS khong_co_user,
       check_login('binh'' --', 'x')      AS thu_injection;
```

| dung | sai_mat_khau | khong_co_user | thu_injection |
| --- | --- | --- | --- |
| t | f | f | f |

Tham số của function là giá trị, không phải đoạn code, nên `binh' --` chỉ là một tên đăng nhập lạ. Nếu ứng dụng ghép chuỗi kiểu `"... WHERE username = '" + u + "' AND password_hash = crypt('" + p + "', password_hash)"` thì với `u = "binh' --"`, phần kiểm tra mật khẩu bị biến thành chú thích và kẻ tấn công đăng nhập được tài khoản `binh` mà không cần mật khẩu.
</details>

**Bài 6.** Sao lưu schema `shop` bằng định dạng custom, khôi phục vào database `shop_restore`, rồi trong `shop_restore` xóa nhầm bảng `payments` và khôi phục lại chỉ bảng đó từ file dump. So sánh số dòng và cấu trúc bảng `payments` sau khi khôi phục với bản gốc. Dọn dẹp khi xong.

<details>
<summary>Đáp án</summary>

```sh
docker compose exec db pg_dump -U postgres -d sql_challenge -n shop -Fc -f /data/shop.dump
docker compose exec db createdb -U postgres shop_restore
docker compose exec db pg_restore -U postgres -d shop_restore /data/shop.dump
docker compose exec db psql -U postgres -d shop_restore -c "ALTER DATABASE shop_restore SET search_path = shop, public"
docker compose exec db psql -U postgres -d shop_restore -c "DROP TABLE payments"
docker compose exec db pg_restore -U postgres -d shop_restore -t payments /data/shop.dump
docker compose exec db psql -U postgres -d shop_restore -c "SELECT count(*) FROM payments" -c "\d payments"
```

```text
 count
-------
    37

                         Table "shop.payments"
   Column   |           Type           | Collation | Nullable | Default
------------+--------------------------+-----------+----------+---------
 payment_id | integer                  |           | not null |
 order_id   | integer                  |           | not null |
 amount     | numeric(12,0)            |           | not null |
 method     | character varying(20)    |           | not null |
 paid_at    | timestamp with time zone |           | not null |
Check constraints:
    "payments_amount_check" CHECK (amount > 0::numeric)
    "payments_method_check" CHECK (method::text = ANY (ARRAY['cash'::character varying::text, 'card'::character varying::text, 'momo'::character varying::text, 'bank_transfer'::character varying::text]))
```

Đủ 37 dòng, còn các CHECK, nhưng mất PRIMARY KEY, FOREIGN KEY tới `orders`, index trên `order_id` và IDENTITY của `payment_id` (so với `\d payments` trong `sql_challenge`). Trong `pg_restore`, ràng buộc khóa và index là các mục riêng, `-t` không kéo theo. Khi cần khôi phục một bảng đầy đủ, an toàn hơn là khôi phục cả schema vào database tạm rồi chép dữ liệu sang.

```sh
docker compose exec db dropdb -U postgres shop_restore
docker compose exec db rm /data/shop.dump
```
</details>

### Thử thách

**Bài 7.** Thiết kế và tạo bộ quyền cho ba nhóm của DSC Shop, kèm câu lệnh kiểm chứng mỗi nhóm bằng `SET ROLE`:

- `shop_sales`: đọc sản phẩm, danh mục, khách, đơn, dòng hàng; tạo đơn và dòng hàng; đổi trạng thái đơn; không được xem `customers.birth_date` và không được xóa gì.
- `shop_hr`: đọc và sửa `employees`, không đọc được bất kỳ bảng nào khác.
- `shop_analyst`: đọc mọi bảng trừ `employees.salary` và các cột liên lạc của khách (`email`, `phone`).

<details>
<summary>Đáp án</summary>

Một cách làm (ý chính là kết hợp quyền mức bảng và mức cột):

```sql
CREATE ROLE shop_sales NOLOGIN;
CREATE ROLE shop_hr NOLOGIN;
CREATE ROLE shop_analyst NOLOGIN;
GRANT USAGE ON SCHEMA shop TO shop_sales, shop_hr, shop_analyst;

-- shop_sales
GRANT SELECT ON categories, products, orders, order_items TO shop_sales;
GRANT SELECT (customer_id, full_name, email, phone, city, created_at) ON customers TO shop_sales;
GRANT INSERT ON orders, order_items TO shop_sales;
GRANT UPDATE (status) ON orders TO shop_sales;

-- shop_hr
GRANT SELECT, INSERT, UPDATE ON employees TO shop_hr;

-- shop_analyst
GRANT SELECT ON categories, products, orders, order_items, payments TO shop_analyst;
GRANT SELECT (customer_id, full_name, city, birth_date, created_at) ON customers TO shop_analyst;
GRANT SELECT (employee_id, full_name, title, manager_id, hire_date) ON employees TO shop_analyst;

SELECT has_column_privilege('shop_sales',   'shop.customers', 'birth_date', 'SELECT') AS sales_birth,
       has_table_privilege ('shop_sales',   'shop.orders', 'DELETE')                  AS sales_delete,
       has_table_privilege ('shop_hr',      'shop.orders', 'SELECT')                  AS hr_orders,
       has_column_privilege('shop_analyst', 'shop.employees', 'salary', 'SELECT')     AS analyst_salary,
       has_column_privilege('shop_analyst', 'shop.employees', 'title', 'SELECT')      AS analyst_title;
```

| sales_birth | sales_delete | hr_orders | analyst_salary | analyst_title |
| --- | --- | --- | --- | --- |
| f | f | f | f | t |

Kiểm chứng bằng truy vấn thật, ví dụ nhà phân tích đếm nhân viên theo chức danh:

```sql
SET ROLE shop_analyst;
SELECT title, count(*) AS so_nguoi FROM employees GROUP BY title ORDER BY so_nguoi DESC, title LIMIT 2;
RESET ROLE;
```

| title | so_nguoi |
| --- | --- |
| Nhân viên bán hàng | 3 |
| Giám đốc | 1 |

```sql
SET ROLE shop_analyst;
SELECT avg(salary) FROM employees;
RESET ROLE;
```

```text
ERROR:  permission denied for table employees
```

Dọn dẹp:

```sql
DROP OWNED BY shop_sales, shop_hr, shop_analyst;
DROP ROLE shop_sales, shop_hr, shop_analyst;
```
</details>

## Tóm tắt

- PostgreSQL chỉ có role: role `LOGIN` là user, role `NOLOGIN` làm nhóm quyền. Role thuộc cả cluster.
- Muốn đọc một bảng cần đủ ba tầng: `CONNECT` trên database, `USAGE` trên schema, `SELECT` trên bảng (hoặc trên từng cột). Thu hồi bằng `REVOKE`; nhớ `REVOKE CONNECT ... FROM PUBLIC` và `ALTER DEFAULT PRIVILEGES` cho bảng tạo sau.
- Quyền tối thiểu: ứng dụng dùng user riêng, chỉ có quyền nghiệp vụ cần; người làm báo cáo chỉ đọc; dữ liệu nhạy cảm che bằng quyền mức cột, view, hoặc RLS cho từng dòng.
- SQL injection đến từ việc ghép dữ liệu vào câu SQL. Truy vấn tham số hóa chặn tận gốc vì cấu trúc câu được chốt trước khi điền giá trị. Quyền tối thiểu giới hạn thiệt hại nếu vẫn có lỗ hổng.
- Không lưu mật khẩu dạng rõ, không dùng md5/sha256 cho mật khẩu. Dùng bcrypt/argon2 có salt, ưu tiên hash ở tầng ứng dụng; trong SQL có `crypt()` + `gen_salt('bf')` của pgcrypto.
- Sao lưu bằng `pg_dump` (`-Fc` cho `pg_restore`), role sao lưu riêng bằng `pg_dumpall --globals-only`, và khôi phục thử vào database mới định kỳ.

## Đọc thêm

- [PostgreSQL 16: Database Roles](https://www.postgresql.org/docs/16/user-manag.html), [GRANT](https://www.postgresql.org/docs/16/sql-grant.html), [Row Security Policies](https://www.postgresql.org/docs/16/ddl-rowsecurity.html)
- [PostgreSQL 16: pgcrypto](https://www.postgresql.org/docs/16/pgcrypto.html), [pg_dump](https://www.postgresql.org/docs/16/app-pgdump.html), [pg_restore](https://www.postgresql.org/docs/16/app-pgrestore.html)
- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)

---

[⬅️ Ngày 29: Window function và truy vấn đệ quy](29-recursive-queries-window-functions.md) | [📚 Mục lục](../README.md) | [Tổng kết và dự án cuối khóa ➡️](99-summary.md)
