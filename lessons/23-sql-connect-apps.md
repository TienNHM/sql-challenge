# Ngày 23: Kết nối SQL từ ứng dụng

> **Tóm tắt:** Đến giờ bạn gõ SQL trong psql hoặc Adminer. Ứng dụng thật (web, API, script báo cáo) gửi SQL qua một thư viện gọi là driver. Bài này dùng Python (psycopg 3) và Node.js (pg) để kết nối DSC Shop, truyền tham số an toàn, dùng connection pool, chạy transaction từ code, xử lý lỗi và tránh bẫy N+1 khi dùng ORM.

**Sau bài này bạn có thể:**

- Viết được đoạn Python và Node.js kết nối PostgreSQL, chạy truy vấn có tham số và đọc kết quả.
- Giải thích được vì sao truy vấn tham số hóa chặn được SQL injection, và dùng đúng ký hiệu placeholder của từng driver.
- Dùng connection pool thay vì mở kết nối mới cho mỗi yêu cầu.
- Viết được một nghiệp vụ nhiều câu lệnh (đặt hàng, trừ kho) trong một transaction từ code: kiểm tra số dòng bị ảnh hưởng, ROLLBACK khi lỗi, thử lại khi gặp lỗi tuần tự hóa hoặc deadlock.
- Nhận ra vấn đề N+1 và viết lại thành một truy vấn.

**Cần biết trước:** [Ngày 6](06-insert-update-delete.md) (INSERT, UPDATE, RETURNING), [Ngày 10](10-join.md) (JOIN), [Ngày 16](16-transactions-acid.md) (transaction, isolation level), [Ngày 17](17-stored-procedures-functions.md) (procedure).

## Ứng dụng nói chuyện với PostgreSQL như thế nào

Ứng dụng không "mở file database" ra đọc. Nó mở một kết nối mạng tới PostgreSQL (mặc định cổng 5432), đăng nhập bằng user và mật khẩu, rồi gửi câu SQL qua kết nối đó. Thư viện lo phần giao tiếp này gọi là driver:

| Ngôn ngữ | Driver phổ biến cho PostgreSQL |
| --- | --- |
| Python | `psycopg` (bản 3, bài này dùng), `psycopg2` (bản cũ), `asyncpg` |
| Node.js | `pg` (node-postgres, bài này dùng), `postgres` |
| Java | JDBC driver `org.postgresql` |
| C# | `Npgsql` |

```mermaid
sequenceDiagram
    participant App as Ứng dụng
    participant Drv as Driver (psycopg, pg)
    participant DB as PostgreSQL
    App->>Drv: Kết nối (host, port, user, mật khẩu, database)
    Drv->>DB: Mở kết nối TCP và xác thực
    App->>Drv: Câu SQL + tham số
    Drv->>DB: Gửi câu SQL và tham số riêng
    DB-->>Drv: Các dòng kết quả hoặc số dòng bị ảnh hưởng
    Drv-->>App: Dữ liệu dạng list/tuple/object
    App->>Drv: Đóng kết nối (hoặc trả về pool)
```

### Thông tin kết nối và biến môi trường

Với môi trường Docker của khóa học (xem [setup/README.md](../setup/README.md)), thông tin kết nối viết gọn thành một connection string:

```text
postgresql://postgres:postgres@localhost:5432/sql_challenge
```

Đừng viết chuỗi này (nhất là mật khẩu) thẳng vào code: push lên GitHub là lộ. Hãy đặt nó trong biến môi trường `DATABASE_URL` rồi để code đọc ra:

```sh
# Git Bash / macOS / Linux
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/sql_challenge"
```

```powershell
# PowerShell
$env:DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/sql_challenge"
```

Dự án thật thường để biến này trong file `.env` (và thêm `.env` vào `.gitignore`). User `postgres` là superuser, chỉ dùng khi học. Ứng dụng thật nên dùng một user riêng chỉ có đúng các quyền cần thiết; [Ngày 30](30-database-security.md) sẽ tạo user như vậy.

Cài thư viện:

```sh
pip install "psycopg[binary,pool]"   # Python: driver + connection pool
npm install pg                       # Node.js
```

## Truy vấn đầu tiên

### Python với psycopg 3

```python
import os
import psycopg

DSN = os.environ["DATABASE_URL"]

with psycopg.connect(DSN) as conn:
    rows = conn.execute(
        """
        SELECT sku, name, price
        FROM products
        WHERE category_id = %s AND price >= %s
        ORDER BY price DESC
        """,
        (3, 25_000_000),
    ).fetchall()

for sku, name, price in rows:
    print(sku, name, price)
```

Kết quả:

```text
LAP-001 ASUS ROG Strix G16 32990000
LAP-002 Lenovo Legion 5 29990000
```

Vài điều cần để ý:

- `%s` là chỗ giữ (placeholder) cho tham số. Giá trị thật được truyền riêng trong tuple `(3, 25_000_000)`, theo đúng thứ tự.
- `fetchall()` trả về list các tuple. Muốn lấy một dòng dùng `fetchone()` (trả `None` nếu không có dòng nào).
- Cột `NUMERIC` được trả về dạng `decimal.Decimal` của Python, giữ đúng giá trị tiền, không bị sai số như `float`.
- Khối `with psycopg.connect(...)` tự `COMMIT` khi kết thúc bình thường, tự `ROLLBACK` nếu có exception, rồi đóng kết nối.

Muốn mỗi dòng là một dict (tiện khi trả JSON), dùng `row_factory`:

```python
import os
import psycopg
from psycopg.rows import dict_row

with psycopg.connect(os.environ["DATABASE_URL"], row_factory=dict_row) as conn:
    row = conn.execute(
        "SELECT customer_id, full_name, city FROM customers WHERE email = %s",
        ("binh.tran@gmail.com",),
    ).fetchone()

print(row)
```

```text
{'customer_id': 2, 'full_name': 'Trần Thị Bình', 'city': 'Hà Nội'}
```

Chú ý dấu phẩy trong `("binh.tran@gmail.com",)`: tuple một phần tử phải có dấu phẩy, thiếu là lỗi (xem mục Lỗi thường gặp).

### Node.js với pg

```js
const { Client } = require('pg');

async function main() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    const result = await client.query(
      `SELECT sku, name, price
       FROM products
       WHERE category_id = $1 AND price >= $2
       ORDER BY price DESC`,
      [3, 25000000]
    );
    console.log(result.rows);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

```text
[
  { sku: 'LAP-001', name: 'ASUS ROG Strix G16', price: '32990000' },
  { sku: 'LAP-002', name: 'Lenovo Legion 5', price: '29990000' }
]
```

Node dùng `$1`, `$2` (đúng cú pháp tham số của PostgreSQL). Để ý `price` trả về là chuỗi `'32990000'`: kiểu `number` của JavaScript là số thực dấu phẩy động nên `pg` cố ý không tự đổi `NUMERIC` sang `number` để tránh mất chính xác. Cần tính toán tiền thì dùng thư viện số thập phân, hoặc để SQL tính.

`result.rowCount` cho biết số dòng bị ảnh hưởng với `INSERT`/`UPDATE`/`DELETE`.

## Truy vấn tham số hóa: luôn dùng, không nối chuỗi

Cách sai mà người mới hay viết là ghép dữ liệu người dùng vào câu SQL:

```python
# SAI: email lấy từ ô nhập liệu trên web
sql = f"SELECT order_id, status FROM orders o JOIN customers c ON c.customer_id = o.customer_id WHERE c.email = '{email}'"
conn.execute(sql)
```

Nếu người dùng gõ vào ô email chuỗi `' OR '1'='1`, câu SQL thành `... WHERE c.email = '' OR '1'='1'`, điều kiện luôn đúng và trả về đơn hàng của mọi khách. Đây là SQL injection. [Ngày 30](30-database-security.md) có demo đầy đủ (kể cả đọc trộm lương nhân viên) và sơ đồ so sánh hai cách.

Cách đúng là truy vấn tham số hóa (parameterized query):

```python
conn.execute(
    "SELECT order_id, status FROM orders o JOIN customers c ON c.customer_id = o.customer_id WHERE c.email = %s",
    (email,),
)
```

Vì sao cách này an toàn? Driver gửi câu SQL (chứa `$1`) và giá trị tham số thành hai phần riêng. PostgreSQL phân tích (parse) câu SQL trước, chốt cấu trúc câu lệnh, rồi mới điền giá trị vào chỗ `$1`. Lúc đó giá trị chỉ còn là một chuỗi dữ liệu, không thể "mọc" thêm `OR`, `UNION` hay `;` vào câu lệnh nữa. Với input `' OR '1'='1`, truy vấn trên trả về 0 dòng vì không khách nào có email như vậy.

> Đừng tự "escape" dấu nháy bằng `replace("'", "''")`. Tự escape dễ sót trường hợp, còn tham số hóa thì đúng trong mọi trường hợp.

### Placeholder khác nhau theo driver

Ý tưởng giống nhau, nhưng ký hiệu thì mỗi driver một kiểu. Chép code từ driver này sang driver khác mà không đổi ký hiệu là lỗi ngay.

| Driver | Ngôn ngữ | Placeholder |
| --- | --- | --- |
| psycopg 3, psycopg2 | Python | `%s` hoặc `%(ten)s` (kể cả với số, không dùng `%d`) |
| asyncpg | Python | `$1`, `$2` |
| sqlite3 | Python | `?` hoặc `:ten` |
| pg (node-postgres) | Node.js | `$1`, `$2` |
| mysql2 | Node.js | `?` |
| JDBC | Java | `?` |
| SqlClient (SQL Server) | C# | `@ten` |

### Những thứ không truyền bằng tham số được

Tham số chỉ thay được giá trị (số, chuỗi, ngày...). Tên bảng, tên cột, từ khóa `ASC`/`DESC` không truyền bằng `%s` được. Khi cần cho người dùng chọn cột sắp xếp, hãy so với một danh sách cho phép (whitelist) rồi ghép bằng module `psycopg.sql`, nó tự đặt tên trong ngoặc kép đúng cách:

```python
import os
import psycopg
from psycopg import sql

ALLOWED_SORT = {"price", "name", "stock_quantity"}

def list_products(conn, sort_by="price", descending=False):
    if sort_by not in ALLOWED_SORT:
        raise ValueError(f"Không cho phép sắp xếp theo {sort_by!r}")
    query = sql.SQL(
        "SELECT sku, name, price FROM products WHERE category_id = %s ORDER BY {col} {dir} LIMIT 3"
    ).format(
        col=sql.Identifier(sort_by),
        dir=sql.SQL("DESC" if descending else "ASC"),
    )
    return conn.execute(query, (10,)).fetchall()

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    for row in list_products(conn, "price", descending=True):
        print(row)
    list_products(conn, "price; DROP TABLE orders")   # ValueError, không chạy SQL nào
```

```text
('ACC-002', 'Chuột Logitech MX Master 3S', Decimal('2490000'))
('ACC-003', 'Bàn phím cơ Keychron K2', Decimal('1890000'))
('ACC-001', 'Chuột Logitech G102', Decimal('399000'))
ValueError: Không cho phép sắp xếp theo 'price; DROP TABLE orders'
```

Hai trường hợp hay gặp khác:

```python
# LIKE/ILIKE: dấu % nằm trong GIÁ TRỊ tham số, không nằm trong câu SQL
conn.execute("SELECT sku, name FROM products WHERE name ILIKE %s ORDER BY sku", (f"%{kw}%",))
# kw = "logitech" -> [('ACC-001', 'Chuột Logitech G102'), ('ACC-002', 'Chuột Logitech MX Master 3S')]

# Danh sách giá trị: truyền một list và dùng = ANY(...) thay cho IN (...)
conn.execute("SELECT order_id, status FROM orders WHERE order_id = ANY(%s) ORDER BY order_id", ([5, 15, 28],))
# -> [(5, 'cancelled'), (15, 'cancelled'), (28, 'cancelled')]
```

`= ANY(mảng)` là cú pháp PostgreSQL, nghĩa là "bằng một phần tử bất kỳ trong mảng", tương đương `IN (5, 15, 28)` nhưng chỉ cần một tham số. Trong Node viết `WHERE order_id = ANY($1::int[])` và truyền mảng JavaScript.

## Connection pool

Mỗi lần mở kết nối mới, PostgreSQL phải bắt tay TCP, xác thực mật khẩu và tạo một tiến trình riêng phục vụ kết nối đó. Việc này tốn thời gian. Hơn nữa server chỉ nhận số kết nối có hạn (mặc định `max_connections = 100`). Một web server mở kết nối mới cho mỗi request sẽ vừa chậm vừa dễ làm cạn kết nối.

Connection pool giữ sẵn một nhóm kết nối đã mở. Mỗi request "mượn" một kết nối, dùng xong thì trả lại cho request sau dùng tiếp.

```mermaid
sequenceDiagram
    participant R as Request
    participant P as Pool (giữ sẵn 2-5 kết nối)
    participant DB as PostgreSQL
    R->>P: Mượn một kết nối
    P-->>R: Kết nối đã mở sẵn
    R->>DB: Truy vấn
    DB-->>R: Kết quả
    R->>P: Trả kết nối (không đóng)
```

Đo thử 200 truy vấn `SELECT 1`, mở kết nối mới mỗi lần so với dùng pool:

```python
import os
import time
import psycopg
from psycopg_pool import ConnectionPool

DSN = os.environ["DATABASE_URL"]
N = 200

start = time.perf_counter()
for _ in range(N):
    with psycopg.connect(DSN) as conn:          # mở kết nối mới mỗi lần
        conn.execute("SELECT 1").fetchone()
print(f"Mở mới mỗi lần: {time.perf_counter() - start:.2f} giây")

with ConnectionPool(DSN, min_size=2, max_size=5) as pool:
    start = time.perf_counter()
    for _ in range(N):
        with pool.connection() as conn:          # mượn kết nối có sẵn
            conn.execute("SELECT 1").fetchone()
    print(f"Dùng pool:      {time.perf_counter() - start:.2f} giây")
```

Trên máy mình (Windows, PostgreSQL trong Docker Desktop):

```text
Mở mới mỗi lần: 4.23 giây
Dùng pool:      0.25 giây
```

Số trên máy bạn sẽ khác, nhưng chênh lệch cỡ hàng chục lần là bình thường. Trong Node.js, `pg` có sẵn `Pool`: `const pool = new Pool({ connectionString, max: 10 })`, sau đó gọi `pool.query(...)` y như `client.query(...)`. Tạo pool một lần khi ứng dụng khởi động, không tạo mới cho mỗi request.

## Transaction từ code

Đặt một đơn hàng gồm nhiều bước: tạo dòng `orders`, trừ kho từng sản phẩm, thêm `order_items`. Các bước phải thành công cùng nhau hoặc không bước nào được giữ lại (tính nguyên tử, xem [Ngày 16](16-transactions-acid.md)).

### Python

```python
import os
from psycopg_pool import ConnectionPool

pool = ConnectionPool(os.environ["DATABASE_URL"], min_size=1, max_size=5, open=True)


class OutOfStock(Exception):
    pass


def place_order(customer_id, items):
    """items: danh sách (product_id, quantity). Trả về order_id mới."""
    with pool.connection() as conn:
        with conn.transaction():
            order_id = conn.execute(
                """
                INSERT INTO orders (customer_id, order_date, status, channel, shipping_city)
                VALUES (%s, now(), 'pending', 'online', NULL)
                RETURNING order_id
                """,
                (customer_id,),
            ).fetchone()[0]

            for product_id, quantity in items:
                # Trừ kho có điều kiện: chỉ trừ khi còn đủ hàng
                cur = conn.execute(
                    """
                    UPDATE products
                    SET stock_quantity = stock_quantity - %s
                    WHERE product_id = %s AND stock_quantity >= %s
                    RETURNING price
                    """,
                    (quantity, product_id, quantity),
                )
                if cur.rowcount == 0:
                    # 0 dòng bị sửa: hết hàng (hoặc không có sản phẩm này).
                    # Ném lỗi bên trong khối transaction() => psycopg tự ROLLBACK
                    raise OutOfStock(f"Sản phẩm {product_id} không đủ hàng")
                price = cur.fetchone()[0]

                conn.execute(
                    """
                    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (order_id, product_id, quantity, price),
                )
            return order_id


if __name__ == "__main__":
    print("Đơn mới:", place_order(16, [(16, 2), (23, 1)]))
    try:
        place_order(16, [(17, 1), (3, 1)])   # sản phẩm 3 đang hết hàng
    except OutOfStock as e:
        print("Lỗi:", e)
    pool.close()
```

Chạy trên dữ liệu gốc:

```text
Đơn mới: 41
Lỗi: Sản phẩm 3 không đủ hàng
```

Kiểm tra lại trong psql:

| product_id | stock_quantity |
| --- | --- |
| 3 | 0 |
| 16 | 58 |
| 17 | 20 |
| 23 | 199 |

Đơn 41 đã trừ 2 chuột G102 (60 → 58) và 1 cáp (200 → 199). Đơn thứ hai bị ROLLBACK toàn bộ: chuột MX Master (sản phẩm 17) vẫn còn 20 dù câu UPDATE trừ kho của nó đã chạy trước khi phát hiện sản phẩm 3 hết hàng, và không có dòng `orders` nào thừa. Đơn kế tiếp sẽ có id 43 chứ không phải 42: giá trị IDENTITY đã cấp trong transaction bị hủy thì không được trả lại, nên id có "lỗ hổng" là bình thường.

Mấu chốt là `cur.rowcount`: số dòng câu lệnh vừa tác động (trong psql chính là con số ở `UPDATE 1` hay `UPDATE 0`). Câu UPDATE có điều kiện không bao giờ báo lỗi khi hết hàng, nó chỉ sửa 0 dòng. Nếu code không kiểm tra `rowcount`, đơn hàng vẫn được tạo dù kho không bị trừ. Đây là việc "tự kiểm tra `UPDATE 0`" mà [Ngày 16](16-transactions-acid.md) đã hẹn. Node.js dùng `result.rowCount` tương tự.

Điều kiện `stock_quantity >= %s` nằm ngay trong câu UPDATE là có chủ đích. Nếu viết kiểu "SELECT xem tồn kho, rồi if đủ thì UPDATE", hai request đồng thời có thể cùng thấy còn 1 sản phẩm và cùng trừ (lost update, Ngày 16). Một câu UPDATE có điều kiện thì PostgreSQL khóa dòng và kiểm tra lại, không bị lỗi này.

### Node.js

Trong Node, transaction phải chạy trên **một** kết nối. `pool.query()` mỗi lần có thể lấy một kết nối khác, nên `BEGIN` ở kết nối này còn `COMMIT` ở kết nối kia. Phải mượn hẳn một client:

```js
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 5 });

async function placeOrder(customerId, items) {
  const client = await pool.connect(); // mượn MỘT kết nối cho cả transaction
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO orders (customer_id, order_date, status, channel)
       VALUES ($1, now(), 'pending', 'online')
       RETURNING order_id`,
      [customerId]
    );
    const orderId = rows[0].order_id;

    for (const { productId, quantity } of items) {
      const upd = await client.query(
        `UPDATE products
         SET stock_quantity = stock_quantity - $1
         WHERE product_id = $2 AND stock_quantity >= $1
         RETURNING price`,
        [quantity, productId]
      );
      if (upd.rowCount === 0) {
        throw new Error(`Sản phẩm ${productId} không đủ hàng`);
      }
      await client.query(
        `INSERT INTO order_items (order_id, product_id, quantity, unit_price)
         VALUES ($1, $2, $3, $4)`,
        [orderId, productId, quantity, upd.rows[0].price]
      );
    }

    await client.query('COMMIT');
    return orderId;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release(); // trả kết nối về pool, kể cả khi lỗi
  }
}
```

Quên `client.release()` thì sau vài request pool hết kết nối và ứng dụng treo. Vì vậy đặt nó trong `finally`.

### Thử lại khi gặp lỗi tuần tự hóa hoặc deadlock

Ở [Ngày 16](16-transactions-acid.md) bạn đã thấy hai lỗi mà PostgreSQL chủ động ném ra để bảo vệ dữ liệu khi nhiều transaction chạy cùng lúc:

| SQLSTATE | Tên | Khi nào |
| --- | --- | --- |
| `40001` | serialization_failure | Ở mức `REPEATABLE READ`/`SERIALIZABLE`, transaction định sửa một dòng mà phiên khác vừa sửa và commit |
| `40P01` | deadlock_detected | Hai transaction chờ khóa của nhau, PostgreSQL hủy một bên |

Hai lỗi này không phải do dữ liệu sai: chạy lại nguyên transaction từ đầu thường sẽ thành công. Vì vậy code nên bắt riêng hai mã này và thử lại, có giới hạn số lần (để không lặp vô tận) và chờ một chút giữa các lần. Các lỗi khác (vi phạm ràng buộc, hết hàng) thì không thử lại, vì chạy lại cũng sai y như cũ.

```python
import os
import time
import psycopg
from psycopg import errors

DSN = os.environ["DATABASE_URL"]
RETRYABLE = (errors.SerializationFailure, errors.DeadlockDetected)   # 40001, 40P01

def run_with_retry(conn, work, max_attempts=3):
    """Chạy work(conn) trong một transaction, thử lại khi gặp 40001/40P01."""
    for attempt in range(1, max_attempts + 1):
        try:
            with conn.transaction():
                return work(conn, attempt)
        except RETRYABLE as e:
            print(f"Lần {attempt}: {e.sqlstate} {e.diag.message_primary}")
            if attempt == max_attempts:
                raise
            time.sleep(0.05 * 2 ** attempt)   # chờ một chút rồi thử lại

def restock(conn, attempt):
    # Đọc tồn kho rồi ghi lại (cố ý viết kiểu "đọc rồi ghi" để thấy xung đột)
    stock = conn.execute(
        "SELECT stock_quantity FROM products WHERE product_id = %s", (16,)
    ).fetchone()[0]
    if attempt == 1:
        # Giả lập một phiên khác sửa cùng dòng đúng lúc này
        with psycopg.connect(DSN, autocommit=True) as other:
            other.execute("UPDATE products SET stock_quantity = stock_quantity - 1 WHERE product_id = 16")
    conn.execute(
        "UPDATE products SET stock_quantity = %s WHERE product_id = %s", (stock + 10, 16)
    )
    return stock + 10

with psycopg.connect(DSN) as conn:
    conn.isolation_level = psycopg.IsolationLevel.REPEATABLE_READ
    print("Tồn kho mới:", run_with_retry(conn, restock))
```

Chạy trên dữ liệu gốc (chuột G102 còn 60):

```text
Lần 1: 40001 could not serialize access due to concurrent update
Tồn kho mới: 69
```

Lần 1 đọc được 60, nhưng phiên khác đã trừ còn 59 và commit trước khi lần 1 kịp ghi. Ở mức `REPEATABLE READ`, PostgreSQL từ chối ghi đè lên thay đổi đó (nếu không, 1 chiếc vừa bán sẽ "biến mất", đúng hiện tượng lost update). Lần 2 chạy lại từ đầu, đọc 59 và ghi 69, kết quả đúng. Điều quan trọng: thử lại **cả transaction** (gồm cả câu SELECT), không chỉ câu UPDATE bị lỗi. Trong Node.js, kiểm tra `err.code === '40001' || err.code === '40P01'` trong khối `catch` rồi gọi lại hàm như `placeOrder` ở trên.

### Gọi procedure từ code

Nếu nghiệp vụ đã nằm trong procedure, như `place_order` ở [Ngày 17](17-stored-procedures-functions.md), code chỉ cần `CALL` nó với tham số. Giá trị của tham số `OUT` trả về như một dòng kết quả:

```python
import os
import psycopg
from psycopg import errors

def place_order(conn, customer_id, product_id, quantity):
    with conn.transaction():
        row = conn.execute(
            "CALL place_order(%s, %s, %s, NULL)", (customer_id, product_id, quantity)
        ).fetchone()
        return row[0]          # giá trị của tham số OUT o_order_id

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    print("Đơn mới:", place_order(conn, 16, 16, 2))
    try:
        place_order(conn, 16, 3, 1)
    except errors.CheckViolation as e:
        print("Lỗi:", e.sqlstate, e.diag.message_primary)
```

```text
Đơn mới: 41
Lỗi: 23514 Sản phẩm 3 không đủ hàng hoặc đã ngừng bán
```

Mã lỗi `23514` chính là `ERRCODE = 'check_violation'` mà procedure tự gắn khi `RAISE EXCEPTION`, nên code bắt đúng lỗi bằng `errors.CheckViolation` thay vì đọc chuỗi thông báo. Node.js tương tự: `const { rows } = await pool.query('CALL place_order($1, $2, $3, NULL)', [16, 16, 2])` trả về `rows[0].o_order_id`. Cần tạo procedure ở Ngày 17 trước khi chạy đoạn này.

Code ở trên đã ghi dữ liệu vào `shop`. Muốn đưa dữ liệu về như cũ, chạy lại hai file init (mục "Làm lại từ đầu" trong [setup/README.md](../setup/README.md)).

## Xử lý lỗi

Lỗi từ PostgreSQL có mã SQLSTATE 5 ký tự. Một số mã hay gặp:

| SQLSTATE | Tên | Khi nào |
| --- | --- | --- |
| `23505` | unique_violation | Trùng giá trị UNIQUE (email, sku) |
| `23503` | foreign_key_violation | Khóa ngoại trỏ tới dòng không tồn tại |
| `23502` | not_null_violation | Thiếu giá trị cho cột NOT NULL |
| `23514` | check_violation | Vi phạm CHECK (giá âm, status lạ) |
| `22P02` | invalid_text_representation | Chuỗi không đổi được sang số |

psycopg có sẵn lớp exception cho từng mã, bắt đúng loại lỗi để trả thông báo dễ hiểu:

```python
import os
import psycopg
from psycopg import errors

def add_customer(conn, full_name, email):
    try:
        with conn.transaction():
            return conn.execute(
                "INSERT INTO customers (full_name, email) VALUES (%s, %s) RETURNING customer_id",
                (full_name, email),
            ).fetchone()[0]
    except errors.UniqueViolation:
        return "Email đã được dùng"
    except errors.NotNullViolation:
        return "Thiếu họ tên"

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    print(add_customer(conn, "Trần Bình", "binh.tran@gmail.com"))
    print(add_customer(conn, None, "moi@gmail.com"))
    try:
        conn.execute("INSERT INTO orders (customer_id, order_date, channel) VALUES (%s, now(), 'online')", (999,))
    except psycopg.Error as e:
        print(type(e).__name__, e.sqlstate)
        print(e.diag.message_primary)
        print(e.diag.message_detail)
        print(e.diag.constraint_name)
    conn.rollback()
```

```text
Email đã được dùng
Thiếu họ tên
ForeignKeyViolation 23503
insert or update on table "orders" violates foreign key constraint "orders_customer_id_fkey"
Key (customer_id)=(999) is not present in table "customers".
orders_customer_id_fkey
```

Sau một lỗi, transaction hiện tại bị hỏng ("current transaction is aborted"), mọi câu tiếp theo đều bị từ chối cho tới khi `ROLLBACK`. Đó là lý do có `conn.rollback()` ở cuối, và vì sao gói từng thao tác trong `with conn.transaction():` là thói quen tốt.

Trong Node, mã lỗi nằm ở `err.code`. Ví dụ một API nhỏ bằng Express dùng pool, tham số hóa, trả 404 khi không có dữ liệu, 400 khi dữ liệu sai và không làm sập server khi lỗi:

```js
const express = require('express');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 10 });
const app = express();
app.use(express.json());

// GET /products?category_id=10&max_price=3000000
app.get('/products', async (req, res, next) => {
  try {
    const categoryId = req.query.category_id ?? null;
    const maxPrice = req.query.max_price ?? null;
    const { rows } = await pool.query(
      `SELECT product_id, sku, name, price, stock_quantity
       FROM products
       WHERE is_active
         AND ($1::int IS NULL OR category_id = $1::int)
         AND ($2::numeric IS NULL OR price <= $2::numeric)
       ORDER BY price`,
      [categoryId, maxPrice]
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

// GET /products/LAP-001
app.get('/products/:sku', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT product_id, sku, name, price, stock_quantity FROM products WHERE sku = $1',
      [req.params.sku]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Không tìm thấy sản phẩm' });
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

// PATCH /products/LAP-001/price   body: {"price": 31990000}
app.patch('/products/:sku/price', async (req, res, next) => {
  try {
    const result = await pool.query(
      'UPDATE products SET price = $1 WHERE sku = $2 RETURNING sku, price',
      [req.body.price, req.params.sku]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Không tìm thấy sản phẩm' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

// Mọi lỗi dồn về đây: ghi log đầy đủ ở server, trả thông báo gọn cho client
app.use((err, req, res, next) => {
  if (err.code === '23514' || err.code === '22P02') {
    return res.status(400).json({ error: 'Dữ liệu không hợp lệ' });
  }
  console.error(err);
  res.status(500).json({ error: 'Lỗi máy chủ' });
});

app.listen(3000, () => console.log('API chạy ở http://localhost:3000'));
```

Cài `npm install express pg`, chạy `node server.js` rồi gọi thử:

```sh
curl "http://localhost:3000/products?category_id=10&max_price=1000000"
# [{"product_id":24,"sku":"ACC-009","name":"Lót chuột DSC XXL","price":"250000","stock_quantity":30},
#  {"product_id":16,"sku":"ACC-001","name":"Chuột Logitech G102","price":"399000","stock_quantity":60}]

curl -i http://localhost:3000/products/XXX-999
# HTTP/1.1 404 ... {"error":"Không tìm thấy sản phẩm"}

curl -X PATCH http://localhost:3000/products/LAP-001/price -H "Content-Type: application/json" -d '{"price": 31990000}'
# {"sku":"LAP-001","price":"31990000"}

curl -X PATCH http://localhost:3000/products/LAP-001/price -H "Content-Type: application/json" -d '{"price": -5}'
# {"error":"Dữ liệu không hợp lệ"}   (CHECK price >= 0 chặn ở database, mã 23514)
```

Mẹo `($1::int IS NULL OR category_id = $1::int)` cho phép một câu SQL cố định phục vụ cả trường hợp có và không có bộ lọc, mà không phải ghép chuỗi SQL. Lưu ý: không trả `err.message` thô cho client, vì thông báo lỗi có thể lộ tên bảng, tên cột cho kẻ tấn công.

## ORM và vấn đề N+1

ORM (Object-Relational Mapping) như SQLAlchemy, Django ORM (Python), Prisma, Sequelize, TypeORM (Node.js) cho bạn làm việc với object thay vì viết SQL. ORM tiện cho CRUD đơn giản, tự tham số hóa nên an toàn trước injection, nhưng nó vẫn sinh ra SQL. Không hiểu SQL bên dưới thì rất dễ viết code chạy chậm.

Lỗi kinh điển là N+1: chạy 1 truy vấn lấy danh sách, rồi trong vòng lặp chạy thêm 1 truy vấn cho mỗi phần tử. Ví dụ đếm số đơn của khách ở Hà Nội:

```python
import os
import psycopg

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    # Cách N+1: 1 truy vấn lấy khách + N truy vấn lấy đơn của từng khách
    n_queries = 1
    customers = conn.execute(
        "SELECT customer_id, full_name FROM customers WHERE city = %s ORDER BY customer_id",
        ("Hà Nội",),
    ).fetchall()
    for customer_id, full_name in customers:
        count = conn.execute(
            "SELECT count(*) FROM orders WHERE customer_id = %s", (customer_id,)
        ).fetchone()[0]
        n_queries += 1
        print(full_name, count)
    print("Số truy vấn:", n_queries)
```

```text
Trần Thị Bình 4
Đặng Thu Giang 2
Phan Thị Oanh 2
Nguyễn Văn An 2
Số truy vấn: 5
```

4 khách thì 5 truy vấn. 10.000 khách thì 10.001 truy vấn, mỗi cái tốn một vòng đi về qua mạng. Cách đúng là để database làm việc nó giỏi nhất, một truy vấn duy nhất:

```sql
SELECT c.full_name, count(o.order_id) AS so_don
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE c.city = 'Hà Nội'
GROUP BY c.customer_id, c.full_name
ORDER BY c.customer_id;
```

| full_name | so_don |
| --- | --- |
| Trần Thị Bình | 4 |
| Đặng Thu Giang | 2 |
| Phan Thị Oanh | 2 |
| Nguyễn Văn An | 2 |

Với ORM, N+1 thường ẩn sau thuộc tính quan hệ được tải lười (lazy loading). Ví dụ minh họa với SQLAlchemy 2.0 (giả sử đã khai báo model `Customer` có quan hệ `Customer.orders`):

```python
from sqlalchemy import select
from sqlalchemy.orm import selectinload

# N+1: mỗi lần đọc c.orders, SQLAlchemy chạy thêm một câu SELECT
customers = session.scalars(select(Customer).where(Customer.city == "Hà Nội")).all()
for c in customers:
    print(c.full_name, len(c.orders))

# Sửa: báo trước cần tải orders, tổng cộng chỉ 2 câu SELECT
customers = session.scalars(
    select(Customer).where(Customer.city == "Hà Nội").options(selectinload(Customer.orders))
).all()
```

Cách phát hiện: bật log SQL của ORM (SQLAlchemy `echo=True`, Prisma `log: ['query']`) và đếm số câu SQL cho một request. Thấy cùng một câu lặp đi lặp lại chỉ khác tham số là N+1. Ngày 28 sẽ bàn thêm về tối ưu truy vấn.

Một việc nữa ORM và các công cụ như Alembic, Prisma Migrate, Flyway hay làm: quản lý migration, tức mỗi thay đổi schema (thêm cột, thêm index) là một file SQL có số phiên bản, lưu trong git và chạy theo thứ tự trên mọi môi trường. Như vậy không ai phải sửa schema bằng tay trên server.

## Lỗi thường gặp

**1. Nối chuỗi tạo câu SQL.** Kể cả f-string, `+`, template literal `` `...${x}` ``. Luôn dùng tham số. Tên cột/bảng động thì dùng whitelist.

**2. Dùng sai ký hiệu placeholder.** Chép `?` của MySQL sang psycopg hoặc pg:

```python
conn.execute("SELECT full_name FROM customers WHERE customer_id = ?", (1,))
# psycopg.ProgrammingError: the query has 0 placeholders but 1 parameters were passed
```

```js
await pool.query('SELECT full_name FROM customers WHERE customer_id = ?', [1]);
// error 42601: syntax error at end of input
```

**3. Bọc placeholder trong nháy đơn.** Driver tự xử lý kiểu dữ liệu, không cần (và không được) thêm nháy:

```python
conn.execute("SELECT full_name FROM customers WHERE email = '%s'", ("binh.tran@gmail.com",))
# psycopg.errors.IndeterminateDatatype: could not determine data type of parameter $1
```

Viết đúng: `WHERE email = %s`.

**4. Quên dấu phẩy ở tuple một phần tử.** `("binh.tran@gmail.com")` chỉ là một chuỗi trong ngoặc, không phải tuple:

```text
TypeError: query parameters should be a sequence or a mapping, got str
```

Viết đúng: `("binh.tran@gmail.com",)` hoặc dùng list `["binh.tran@gmail.com"]`.

**5. Quên COMMIT.** psycopg mặc định mở transaction ngầm. Nếu bạn tự `psycopg.connect()` (không dùng `with`), chạy UPDATE rồi `conn.close()` mà không `conn.commit()`, thay đổi bị bỏ:

```python
conn = psycopg.connect(os.environ["DATABASE_URL"])
conn.execute("UPDATE products SET stock_quantity = 999 WHERE product_id = 1")
conn.close()          # quên commit => stock_quantity của sản phẩm 1 vẫn là 5
```

Dùng `with psycopg.connect(...)` hoặc `with conn.transaction():` để khỏi phải nhớ. Ngược lại, gọi `conn.rollback()` sau một lỗi sẽ hủy **mọi** câu lệnh chưa commit trong transaction ngầm đó, kể cả những câu đã thành công trước lỗi. Gói mỗi thao tác nghiệp vụ trong `with conn.transaction():` riêng thì lỗi của thao tác sau không xóa mất thao tác trước.

**6. Chạy transaction bằng `pool.query()` trong Node.** Các câu có thể chạy trên các kết nối khác nhau. Phải `const client = await pool.connect()` và `client.release()` trong `finally`.

**7. `throw err` trong callback hoặc không bắt lỗi.** Một lỗi SQL làm sập cả server Node. Bắt lỗi, ghi log, trả mã HTTP phù hợp (400/404/409/500).

**8. Dùng `float` cho tiền.** Giữ `Decimal` (Python) hoặc chuỗi/thư viện decimal (Node) cho cột `NUMERIC`.

## Bài tập

Đặt biến môi trường `DATABASE_URL` trước khi chạy. Bài nào sửa dữ liệu thì chạy lại hai file init sau khi làm xong.

### Cơ bản

**Bài 1.** Viết hàm Python `get_orders_of_customer(conn, customer_id)` trả về `order_id`, ngày đặt (kiểu date) và `status` các đơn của một khách, sắp theo ngày đặt. In kết quả với khách 1.

<details>
<summary>Đáp án</summary>

```python
import os
import psycopg

def get_orders_of_customer(conn, customer_id):
    return conn.execute(
        """
        SELECT order_id, order_date::date AS order_date, status
        FROM orders
        WHERE customer_id = %s
        ORDER BY order_date
        """,
        (customer_id,),
    ).fetchall()

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    for row in get_orders_of_customer(conn, 1):
        print(row)
```

Kết quả:

```text
(1, datetime.date(2025, 1, 12), 'delivered')
(4, datetime.date(2025, 2, 14), 'delivered')
(13, datetime.date(2025, 7, 8), 'delivered')
(25, datetime.date(2025, 12, 24), 'delivered')
(37, datetime.date(2026, 9, 2), 'shipped')
```
</details>

**Bài 2.** Viết hàm Node.js `findCustomerByEmail(email)` dùng pool, trả về object khách (`customer_id`, `full_name`, `city`) hoặc `null` nếu không có. Thử với `an.nguyenvan@gmail.com` và với chuỗi `' OR '1'='1`.

<details>
<summary>Đáp án</summary>

```js
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function findCustomerByEmail(email) {
  const { rows } = await pool.query(
    'SELECT customer_id, full_name, city FROM customers WHERE email = $1',
    [email]
  );
  return rows[0] ?? null; // không tìm thấy thì trả null
}

(async () => {
  console.log(await findCustomerByEmail('an.nguyenvan@gmail.com'));
  console.log(await findCustomerByEmail("' OR '1'='1"));
  await pool.end();
})();
```

Kết quả:

```text
{ customer_id: 15, full_name: 'Nguyễn Văn An', city: 'Hà Nội' }
null
```

Chuỗi tấn công chỉ được coi là một email lạ nên không khớp dòng nào.
</details>

**Bài 3.** Đoạn code sau tìm sản phẩm theo từ khóa. Chỉ ra lỗ hổng và sửa lại.

```python
def search(conn, kw):
    return conn.execute(f"SELECT sku, name FROM products WHERE name ILIKE '%{kw}%' ORDER BY sku").fetchall()
```

<details>
<summary>Đáp án</summary>

`kw` được ghép thẳng vào SQL. Với `kw = "x%' OR 1=1 --"` câu thành `... WHERE name ILIKE '%x%' OR 1=1 --%' ORDER BY sku`: phần sau `--` thành chú thích, điều kiện `OR 1=1` trả về mọi sản phẩm. Người dùng đã điều khiển được câu lệnh. Sửa: đưa cả dấu `%` vào giá trị tham số.

```python
def search(conn, kw):
    return conn.execute(
        "SELECT sku, name FROM products WHERE name ILIKE %s ORDER BY sku",
        (f"%{kw}%",),
    ).fetchall()
```

Kết quả `search(conn, "logitech")`:

```text
[('ACC-001', 'Chuột Logitech G102'), ('ACC-002', 'Chuột Logitech MX Master 3S')]
```
</details>

### Vận dụng

**Bài 4.** Viết hàm Python `monthly_revenue(conn, year)` trả về doanh thu từng tháng của một năm (bỏ đơn `cancelled`, doanh thu tính từ `order_items`, làm tròn đến đồng). Năm là tham số, không ghép chuỗi. In kết quả năm 2026.

<details>
<summary>Đáp án</summary>

```python
import os
import psycopg

def monthly_revenue(conn, year):
    return conn.execute(
        """
        SELECT EXTRACT(MONTH FROM o.order_date)::int AS thang,
               ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.order_id
        WHERE o.status <> 'cancelled'
          AND o.order_date >= make_date(%s, 1, 1)
          AND o.order_date <  make_date(%s + 1, 1, 1)
        GROUP BY thang
        ORDER BY thang
        """,
        (year, year),
    ).fetchall()

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    for thang, doanh_thu in monthly_revenue(conn, 2026):
        print(thang, doanh_thu)
```

Kết quả:

| thang | doanh_thu |
| --- | --- |
| 1 | 34030500 |
| 2 | 11560000 |
| 3 | 18490000 |
| 4 | 17759000 |
| 5 | 21990000 |
| 6 | 1640000 |
| 7 | 17091000 |
| 8 | 29990000 |
| 9 | 17630000 |
| 10 | 44870000 |

Lọc bằng khoảng `>= đầu năm AND < đầu năm sau` thay vì `EXTRACT(YEAR ...) = %s` để PostgreSQL dùng được index trên `order_date` nếu có (Ngày 28).
</details>

**Bài 5.** Viết hàm Python `cancel_order(conn, order_id)` trong một transaction: chỉ hủy được đơn đang `pending` (đổi thành `cancelled`), đồng thời cộng trả số lượng của từng dòng hàng vào `stock_quantity`. Nếu đơn không tồn tại hoặc không ở trạng thái `pending` thì báo lỗi và không đổi gì. Thử với đơn 40 và đơn 1.

<details>
<summary>Đáp án</summary>

```python
import os
import psycopg

class CannotCancel(Exception):
    pass

def cancel_order(conn, order_id):
    with conn.transaction():
        row = conn.execute(
            """
            UPDATE orders
            SET status = 'cancelled'
            WHERE order_id = %s AND status = 'pending'
            RETURNING order_id
            """,
            (order_id,),
        ).fetchone()
        if row is None:
            raise CannotCancel(f"Đơn {order_id} không tồn tại hoặc không còn ở trạng thái pending")

        cur = conn.execute(
            """
            UPDATE products p
            SET stock_quantity = p.stock_quantity + oi.quantity
            FROM order_items oi
            WHERE oi.order_id = %s AND oi.product_id = p.product_id
            """,
            (order_id,),
        )
        return cur.rowcount

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    print("Số sản phẩm được cộng lại kho:", cancel_order(conn, 40))
    try:
        cancel_order(conn, 1)
    except CannotCancel as e:
        print("Lỗi:", e)
```

Kết quả:

```text
Số sản phẩm được cộng lại kho: 1
Lỗi: Đơn 1 không tồn tại hoặc không còn ở trạng thái pending
```

Sau đó đơn 40 có status `cancelled`, sản phẩm 12 (Redmi Note 13) tăng từ 25 lên 26. Đặt điều kiện `status = 'pending'` ngay trong UPDATE (thay vì SELECT trước rồi kiểm tra) giúp hai request hủy cùng lúc không cộng kho hai lần.
</details>

**Bài 6.** Đoạn Node.js sau lấy dòng hàng của nhiều đơn bằng N+1. Viết lại thành một truy vấn, kết quả trả về vẫn là object `{ order_id: [ {product_id, quantity}, ... ] }`. Thử với các đơn `[29, 31, 34]`.

```js
async function itemsSlow(orderIds) {
  const result = {};
  for (const id of orderIds) {
    const { rows } = await pool.query(
      'SELECT product_id, quantity FROM order_items WHERE order_id = $1 ORDER BY product_id', [id]);
    result[id] = rows;
  }
  return result;
}
```

<details>
<summary>Đáp án</summary>

```js
async function itemsFast(orderIds) {
  const { rows } = await pool.query(
    `SELECT order_id, product_id, quantity
     FROM order_items
     WHERE order_id = ANY($1::int[])
     ORDER BY order_id, product_id`,
    [orderIds]
  );
  const result = {};
  for (const id of orderIds) result[id] = [];
  for (const r of rows) result[r.order_id].push({ product_id: r.product_id, quantity: r.quantity });
  return result;
}
```

Cả hai hàm in ra cùng một kết quả, nhưng `itemsFast` chỉ chạy 1 truy vấn thay vì 3:

```text
{"29":[{"product_id":12,"quantity":2},{"product_id":22,"quantity":2}],
 "31":[{"product_id":16,"quantity":1},{"product_id":17,"quantity":1},{"product_id":18,"quantity":1}],
 "34":[{"product_id":22,"quantity":1},{"product_id":23,"quantity":5}]}
```
</details>

### Thử thách

**Bài 7.** Thêm vào API Express ở trên endpoint `POST /orders` nhận body `{"customer_id": 16, "items": [{"product_id": 16, "quantity": 2}]}` và dùng hàm `placeOrder` (bản Node). Trả về:

- `201` và `{"order_id": ...}` khi thành công,
- `409` khi một sản phẩm không đủ hàng,
- `400` khi `customer_id` không tồn tại (lỗi khóa ngoại `23503`) hoặc `quantity` không hợp lệ (`23514`, CHECK `quantity > 0`).

<details>
<summary>Đáp án</summary>

Sửa `placeOrder` để ném một lỗi riêng khi hết hàng, rồi ánh xạ lỗi sang mã HTTP:

```js
class OutOfStockError extends Error {}

// trong placeOrder, thay throw new Error(...) bằng:
//   throw new OutOfStockError(`Sản phẩm ${productId} không đủ hàng`);

app.post('/orders', async (req, res, next) => {
  try {
    const { customer_id: customerId, items } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Đơn hàng phải có ít nhất một sản phẩm' });
    }
    const orderId = await placeOrder(
      customerId,
      items.map((i) => ({ productId: i.product_id, quantity: i.quantity }))
    );
    res.status(201).json({ order_id: orderId });
  } catch (err) {
    if (err instanceof OutOfStockError) return res.status(409).json({ error: err.message });
    if (err.code === '23503') return res.status(400).json({ error: 'Khách hàng hoặc sản phẩm không tồn tại' });
    next(err); // 23514, 22P02 và lỗi khác đi qua middleware xử lý lỗi chung
  }
});
```

Đặt hàng sản phẩm 3 (đang hết hàng) sẽ nhận `409`, không có dòng `orders` nào được tạo vì `placeOrder` đã ROLLBACK. Gửi `"quantity": 0` thì câu UPDATE trừ kho vẫn chạy được, nhưng câu INSERT vào `order_items` vi phạm CHECK `quantity > 0` (mã `23514`), transaction bị ROLLBACK và middleware trả `400`.
</details>

## Tóm tắt

- Ứng dụng gửi SQL qua driver: psycopg 3 (Python, placeholder `%s`), pg (Node.js, placeholder `$1`). Thông tin kết nối để trong biến môi trường, không viết thẳng vào code.
- Luôn dùng truy vấn tham số hóa. Câu SQL và giá trị được gửi riêng, PostgreSQL chốt cấu trúc câu trước nên giá trị không thể biến thành code. Tên cột/bảng động thì dùng whitelist.
- Dùng connection pool: tạo một lần, mượn và trả kết nối cho mỗi request.
- Nghiệp vụ nhiều bước chạy trong một transaction trên một kết nối; lỗi thì ROLLBACK. Đặt điều kiện kiểm tra (đủ hàng, đúng trạng thái) ngay trong câu UPDATE và kiểm tra `rowcount`/`rowCount`: 0 dòng nghĩa là điều kiện không thỏa.
- Lỗi `40001` (serialization_failure) và `40P01` (deadlock_detected) thì thử lại cả transaction, có giới hạn số lần. Nghiệp vụ đã có procedure thì gọi `CALL` với tham số.
- Bắt lỗi theo SQLSTATE, trả thông báo gọn cho người dùng, ghi log chi tiết ở server.
- ORM tiện nhưng vẫn sinh SQL; cảnh giác N+1, thay vòng lặp truy vấn bằng JOIN hoặc `= ANY(...)`.

## Đọc thêm

- [psycopg 3: Basic module usage](https://www.psycopg.org/psycopg3/docs/basic/usage.html) và [Passing parameters to SQL queries](https://www.psycopg.org/psycopg3/docs/basic/params.html)
- [node-postgres: Queries, Pooling, Transactions](https://node-postgres.com/)
- [Hai giao dịch cùng cộng 100, số dư chỉ tăng 100: isolation level qua thí nghiệm thật](https://tiennhm.io.vn/blog/sql-isolation-level-lost-update-phantom-read) — Hai phiên cùng đọc số dư 1000 rồi cùng ghi 1100, đúng kịch bản cần tránh khi trừ kho từ code.

---

[⬅️ Ngày 22: Làm việc với JSON và JSONB](22-sql-json-practice.md) | [📚 Mục lục](../README.md) | [Ngày 24: Nhập và xuất dữ liệu với CSV ➡️](24-import-export-data.md)
