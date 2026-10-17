# Ngày 11: Truy vấn con (subquery) và CTE

> **Tóm tắt:** Nhiều câu hỏi cần hai bước: "sản phẩm nào đắt hơn giá trung bình" phải tính trung bình trước rồi mới lọc. Truy vấn con (subquery) cho phép đặt một câu `SELECT` vào bên trong câu khác để làm việc đó trong một lần chạy. Bài này đi qua các dạng subquery (trả về một giá trị, một danh sách, một bảng), phân biệt subquery thường và subquery tương quan, `EXISTS`/`NOT EXISTS`, cái bẫy `NOT IN` gặp NULL, và cách dùng CTE (`WITH`) để chia truy vấn dài thành từng bước dễ đọc.

**Sau bài này bạn có thể:**

- Viết được subquery vô hướng trong `WHERE` và `SELECT` để so sánh với một giá trị tính toán (trung bình, lớn nhất).
- Dùng được `IN`, `EXISTS`, `NOT EXISTS` để lọc theo dữ liệu ở bảng khác, và giải thích được vì sao `NOT IN` trả về 0 dòng khi danh sách có NULL.
- Phân biệt được subquery thường (tính một lần) và subquery tương quan (tính lại cho từng dòng ngoài).
- Viết được subquery trong `FROM` và CTE `WITH` để tổng hợp nhiều bước, ví dụ "khách chi tiêu trên mức trung bình".

**Cần biết trước:** [Ngày 3](03-select-where.md) (NULL và logic ba trị), [Ngày 8](08-aggregate-functions.md), [Ngày 9](09-group-by-having.md), [Ngày 10](10-join.md).

## 1. Subquery là gì?

Câu hỏi: "những sản phẩm nào có giá cao hơn giá trung bình của cửa hàng?". Không có subquery, bạn phải chạy hai câu. Câu thứ nhất tính trung bình:

```sql
SELECT AVG(price) AS gia_trung_binh
FROM products;
```

| gia_trung_binh |
| --- |
| 10832875.000000000000 |

Rồi chép con số đó vào câu thứ hai. Cách này dở: giá thay đổi thì con số chép tay đã cũ. Subquery là đặt câu thứ nhất vào trong câu thứ hai, bọc trong ngoặc tròn:

```sql
SELECT sku, name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC;
```

| sku | name | price |
| --- | --- | --- |
| LAP-001 | ASUS ROG Strix G16 | 32990000 |
| LAP-002 | Lenovo Legion 5 | 29990000 |
| LAP-005 | MacBook Air M2 13 inch | 24990000 |
| LAP-003 | Acer Nitro V 15 | 21990000 |
| PHN-001 | iPhone 15 128GB | 19990000 |
| PHN-002 | Samsung Galaxy S24 | 18990000 |
| LAP-004 | Dell Inspiron 14 | 18490000 |
| LAP-006 | HP Pavilion 15 | 16990000 |
| TAB-001 | iPad Air M2 11 inch | 16990000 |

Câu bên trong ngoặc gọi là truy vấn con (subquery, inner query), câu bao ngoài gọi là truy vấn ngoài (outer query). Subquery có thể nằm ở ba chỗ, tùy nó trả về gì:

| Subquery trả về | Gọi là | Đặt ở đâu | Ví dụ toán tử |
| --- | --- | --- | --- |
| Đúng 1 dòng 1 cột | Vô hướng (scalar) | `WHERE`, `SELECT`, `HAVING` | `=`, `>`, `<`, ... |
| 1 cột, nhiều dòng | Danh sách | `WHERE` | `IN`, `NOT IN`, `ANY`, `ALL` |
| Nhiều dòng, nhiều cột | Bảng | `FROM`, `EXISTS` | `FROM (...) AS t`, `EXISTS (...)` |

## 2. Subquery vô hướng: một giá trị duy nhất

Subquery vô hướng trả về đúng một ô (1 dòng, 1 cột), nên dùng được ở mọi chỗ cần một giá trị. Trong `SELECT`, nó cho thêm một cột tính toán. Ví dụ so sánh giá laptop gaming với giá trung bình cả cửa hàng:

```sql
SELECT sku, name, price,
       price - (SELECT ROUND(AVG(price)) FROM products) AS chenh_lech
FROM products
WHERE category_id = 3
ORDER BY price DESC;
```

| sku | name | price | chenh_lech |
| --- | --- | --- | --- |
| LAP-001 | ASUS ROG Strix G16 | 32990000 | 22157125 |
| LAP-002 | Lenovo Legion 5 | 29990000 | 19157125 |
| LAP-003 | Acer Nitro V 15 | 21990000 | 11157125 |

Nếu subquery dùng với `=`, `>` mà trả về nhiều hơn một dòng, PostgreSQL báo lỗi ngay khi chạy:

```sql
SELECT sku, name, price
FROM products
WHERE price = (SELECT price FROM products WHERE category_id = 3);
```

```text
ERROR:  more than one row returned by a subquery used as an expression
```

Danh mục 3 có 3 sản phẩm, nên subquery trả về 3 giá. "Bằng ba giá" là vô nghĩa. Bạn phải chọn: muốn "bằng một trong các giá" thì dùng `IN` (mục 3), muốn "bằng giá cao nhất" thì dùng `MAX(price)` để subquery chỉ còn một giá trị.

Ngược lại, nếu subquery vô hướng không trả về dòng nào, kết quả của nó là NULL (không báo lỗi).

## 3. Subquery trả về danh sách: IN, ANY, ALL

`IN (subquery)` kiểm tra giá trị có nằm trong danh sách mà subquery trả về không. Ví dụ: khách nào từng mua tại cửa hàng (đơn `offline`)?

```sql
SELECT customer_id, full_name
FROM customers
WHERE customer_id IN (SELECT customer_id FROM orders WHERE channel = 'offline')
ORDER BY customer_id;
```

| customer_id | full_name |
| --- | --- |
| 1 | Nguyễn Văn An |
| 2 | Trần Thị Bình |
| 3 | Lê Hoàng Cường |
| 4 | Phạm Minh Duy |
| 5 | Hoàng Thị Em |
| ... | ... |

(... tổng 13 dòng)

So với `JOIN` ở Ngày 10: viết bằng `JOIN customers c ... JOIN orders o ... WHERE o.channel = 'offline'` ra 15 dòng, vì khách 1 và khách 2 mỗi người có 2 đơn offline nên tên bị lặp. `IN` chỉ hỏi "có hay không", mỗi khách xuất hiện tối đa một lần. Khi bạn chỉ cần lọc theo bảng khác mà không cần lấy cột của nó, `IN` hoặc `EXISTS` (mục 5) diễn đạt đúng ý hơn `JOIN`.

`ANY` và `ALL` đi kèm toán tử so sánh:

- `x > ANY (subquery)`: lớn hơn ít nhất một giá trị trong danh sách. `x = ANY (...)` chính là `x IN (...)`.
- `x > ALL (subquery)`: lớn hơn mọi giá trị trong danh sách.

Sản phẩm đắt hơn mọi máy tính bảng (danh mục 8):

```sql
SELECT sku, name, price
FROM products
WHERE price > ALL (SELECT price FROM products WHERE category_id = 8)
ORDER BY price DESC;
```

| sku | name | price |
| --- | --- | --- |
| LAP-001 | ASUS ROG Strix G16 | 32990000 |
| LAP-002 | Lenovo Legion 5 | 29990000 |
| LAP-005 | MacBook Air M2 13 inch | 24990000 |
| LAP-003 | Acer Nitro V 15 | 21990000 |
| PHN-001 | iPhone 15 128GB | 19990000 |
| PHN-002 | Samsung Galaxy S24 | 18990000 |
| LAP-004 | Dell Inspiron 14 | 18490000 |

Máy tính bảng đắt nhất là iPad Air 16.990.000, nên câu này tương đương `price > (SELECT MAX(price) ...)`. Nhiều người thấy cách viết `MAX` dễ đọc hơn; cả hai đều đúng.

## 4. Subquery thường và subquery tương quan

Mọi subquery ở các mục trên đều tự chạy được một mình: copy phần trong ngoặc ra chạy riêng vẫn ra kết quả. Đó là subquery thường (non-correlated). Về mặt logic, nó chỉ cần tính một lần, rồi kết quả được dùng cho mọi dòng của truy vấn ngoài.

Giờ đổi câu hỏi: "sản phẩm nào đắt hơn giá trung bình của chính danh mục của nó?". Mỗi sản phẩm cần so với một trung bình khác nhau, tùy nó thuộc danh mục nào. Subquery phải biết đang xét sản phẩm nào:

```sql
SELECT p.sku, p.name, p.category_id, p.price
FROM products p
WHERE p.price > (SELECT AVG(p2.price)
                 FROM products p2
                 WHERE p2.category_id = p.category_id)
ORDER BY p.category_id, p.price DESC;
```

| sku | name | category_id | price |
| --- | --- | --- | --- |
| LAP-001 | ASUS ROG Strix G16 | 3 | 32990000 |
| LAP-002 | Lenovo Legion 5 | 3 | 29990000 |
| LAP-005 | MacBook Air M2 13 inch | 4 | 24990000 |
| PC-003 | PC văn phòng DSC Basic | 5 | 9990000 |
| PHN-001 | iPhone 15 128GB | 7 | 19990000 |
| PHN-002 | Samsung Galaxy S24 | 7 | 18990000 |
| TAB-001 | iPad Air M2 11 inch | 8 | 16990000 |
| ACC-002 | Chuột Logitech MX Master 3S | 10 | 2490000 |
| ACC-003 | Bàn phím cơ Keychron K2 | 10 | 1890000 |
| ACC-004 | Tai nghe Sony WH-1000XM5 | 11 | 7990000 |
| ACC-005 | Tai nghe AirPods Pro 2 | 11 | 5990000 |
| ACC-007 | Sạc Anker 65W | 12 | 890000 |

Điểm mấu chốt là `p.category_id` bên trong subquery: nó tham chiếu tới cột của truy vấn ngoài. Subquery như vậy gọi là subquery tương quan (correlated subquery). Bạn không chạy riêng được nó (chạy riêng sẽ lỗi vì không biết `p` là gì), và về mặt logic nó được tính lại cho từng dòng của truy vấn ngoài:

![Subquery tương quan chạy theo từng dòng của products. Với dòng LAP-001 ASUS ROG Strix G16 (category_id 3, giá 32.990.000), truy vấn con AVG(p2.price) WHERE p2.category_id = 3 trả về 28.323.333; 32.990.000 lớn hơn nên WHERE cho TRUE, giữ dòng. Với dòng LAP-003 Acer Nitro V 15 (category_id 3, giá 21.990.000), truy vấn con chạy lại với category_id = 3, trả về 28.323.333; 21.990.000 nhỏ hơn nên FALSE, bỏ dòng. Với dòng PHN-001 iPhone 15 128GB (category_id 7, giá 19.990.000), truy vấn con chạy lại với category_id = 7, trả về 11.140.000; lớn hơn nên giữ dòng. Cứ thế cho cả 24 dòng của products. Ngược lại, truy vấn con không tương quan WHERE price > (SELECT AVG(price) FROM products) không nhắc tới cột nào của dòng ngoài nên chỉ cần tính một lần, ra 10.832.875, rồi dùng cho mọi dòng.](img/tuong-quan-tung-dong.png#gh-light-mode-only)
![Subquery tương quan chạy theo từng dòng của products. Với dòng LAP-001 ASUS ROG Strix G16 (category_id 3, giá 32.990.000), truy vấn con AVG(p2.price) WHERE p2.category_id = 3 trả về 28.323.333; 32.990.000 lớn hơn nên WHERE cho TRUE, giữ dòng. Với dòng LAP-003 Acer Nitro V 15 (category_id 3, giá 21.990.000), truy vấn con chạy lại với category_id = 3, trả về 28.323.333; 21.990.000 nhỏ hơn nên FALSE, bỏ dòng. Với dòng PHN-001 iPhone 15 128GB (category_id 7, giá 19.990.000), truy vấn con chạy lại với category_id = 7, trả về 11.140.000; lớn hơn nên giữ dòng. Cứ thế cho cả 24 dòng của products. Ngược lại, truy vấn con không tương quan WHERE price > (SELECT AVG(price) FROM products) không nhắc tới cột nào của dòng ngoài nên chỉ cần tính một lần, ra 10.832.875, rồi dùng cho mọi dòng.](img/tuong-quan-tung-dong-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/subquery/tuong-quan-tung-dong.html) · [nền tối](../diagrams/subquery/tuong-quan-tung-dong-dark.html)</small>

"Tính lại cho từng dòng" là cách hiểu kết quả, không phải cam kết về cách chạy. Bộ tối ưu của PostgreSQL có thể viết lại câu lệnh (ví dụ biến nó thành JOIN) để chạy nhanh hơn, và kết quả vẫn y như vậy. Bạn sẽ xem database thật sự làm gì bằng `EXPLAIN` ở [Ngày 20](20-query-performance.md). Với bảng lớn, một subquery tương quan trong `SELECT` có thể chậm thật, vì nó dễ bị chạy lại cho từng dòng.

Subquery tương quan trong `SELECT` rất tiện để thêm cột "tính theo từng dòng". Số đơn và ngày đơn gần nhất của mỗi khách:

```sql
SELECT c.customer_id,
       c.full_name,
       (SELECT COUNT(*) FROM orders o
         WHERE o.customer_id = c.customer_id) AS so_don,
       (SELECT MAX(o.order_date)::date FROM orders o
         WHERE o.customer_id = c.customer_id) AS don_gan_nhat
FROM customers c
WHERE c.customer_id BETWEEN 14 AND 18
ORDER BY c.customer_id;
```

| customer_id | full_name | so_don | don_gan_nhat |
| --- | --- | --- | --- |
| 14 | Huỳnh Tấn Phát | 2 | 2026-05-20 |
| 15 | Nguyễn Văn An | 2 | 2026-10-05 |
| 16 | Tạ Quang Sơn | 0 | NULL |
| 17 | Châu Ngọc Trâm | 0 | NULL |
| 18 | Mai Đức Uy | 2 | 2026-08-08 |

Khác với `LEFT JOIN` + `GROUP BY` ở Ngày 10, ở đây `COUNT(*)` ra đúng 0 cho khách chưa mua, vì subquery đếm các đơn khớp, mà không có đơn nào khớp.

## 5. EXISTS và NOT EXISTS

`EXISTS (subquery)` trả về TRUE nếu subquery có ít nhất một dòng, FALSE nếu không có dòng nào. Nó không quan tâm subquery chọn cột gì, nên người ta hay viết `SELECT 1`. `EXISTS` gần như luôn đi với subquery tương quan.

Khách có đặt hàng từ tháng 7/2026 trở đi:

```sql
SELECT c.customer_id, c.full_name
FROM customers c
WHERE EXISTS (SELECT 1
              FROM orders o
              WHERE o.customer_id = c.customer_id
                AND o.order_date >= '2026-07-01')
ORDER BY c.customer_id;
```

| customer_id | full_name |
| --- | --- |
| 1 | Nguyễn Văn An |
| 3 | Lê Hoàng Cường |
| 6 | Võ Quốc Phong |
| 13 | Phan Thị Oanh |
| 15 | Nguyễn Văn An |
| 18 | Mai Đức Uy |

`NOT EXISTS` là cách viết rõ ràng nhất cho câu hỏi "không có". Khách chưa từng đặt hàng:

```sql
SELECT c.customer_id, c.full_name
FROM customers c
WHERE NOT EXISTS (SELECT 1
                  FROM orders o
                  WHERE o.customer_id = c.customer_id)
ORDER BY c.customer_id;
```

| customer_id | full_name |
| --- | --- |
| 16 | Tạ Quang Sơn |
| 17 | Châu Ngọc Trâm |

Kết quả giống anti-join `LEFT JOIN ... WHERE o.order_id IS NULL` ở Ngày 10. Hai cách đều đúng; `NOT EXISTS` đọc gần với câu hỏi tiếng Việt hơn và không có bẫy NULL như `NOT IN` ở mục tiếp theo.

## 6. Bẫy NOT IN gặp NULL

Câu hỏi: "nhân viên nào chưa bán được đơn nào?". Viết bằng `NOT IN` nghe rất tự nhiên:

```sql
SELECT e.employee_id, e.full_name
FROM employees e
WHERE e.employee_id NOT IN (SELECT employee_id FROM orders)
ORDER BY e.employee_id;
```

| employee_id | full_name |
| --- | --- |

(0 dòng)

Không lỗi, nhưng 0 dòng. Trong khi rõ ràng giám đốc chưa bán đơn nào. Lý do: đơn online có `employee_id` là NULL, nên danh sách trả về chứa NULL. Với giám đốc (`employee_id = 1`), điều kiện `1 NOT IN (4, NULL, 5, ...)` nghĩa là:

```text
1 <> 4  AND  1 <> NULL  AND  1 <> 5  AND ...
TRUE    AND  UNKNOWN    AND  TRUE    AND ...   →  UNKNOWN
```

`1 <> NULL` không phải TRUE mà là UNKNOWN (logic ba trị, Ngày 3). `TRUE AND UNKNOWN` là UNKNOWN, và `WHERE` chỉ giữ dòng có điều kiện TRUE. Chỉ cần danh sách có một NULL, `NOT IN` không bao giờ ra TRUE, mọi dòng đều bị loại.

Hai cách sửa:

```sql
-- Cách 1 (nên dùng): NOT EXISTS, không bị ảnh hưởng bởi NULL
SELECT e.employee_id, e.full_name
FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.employee_id)
ORDER BY e.employee_id;

-- Cách 2: loại NULL khỏi danh sách
SELECT e.employee_id, e.full_name
FROM employees e
WHERE e.employee_id NOT IN (SELECT employee_id FROM orders WHERE employee_id IS NOT NULL)
ORDER BY e.employee_id;
```

Cả hai cho:

| employee_id | full_name |
| --- | --- |
| 1 | Nguyễn Thành Long |
| 2 | Lê Thị Hạnh |
| 3 | Trần Quốc Bảo |
| 7 | Lâm Gia Huy |

Cách 2 đúng hôm nay nhưng dễ quên khi viết câu mới. Hãy tập thói quen: câu hỏi "không có" thì dùng `NOT EXISTS`. `IN` (không có `NOT`) không gặp bẫy này: NULL trong danh sách chỉ không khớp với gì, các giá trị khác vẫn khớp bình thường.

## 7. Subquery trong FROM: bảng tạm

Subquery trả về một bảng thì đặt được vào `FROM`, như một bảng bình thường. Nó còn được gọi là bảng dẫn xuất (derived table). Cách này dùng khi cần tổng hợp hai lần, việc mà một câu `GROUP BY` không làm được (bạn đã gặp ở bài 9 của Ngày 9).

Trung bình mỗi khách (đã mua) có bao nhiêu đơn? Bước 1 đếm đơn của từng khách, bước 2 lấy trung bình của các con số đó:

```sql
SELECT ROUND(AVG(so_don), 2) AS tb_don_moi_khach,
       MAX(so_don)           AS nhieu_nhat
FROM (SELECT customer_id, COUNT(*) AS so_don
      FROM orders
      GROUP BY customer_id) AS t;
```

| tb_don_moi_khach | nhieu_nhat |
| --- | --- |
| 2.50 | 5 |

`AS t` đặt tên cho bảng tạm. Truy vấn ngoài dùng các cột của nó (`so_don`) như cột của một bảng thật. Bạn cũng có thể JOIN bảng tạm với bảng khác, như cách sửa lỗi nhân dòng ở mục 10 của Ngày 10.

> **Ghi chú dialect:** PostgreSQL từ bản 16 cho phép bỏ alias của subquery trong `FROM`. MySQL, SQL Server và PostgreSQL bản cũ hơn bắt buộc phải có alias (MySQL báo lỗi `Every derived table must have its own alias`). Luôn đặt alias để câu lệnh chạy được ở mọi nơi và dễ đọc.

## 8. CTE: đặt tên cho từng bước với WITH

Khi truy vấn có nhiều bước, subquery lồng trong subquery rất khó đọc vì bạn phải đọc từ trong ra ngoài. CTE (Common Table Expression) viết các bước theo thứ tự từ trên xuống, mỗi bước có một tên:

```text
WITH ten_buoc_1 AS (
    SELECT ...
),
ten_buoc_2 AS (
    SELECT ... FROM ten_buoc_1 ...
)
SELECT ... FROM ten_buoc_2 ...;
```

Mỗi CTE giống một bảng tạm chỉ sống trong câu lệnh đó. CTE sau dùng được CTE trước, và truy vấn chính dùng được tất cả.

Câu hỏi: "khách nào có tổng chi tiêu cao hơn mức chi tiêu trung bình của các khách?". Ba bước:

1. Tổng tiền của từng đơn (từ `order_items`).
2. Tổng chi tiêu của từng khách: cộng các đơn đã thanh toán, tức `status NOT IN ('pending', 'cancelled')` (cùng định nghĩa với doanh thu của cửa hàng).
3. Giữ những khách có tổng chi tiêu lớn hơn trung bình của bước 2.

```sql
WITH tien_don AS (
    SELECT order_id,
           SUM(quantity * unit_price * (1 - discount)) AS tong_tien
    FROM order_items
    GROUP BY order_id
),
chi_tieu AS (
    SELECT o.customer_id,
           ROUND(SUM(t.tong_tien)) AS tong_chi
    FROM orders o
    JOIN tien_don t ON t.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.customer_id
)
SELECT c.customer_id, c.full_name, ct.tong_chi
FROM chi_tieu ct
JOIN customers c ON c.customer_id = ct.customer_id
WHERE ct.tong_chi > (SELECT AVG(tong_chi) FROM chi_tieu)
ORDER BY ct.tong_chi DESC;
```

| customer_id | full_name | tong_chi |
| --- | --- | --- |
| 10 | Dương Minh Khoa | 63220500 |
| 15 | Nguyễn Văn An | 58970000 |
| 2 | Trần Thị Bình | 58262500 |
| 18 | Mai Đức Uy | 46980000 |
| 14 | Huỳnh Tấn Phát | 45880500 |
| 1 | Nguyễn Văn An | 45430000 |
| 9 | Ngô Thị Lan | 43570000 |
| 6 | Võ Quốc Phong | 42018500 |

(Mức trung bình của 16 khách đã mua là khoảng 33,5 triệu.)

Hai điểm đáng chú ý:

- `chi_tieu` được dùng hai lần: một lần trong `FROM`, một lần trong subquery vô hướng `(SELECT AVG(tong_chi) FROM chi_tieu)`. Viết bằng subquery trong `FROM` thì bạn phải chép nguyên đoạn tính chi tiêu hai lần.
- `tien_don` tổng hợp `order_items` về mỗi đơn một dòng trước khi JOIN, đúng nguyên tắc tránh nhân dòng của Ngày 10.

Cách đọc và gỡ lỗi CTE: chạy từng bước. Thay truy vấn chính bằng `SELECT * FROM tien_don` để xem bước 1 đã đúng chưa, rồi mới sang bước 2.

CTE trong bài này là CTE thường (không đệ quy). `WITH RECURSIVE` để đi trên cây danh mục, cây nhân viên sẽ học ở [Ngày 29](29-recursive-queries-window-functions.md).

## 9. Chọn cách nào?

Cùng một câu hỏi thường viết được bằng nhiều cách. Gợi ý cho người mới:

| Câu hỏi | Nên dùng |
| --- | --- |
| So sánh với một con số tính từ bảng (trung bình, lớn nhất) | Subquery vô hướng |
| Lọc theo "có tồn tại ở bảng khác" | `EXISTS` hoặc `IN` |
| Lọc theo "không tồn tại ở bảng khác" | `NOT EXISTS` (tránh `NOT IN`) |
| Cần lấy cột của bảng khác để hiển thị | `JOIN` |
| Tổng hợp hai lần, hoặc nhiều bước | CTE `WITH` (hoặc subquery trong `FROM`) |
| So sánh mỗi dòng với nhóm của chính nó | Subquery tương quan (sau này: window function, Ngày 29) |

Về tốc độ: PostgreSQL thường tự viết lại `IN`, `EXISTS` thành phép JOIN tương đương, nên đừng chọn cách viết vì lời đồn "cái này nhanh hơn". Viết cho đúng và dễ đọc trước, đo bằng `EXPLAIN ANALYZE` khi cần ([Ngày 20](20-query-performance.md), [Ngày 28](28-sql-query-optimization.md)).

## Lỗi thường gặp

**1. Subquery vô hướng trả về nhiều dòng.** `WHERE price = (SELECT price FROM products WHERE category_id = 3)` lỗi `more than one row returned by a subquery used as an expression`. Dùng `IN` nếu muốn so với cả danh sách, hoặc dùng hàm tổng hợp (`MAX`, `AVG`) để còn một giá trị.

**2. NOT IN với danh sách có NULL.** Trả về 0 dòng mà không báo lỗi (mục 6). Dùng `NOT EXISTS`.

**3. Quên điều kiện tương quan trong EXISTS.** Thiếu `o.customer_id = c.customer_id`, subquery trở thành "có đơn nào trong năm 2026 không?", câu trả lời luôn là có, và mọi khách đều được chọn:

```sql
SELECT COUNT(*) AS so_khach
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.order_date >= '2026-07-01');
```

| so_khach |
| --- |
| 18 |

Đúng phải là 6 khách (mục 5). Mỗi khi viết `EXISTS`, kiểm tra subquery có nhắc tới alias của truy vấn ngoài chưa.

**4. Nhầm cột của truy vấn ngoài và truy vấn trong.** Trong subquery tương quan, cả hai đều có bảng `products`. Nếu viết `WHERE category_id = category_id` (không có alias), cả hai `category_id` đều được hiểu là của bảng gần nhất (bên trong), điều kiện luôn đúng với dòng có danh mục, và subquery trở thành trung bình của cả cửa hàng. Luôn đặt alias khác nhau (`p`, `p2`) và ghi rõ.

**5. Lồng quá nhiều tầng.** Ba tầng subquery lồng nhau thì rất khó đọc và sửa. Chuyển sang CTE, mỗi bước một tên.

## Bài tập

### Cơ bản

**Bài 1.** Liệt kê các sản phẩm có giá thấp hơn giá trung bình của cửa hàng, sắp xếp giá giảm dần.

<details>
<summary>Đáp án</summary>

```sql
SELECT sku, name, price
FROM products
WHERE price < (SELECT AVG(price) FROM products)
ORDER BY price DESC;
```

Kết quả:

| sku | name | price |
| --- | --- | --- |
| PC-003 | PC văn phòng DSC Basic | 9990000 |
| TAB-002 | Samsung Galaxy Tab S9 FE | 9490000 |
| ACC-004 | Tai nghe Sony WH-1000XM5 | 7990000 |
| PC-001 | Màn hình LG UltraGear 27 inch | 6490000 |
| ACC-005 | Tai nghe AirPods Pro 2 | 5990000 |
| ... | ... | ... |
| ACC-008 | Cáp USB-C to USB-C 1m | 150000 |

(... tổng 15 dòng)
</details>

**Bài 2.** Khách nào đã từng đặt mua một sản phẩm thuộc danh mục `Laptop gaming`? Dùng `IN`, không dùng `JOIN` ở truy vấn ngoài.

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id, full_name
FROM customers
WHERE customer_id IN (
    SELECT o.customer_id
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE oi.product_id IN (
        SELECT p.product_id
        FROM products p
        JOIN categories c ON c.category_id = p.category_id
        WHERE c.name = 'Laptop gaming'
    )
)
ORDER BY customer_id;
```

Kết quả:

| customer_id | full_name |
| --- | --- |
| 4 | Phạm Minh Duy |
| 6 | Võ Quốc Phong |
| 10 | Dương Minh Khoa |
| 14 | Huỳnh Tấn Phát |
| 18 | Mai Đức Uy |

Khách 4 có mặt vì đơn 5 (ASUS ROG) dù sau đó bị hủy; đề hỏi "đã từng đặt mua" nên vẫn tính.
</details>

**Bài 3.** Dùng `NOT EXISTS` tìm sản phẩm chưa từng xuất hiện trong đơn hàng nào.

<details>
<summary>Đáp án</summary>

```sql
SELECT p.sku, p.name
FROM products p
WHERE NOT EXISTS (SELECT 1
                  FROM order_items oi
                  WHERE oi.product_id = p.product_id);
```

Kết quả:

| sku | name |
| --- | --- |
| ACC-009 | Lót chuột DSC XXL |
</details>

### Vận dụng

**Bài 4.** Liệt kê các đơn của khách 1: mã đơn, ngày, trạng thái và tổng tiền đơn. Tính tổng tiền bằng subquery tương quan trong `SELECT`.

<details>
<summary>Đáp án</summary>

```sql
SELECT o.order_id,
       o.order_date::date AS ngay,
       o.status,
       (SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount)))
        FROM order_items oi
        WHERE oi.order_id = o.order_id) AS tong_tien
FROM orders o
WHERE o.customer_id = 1
ORDER BY o.order_id;
```

Kết quả:

| order_id | ngay | status | tong_tien |
| --- | --- | --- | --- |
| 1 | 2025-01-12 | delivered | 699000 |
| 4 | 2025-02-14 | delivered | 7881000 |
| 13 | 2025-07-08 | delivered | 2230000 |
| 25 | 2025-12-24 | delivered | 24980000 |
| 37 | 2026-09-02 | shipped | 9640000 |
</details>

**Bài 5.** Với mỗi danh mục có sản phẩm, tìm sản phẩm đắt nhất của danh mục đó.

<details>
<summary>Đáp án</summary>

```sql
SELECT p.category_id, p.sku, p.name, p.price
FROM products p
WHERE p.price = (SELECT MAX(p2.price)
                 FROM products p2
                 WHERE p2.category_id = p.category_id)
ORDER BY p.category_id;
```

Kết quả:

| category_id | sku | name | price |
| --- | --- | --- | --- |
| 3 | LAP-001 | ASUS ROG Strix G16 | 32990000 |
| 4 | LAP-005 | MacBook Air M2 13 inch | 24990000 |
| 5 | PC-003 | PC văn phòng DSC Basic | 9990000 |
| 7 | PHN-001 | iPhone 15 128GB | 19990000 |
| 8 | TAB-001 | iPad Air M2 11 inch | 16990000 |
| 10 | ACC-002 | Chuột Logitech MX Master 3S | 2490000 |
| 11 | ACC-004 | Tai nghe Sony WH-1000XM5 | 7990000 |
| 12 | ACC-007 | Sạc Anker 65W | 890000 |

Nếu hai sản phẩm cùng danh mục bằng giá cao nhất, cả hai đều được in. Đây là bài "top-1 mỗi nhóm"; Ngày 29 có cách tổng quát hơn với window function.
</details>

**Bài 6.** Trong năm 2025, tháng nào có nhiều đơn nhất (tính mọi trạng thái)? Nếu nhiều tháng bằng nhau thì in hết. Dùng CTE.

<details>
<summary>Đáp án</summary>

```sql
WITH theo_thang AS (
    SELECT DATE_TRUNC('month', order_date)::date AS thang,
           COUNT(*) AS so_don
    FROM orders
    WHERE order_date >= '2025-01-01'
      AND order_date <  '2026-01-01'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT thang, so_don
FROM theo_thang
WHERE so_don = (SELECT MAX(so_don) FROM theo_thang)
ORDER BY thang;
```

Kết quả:

| thang | so_don |
| --- | --- |
| 2025-09-01 | 3 |
| 2025-11-01 | 3 |

Dùng `ORDER BY so_don DESC LIMIT 1` sẽ chỉ in một trong hai tháng, mất tháng còn lại.
</details>

### Thử thách

**Bài 7.** Tìm khách chỉ mua online: đã có ít nhất một đơn, nhưng chưa từng có đơn `offline`.

<details>
<summary>Đáp án</summary>

```sql
SELECT c.customer_id, c.full_name
FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o
              WHERE o.customer_id = c.customer_id)
  AND NOT EXISTS (SELECT 1 FROM orders o
                  WHERE o.customer_id = c.customer_id
                    AND o.channel = 'offline')
ORDER BY c.customer_id;
```

Kết quả:

| customer_id | full_name |
| --- | --- |
| 13 | Phan Thị Oanh |
| 14 | Huỳnh Tấn Phát |
| 15 | Nguyễn Văn An |

Thiếu điều kiện `EXISTS` thứ nhất thì khách 16, 17 (chưa mua gì) cũng lọt vào, vì họ cũng "chưa từng mua offline".
</details>

**Bài 8.** Danh mục nào chiếm trên 20% tổng doanh thu (đơn có `status NOT IN ('pending', 'cancelled')`)? In doanh thu và tỷ lệ phần trăm, làm tròn 1 chữ số thập phân.

<details>
<summary>Đáp án</summary>

```sql
WITH doanh_thu AS (
    SELECT cat.name AS danh_muc,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS tien
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY cat.category_id, cat.name
)
SELECT danh_muc,
       ROUND(tien) AS doanh_thu,
       ROUND(100 * tien / (SELECT SUM(tien) FROM doanh_thu), 1) AS ty_le_phan_tram
FROM doanh_thu
WHERE tien > 0.2 * (SELECT SUM(tien) FROM doanh_thu)
ORDER BY tien DESC;
```

Kết quả:

| danh_muc | doanh_thu | ty_le_phan_tram |
| --- | --- | --- |
| Điện thoại | 135492500 | 25.3 |
| Laptop gaming | 135151000 | 25.2 |
</details>

## Tóm tắt

- Subquery là câu `SELECT` trong ngoặc, đặt bên trong câu khác. Trả về một giá trị thì dùng như một giá trị; trả về một cột thì dùng với `IN`, `ANY`, `ALL`; trả về một bảng thì đặt trong `FROM`.
- Subquery vô hướng dùng với `=`, `>` phải trả về tối đa một dòng, nếu không sẽ lỗi.
- Subquery thường tự chạy được và chỉ cần tính một lần. Subquery tương quan tham chiếu cột của truy vấn ngoài và (về mặt logic) được tính lại cho từng dòng ngoài.
- `EXISTS` hỏi "có ít nhất một dòng không". `NOT EXISTS` là cách an toàn cho câu hỏi "không có".
- `NOT IN` với danh sách có NULL luôn trả về 0 dòng. Tránh `NOT IN` với subquery trên cột có thể NULL.
- Subquery trong `FROM` (bảng dẫn xuất) cần alias, dùng để tổng hợp hai lần.
- CTE `WITH` đặt tên cho từng bước, đọc từ trên xuống, dùng lại được nhiều lần trong cùng câu lệnh. Gỡ lỗi bằng cách chạy từng CTE.

## Đọc thêm

- [PostgreSQL: Subquery Expressions (EXISTS, IN, ANY, ALL)](https://www.postgresql.org/docs/16/functions-subquery.html)
- [PostgreSQL: WITH Queries (CTE)](https://www.postgresql.org/docs/16/queries-with.html)
- [Vì sao NOT IN của bạn trả về 0 dòng? Logic ba trị của SQL và cái bẫy NULL](https://tiennhm.io.vn/blog/sql-null-not-in-three-valued-logic) — Một câu NOT IN trả về đúng 0 dòng trong khi bảng có dữ liệu, còn NOT EXISTS cùng ý định lại trả về đủ.
- [LEFT JOIN của bạn đã thành INNER JOIN mà không ai báo](https://tiennhm.io.vn/blog/left-join-thanh-inner-join) — Thêm một điều kiện WHERE lên cột của bảng bên phải là LEFT JOIN âm thầm biến thành INNER JOIN, và những dòng bạn cố tình giữ lại biến mất.
- [Luỹ kế của bạn sai ngay dòng đầu: window function, RANGE và cái mặc định ít ai đọc](https://tiennhm.io.vn/blog/window-function-vs-group-by) — GROUP BY gom 200.000 dòng thành 200, window function giữ nguyên cả 200.000 mà vẫn có số tổng của nhóm.

---

[⬅️ Ngày 10: Kết hợp nhiều bảng với JOIN](10-join.md) | [📚 Mục lục](../README.md) | [Ngày 12: UNION, INTERSECT và EXCEPT ➡️](12-union-intersect.md)
