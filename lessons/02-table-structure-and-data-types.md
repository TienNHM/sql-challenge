# Ngày 2: Bảng, kiểu dữ liệu và ràng buộc

> **Tóm tắt:** Một bảng tốt không chỉ có cột và dòng: mỗi cột có kiểu dữ liệu đúng, và bảng có các ràng buộc (khóa chính, khóa ngoại, `UNIQUE`, `NOT NULL`, `CHECK`, `DEFAULT`) để database tự chặn dữ liệu sai. Hôm nay bạn đọc hiểu schema DSC Shop, rồi tự tạo, sửa và xóa bảng trên một khu vực nháp riêng.

**Sau bài này bạn có thể:**

- Chọn kiểu dữ liệu PostgreSQL phù hợp cho từng cột, đặc biệt là tiền (`NUMERIC`) và thời điểm (`TIMESTAMPTZ`).
- Viết `CREATE TABLE` có khóa chính tự tăng (`IDENTITY`) và đủ các ràng buộc `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, `FOREIGN KEY`.
- Chọn hành vi `ON DELETE CASCADE`, `SET NULL` hoặc `RESTRICT` cho khóa ngoại và giải thích hệ quả khi xóa dòng cha.
- Sửa cấu trúc bảng bằng `ALTER TABLE` và xóa bảng bằng `DROP TABLE`.
- Đọc kết quả `\d tên_bảng` để biết bảng có những cột, kiểu và ràng buộc nào.

**Cần biết trước:** [Ngày 1](01-intro-to-sql-and-dbms.md)

## Bảng, cột, dòng

Bảng giống một trang tính có cấu trúc cố định:

- **Cột** (column) là một thuộc tính, có tên và kiểu dữ liệu cố định: `full_name` luôn là chuỗi, `birth_date` luôn là ngày.
- **Dòng** (row) là một bản ghi: một khách hàng, một đơn hàng.
- **Ô** là giá trị của một cột tại một dòng. Ô có thể là NULL (không có giá trị) nếu cột cho phép.

Khác với trang tính, database **kiểm tra** dữ liệu trước khi ghi: không cho ghi chữ vào cột số, không cho hai khách cùng email, không cho đơn hàng trỏ tới khách không tồn tại. Những quy tắc đó là kiểu dữ liệu và ràng buộc, nội dung chính của bài này.

### Khu vực nháp cho bài hôm nay

Để không làm hỏng các bảng của cửa hàng, mọi bảng bạn tạo hôm nay nằm trong một schema riêng tên `nhap`. Chạy khối này mỗi lần mở phiên `psql` mới:

```sql
DROP SCHEMA IF EXISTS nhap CASCADE;
CREATE SCHEMA nhap;
SET search_path = nhap, shop, public;
```

`SET search_path = nhap, shop, public` nghĩa là: khi gặp tên bảng không ghi schema, tìm trong `nhap` trước, rồi `shop`, rồi `public`. Vì vậy `CREATE TABLE vouchers` sẽ tạo `nhap.vouchers`, còn `customers` vẫn tìm ra `shop.customers`. `SET` chỉ có hiệu lực trong phiên hiện tại; thoát `psql` rồi vào lại thì chạy lại dòng `SET` (bỏ hai dòng đầu nếu muốn giữ các bảng nháp đã tạo). Cuối bài có lệnh dọn dẹp.

## Kiểu dữ liệu trong PostgreSQL

### Số nguyên

| Kiểu | Kích thước | Phạm vi | Dùng cho |
| --- | --- | --- | --- |
| `SMALLINT` | 2 byte | -32.768 đến 32.767 | Số nhỏ: điểm đánh giá 1-5 |
| `INT` (`INTEGER`) | 4 byte | khoảng ±2,1 tỷ | Mặc định cho id, số lượng, tồn kho |
| `BIGINT` | 8 byte | khoảng ±9,2 × 10^18 | Id của bảng có thể vượt 2 tỷ dòng (log, sự kiện) |

DSC Shop dùng `INT` cho mọi id và số lượng. Bảng log hay bảng sự kiện tăng nhanh thì nên dùng `BIGINT` ngay từ đầu, vì đổi kiểu khóa chính khi bảng đã lớn rất tốn công.

### Số thập phân: NUMERIC và FLOAT, tiền phải dùng NUMERIC

PostgreSQL có hai họ số thập phân:

- `NUMERIC(p, s)` (tên khác `DECIMAL`): **chính xác tuyệt đối**. `p` là tổng số chữ số, `s` là số chữ số sau dấu phẩy.
- `REAL` (4 byte) và `DOUBLE PRECISION` (8 byte, tên khác `FLOAT8`, `FLOAT`): số thực dấu phẩy động theo chuẩn IEEE 754, tính nhanh nhưng **xấp xỉ**.

Thử cộng 0,1 với 0,2 bằng hai kiểu (cú pháp `giá_trị::kiểu` là ép kiểu, sẽ học kỹ ở Ngày 5):

```sql
SELECT 0.1::FLOAT8 + 0.2::FLOAT8   AS tong_float,
       0.1::NUMERIC + 0.2::NUMERIC AS tong_numeric;
```

| tong_float | tong_numeric |
| --- | --- |
| 0.30000000000000004 | 0.3 |

```sql
SELECT 0.1::FLOAT8 + 0.2::FLOAT8 = 0.3::FLOAT8     AS float_bang_0_3,
       0.1::NUMERIC + 0.2::NUMERIC = 0.3::NUMERIC AS numeric_bang_0_3;
```

| float_bang_0_3 | numeric_bang_0_3 |
| --- | --- |
| f | t |

Với `FLOAT`, 0,1 + 0,2 không bằng 0,3. Sai số nhỏ, nhưng cộng dồn qua hàng triệu giao dịch thì sổ sách lệch, và phép so sánh bằng cho kết quả sai. Vì vậy **tiền luôn dùng `NUMERIC`**. `FLOAT` hợp với số đo khoa học, tọa độ, nơi sai số nhỏ chấp nhận được.

DSC Shop dùng `NUMERIC(12,0)` cho tiền VNĐ (tối đa 12 chữ số, không có phần lẻ, đủ cho 999 tỷ) và `NUMERIC(3,2)` cho `order_items.discount` (tỷ lệ giảm giá từ 0.00 đến 1.00). Giá trị có nhiều chữ số lẻ hơn `s` sẽ được làm tròn; phần nguyên vượt quá thì báo lỗi:

```sql
SELECT 32990000.4::NUMERIC(12,0) AS lam_tron_ve_dong,
       0.125::NUMERIC(3,2)       AS discount_2_chu_so;
```

| lam_tron_ve_dong | discount_2_chu_so |
| --- | --- |
| 32990000 | 0.13 |

```sql
SELECT 15::NUMERIC(3,2);
```

```text
ERROR:  numeric field overflow
DETAIL:  A field with precision 3, scale 2 must round to an absolute value less than 10^1.
```

`NUMERIC(3,2)` chỉ còn 1 chữ số cho phần nguyên, nên giá trị phải nhỏ hơn 10.

### Chuỗi ký tự

| Kiểu | Ý nghĩa |
| --- | --- |
| `VARCHAR(n)` | Chuỗi tối đa `n` ký tự; dài hơn thì báo lỗi |
| `TEXT` | Chuỗi không giới hạn độ dài |
| `CHAR(n)` | Chuỗi đúng `n` ký tự, thiếu thì tự thêm dấu cách vào cuối |

Trong PostgreSQL, `VARCHAR(n)` và `TEXT` được lưu như nhau và nhanh như nhau. Chọn `VARCHAR(n)` khi giới hạn độ dài là một quy tắc nghiệp vụ (mã SKU tối đa 20 ký tự, số điện thoại tối đa 20 ký tự), chọn `TEXT` cho nội dung tự do như ghi chú đơn hàng (`orders.note`). `CHAR(n)` ít dùng; chuyện tự thêm dấu cách thường gây bất ngờ hơn là có ích. `n` tính theo **ký tự**, không theo byte, nên `VARCHAR(100)` chứa đủ 100 chữ tiếng Việt có dấu.

### Ngày giờ

| Kiểu | Lưu gì | Ví dụ |
| --- | --- | --- |
| `DATE` | Chỉ ngày | `2002-03-15` (`customers.birth_date`) |
| `TIME` | Chỉ giờ trong ngày | `14:30:00` |
| `TIMESTAMP` | Ngày + giờ, **không** có múi giờ (tên đầy đủ `timestamp without time zone`) | `2026-10-17 09:00:00` |
| `TIMESTAMPTZ` | Một **thời điểm** tuyệt đối (tên đầy đủ `timestamp with time zone`) | `2026-10-17 09:00:00+07` |
| `INTERVAL` | Khoảng thời gian | `3 days`, `2 hours` (Ngày 5) |

Khác biệt giữa `TIMESTAMP` và `TIMESTAMPTZ` dễ hiểu nhầm nhất. `TIMESTAMP` chỉ là "con số trên mặt đồng hồ", không biết đó là giờ ở đâu. `TIMESTAMPTZ` là một thời điểm thật: PostgreSQL đổi giá trị nhập vào sang UTC để lưu, và khi hiển thị thì đổi theo múi giờ của phiên (`TimeZone`). Thử ghi cùng một chuỗi vào hai cột:

```sql
CREATE TABLE thoi_gian (
    ts   TIMESTAMP,
    tstz TIMESTAMPTZ
);
INSERT INTO thoi_gian VALUES ('2026-10-17 09:00:00', '2026-10-17 09:00:00');
SHOW TIME ZONE;
SELECT * FROM thoi_gian;
```

`INSERT INTO ... VALUES` thêm một dòng vào bảng; Ngày 6 sẽ học đầy đủ, hôm nay chỉ dùng dạng đơn giản nhất. Kết quả:

| TimeZone |
| --- |
| Asia/Ho_Chi_Minh |

| ts | tstz |
| --- | --- |
| 2026-10-17 09:00:00 | 2026-10-17 09:00:00+07 |

Môi trường Docker của khóa học đặt múi giờ `Asia/Ho_Chi_Minh` (UTC+7), nên `tstz` hiểu "9 giờ" là 9 giờ ở Việt Nam. Giờ đổi phiên sang UTC, như một server đặt ở nước ngoài:

```sql
SET TIME ZONE 'UTC';
SELECT * FROM thoi_gian;
RESET TIME ZONE;
```

| ts | tstz |
| --- | --- |
| 2026-10-17 09:00:00 | 2026-10-17 02:00:00+00 |

`tstz` hiển thị 02:00 UTC, vẫn đúng là cùng một thời điểm. `ts` vẫn ghi 09:00 và không ai biết đó là 9 giờ ở đâu. Quy tắc: **thời điểm xảy ra sự việc** (đơn được đặt, tiền được trả, bản ghi được tạo) dùng `TIMESTAMPTZ`, như `orders.order_date`, `payments.paid_at`, `created_at` trong DSC Shop. Nếu cài PostgreSQL trực tiếp, múi giờ phiên có thể khác `Asia/Ho_Chi_Minh` và cột `tstz` hiển thị khác, nhưng vẫn là cùng thời điểm.

> **Ghi chú dialect:** MySQL có `DATETIME` (không múi giờ) và `TIMESTAMP` (lưu theo UTC, phạm vi 1970-2038). SQL Server dùng `DATETIME2` và `DATETIMEOFFSET`; ở SQL Server, `TIMESTAMP` không phải kiểu ngày giờ mà là tên cũ của `rowversion`. PostgreSQL không có kiểu `DATETIME`.

### BOOLEAN và JSONB

`BOOLEAN` nhận `TRUE`, `FALSE` hoặc NULL; `psql` hiển thị là `t` và `f`. Ví dụ `products.is_active` cho biết sản phẩm còn kinh doanh hay không.

`JSONB` lưu dữ liệu JSON (đã phân tích sẵn, truy vấn nhanh). `products.attributes` dùng JSONB vì mỗi loại sản phẩm có thông số khác nhau: laptop có `cpu`, `ram_gb`; điện thoại có `colors`. Ngày 22 sẽ học cách truy vấn và khi nào nên dùng JSONB thay vì tách cột.

> **Ghi chú dialect:** MySQL viết `BOOLEAN` nhưng thực chất lưu là `TINYINT(1)` (`TRUE` = 1, `FALSE` = 0). SQL Server dùng `BIT` (1 hoặc 0).

## Khóa chính và cột tự tăng IDENTITY

**Khóa chính** (primary key) là cột (hoặc nhóm cột) xác định duy nhất mỗi dòng. `PRIMARY KEY` = `UNIQUE` + `NOT NULL`, và mỗi bảng chỉ có một khóa chính.

Thường ta để database tự sinh số cho khóa chính bằng cột **IDENTITY**:

```sql
CREATE TABLE vouchers (
    voucher_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code             VARCHAR(20)   NOT NULL UNIQUE,
    discount_percent INT           NOT NULL CHECK (discount_percent BETWEEN 1 AND 50),
    min_order        NUMERIC(12,0) NOT NULL DEFAULT 0 CHECK (min_order >= 0),
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    expires_at       DATE,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now()
);
```

Bảng `vouchers` (mã giảm giá) này sẽ theo bạn suốt phần ràng buộc. Thêm hai mã, không truyền `voucher_id`:

```sql
INSERT INTO vouchers (code, discount_percent, min_order, expires_at)
VALUES ('CHAOTANSV', 10, 0, '2026-12-31');
INSERT INTO vouchers (code, discount_percent, min_order)
VALUES ('LAPTOP5', 5, 15000000);
SELECT voucher_id, code, discount_percent, min_order, is_active, expires_at
FROM vouchers;
```

| voucher_id | code | discount_percent | min_order | is_active | expires_at |
| --- | --- | --- | --- | --- | --- |
| 1 | CHAOTANSV | 10 | 0 | t | 2026-12-31 |
| 2 | LAPTOP5 | 5 | 15000000 | t | |

`voucher_id` tự nhận 1, 2. `is_active` tự nhận `TRUE` nhờ `DEFAULT`. `expires_at` của `LAPTOP5` là NULL vì không truyền và cột không có `DEFAULT`.

`GENERATED ALWAYS` cấm tự ghi giá trị cho cột này:

```sql
INSERT INTO vouchers (voucher_id, code, discount_percent)
VALUES (100, 'THU100', 10);
```

```text
ERROR:  cannot insert a non-DEFAULT value into column "voucher_id"
DETAIL:  Column "voucher_id" is an identity column defined as GENERATED ALWAYS.
HINT:  Use OVERRIDING SYSTEM VALUE to override.
```

Nếu cần cho phép ghi tay (ví dụ khi chuyển dữ liệu từ hệ cũ), dùng `GENERATED BY DEFAULT AS IDENTITY`. Mã nguồn cũ hay dùng `SERIAL`, cách viết riêng của PostgreSQL trước khi có `IDENTITY` (chuẩn SQL); bảng mới nên dùng `IDENTITY`.

> **Ghi chú dialect:** cột tự tăng ở MySQL viết `INT AUTO_INCREMENT PRIMARY KEY`, ở SQL Server viết `INT IDENTITY(1,1) PRIMARY KEY`, ở SQLite viết `INTEGER PRIMARY KEY` (chỉ đúng kiểu `INTEGER` mới tự tăng).

## Các ràng buộc

Ràng buộc (constraint) là quy tắc gắn vào bảng; mọi lệnh ghi vi phạm đều bị từ chối, dù đến từ ứng dụng nào. Bảng `vouchers` ở trên đã có đủ các loại. Thử vi phạm từng cái.

### NOT NULL

Cột bắt buộc có giá trị. Thiếu `discount_percent`:

```sql
INSERT INTO vouchers (code) VALUES ('THIEUGIAM');
```

```text
ERROR:  null value in column "discount_percent" of relation "vouchers" violates not-null constraint
DETAIL:  Failing row contains (3, THIEUGIAM, null, 0, t, null, 2026-10-17 16:11:29.792089+07).
```

(Thời điểm trong dòng `DETAIL` là lúc bạn chạy lệnh.) Mặc định mọi cột đều cho phép NULL, nên hãy chủ động thêm `NOT NULL` cho cột nào nghiệp vụ bắt buộc.

### UNIQUE

Không có hai dòng trùng giá trị:

```sql
INSERT INTO vouchers (code, discount_percent) VALUES ('CHAOTANSV', 15);
```

```text
ERROR:  duplicate key value violates unique constraint "vouchers_code_key"
DETAIL:  Key (code)=(CHAOTANSV) already exists.
```

`UNIQUE` không cấm nhiều dòng cùng NULL, vì NULL nghĩa là "không biết", hai giá trị không biết không được coi là trùng nhau. Đó là lý do `customers.email` là `UNIQUE` mà vẫn có hai khách không có email (Hoàng Thị Em và Châu Ngọc Trâm). `UNIQUE` cũng có thể đặt trên nhiều cột, ví dụ `UNIQUE (product_id, customer_id)`: mỗi khách chỉ đánh giá một sản phẩm một lần.

### CHECK

Điều kiện mà mọi dòng phải thỏa:

```sql
INSERT INTO vouchers (code, discount_percent) VALUES ('SIEUSALE', 70);
```

```text
ERROR:  new row for relation "vouchers" violates check constraint "vouchers_discount_percent_check"
DETAIL:  Failing row contains (5, SIEUSALE, 70, 0, t, null, 2026-10-17 16:11:29.792438+07).
```

DSC Shop dùng `CHECK` cho giá không âm (`price >= 0`), số lượng dương (`quantity > 0`), và danh sách giá trị hợp lệ: `status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')`.

Kiểu dữ liệu cũng là một lớp kiểm tra. Mã dài quá 20 ký tự:

```sql
INSERT INTO vouchers (code, discount_percent) VALUES ('GIAMGIACUCSOCDIP20THANG11', 20);
```

```text
ERROR:  value too long for type character varying(20)
```

### DEFAULT

Giá trị dùng khi lệnh `INSERT` không nhắc tới cột: `DEFAULT 0`, `DEFAULT TRUE`, `DEFAULT now()` (thời điểm hiện tại). `DEFAULT` không phải ràng buộc theo nghĩa chặn dữ liệu, nhưng giúp dữ liệu nhất quán mà không cần ứng dụng nhớ điền.

Thêm một mã hợp lệ và xem `voucher_id`:

```sql
INSERT INTO vouchers (code, discount_percent) VALUES ('PHUKIEN15', 15);
SELECT voucher_id, code FROM vouchers;
```

| voucher_id | code |
| --- | --- |
| 1 | CHAOTANSV |
| 2 | LAPTOP5 |
| 6 | PHUKIEN15 |

Mã mới nhận số 6 chứ không phải 3: các lệnh `INSERT` vi phạm `NOT NULL`, `UNIQUE`, `CHECK` ở trên đã lấy số 3, 4, 5 trước khi bị từ chối, và số đã lấy thì không trả lại. Cột IDENTITY đảm bảo **không trùng**, không đảm bảo **liên tục**. Đừng dùng id để đếm số dòng.

### FOREIGN KEY và ON DELETE

**Khóa ngoại** (foreign key) đảm bảo giá trị ở bảng con luôn trỏ tới một dòng có thật ở bảng cha. Tạo giỏ hàng: mỗi giỏ thuộc một khách của cửa hàng, có thể gắn một voucher; mỗi dòng trong giỏ là một sản phẩm của cửa hàng.

```sql
CREATE TABLE carts (
    cart_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES shop.customers (customer_id),
    voucher_id  INT REFERENCES vouchers (voucher_id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE cart_items (
    cart_id    INT NOT NULL REFERENCES carts (cart_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES shop.products (product_id) ON DELETE RESTRICT,
    quantity   INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (cart_id, product_id)
);
```

`cart_items` có **khóa chính ghép** từ hai cột `(cart_id, product_id)`, giống `order_items` của DSC Shop: một sản phẩm chỉ xuất hiện một lần trong mỗi giỏ (muốn mua 2 cái thì tăng `quantity`). Thêm dữ liệu:

```sql
INSERT INTO carts (customer_id, voucher_id) VALUES (16, 1);   -- giỏ 1: khách 16, dùng CHAOTANSV
INSERT INTO carts (customer_id) VALUES (4);                   -- giỏ 2: khách 4, không voucher
INSERT INTO cart_items (cart_id, product_id, quantity) VALUES (1, 1, 1);  -- ASUS ROG Strix G16
INSERT INTO cart_items (cart_id, product_id, quantity) VALUES (1, 16, 2); -- Chuột Logitech G102
INSERT INTO cart_items (cart_id, product_id) VALUES (2, 10);              -- iPhone 15, quantity mặc định 1
SELECT * FROM cart_items;
```

| cart_id | product_id | quantity |
| --- | --- | --- |
| 1 | 1 | 1 |
| 1 | 16 | 2 |
| 2 | 10 | 1 |

Giỏ của khách không tồn tại bị chặn:

```sql
INSERT INTO carts (customer_id) VALUES (999);
```

```text
ERROR:  insert or update on table "carts" violates foreign key constraint "carts_customer_id_fkey"
DETAIL:  Key (customer_id)=(999) is not present in table "customers".
```

Thêm lại một sản phẩm đã có trong giỏ thì vi phạm khóa chính ghép:

```sql
INSERT INTO cart_items (cart_id, product_id) VALUES (1, 1);
```

```text
ERROR:  duplicate key value violates unique constraint "cart_items_pkey"
DETAIL:  Key (cart_id, product_id)=(1, 1) already exists.
```

Câu hỏi khó hơn: **xóa dòng cha thì dòng con ra sao?** Đó là việc của mệnh đề `ON DELETE`:

| Hành vi | Khi xóa dòng cha | Dùng khi |
| --- | --- | --- |
| `NO ACTION` (mặc định) | Báo lỗi nếu còn dòng con trỏ tới | Dữ liệu con có giá trị riêng, không được mất (đơn hàng, thanh toán) |
| `RESTRICT` | Báo lỗi, giống `NO ACTION` (khác ở thời điểm kiểm tra, chỉ quan trọng trong các tình huống nâng cao) | Như trên, khi muốn ghi rõ ý định "cấm xóa" |
| `CASCADE` | Xóa luôn các dòng con | Dòng con không có nghĩa nếu thiếu cha: dòng hàng của đơn, món trong giỏ |
| `SET NULL` | Đặt cột khóa ngoại của dòng con thành NULL | Quan hệ không bắt buộc: voucher bị gỡ thì giỏ vẫn còn, chỉ là không còn voucher |

Lệnh `DELETE FROM bảng WHERE điều_kiện` xóa các dòng thỏa điều kiện (Ngày 3 học `WHERE`, Ngày 6 học `DELETE`). Xóa giỏ 2, món hàng của giỏ 2 bị xóa theo nhờ `CASCADE`:

```sql
DELETE FROM carts WHERE cart_id = 2;
SELECT * FROM cart_items;
```

| cart_id | product_id | quantity |
| --- | --- | --- |
| 1 | 1 | 1 |
| 1 | 16 | 2 |

Xóa voucher `CHAOTANSV` (id 1), giỏ 1 còn nguyên nhưng `voucher_id` thành NULL nhờ `SET NULL`:

```sql
DELETE FROM vouchers WHERE voucher_id = 1;
SELECT cart_id, customer_id, voucher_id FROM carts;
```

| cart_id | customer_id | voucher_id |
| --- | --- | --- |
| 1 | 16 | |

Còn khóa ngoại `carts.customer_id` dùng hành vi mặc định `NO ACTION`, nên không xóa được khách 16 khi khách còn giỏ hàng:

```sql
DELETE FROM shop.customers WHERE customer_id = 16;
```

```text
ERROR:  update or delete on table "customers" violates foreign key constraint "carts_customer_id_fkey" on table "carts"
DETAIL:  Key (customer_id)=(16) is still referenced from table "carts".
```

Lệnh bị từ chối nên bảng `shop.customers` không thay đổi. Nếu lỡ sửa hỏng dữ liệu cửa hàng trong lúc thử, xem mục "Làm lại từ đầu" trong [setup/README.md](../setup/README.md#làm-lại-từ-đầu).

## Đọc schema DSC Shop

Giờ bạn đã đọc được mọi thứ trong định nghĩa bảng của cửa hàng. Sơ đồ dưới đây tóm tắt năm bảng chính cùng khóa và ràng buộc của chúng:

![Sơ đồ năm bảng customers, orders, order_items, products, payments của DSC Shop, mỗi cột ghi kiểu dữ liệu và các nhãn ràng buộc PK (khóa chính), FK (khóa ngoại), UQ (UNIQUE), NN (NOT NULL), CK (CHECK), DF (DEFAULT). Mũi tên khóa ngoại nối từ cột con tới cột cha: orders.customer_id tới customers.customer_id, payments.order_id tới orders.order_id, order_items.product_id tới products.product_id đều dùng hành vi mặc định NO ACTION, nghĩa là không xóa được dòng cha khi còn dòng con. Riêng order_items.order_id tới orders.order_id được tô màu nhấn với nhãn ON DELETE CASCADE: xóa một đơn thì các dòng order_items của đơn tự bị xóa theo. order_items có khóa chính ghép (order_id, product_id).](img/khoa-va-rang-buoc.png#gh-light-mode-only)
![Sơ đồ năm bảng customers, orders, order_items, products, payments của DSC Shop, mỗi cột ghi kiểu dữ liệu và các nhãn ràng buộc PK (khóa chính), FK (khóa ngoại), UQ (UNIQUE), NN (NOT NULL), CK (CHECK), DF (DEFAULT). Mũi tên khóa ngoại nối từ cột con tới cột cha: orders.customer_id tới customers.customer_id, payments.order_id tới orders.order_id, order_items.product_id tới products.product_id đều dùng hành vi mặc định NO ACTION, nghĩa là không xóa được dòng cha khi còn dòng con. Riêng order_items.order_id tới orders.order_id được tô màu nhấn với nhãn ON DELETE CASCADE: xóa một đơn thì các dòng order_items của đơn tự bị xóa theo. order_items có khóa chính ghép (order_id, product_id).](img/khoa-va-rang-buoc-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/table-structure-and-data-types/khoa-va-rang-buoc.html) · [nền tối](../diagrams/table-structure-and-data-types/khoa-va-rang-buoc-dark.html)</small>

Đây là đoạn định nghĩa bảng `orders` trong [setup/init/01_schema.sql](../setup/init/01_schema.sql):

```sql
CREATE TABLE shop.orders (
    order_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   INT         NOT NULL REFERENCES shop.customers (customer_id),
    employee_id   INT         REFERENCES shop.employees (employee_id),   -- NULL với đơn online
    order_date    TIMESTAMPTZ NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
    channel       VARCHAR(10) NOT NULL CHECK (channel IN ('online', 'offline')),
    shipping_city VARCHAR(100),
    note          TEXT
);
```

(Khối này chỉ để đọc, đừng chạy: bảng `shop.orders` đã tồn tại.) Và đây là cách `psql` hiển thị nó:

```sql
\d orders
```

```text
                                      Table "shop.orders"
    Column     |           Type           | Collation | Nullable |           Default
---------------+--------------------------+-----------+----------+------------------------------
 order_id      | integer                  |           | not null | generated always as identity
 customer_id   | integer                  |           | not null |
 employee_id   | integer                  |           |          |
 order_date    | timestamp with time zone |           | not null |
 status        | character varying(20)    |           | not null | 'pending'::character varying
 channel       | character varying(10)    |           | not null |
 shipping_city | character varying(100)   |           |          |
 note          | text                     |           |          |
Indexes:
    "orders_pkey" PRIMARY KEY, btree (order_id)
    "orders_customer_id_idx" btree (customer_id)
Check constraints:
    "orders_channel_check" CHECK (channel::text = ANY (ARRAY['online'::character varying, 'offline'::character varying]::text[]))
    "orders_status_check" CHECK (status::text = ANY (ARRAY['pending'::character varying, 'paid'::character varying, 'shipped'::character varying, 'delivered'::character varying, 'cancelled'::character varying]::text[]))
Foreign-key constraints:
    "orders_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    "orders_employee_id_fkey" FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
Referenced by:
    TABLE "order_items" CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
    TABLE "payments" CONSTRAINT "payments_order_id_fkey" FOREIGN KEY (order_id) REFERENCES orders(order_id)
```

Đọc từng phần:

- **Các cột**: kiểu, `not null`, giá trị mặc định. `employee_id` cho phép NULL vì đơn online không có nhân viên bán.
- **Indexes**: khóa chính tự tạo một chỉ mục (index) tên `orders_pkey`. `orders_customer_id_idx` là index được tạo thêm cho khóa ngoại, vì PostgreSQL **không** tự tạo index cho khóa ngoại (Ngày 15 giải thích vì sao cần).
- **Check constraints**: PostgreSQL viết lại `status IN (...)` thành dạng `= ANY (ARRAY[...])`, ý nghĩa như nhau.
- **Foreign-key constraints**: các khóa ngoại của bảng này trỏ đi đâu.
- **Referenced by**: bảng nào trỏ tới bảng này, kèm hành vi `ON DELETE`.
- **Tên ràng buộc** tự sinh theo mẫu `bảng_cột_loại` (`pkey`, `key` cho `UNIQUE`, `check`, `fkey`). Thông báo lỗi luôn ghi tên này, nên đọc tên là biết ngay quy tắc nào bị vi phạm. Muốn tự đặt tên thì viết `CONSTRAINT tên_ràng_buộc CHECK (...)`.

Vài quyết định thiết kế đáng chú ý của DSC Shop:

- Không có cột tổng tiền trong `orders`. Tổng tiền luôn tính từ `order_items` (Ngày 8), nên không bao giờ bị lệch với các dòng hàng.
- `order_items.unit_price` lưu giá **lúc mua**, tách khỏi `products.price` hiện tại, vì giá bán thay đổi theo thời gian.
- `order_items` dùng `ON DELETE CASCADE` vì dòng hàng không có nghĩa nếu không có đơn. `payments` thì không: tiền đã thu là dữ liệu kế toán, không được tự biến mất khi ai đó xóa đơn.

## ALTER TABLE: sửa cấu trúc bảng

Yêu cầu nghiệp vụ thay đổi thì cấu trúc bảng cũng đổi theo. `ALTER TABLE` sửa bảng mà không mất dữ liệu đang có.

Thêm cột:

```sql
ALTER TABLE vouchers ADD COLUMN description TEXT;
ALTER TABLE vouchers ADD COLUMN max_uses INT NOT NULL DEFAULT 100 CHECK (max_uses > 0);
SELECT code, description, max_uses FROM vouchers;
```

| code | description | max_uses |
| --- | --- | --- |
| LAPTOP5 | | 100 |
| PHUKIEN15 | | 100 |

Cột mới không có `DEFAULT` thì các dòng cũ nhận NULL; có `DEFAULT` thì các dòng cũ nhận giá trị mặc định.

Các thao tác khác:

```sql
ALTER TABLE vouchers RENAME COLUMN description TO note;                -- đổi tên cột
ALTER TABLE vouchers ALTER COLUMN code TYPE VARCHAR(30);               -- đổi kiểu
ALTER TABLE vouchers ALTER COLUMN min_order SET DEFAULT 100000;        -- đổi giá trị mặc định
ALTER TABLE vouchers ADD CONSTRAINT vouchers_min_order_max
    CHECK (min_order <= 100000000);                                     -- thêm ràng buộc có tên
ALTER TABLE vouchers DROP COLUMN note;                                 -- xóa cột
\d vouchers
```

```text
                                       Table "nhap.vouchers"
      Column      |           Type           | Collation | Nullable |           Default
------------------+--------------------------+-----------+----------+------------------------------
 voucher_id       | integer                  |           | not null | generated always as identity
 code             | character varying(30)    |           | not null |
 discount_percent | integer                  |           | not null |
 min_order        | numeric(12,0)            |           | not null | 100000
 is_active        | boolean                  |           | not null | true
 expires_at       | date                     |           |          |
 created_at       | timestamp with time zone |           | not null | now()
 max_uses         | integer                  |           | not null | 100
Indexes:
    "vouchers_pkey" PRIMARY KEY, btree (voucher_id)
    "vouchers_code_key" UNIQUE CONSTRAINT, btree (code)
Check constraints:
    "vouchers_discount_percent_check" CHECK (discount_percent >= 1 AND discount_percent <= 50)
    "vouchers_max_uses_check" CHECK (max_uses > 0)
    "vouchers_min_order_check" CHECK (min_order >= 0::numeric)
    "vouchers_min_order_max" CHECK (min_order <= 100000000::numeric)
Referenced by:
    TABLE "carts" CONSTRAINT "carts_voucher_id_fkey" FOREIGN KEY (voucher_id) REFERENCES vouchers(voucher_id) ON DELETE SET NULL
```

Một số lệnh khác cùng họ: `ALTER COLUMN ... SET NOT NULL` / `DROP NOT NULL`, `ALTER COLUMN ... DROP DEFAULT`, `DROP CONSTRAINT tên_ràng_buộc`, `ALTER TABLE ... RENAME TO tên_mới`.

Thêm ràng buộc vào bảng đã có dữ liệu thì dữ liệu cũ cũng phải thỏa. Mã `LAPTOP5` không có ngày hết hạn, nên:

```sql
ALTER TABLE vouchers ALTER COLUMN expires_at SET NOT NULL;
```

```text
ERROR:  column "expires_at" of relation "vouchers" contains null values
```

Muốn làm được, trước hết phải điền giá trị cho các dòng đang NULL (bằng `UPDATE`, Ngày 6), rồi mới thêm `NOT NULL`. Cùng lý do, thêm một cột `NOT NULL` không có `DEFAULT` vào bảng đã có dữ liệu cũng thất bại, vì các dòng cũ sẽ nhận NULL:

```sql
ALTER TABLE vouchers ADD COLUMN channel VARCHAR(10) NOT NULL;
```

```text
ERROR:  column "channel" of relation "vouchers" contains null values
```

Cách đúng: kèm `DEFAULT` (`... NOT NULL DEFAULT 'online'`), hoặc thêm cột cho phép NULL, điền dữ liệu, rồi mới `SET NOT NULL`.

## DROP TABLE: xóa bảng

`DROP TABLE` xóa cả cấu trúc lẫn dữ liệu, không hỏi lại. Bảng đang được khóa ngoại của bảng khác trỏ tới thì không xóa được:

```sql
DROP TABLE vouchers;
```

```text
ERROR:  cannot drop table vouchers because other objects depend on it
DETAIL:  constraint carts_voucher_id_fkey on table carts depends on table vouchers
HINT:  Use DROP ... CASCADE to drop the dependent objects too.
```

`CASCADE` xóa bảng và cả các đối tượng phụ thuộc. Ở đây chỉ ràng buộc khóa ngoại `carts_voucher_id_fkey` bị xóa; bảng `carts` và dữ liệu của nó vẫn còn. `IF EXISTS` giúp lệnh không báo lỗi khi bảng không tồn tại, tiện cho script chạy lại nhiều lần:

```sql
DROP TABLE vouchers CASCADE;
DROP TABLE IF EXISTS vouchers;
```

```text
NOTICE:  drop cascades to constraint carts_voucher_id_fkey on table carts
DROP TABLE
NOTICE:  table "vouchers" does not exist, skipping
DROP TABLE
```

Tương tự, `DROP SCHEMA nhap CASCADE` xóa schema cùng mọi bảng bên trong; đó là lệnh dọn dẹp cuối bài.

> Trên database thật, `DROP TABLE` và `DROP ... CASCADE` là lệnh nguy hiểm nhất bạn sẽ gõ. Luôn kiểm tra `\conninfo` xem đang ở database nào trước khi chạy.

## Lỗi thường gặp

**Dùng FLOAT cho tiền.** Như đã thấy, `0.1 + 0.2` bằng `FLOAT` không ra `0.3`. Sai:

```sql
CREATE TABLE gia_sai (gia FLOAT);
```

Đúng:

```sql
CREATE TABLE gia_dung (gia NUMERIC(12,0));
```

**Dùng TIMESTAMP cho thời điểm sự kiện.** `TIMESTAMP` không biết múi giờ, nên khi server hoặc người dùng ở múi giờ khác, giờ ghi nhận bị hiểu sai. Thời điểm đặt hàng, thanh toán, tạo bản ghi dùng `TIMESTAMPTZ`.

**Đặt tên có chữ hoa trong nháy kép.** PostgreSQL đổi tên không có nháy kép thành chữ thường, còn tên trong nháy kép thì giữ nguyên chữ hoa:

```sql
CREATE TABLE SanPham (MaSP INT);
SELECT * FROM sanpham;
```

| masp |
| --- |

(0 dòng, chạy được: bảng thực sự tên `sanpham`, cột tên `masp`.)

```sql
CREATE TABLE "KhachHang" ("MaKH" INT);
SELECT * FROM KhachHang;
```

```text
ERROR:  relation "khachhang" does not exist
LINE 1: SELECT * FROM KhachHang;
                      ^
```

Từ giờ bạn buộc phải viết `"KhachHang"` (có nháy kép, đúng chữ hoa) ở mọi nơi. Công cụ đồ họa và ORM đôi khi tạo bảng kiểu này. Cách tránh: luôn đặt tên chữ thường, `snake_case`.

**Thêm cột NOT NULL không có DEFAULT vào bảng đã có dữ liệu.** Các dòng cũ nhận NULL nên vi phạm ngay ràng buộc (ví dụ ở mục `ALTER TABLE`). Kèm `DEFAULT`, hoặc thêm cột cho phép NULL, điền dữ liệu rồi mới `SET NOT NULL`.

**Nghĩ rằng CHECK chặn được NULL.** `CHECK` chỉ từ chối dòng làm điều kiện **sai**; nếu điều kiện cho kết quả NULL (không xác định) thì dòng vẫn được nhận. Cột bắt buộc thì phải có `NOT NULL` riêng. Bài tập 7 có ví dụ cụ thể.

**Dùng CASCADE ở mọi khóa ngoại cho tiện.** `ON DELETE CASCADE` trên khóa ngoại `orders.customer_id` sẽ khiến lệnh xóa một khách hàng âm thầm xóa luôn toàn bộ đơn hàng của họ. Chỉ dùng `CASCADE` khi dòng con thực sự là "một phần" của dòng cha.

## Bài tập

Tất cả bài tập làm trong schema `nhap`. Nếu vừa mở phiên mới, chạy lại khối tạo khu vực nháp ở đầu bài.

### Cơ bản

**Bài 1.** Chọn kiểu dữ liệu PostgreSQL cho từng cột của bảng `employees` sắp mở rộng: (a) lương tháng (VNĐ); (b) ngày vào làm; (c) thời điểm nhân viên đăng nhập gần nhất; (d) còn đang làm việc hay không; (e) giới thiệu bản thân, dài tùy ý; (f) mã số thuế cá nhân, 10 hoặc 13 chữ số.

<details>
<summary>Đáp án</summary>

| Cột | Kiểu | Lý do |
| --- | --- | --- |
| (a) lương | `NUMERIC(12,0)` | Tiền, phải chính xác (`employees.salary` của DSC Shop dùng đúng kiểu này) |
| (b) ngày vào làm | `DATE` | Chỉ cần ngày |
| (c) lần đăng nhập gần nhất | `TIMESTAMPTZ` | Một thời điểm sự kiện |
| (d) đang làm việc | `BOOLEAN` | Chỉ có đúng/sai |
| (e) giới thiệu | `TEXT` | Nội dung tự do, không cần giới hạn |
| (f) mã số thuế | `VARCHAR(13)` | Là mã, không dùng để tính toán; lưu dạng số sẽ mất số 0 ở đầu |
</details>

**Bài 2.** Xem cấu trúc bảng `payments` và trả lời: (a) phương thức thanh toán nhận những giá trị nào; (b) có ghi được một khoản thanh toán số tiền 0 không; (c) xóa một đơn hàng đã có thanh toán thì chuyện gì xảy ra?

<details>
<summary>Đáp án</summary>

```sql
\d payments
```

```text
                                    Table "shop.payments"
   Column   |           Type           | Collation | Nullable |           Default
------------+--------------------------+-----------+----------+------------------------------
 payment_id | integer                  |           | not null | generated always as identity
 order_id   | integer                  |           | not null |
 amount     | numeric(12,0)            |           | not null |
 method     | character varying(20)    |           | not null |
 paid_at    | timestamp with time zone |           | not null |
Indexes:
    "payments_pkey" PRIMARY KEY, btree (payment_id)
    "payments_order_id_idx" btree (order_id)
Check constraints:
    "payments_amount_check" CHECK (amount > 0::numeric)
    "payments_method_check" CHECK (method::text = ANY (ARRAY['cash'::character varying, 'card'::character varying, 'momo'::character varying, 'bank_transfer'::character varying]::text[]))
Foreign-key constraints:
    "payments_order_id_fkey" FOREIGN KEY (order_id) REFERENCES orders(order_id)
```

(a) `cash`, `card`, `momo`, `bank_transfer`. (b) Không, `amount > 0`. (c) Khóa ngoại `payments_order_id_fkey` không ghi `ON DELETE` nên là `NO ACTION`: lệnh xóa đơn bị từ chối (Bài 8 thử thật).
</details>

**Bài 3.** Tạo bảng `suppliers` (nhà cung cấp) gồm: mã tự tăng làm khóa chính; tên (bắt buộc, tối đa 150 ký tự); mã số thuế (bắt buộc, không trùng, tối đa 13 ký tự); email (không trùng, được để trống); thành phố; trạng thái hoạt động (mặc định đang hoạt động); thời điểm tạo (mặc định là lúc thêm). Thêm hai nhà cung cấp, một có đủ thông tin, một chỉ có tên và mã số thuế, rồi xem lại bảng.

<details>
<summary>Đáp án</summary>

```sql
CREATE TABLE suppliers (
    supplier_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    tax_code    VARCHAR(13)  NOT NULL UNIQUE,
    email       VARCHAR(255) UNIQUE,
    city        VARCHAR(100),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
INSERT INTO suppliers (name, tax_code, email, city)
VALUES ('Công ty Phân phối Số Việt', '0301234567', 'sales@sovietdist.vn', 'TP. Hồ Chí Minh');
INSERT INTO suppliers (name, tax_code)
VALUES ('Nhà phân phối Linh Kiện Xanh', '0109876543');
SELECT supplier_id, name, tax_code, email, city, is_active FROM suppliers;
```

Kết quả:

| supplier_id | name | tax_code | email | city | is_active |
| --- | --- | --- | --- | --- | --- |
| 1 | Công ty Phân phối Số Việt | 0301234567 | sales@sovietdist.vn | TP. Hồ Chí Minh | t |
| 2 | Nhà phân phối Linh Kiện Xanh | 0109876543 | | | t |
</details>

### Vận dụng

**Bài 4.** Sửa bảng `suppliers` ở Bài 3: thêm cột số điện thoại (tối đa 20 ký tự) và đặt ràng buộc không trùng tên `suppliers_phone_key` cho nó; đổi tên cột `name` thành `supplier_name`; đặt thành phố mặc định là `TP. Hồ Chí Minh`. Kiểm tra bằng `\d`.

<details>
<summary>Đáp án</summary>

```sql
ALTER TABLE suppliers ADD COLUMN phone VARCHAR(20);
ALTER TABLE suppliers ADD CONSTRAINT suppliers_phone_key UNIQUE (phone);
ALTER TABLE suppliers RENAME COLUMN name TO supplier_name;
ALTER TABLE suppliers ALTER COLUMN city SET DEFAULT 'TP. Hồ Chí Minh';
\d suppliers
```

Kết quả:

```text
                                         Table "nhap.suppliers"
    Column     |           Type           | Collation | Nullable |               Default
---------------+--------------------------+-----------+----------+--------------------------------------
 supplier_id   | integer                  |           | not null | generated always as identity
 supplier_name | character varying(150)   |           | not null |
 tax_code      | character varying(13)    |           | not null |
 email         | character varying(255)   |           |          |
 city          | character varying(100)   |           |          | 'TP. Hồ Chí Minh'::character varying
 is_active     | boolean                  |           | not null | true
 created_at    | timestamp with time zone |           | not null | now()
 phone         | character varying(20)    |           |          |
Indexes:
    "suppliers_pkey" PRIMARY KEY, btree (supplier_id)
    "suppliers_email_key" UNIQUE CONSTRAINT, btree (email)
    "suppliers_phone_key" UNIQUE CONSTRAINT, btree (phone)
    "suppliers_tax_code_key" UNIQUE CONSTRAINT, btree (tax_code)
```

Đặt `DEFAULT` mới không làm thay đổi các dòng đã có: nhà cung cấp số 2 vẫn có `city` là NULL. `DEFAULT` chỉ áp dụng cho các lần `INSERT` sau.
</details>

**Bài 5.** Tạo bảng `product_reviews` (đánh giá sản phẩm của khách DSC Shop): mã tự tăng; sản phẩm và khách hàng (bắt buộc, là khóa ngoại tới `shop.products` và `shop.customers`); số sao từ 1 đến 5 (dùng `SMALLINT`); bình luận; thời điểm tạo. Mỗi khách chỉ được đánh giá mỗi sản phẩm một lần. Sau đó thử bốn lệnh: khách 1 đánh giá iPhone 15 (product 10) 5 sao kèm bình luận "Máy đẹp, pin ổn"; khách 2 đánh giá sản phẩm 10 với 6 sao; khách 1 đánh giá lại sản phẩm 10 với 4 sao; khách 1 đánh giá sản phẩm 99. Lệnh nào thành công, lệnh nào lỗi, vì sao?

<details>
<summary>Đáp án</summary>

```sql
CREATE TABLE product_reviews (
    review_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  INT         NOT NULL REFERENCES shop.products (product_id),
    customer_id INT         NOT NULL REFERENCES shop.customers (customer_id),
    rating      SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (product_id, customer_id)
);
INSERT INTO product_reviews (product_id, customer_id, rating, comment)
VALUES (10, 1, 5, 'Máy đẹp, pin ổn');
INSERT INTO product_reviews (product_id, customer_id, rating)
VALUES (10, 2, 6);
INSERT INTO product_reviews (product_id, customer_id, rating)
VALUES (10, 1, 4);
INSERT INTO product_reviews (product_id, customer_id, rating)
VALUES (99, 1, 4);
SELECT review_id, product_id, customer_id, rating, comment FROM product_reviews;
```

Kết quả: lệnh 1 thành công. Ba lệnh sau lỗi:

```text
ERROR:  new row for relation "product_reviews" violates check constraint "product_reviews_rating_check"
DETAIL:  Failing row contains (2, 10, 2, 6, null, 2026-10-17 16:11:54.227054+07).
ERROR:  duplicate key value violates unique constraint "product_reviews_product_id_customer_id_key"
DETAIL:  Key (product_id, customer_id)=(10, 1) already exists.
ERROR:  insert or update on table "product_reviews" violates foreign key constraint "product_reviews_product_id_fkey"
DETAIL:  Key (product_id)=(99) is not present in table "products".
```

| review_id | product_id | customer_id | rating | comment |
| --- | --- | --- | --- | --- |
| 1 | 10 | 1 | 5 | Máy đẹp, pin ổn |

Lệnh 2 vi phạm `CHECK` (6 sao), lệnh 3 vi phạm `UNIQUE (product_id, customer_id)`, lệnh 4 vi phạm khóa ngoại (không có sản phẩm 99).
</details>

**Bài 6.** Không chạy, hãy dự đoán kết quả của từng biểu thức, rồi chạy để kiểm tra: `18490000.5::NUMERIC(12,0)`, `0.075::NUMERIC(3,2)`, `1::NUMERIC(3,2)`, `10::NUMERIC(3,2)`. Biểu thức cuối cho biết điều gì về cột `order_items.discount`?

<details>
<summary>Đáp án</summary>

```sql
SELECT 18490000.5::NUMERIC(12,0) AS a,
       0.075::NUMERIC(3,2)       AS b,
       1::NUMERIC(3,2)           AS c;
```

| a | b | c |
| --- | --- | --- |
| 18490001 | 0.08 | 1.00 |

```sql
SELECT 10::NUMERIC(3,2);
```

```text
ERROR:  numeric field overflow
DETAIL:  A field with precision 3, scale 2 must round to an absolute value less than 10^1.
```

`NUMERIC` làm tròn nửa lên (`.5` thành 1), và luôn hiển thị đủ `s` chữ số lẻ (`1.00`). `NUMERIC(3,2)` không chứa nổi 10, nên nếu ai đó nhầm nhập `discount` là phần trăm (`10` thay vì `0.10`) thì bị chặn ngay ở kiểu dữ liệu; còn `CHECK (discount BETWEEN 0 AND 1)` chặn các giá trị từ 1.01 đến 9.99.
</details>

### Thử thách

**Bài 7.** Thiết kế bảng `shipments` (vận chuyển) cho đơn hàng DSC Shop:

- Mỗi đơn có tối đa một lần giao; xóa đơn thì thông tin giao hàng của đơn cũng mất.
- Đơn vị vận chuyển chỉ nhận `GHN`, `GHTK`, `ViettelPost`.
- Phí giao (VNĐ) không âm, mặc định 0.
- Thời điểm gửi hàng bắt buộc; thời điểm giao xong có thể chưa có, nhưng nếu có thì không được sớm hơn lúc gửi.

Thử thêm: đơn 1 gửi bằng GHN lúc `2025-01-13 09:00+07`, giao xong `2025-01-15 16:00+07`, phí 30.000; đơn 2 gửi bằng GHTK lúc `2025-01-21 08:00+07`, chưa giao xong; đơn 3 gửi lúc `2025-02-04 08:00+07` nhưng giao xong `2025-02-02 08:00+07`; đơn 1 gửi thêm lần nữa bằng GHTK.

<details>
<summary>Đáp án</summary>

```sql
CREATE TABLE shipments (
    shipment_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     INT           NOT NULL UNIQUE
                 REFERENCES shop.orders (order_id) ON DELETE CASCADE,
    carrier      VARCHAR(20)   NOT NULL
                 CHECK (carrier IN ('GHN', 'GHTK', 'ViettelPost')),
    fee          NUMERIC(12,0) NOT NULL DEFAULT 0 CHECK (fee >= 0),
    shipped_at   TIMESTAMPTZ   NOT NULL,
    delivered_at TIMESTAMPTZ,
    CHECK (delivered_at >= shipped_at)
);
INSERT INTO shipments (order_id, carrier, fee, shipped_at, delivered_at)
VALUES (1, 'GHN', 30000, '2025-01-13 09:00+07', '2025-01-15 16:00+07');
INSERT INTO shipments (order_id, carrier, shipped_at)
VALUES (2, 'GHTK', '2025-01-21 08:00+07');
INSERT INTO shipments (order_id, carrier, shipped_at, delivered_at)
VALUES (3, 'GHN', '2025-02-04 08:00+07', '2025-02-02 08:00+07');
INSERT INTO shipments (order_id, carrier, shipped_at)
VALUES (1, 'GHTK', '2025-01-14 08:00+07');
SELECT shipment_id, order_id, carrier, fee, shipped_at, delivered_at FROM shipments;
```

Hai lệnh cuối lỗi:

```text
ERROR:  new row for relation "shipments" violates check constraint "shipments_check"
DETAIL:  Failing row contains (3, 3, GHN, 0, 2025-02-04 08:00:00+07, 2025-02-02 08:00:00+07).
ERROR:  duplicate key value violates unique constraint "shipments_order_id_key"
DETAIL:  Key (order_id)=(1) already exists.
```

| shipment_id | order_id | carrier | fee | shipped_at | delivered_at |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | GHN | 30000 | 2025-01-13 09:00:00+07 | 2025-01-15 16:00:00+07 |
| 2 | 2 | GHTK | 0 | 2025-01-21 08:00:00+07 | |

Các điểm mấu chốt:

- `UNIQUE` trên `order_id` biến quan hệ thành 1-1: mỗi đơn tối đa một lần giao.
- `CHECK (delivered_at >= shipped_at)` là ràng buộc **cấp bảng** vì liên quan hai cột, viết sau danh sách cột.
- Đơn 2 có `delivered_at` là NULL, điều kiện `NULL >= shipped_at` cho kết quả không xác định, và `CHECK` vẫn nhận dòng. Ở đây đó đúng là điều ta muốn (chưa giao xong), nhưng hãy nhớ hiện tượng này: `CHECK` không thay được `NOT NULL`. Ngày 3 giải thích logic ba trị đứng sau.
</details>

**Bài 8.** `order_items` và `payments` đều trỏ tới `orders`, nhưng chỉ `order_items` có `ON DELETE CASCADE`. Thử xóa đơn 1 trong một transaction rồi hủy (`BEGIN ... ROLLBACK`, để chắc chắn không mất dữ liệu). Chuyện gì xảy ra với các dòng `order_items` của đơn 1? Vì sao thiết kế này hợp lý?

<details>
<summary>Đáp án</summary>

```sql
BEGIN;
DELETE FROM shop.orders WHERE order_id = 1;
ROLLBACK;
```

```text
ERROR:  update or delete on table "orders" violates foreign key constraint "payments_order_id_fkey" on table "payments"
DETAIL:  Key (order_id)=(1) is still referenced from table "payments".
```

Đơn 1 đã có thanh toán, khóa ngoại `payments_order_id_fkey` (`NO ACTION`) chặn lệnh xóa. Cả câu lệnh thất bại, nên các dòng `order_items` của đơn 1 **cũng không bị xóa**: `CASCADE` chỉ chạy khi việc xóa dòng cha thành công. Một câu lệnh hoặc thành công trọn vẹn, hoặc không thay đổi gì.

Thiết kế hợp lý vì dòng hàng chỉ là chi tiết của đơn, nên đi cùng đơn. Còn thanh toán là tiền thật đã thu: database buộc người dùng xử lý thanh toán (hoàn tiền, ghi nhận) trước, thay vì để một lệnh xóa đơn làm biến mất dấu vết kế toán. Thực tế các cửa hàng thường không xóa đơn mà chuyển `status` thành `cancelled`.
</details>

### Dọn dẹp

Xong bài, xóa toàn bộ khu vực nháp và đưa `search_path` về mặc định:

```sql
DROP SCHEMA nhap CASCADE;
RESET search_path;
```

## Tóm tắt

- Mỗi cột có kiểu dữ liệu: `INT`/`BIGINT` cho số nguyên, `NUMERIC(p,s)` cho tiền (không dùng `FLOAT`), `VARCHAR(n)`/`TEXT` cho chuỗi, `DATE` cho ngày, `TIMESTAMPTZ` cho thời điểm sự kiện, `BOOLEAN`, `JSONB`.
- Khóa chính tự tăng: `INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY`; id không trùng nhưng có thể có khoảng trống.
- Ràng buộc để database tự chặn dữ liệu sai: `NOT NULL`, `UNIQUE` (cho phép nhiều NULL), `CHECK` (NULL vẫn lọt), `DEFAULT`, `PRIMARY KEY`, `FOREIGN KEY`.
- `ON DELETE`: mặc định `NO ACTION`/`RESTRICT` chặn xóa dòng cha; `CASCADE` xóa theo; `SET NULL` gỡ liên kết.
- `ALTER TABLE` thêm/đổi/xóa cột và ràng buộc; dữ liệu cũ phải thỏa ràng buộc mới. `DROP TABLE [IF EXISTS] ... [CASCADE]` xóa bảng.
- `\d tên_bảng` cho biết toàn bộ cột, kiểu, index, ràng buộc và ai đang trỏ tới bảng.
- Đặt tên chữ thường `snake_case`, tránh nháy kép.

## Đọc thêm

- [PostgreSQL: Data Types](https://www.postgresql.org/docs/16/datatype.html) và [Constraints](https://www.postgresql.org/docs/16/ddl-constraints.html).
- [Giới thiệu UUID (Universally Unique Identifier) - Định danh duy nhất toàn cầu](https://tiennhm.io.vn/blog/gioi-thieu-uuid-universally-unique-identifier) — UUID là chuẩn định danh 128-bit tạo được ID duy nhất toàn cầu mà không cần cơ quan trung tâm, một lựa chọn khác cho khóa chính bên cạnh `IDENTITY`.
- [Vì sao NOT IN của bạn trả về 0 dòng? Logic ba trị của SQL và cái bẫy NULL](https://tiennhm.io.vn/blog/sql-null-not-in-three-valued-logic) — Một câu NOT IN trả về đúng 0 dòng trong khi bảng có dữ liệu; cùng một logic ba trị khiến `CHECK` cho NULL đi qua.
- [Có index rồi mà truy vấn vẫn quét toàn bảng? Sargability và một hàm bọc quanh cột](https://tiennhm.io.vn/blog/sql-index-khong-duoc-dung-sargable) — Đọc trước cho Ngày 15 và 28: cột đã có index, câu WHERE lọc đúng cột đó, nhưng execution plan vẫn là Seq Scan.

---

[⬅️ Ngày 1: Giới thiệu SQL, RDBMS và môi trường thực hành](01-intro-to-sql-and-dbms.md) | [📚 Mục lục](../README.md) | [Ngày 3: SELECT và WHERE, truy vấn và lọc dữ liệu ➡️](03-select-where.md)
