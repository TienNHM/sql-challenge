# Ngày 14: Ôn tập 2 - Báo cáo trên DSC Shop

> **Tóm tắt:** Bài ôn tập chặng 2 (Ngày 8-13): hàm tổng hợp, GROUP BY/HAVING, JOIN, subquery và CTE, phép toán tập hợp, CASE. Thay vì các câu hỏi rời rạc, bạn sẽ viết một bộ báo cáo mà một cửa hàng thật cần: doanh thu theo tháng, theo danh mục, theo nhân viên, khách chưa mua, đối soát thanh toán. Mọi bài chỉ dùng kiến thức đã học, không dùng window function.

**Sau bài này bạn có thể:**

- Viết được báo cáo doanh thu theo thời gian, theo danh mục, theo kênh và theo nhân viên trên dữ liệu nhiều bảng.
- Chọn đúng công cụ cho câu hỏi "có ở A mà không có ở B": `NOT EXISTS`, `LEFT JOIN ... IS NULL`, `EXCEPT`.
- Nhận ra và sửa được lỗi nhân dòng khi JOIN rồi SUM, lỗi `COUNT(*)` với `LEFT JOIN`, bẫy `NOT IN` với `NULL`.
- Giải được bài "top 1 mỗi nhóm" và "so với tháng trước" chỉ bằng CTE, subquery và JOIN.

**Cần biết trước:** [Ngày 8](08-aggregate-functions.md), [Ngày 9](09-group-by-having.md), [Ngày 10](10-join.md), [Ngày 11](11-subquery.md), [Ngày 12](12-union-intersect.md), [Ngày 13](13-case-when.md)

## Nhìn lại chặng 2

| Ngày | Chủ đề | Câu hỏi nó trả lời | Bẫy hay gặp |
| --- | --- | --- | --- |
| 8 | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` | Bao nhiêu? Tổng bao nhiêu? | `COUNT(*)` khác `COUNT(cot)`; hàm tổng hợp bỏ qua `NULL` |
| 9 | `GROUP BY`, `HAVING` | ... theo từng nhóm? | Lọc hàm tổng hợp phải ở `HAVING`, không ở `WHERE` |
| 10 | `JOIN` | Dữ liệu nằm ở nhiều bảng | Nhân dòng khi JOIN rồi `SUM`; điều kiện ở `WHERE` biến `LEFT JOIN` thành `INNER JOIN` |
| 11 | Subquery, `EXISTS`, CTE | So với một con số tính từ chính dữ liệu; có hay không có | `NOT IN` gặp `NULL` trả 0 dòng |
| 12 | `UNION`, `INTERSECT`, `EXCEPT` | Gộp, phần chung, phần chênh lệch | `UNION` loại trùng làm mất dòng thật |
| 13 | `CASE`, `FILTER` | Phân loại, đếm/cộng có điều kiện, pivot | Thứ tự `WHEN`; thiếu `ELSE` thành `NULL` |

Thứ tự thực thi logic của một câu `SELECT` (Ngày 9) là chìa khóa cho phần lớn các lỗi trên:

```mermaid
flowchart LR
    F["FROM / JOIN"] --> W["WHERE"] --> G["GROUP BY"] --> H["HAVING"] --> S["SELECT"] --> O["ORDER BY / LIMIT"]
```

## Quy ước dùng trong bài

Để các báo cáo nhất quán với nhau, bài này dùng hai định nghĩa:

- **Đơn đã thanh toán:** `status NOT IN ('pending', 'cancelled')`. Đơn `pending` chưa trả tiền, đơn `cancelled` đã hủy. Đây cũng là các đơn có dòng trong bảng `payments`.
- **Doanh thu** của một dòng hàng: `quantity * unit_price * (1 - discount)`. Doanh thu của đơn, của tháng, ... là tổng các dòng hàng tương ứng. Dùng `unit_price` (giá lúc mua), không dùng `products.price` (giá hiện tại).

Số tiền có chiết khấu sẽ có phần thập phân `.00`, nên các báo cáo bọc `ROUND(...)` để in gọn. Tất cả bài chỉ đọc dữ liệu.

Cách làm: đọc đề, tự viết và chạy, so với kết quả trong phần Đáp án. Kết quả của bạn phải **giống từng con số**; nếu lệch, tìm xem bạn hiểu sai đề hay viết sai truy vấn.

## Phần A: Khởi động

**Bài A1.** Đếm số đơn theo từng trạng thái, sắp theo vòng đời đơn hàng: `pending`, `paid`, `shipped`, `delivered`, rồi `cancelled`.

<details>
<summary>Đáp án</summary>

```sql
SELECT status, COUNT(*) AS so_don
FROM orders
GROUP BY status
ORDER BY CASE status
             WHEN 'pending'   THEN 1
             WHEN 'paid'      THEN 2
             WHEN 'shipped'   THEN 3
             WHEN 'delivered' THEN 4
             ELSE 5
         END;
```

Kết quả:

| status | so_don |
| --- | --- |
| pending | 1 |
| paid | 2 |
| shipped | 1 |
| delivered | 33 |
| cancelled | 3 |

</details>

**Bài A2.** Với mỗi kênh bán (`online`, `offline`), tính số đơn đã thanh toán, doanh thu, giá trị trung bình mỗi đơn và đơn lớn nhất.

Gợi ý: "trung bình mỗi đơn" phải tính trên **tổng tiền của đơn**, không phải trên từng dòng hàng. Hãy tính tổng tiền mỗi đơn trong một CTE trước.

<details>
<summary>Đáp án</summary>

```sql
WITH tong_don AS (
    SELECT o.order_id, o.channel,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS tien
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.order_id, o.channel
)
SELECT channel,
       COUNT(*)         AS so_don,
       ROUND(SUM(tien)) AS doanh_thu,
       ROUND(AVG(tien)) AS gia_tri_tb_don,
       ROUND(MAX(tien)) AS don_lon_nhat
FROM tong_don
GROUP BY channel
ORDER BY doanh_thu DESC;
```

Kết quả:

| channel | so_don | doanh_thu | gia_tri_tb_don | don_lon_nhat |
| --- | --- | --- | --- | --- |
| online | 21 | 324642500 | 15459167 | 39980000 |
| offline | 15 | 211648500 | 14109900 | 31340500 |

Nếu bỏ CTE và viết thẳng `AVG(oi.quantity * oi.unit_price * (1 - oi.discount))` trên bảng JOIN, bạn được trung bình mỗi **dòng hàng**, một con số khác hẳn.

</details>

## Phần B: Báo cáo doanh thu

**Bài B1.** Doanh thu và số đơn đã thanh toán theo từng tháng của năm 2025.

<details>
<summary>Đáp án</summary>

```sql
SELECT DATE_TRUNC('month', o.order_date)::date AS thang,
       COUNT(DISTINCT o.order_id) AS so_don,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status NOT IN ('pending', 'cancelled')
  AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
GROUP BY thang
ORDER BY thang;
```

Kết quả:

| thang | so_don | doanh_thu |
| --- | --- | --- |
| 2025-01-01 | 2 | 27689000 |
| 2025-02-01 | 2 | 13661000 |
| 2025-03-01 | 1 | 1380000 |
| 2025-04-01 | 2 | 42379500 |
| 2025-05-01 | 2 | 16570000 |
| 2025-06-01 | 2 | 50769000 |
| 2025-07-01 | 2 | 11720000 |
| 2025-08-01 | 1 | 8980000 |
| 2025-09-01 | 3 | 43568500 |
| 2025-10-01 | 1 | 18990000 |
| 2025-11-01 | 3 | 40762500 |
| 2025-12-01 | 2 | 49661000 |

Ba điểm cần để ý:

- `COUNT(DISTINCT o.order_id)` chứ không phải `COUNT(*)`: sau khi JOIN, mỗi đơn có nhiều dòng (một dòng mỗi sản phẩm).
- `DATE_TRUNC('month', ...)` giữ cả năm lẫn tháng. Nếu nhóm theo `EXTRACT(MONTH FROM order_date)` mà không lọc năm, tháng 1/2025 và tháng 1/2026 bị cộng chung: tháng 1 sẽ ra 61719500, là tổng của hai tháng ở hai năm khác nhau.
- Lọc khoảng thời gian bằng `>=` và `<` ngày đầu kỳ sau, không dùng `BETWEEN '2025-01-01' AND '2025-12-31'` vì cột là `TIMESTAMPTZ` và sẽ bỏ sót các đơn trong ngày 31/12 sau 00:00.

</details>

**Bài B2.** Vẫn báo cáo theo tháng nhưng trên **toàn bộ** dữ liệu (cả hai năm), và chỉ giữ những tháng có doanh thu từ 40 triệu trở lên.

<details>
<summary>Đáp án</summary>

```sql
SELECT DATE_TRUNC('month', o.order_date)::date AS thang,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status NOT IN ('pending', 'cancelled')
GROUP BY thang
HAVING SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) >= 40000000
ORDER BY thang;
```

Kết quả:

| thang | doanh_thu |
| --- | --- |
| 2025-04-01 | 42379500 |
| 2025-06-01 | 50769000 |
| 2025-09-01 | 43568500 |
| 2025-11-01 | 40762500 |
| 2025-12-01 | 49661000 |

Điều kiện về trạng thái đơn lọc từng dòng nên ở `WHERE`; điều kiện về tổng doanh thu lọc từng nhóm nên ở `HAVING`.

</details>

**Bài B3.** Doanh thu theo danh mục. Hiện mọi danh mục **lá** (danh mục không có danh mục con), kể cả danh mục chưa bán được gì, kèm tên danh mục cha, số sản phẩm, tổng số lượng bán và doanh thu. Sắp theo doanh thu giảm dần.

Gợi ý: tính doanh thu theo sản phẩm trong CTE trước, rồi đi từ `categories` bằng `LEFT JOIN`. Danh mục lá là danh mục mà không tồn tại danh mục nào có `parent_id` trỏ tới nó.

<details>
<summary>Đáp án</summary>

```sql
WITH doanh_thu_sp AS (
    SELECT oi.product_id,
           SUM(oi.quantity) AS so_luong,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS doanh_thu
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY oi.product_id
)
SELECT c.name                               AS danh_muc,
       cha.name                             AS danh_muc_cha,
       COUNT(p.product_id)                  AS so_sp,
       COALESCE(SUM(d.so_luong), 0)         AS so_luong_ban,
       COALESCE(ROUND(SUM(d.doanh_thu)), 0) AS doanh_thu
FROM categories c
LEFT JOIN categories cha ON cha.category_id = c.parent_id
LEFT JOIN products p     ON p.category_id = c.category_id
LEFT JOIN doanh_thu_sp d ON d.product_id = p.product_id
WHERE NOT EXISTS (SELECT 1 FROM categories con WHERE con.parent_id = c.category_id)
GROUP BY c.category_id, c.name, cha.name
ORDER BY doanh_thu DESC, danh_muc;
```

Kết quả:

| danh_muc | danh_muc_cha | so_sp | so_luong_ban | doanh_thu |
| --- | --- | --- | --- | --- |
| Điện thoại | Điện thoại & Tablet | 4 | 12 | 135492500 |
| Laptop gaming | Laptop | 3 | 5 | 135151000 |
| Laptop văn phòng | Laptop | 3 | 5 | 104700500 |
| Máy tính bảng | Điện thoại & Tablet | 2 | 4 | 52960000 |
| Tai nghe & Loa | Phụ kiện | 3 | 7 | 42833000 |
| PC & Màn hình | Máy tính | 3 | 7 | 42330000 |
| Chuột & Bàn phím | Phụ kiện | 4 | 12 | 15534000 |
| Sạc & Cáp | Phụ kiện | 2 | 19 | 7290000 |
| Thiết bị mạng | *(NULL)* | 0 | 0 | 0 |

Vì sao phải tính trong CTE trước? Nếu JOIN thẳng `products` với `order_items` và `orders` rồi lọc `o.status IN (...)` ở `WHERE`, các danh mục không có dòng hàng sẽ bị loại (`LEFT JOIN` thành `INNER JOIN`). Còn nếu đưa điều kiện trạng thái vào `ON` của `orders`, dòng hàng của đơn bị hủy vẫn còn trong `order_items` và vẫn bị cộng vào `SUM`. Tách CTE giúp mỗi bước làm đúng một việc.

`COUNT(p.product_id)` (không phải `COUNT(*)`) cho 0 ở "Thiết bị mạng"; `COUNT(*)` sẽ cho 1 vì `LEFT JOIN` vẫn giữ một dòng cho danh mục đó.

</details>

**Bài B4.** Top 5 sản phẩm có doanh thu cao nhất, kèm tổng số lượng bán.

<details>
<summary>Đáp án</summary>

```sql
SELECT p.sku, p.name,
       SUM(oi.quantity) AS so_luong,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status NOT IN ('pending', 'cancelled')
GROUP BY p.product_id, p.sku, p.name
ORDER BY doanh_thu DESC
LIMIT 5;
```

Kết quả:

| sku | name | so_luong | doanh_thu |
| --- | --- | --- | --- |
| PHN-001 | iPhone 15 128GB | 4 | 78960500 |
| LAP-002 | Lenovo Legion 5 | 2 | 59980000 |
| LAP-005 | MacBook Air M2 13 inch | 2 | 50730500 |
| LAP-003 | Acer Nitro V 15 | 2 | 43830500 |
| LAP-004 | Dell Inspiron 14 | 2 | 36980000 |

</details>

**Bài B5.** Doanh số của từng nhân viên bán hàng (chức danh có chữ "bán hàng"): tên, chức danh, tên quản lý trực tiếp, số đơn đã thanh toán đã bán và doanh thu. Nhân viên chưa bán đơn nào vẫn phải hiện với số 0.

<details>
<summary>Đáp án</summary>

```sql
WITH ban_hang AS (
    SELECT o.employee_id,
           COUNT(DISTINCT o.order_id) AS so_don,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS doanh_thu
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
      AND o.employee_id IS NOT NULL
    GROUP BY o.employee_id
)
SELECT e.full_name                     AS nhan_vien,
       e.title                         AS chuc_danh,
       m.full_name                     AS quan_ly,
       COALESCE(b.so_don, 0)           AS so_don,
       COALESCE(ROUND(b.doanh_thu), 0) AS doanh_thu
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
LEFT JOIN ban_hang b  ON b.employee_id = e.employee_id
WHERE e.title ILIKE '%bán hàng%'
ORDER BY doanh_thu DESC;
```

Kết quả:

| nhan_vien | chuc_danh | quan_ly | so_don | doanh_thu |
| --- | --- | --- | --- | --- |
| Vũ Hoài Nam | Nhân viên bán hàng | Lê Thị Hạnh | 4 | 82907500 |
| Phạm Thị Thu | Nhân viên bán hàng | Lê Thị Hạnh | 5 | 63700000 |
| Đỗ Minh Tuấn | Nhân viên bán hàng | Lê Thị Hạnh | 5 | 63401000 |
| Kiều Anh Thư | Thực tập sinh bán hàng | Phạm Thị Thu | 1 | 1640000 |

Bảng `employees` xuất hiện hai lần với hai alias khác nhau (`e` là nhân viên, `m` là quản lý): đó là SELF JOIN của Ngày 10. `ILIKE` để không phân biệt hoa thường.

</details>

## Phần C: Khách hàng

**Bài C1.** Tìm khách chưa từng đặt đơn nào, bằng hai cách: `NOT EXISTS` và `LEFT JOIN ... IS NULL`. Hiện mã, tên, ngày đăng ký.

<details>
<summary>Đáp án</summary>

```sql
SELECT c.customer_id, c.full_name, c.created_at::date AS ngay_dang_ky
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
ORDER BY c.customer_id;
```

```sql
SELECT c.customer_id, c.full_name, c.created_at::date AS ngay_dang_ky
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;
```

Kết quả (cả hai cách):

| customer_id | full_name | ngay_dang_ky |
| --- | --- | --- |
| 16 | Tạ Quang Sơn | 2025-11-20 |
| 17 | Châu Ngọc Trâm | 2026-01-15 |

Ở cách `LEFT JOIN`, điều kiện `IS NULL` phải đặt trên một cột **không thể** `NULL` khi ghép được, như khóa chính `o.order_id`. Dùng `EXCEPT` (Ngày 12) cũng ra đúng `customer_id` 16 và 17, nhưng chỉ trả về cột đem so sánh.

</details>

**Bài C2.** Tìm khách đã mua ở **cả hai** kênh online và offline, chỉ tính đơn không bị hủy. Giải bằng `INTERSECT`, rồi giải lại bằng `GROUP BY ... HAVING` và hiện thêm số đơn mỗi kênh.

<details>
<summary>Đáp án</summary>

```sql
SELECT c.customer_id, c.full_name
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
WHERE o.channel = 'online' AND o.status <> 'cancelled'
INTERSECT
SELECT c.customer_id, c.full_name
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
WHERE o.channel = 'offline' AND o.status <> 'cancelled'
ORDER BY customer_id;
```

```sql
SELECT c.customer_id, c.full_name,
       COUNT(*) FILTER (WHERE o.channel = 'online')  AS don_online,
       COUNT(*) FILTER (WHERE o.channel = 'offline') AS don_offline
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status <> 'cancelled'
GROUP BY c.customer_id, c.full_name
HAVING COUNT(DISTINCT o.channel) = 2
ORDER BY c.customer_id;
```

Kết quả của cách thứ hai:

| customer_id | full_name | don_online | don_offline |
| --- | --- | --- | --- |
| 1 | Nguyễn Văn An | 3 | 2 |
| 2 | Trần Thị Bình | 2 | 2 |
| 3 | Lê Hoàng Cường | 2 | 1 |
| 4 | Phạm Minh Duy | 1 | 1 |
| 6 | Võ Quốc Phong | 2 | 1 |
| 7 | Đặng Thu Giang | 1 | 1 |
| 8 | Bùi Văn Hùng | 1 | 1 |
| 9 | Ngô Thị Lan | 1 | 1 |
| 10 | Dương Minh Khoa | 1 | 1 |
| 11 | Lý Thanh Mai | 1 | 1 |
| 18 | Mai Đức Uy | 1 | 1 |

Cách `INTERSECT` trả đúng 11 khách này (hai cột đầu). Khách 5 và 12 có cả hai kênh nếu tính cả đơn bị hủy, nhưng đơn online của họ đã hủy nên bị loại. Cách `HAVING COUNT(DISTINCT channel) = 2` chạy được ở mọi hệ quản trị, kể cả MySQL cũ không có `INTERSECT`.

</details>

**Bài C3.** Tìm khách có tổng chi tiêu (đơn đã thanh toán) **cao hơn mức trung bình** của những khách đã mua.

<details>
<summary>Đáp án</summary>

```sql
WITH chi_tieu AS (
    SELECT o.customer_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS tong_chi
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.customer_id
)
SELECT c.customer_id, c.full_name, ROUND(ct.tong_chi) AS tong_chi
FROM chi_tieu ct
JOIN customers c ON c.customer_id = ct.customer_id
WHERE ct.tong_chi > (SELECT AVG(tong_chi) FROM chi_tieu)
ORDER BY ct.tong_chi DESC;
```

Kết quả:

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

Mức trung bình là khoảng 33,5 triệu (tính trên 16 khách đã mua). Không thể viết `WHERE SUM(...) > AVG(SUM(...))`: hàm tổng hợp không lồng nhau được, nên phải tính tổng trước trong CTE rồi so với một subquery vô hướng. Có `customer_id` trong kết quả nên hai khách cùng tên vẫn phân biệt được.

</details>

**Bài C4.** Khách "trung thành": có từ 3 đơn không bị hủy trở lên. Hiện số đơn, ngày đơn đầu tiên và ngày đơn gần nhất.

<details>
<summary>Đáp án</summary>

```sql
SELECT c.customer_id, c.full_name,
       COUNT(*)                AS so_don,
       MIN(o.order_date)::date AS don_dau,
       MAX(o.order_date)::date AS don_gan_nhat
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status <> 'cancelled'
GROUP BY c.customer_id, c.full_name
HAVING COUNT(*) >= 3
ORDER BY so_don DESC, c.customer_id;
```

Kết quả:

| customer_id | full_name | so_don | don_dau | don_gan_nhat |
| --- | --- | --- | --- | --- |
| 1 | Nguyễn Văn An | 5 | 2025-01-12 | 2026-09-02 |
| 2 | Trần Thị Bình | 4 | 2025-01-20 | 2026-06-15 |
| 3 | Lê Hoàng Cường | 3 | 2025-02-03 | 2026-10-14 |
| 6 | Võ Quốc Phong | 3 | 2025-04-05 | 2026-07-07 |

Ở đây `COUNT(*)` đếm đúng số đơn vì không JOIN `order_items`: mỗi dòng là một đơn.

</details>

## Phần D: Đối soát và chất lượng dữ liệu

**Bài D1.** Kế toán muốn đối soát: với mỗi đơn, tổng tiền hàng có khớp với tổng tiền đã thanh toán không? Một bạn viết:

```sql
SELECT o.order_id,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS tien_hang,
       SUM(pm.amount)                                        AS da_tra
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN payments pm    ON pm.order_id = o.order_id
WHERE o.order_id IN (4, 12)
GROUP BY o.order_id
ORDER BY o.order_id;
```

| order_id | tien_hang | da_tra |
| --- | --- | --- |
| 4 | 7881000.00 | 15762000 |
| 12 | 63760000.00 | 63760000 |

Đơn 4 "đã trả" gấp đôi tiền hàng, còn đơn 12 thì tiền hàng gấp đôi thực tế. Giải thích vì sao, rồi viết lại truy vấn đúng cho các đơn 4, 5, 12, 40, có cột kết luận đối soát.

<details>
<summary>Đáp án</summary>

Đây là lỗi **nhân dòng khi JOIN rồi SUM** (Ngày 10). Đơn 4 có 2 dòng hàng và 1 lần thanh toán: JOIN ra 2 × 1 = 2 dòng, nên khoản thanh toán bị cộng 2 lần. Đơn 12 có 2 dòng hàng và 2 lần trả góp: JOIN ra 2 × 2 = 4 dòng, mỗi dòng hàng bị cộng 2 lần. Cách sửa: tổng hợp **từng bảng riêng** về mức đơn hàng trước, rồi mới JOIN.

```sql
WITH tien_hang AS (
    SELECT order_id, SUM(quantity * unit_price * (1 - discount)) AS tien_hang
    FROM order_items
    GROUP BY order_id
),
da_tra AS (
    SELECT order_id, SUM(amount) AS da_tra, COUNT(*) AS so_lan_tra
    FROM payments
    GROUP BY order_id
)
SELECT o.order_id, o.status,
       ROUND(th.tien_hang)        AS tien_hang,
       COALESCE(dt.da_tra, 0)     AS da_tra,
       COALESCE(dt.so_lan_tra, 0) AS so_lan_tra,
       CASE
           WHEN o.status IN ('pending', 'cancelled') AND dt.da_tra IS NULL THEN 'OK: chưa cần thu'
           WHEN dt.da_tra = th.tien_hang                                   THEN 'OK'
           WHEN dt.da_tra IS NULL                                          THEN 'Thiếu thanh toán'
           ELSE 'Lệch tiền'
       END AS doi_soat
FROM orders o
JOIN tien_hang th   ON th.order_id = o.order_id
LEFT JOIN da_tra dt ON dt.order_id = o.order_id
WHERE o.order_id IN (4, 5, 12, 40)
ORDER BY o.order_id;
```

Kết quả:

| order_id | status | tien_hang | da_tra | so_lan_tra | doi_soat |
| --- | --- | --- | --- | --- | --- |
| 4 | delivered | 7881000 | 7881000 | 1 | OK |
| 5 | cancelled | 32990000 | 0 | 0 | OK: chưa cần thu |
| 12 | delivered | 31880000 | 31880000 | 2 | OK |
| 40 | pending | 4890000 | 0 | 0 | OK: chưa cần thu |

Bỏ dòng `WHERE o.order_id IN (...)`, thay `SELECT` bằng `doi_soat, COUNT(*)` và `GROUP BY doi_soat`, bạn sẽ thấy cả 40 đơn đều khớp: 36 đơn "OK" và 4 đơn "OK: chưa cần thu".

</details>

**Bài D2.** Phân bố đơn đã thanh toán theo giá trị: dưới 5 triệu, 5 đến dưới 20 triệu, từ 20 triệu. Mỗi nhóm cho biết số đơn, doanh thu và tỷ trọng doanh thu (%).

<details>
<summary>Đáp án</summary>

```sql
WITH tong_don AS (
    SELECT o.order_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS tien
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.order_id
)
SELECT CASE
           WHEN tien < 5000000  THEN '1. Dưới 5 triệu'
           WHEN tien < 20000000 THEN '2. 5 - 20 triệu'
           ELSE '3. Từ 20 triệu'
       END AS nhom_gia_tri,
       COUNT(*)         AS so_don,
       ROUND(SUM(tien)) AS doanh_thu,
       ROUND(100.0 * SUM(tien) / (SELECT SUM(tien) FROM tong_don), 1) AS ty_trong_pct
FROM tong_don
GROUP BY nhom_gia_tri
ORDER BY nhom_gia_tri;
```

Kết quả:

| nhom_gia_tri | so_don | doanh_thu | ty_trong_pct |
| --- | --- | --- | --- |
| 1. Dưới 5 triệu | 7 | 16106000 | 3.0 |
| 2. 5 - 20 triệu | 18 | 222083500 | 41.4 |
| 3. Từ 20 triệu | 11 | 298101500 | 55.6 |

Đánh số "1.", "2.", "3." ở đầu nhãn là mẹo để `ORDER BY` theo chữ cái cũng ra đúng thứ tự. 11 đơn lớn mang về hơn một nửa doanh thu.

</details>

## Phần E: Thử thách

**Bài E1.** Với mỗi danh mục, tìm sản phẩm bán được **nhiều nhất** (theo tổng số lượng, đơn đã thanh toán). Nếu hòa thì hiện tất cả sản phẩm đồng hạng. Không dùng window function.

<details>
<summary>Đáp án</summary>

Ý tưởng: tính số lượng bán mỗi sản phẩm trong CTE, rồi giữ sản phẩm có số lượng bằng `MAX` của **chính danh mục đó** (subquery tương quan, Ngày 11).

```sql
WITH ban_theo_sp AS (
    SELECT p.category_id, p.product_id, p.name,
           SUM(oi.quantity) AS so_luong
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY p.category_id, p.product_id, p.name
)
SELECT c.name AS danh_muc, b.name AS san_pham, b.so_luong
FROM ban_theo_sp b
JOIN categories c ON c.category_id = b.category_id
WHERE b.so_luong = (
    SELECT MAX(b2.so_luong)
    FROM ban_theo_sp b2
    WHERE b2.category_id = b.category_id
)
ORDER BY c.name, b.name;
```

Kết quả:

| danh_muc | san_pham | so_luong |
| --- | --- | --- |
| Chuột & Bàn phím | Chuột Logitech G102 | 6 |
| Điện thoại | iPhone 15 128GB | 4 |
| Điện thoại | Xiaomi Redmi Note 13 | 4 |
| Laptop gaming | Acer Nitro V 15 | 2 |
| Laptop gaming | Lenovo Legion 5 | 2 |
| Laptop văn phòng | Dell Inspiron 14 | 2 |
| Laptop văn phòng | MacBook Air M2 13 inch | 2 |
| Máy tính bảng | iPad Air M2 11 inch | 2 |
| Máy tính bảng | Samsung Galaxy Tab S9 FE | 2 |
| PC & Màn hình | Màn hình Dell P2422H | 3 |
| PC & Màn hình | Màn hình LG UltraGear 27 inch | 3 |
| Sạc & Cáp | Cáp USB-C to USB-C 1m | 13 |
| Tai nghe & Loa | Tai nghe AirPods Pro 2 | 3 |
| Tai nghe & Loa | Tai nghe Sony WH-1000XM5 | 3 |

Dữ liệu nhỏ nên nhiều danh mục bị hòa. Cách này tự nhiên giữ tất cả sản phẩm đồng hạng. Ở [Ngày 29](29-recursive-queries-window-functions.md) bạn sẽ học `RANK()`/`ROW_NUMBER()` để giải bài "top N mỗi nhóm" gọn hơn và chọn được cách xử lý khi hòa.

</details>

**Bài E2.** Báo cáo doanh thu từng tháng của năm 2026, kèm doanh thu tháng trước và tỷ lệ tăng trưởng (%) so với tháng trước. Không dùng window function.

<details>
<summary>Đáp án</summary>

Ý tưởng: tính doanh thu theo tháng trong CTE, rồi JOIN CTE với **chính nó** theo điều kiện "tháng của bảng kia = tháng này trừ 1 tháng".

```sql
WITH theo_thang AS (
    SELECT DATE_TRUNC('month', o.order_date) AS thang,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount)) AS doanh_thu
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY thang
)
SELECT t.thang::date       AS thang,
       ROUND(t.doanh_thu)  AS doanh_thu,
       ROUND(tr.doanh_thu) AS thang_truoc,
       ROUND(100.0 * (t.doanh_thu - tr.doanh_thu) / tr.doanh_thu, 1) AS tang_truong_pct
FROM theo_thang t
LEFT JOIN theo_thang tr ON tr.thang = t.thang - INTERVAL '1 month'
WHERE t.thang >= '2026-01-01'
ORDER BY t.thang;
```

Kết quả:

| thang | doanh_thu | thang_truoc | tang_truong_pct |
| --- | --- | --- | --- |
| 2026-01-01 | 34030500 | 49661000 | -31.5 |
| 2026-02-01 | 11560000 | 34030500 | -66.0 |
| 2026-03-01 | 18490000 | 11560000 | 59.9 |
| 2026-04-01 | 17759000 | 18490000 | -4.0 |
| 2026-05-01 | 21990000 | 17759000 | 23.8 |
| 2026-06-01 | 1640000 | 21990000 | -92.5 |
| 2026-07-01 | 17091000 | 1640000 | 942.1 |
| 2026-08-01 | 29990000 | 17091000 | 75.5 |
| 2026-09-01 | 17630000 | 29990000 | -41.2 |
| 2026-10-01 | 39980000 | 17630000 | 126.8 |

Lọc `WHERE t.thang >= '2026-01-01'` đặt **sau** khi JOIN nên tháng 1/2026 vẫn tìm được tháng 12/2025 để so sánh. Nếu lọc năm 2026 ngay trong CTE, tháng 1 sẽ không có tháng trước. Dùng `LEFT JOIN` để tháng không có tháng trước (hoặc tháng trước không có doanh thu) vẫn hiện, với `thang_truoc` là `NULL`. Tháng 10/2026 mới có nửa tháng nên so sánh chưa công bằng. [Ngày 29](29-recursive-queries-window-functions.md) sẽ giải bài này bằng `LAG()`.

</details>

**Bài E3.** Bảng chéo doanh thu theo danh mục và năm: mỗi danh mục một dòng, cột `nam_2025`, `nam_2026`, và cột tỷ trọng (%) của danh mục trên tổng doanh thu. Sắp theo tỷ trọng giảm dần.

<details>
<summary>Đáp án</summary>

```sql
WITH dong_hang AS (
    SELECT c.category_id, c.name AS danh_muc, o.order_date,
           oi.quantity * oi.unit_price * (1 - oi.discount) AS tien
    FROM order_items oi
    JOIN orders o     ON o.order_id = oi.order_id
    JOIN products p   ON p.product_id = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE o.status NOT IN ('pending', 'cancelled')
)
SELECT danh_muc,
       ROUND(SUM(tien) FILTER (WHERE order_date <  '2026-01-01')) AS nam_2025,
       ROUND(SUM(tien) FILTER (WHERE order_date >= '2026-01-01')) AS nam_2026,
       ROUND(100.0 * SUM(tien) / (SELECT SUM(tien) FROM dong_hang), 1) AS ty_trong_pct
FROM dong_hang
GROUP BY category_id, danh_muc
ORDER BY ty_trong_pct DESC;
```

Kết quả:

| danh_muc | nam_2025 | nam_2026 | ty_trong_pct |
| --- | --- | --- | --- |
| Điện thoại | 68641500 | 66851000 | 25.3 |
| Laptop gaming | 51830500 | 83320500 | 25.2 |
| Laptop văn phòng | 86210500 | 18490000 | 19.5 |
| Máy tính bảng | 43470000 | 9490000 | 9.9 |
| Tai nghe & Loa | 32153000 | 10680000 | 8.0 |
| PC & Màn hình | 29350000 | 12980000 | 7.9 |
| Chuột & Bàn phím | 10755000 | 4779000 | 2.9 |
| Sạc & Cáp | 3720000 | 3570000 | 1.4 |

CTE `dong_hang` gom các JOIN và điều kiện lọc vào một chỗ, nên cả truy vấn chính lẫn subquery tính tổng đều dùng lại được mà không phải chép điều kiện hai lần.

</details>

**Bài E4. Tìm lỗi.** Mỗi truy vấn sau đều có lỗi. Đoán kết quả trước khi chạy, giải thích nguyên nhân và sửa lại.

(a) Đếm số đơn của khách 15, 16, 17:

```sql
SELECT c.customer_id, c.full_name, COUNT(*) AS so_don
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE c.customer_id IN (15, 16, 17)
GROUP BY c.customer_id, c.full_name
ORDER BY c.customer_id;
```

(b) Nhân viên chưa từng bán đơn nào:

```sql
SELECT employee_id, full_name
FROM employees
WHERE employee_id NOT IN (SELECT employee_id FROM orders);
```

(c) Khách có từ 3 đơn:

```sql
SELECT customer_id, COUNT(*)
FROM orders
WHERE COUNT(*) >= 3
GROUP BY customer_id;
```

<details>
<summary>Đáp án</summary>

**(a)** Kết quả sai: khách 16 và 17 chưa mua nhưng hiện `so_don = 1`.

| customer_id | full_name | so_don |
| --- | --- | --- |
| 15 | Nguyễn Văn An | 2 |
| 16 | Tạ Quang Sơn | 1 |
| 17 | Châu Ngọc Trâm | 1 |

`LEFT JOIN` vẫn giữ một dòng cho khách không có đơn (các cột của `orders` là `NULL`), và `COUNT(*)` đếm cả dòng đó. Sửa thành `COUNT(o.order_id)` để chỉ đếm dòng có đơn thật:

```sql
SELECT c.customer_id, c.full_name, COUNT(o.order_id) AS so_don
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE c.customer_id IN (15, 16, 17)
GROUP BY c.customer_id, c.full_name
ORDER BY c.customer_id;
```

| customer_id | full_name | so_don |
| --- | --- | --- |
| 15 | Nguyễn Văn An | 2 |
| 16 | Tạ Quang Sơn | 0 |
| 17 | Châu Ngọc Trâm | 0 |

**(b)** Kết quả: 0 dòng, dù rõ ràng giám đốc chưa bán đơn nào. Cột `orders.employee_id` có `NULL` (mọi đơn online). `x NOT IN (..., NULL)` không bao giờ đúng (chỉ sai hoặc `NULL`), nên mọi nhân viên bị loại. Đây là bẫy `NOT IN` của Ngày 11. Sửa bằng `NOT EXISTS`:

```sql
SELECT e.employee_id, e.full_name, e.title
FROM employees e
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.employee_id = e.employee_id)
ORDER BY e.employee_id;
```

| employee_id | full_name | title |
| --- | --- | --- |
| 1 | Nguyễn Thành Long | Giám đốc |
| 2 | Lê Thị Hạnh | Trưởng phòng Kinh doanh |
| 3 | Trần Quốc Bảo | Trưởng phòng Kỹ thuật |
| 7 | Lâm Gia Huy | Kỹ thuật viên |

**(c)** Lỗi ngay khi chạy:

```text
ERROR:  aggregate functions are not allowed in WHERE
```

`WHERE` chạy trước `GROUP BY`, lúc đó chưa có nhóm nào để đếm. Điều kiện trên hàm tổng hợp phải ở `HAVING`:

```sql
SELECT customer_id, COUNT(*) AS so_don
FROM orders
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY customer_id;
```

| customer_id | so_don |
| --- | --- |
| 1 | 5 |
| 2 | 4 |
| 3 | 3 |
| 4 | 3 |
| 6 | 3 |

Kết quả có thêm khách 4 so với Bài C4: truy vấn này đếm cả đơn bị hủy (đơn 5 của khách 4). Đề "có từ 3 đơn" chưa nói rõ có tính đơn hủy không; trong báo cáo thật, hãy hỏi lại người yêu cầu và ghi định nghĩa vào báo cáo.

</details>

## Tự đánh giá

Có 16 bài (A1-A2, B1-B5, C1-C4, D1-D2, E1-E4). Tự chấm mỗi bài 1 điểm nếu kết quả của bạn khớp từng con số, không cần giống từng chữ trong câu lệnh.

- **Từ 13 điểm:** sẵn sàng sang chặng 3 (index, transaction, function, trigger, view).
- **9 đến 12 điểm:** ôn lại các ngày ứng với bài làm sai trước khi đi tiếp.
- **Dưới 9 điểm:** làm lại phần bài tập của Ngày 9, 10, 11 rồi quay lại bài này.

Nếu chỉ chọn một thói quen để mang theo: **trước khi `SUM` trên kết quả JOIN, hãy tự hỏi mỗi dòng đang đại diện cho cái gì** (một đơn? một dòng hàng? một lần thanh toán?). Phần lớn báo cáo sai trong thực tế bắt đầu từ câu hỏi này.

## Tóm tắt

- Thống nhất định nghĩa trước khi viết báo cáo (đơn nào được tính, doanh thu tính thế nào), và dùng lại cùng định nghĩa ở mọi truy vấn.
- Tổng hợp ở đúng "mức": tính tổng theo đơn trong CTE trước, rồi mới tính trung bình hay phân nhóm theo đơn.
- Nhóm theo thời gian bằng `DATE_TRUNC` để không gộp nhầm các năm; lọc khoảng thời gian bằng `>=` và `<`.
- Muốn giữ cả nhóm "không có dữ liệu": đi từ bảng chính bằng `LEFT JOIN`, dùng `COUNT(cot)` và `COALESCE`.
- Nhiều bảng con (dòng hàng, thanh toán) cùng JOIN vào một bảng cha sẽ nhân dòng: tổng hợp từng bảng con riêng rồi mới JOIN.
- "Có ở A mà không có ở B": `NOT EXISTS`, `LEFT JOIN ... IS NULL` hoặc `EXCEPT`; tránh `NOT IN` khi cột có thể `NULL`.
- Top 1 mỗi nhóm và so với kỳ trước giải được bằng CTE + subquery tương quan / self JOIN; window function ở Ngày 29 sẽ làm gọn hơn.

## Đọc thêm

- [Vì sao NOT IN của bạn trả về 0 dòng? Logic ba trị của SQL và cái bẫy NULL](https://tiennhm.io.vn/blog/sql-null-not-in-three-valued-logic) — Một câu NOT IN trả về đúng 0 dòng trong khi bảng có dữ liệu, còn NOT EXISTS cùng ý định lại trả về đủ.
- [LEFT JOIN của bạn đã thành INNER JOIN mà không ai báo](https://tiennhm.io.vn/blog/left-join-thanh-inner-join) — Thêm một điều kiện WHERE lên cột của bảng bên phải là LEFT JOIN âm thầm biến thành INNER JOIN, và những dòng bạn cố tình giữ lại biến mất.

---

[⬅️ Ngày 13: CASE và tổng hợp có điều kiện](13-case-when.md) | [📚 Mục lục](../README.md) | [Ngày 15: Chỉ mục (index) ➡️](15-index.md)
