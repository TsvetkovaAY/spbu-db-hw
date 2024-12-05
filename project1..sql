-- КУРСОВАЯ РАБОТА ЧАСТЬ 1 --
-- Издательство (учет книг, авторов, издательских процессов)--

CREATE TABLE books (
	id serial PRIMARY KEY,
	name VARCHAR(50) NOT NULL,
	author VARCHAR(50) NOT NULL,
	pages INTEGER NOT NULL,
	genre VARCHAR(50) NOT NULL,
	cover VARCHAR(50) NOT NULL,
	paper VARCHAR(50) NOT NULL
	);

INSERT INTO books (name, author, pages, genre, cover, paper) VALUES 
('The night in Lissabon', 'Erich Maria Remarque', '320', 'novel', 'solid', 'premium'),
('1984', 'G.Orwell,', '320', 'Dystopia', 'soft', 'premium'),
('Brave New World', 'Aldous Huxley', '352', 'Dystopia', 'soft', 'premium'),
('We', 'Y. Zamyatin', '224', 'Dystopia', 'solid', 'standart'),
('Fahrenheit 451', 'Ray Bradbury', '382', 'Dystopia', 'solid', 'standart');

ALTER TABLE books
ADD CONSTRAINT unique_name UNIQUE (name);

CREATE TABLE publisher_position (
	id serial PRIMARY KEY,
	process_name VARCHAR(50) NOT NULL,
	short_name VARCHAR(50) NOT NULL,
	price_per_page INTEGER NOT NULL
	);

INSERT INTO publisher_position (process_name, short_name, price_per_page) VALUES 
('Corrector', 'C', '100'),
('Redactor', 'R', '150'),
('Designer', 'D', '120');

CREATE TABLE cover_prices (
	id serial PRIMARY KEY,
	cover_type VARCHAR(50) NOT NULL,
	cover_price INTEGER NOT NULL
	);

INSERT INTO cover_prices (cover_type, cover_price) VALUES 
('solid', '1000'),
('soft', '500');

CREATE TABLE paper_prices (
	id serial PRIMARY KEY,
	paper_type VARCHAR(50) NOT NULL,
	paper_price INTEGER NOT NULL
	);

INSERT INTO paper_prices (paper_type, paper_price) VALUES 
('premium', '1000'),
('standart', '500');

	
CREATE TABLE employees (
	id serial PRIMARY KEY,
	name VARCHAR(50) NOT NULL,
	position INTEGER NOT NULL REFERENCES publisher_position(id),
	books_ids INTEGER[] NOT NULL
	);

INSERT INTO employees (name, position, books_ids) VALUES
  ('Maxim Geller', '1', ARRAY[1, 3]),
  ('Alex Brown', '2', ARRAY[1, 2, 3, 4, 5]),
  ('Liza Bakket', '1', ARRAY[4]),
  ('Bri Cappe', '1', ARRAY[2, 5]),
  ('Paul Peters', '3', ARRAY[1, 2, 3, 4, 5]);

SELECT * FROM employees LIMIT 10;

--Создадим таблицу стоимости выпуска каждой книги (стоимость работы корректора, редактора и дизайнера)

CREATE TABLE price_list (
	book_id INTEGER NOT NULL REFERENCES books(id),
	pages INTEGER NOT NULL,
	corrector_price INTEGER NOT NULL,
	redactor_price INTEGER NOT NULL,
	designer_price INTEGER NOT NULL
	);

INSERT INTO price_list (book_id, pages, corrector_price, redactor_price, designer_price)
SELECT 
	b.id AS book_id, b.pages,
	SUM(CASE WHEN pp.short_name = 'C' THEN b.pages * pp.price_per_page ELSE 0 END) AS corrector_price,
	SUM(CASE WHEN pp.short_name = 'R' THEN b.pages * pp.price_per_page ELSE 0 END) AS redactor_price,
	SUM(CASE WHEN pp.short_name = 'D' THEN b.pages * pp.price_per_page ELSE 0 END) AS designer_price
FROM 
  books b
  JOIN employees e ON b.id = ANY(e.books_ids)
  JOIN publisher_position pp ON e.position = pp.id
GROUP BY 
  b.id, b.pages;
 
ALTER TABLE price_list
ADD COLUMN cover_price INTEGER,
ADD COLUMN paper_price INTEGER; 

UPDATE price_list
SET cover_price = cp.cover_price, paper_price = pp.paper_price
FROM cover_prices cp
JOIN books b ON cp.cover_type = b.cover
JOIN paper_prices pp ON pp.paper_type = b.paper
WHERE b.id = price_list.book_id;

ALTER TABLE price_list
ADD COLUMN total_price INTEGER;

UPDATE price_list
SET total_price = corrector_price + redactor_price + designer_price + cover_price + paper_price;

SELECT * FROM price_list LIMIT 10;

----Высчитаем, какая книга самая дорогая:
SELECT b.name, b.author, pl.total_price
FROM books b
JOIN price_list pl ON b.id = pl.book_id
ORDER BY pl.total_price DESC
LIMIT 1;

----Высчитаем, какая книга самая дешевая:
SELECT b.name, b.author, pl.total_price
FROM books b
JOIN price_list pl ON b.id = pl.book_id
ORDER BY pl.total_price ASC
LIMIT 1;

CREATE TABLE employees_books (
		id serial PRIMARY KEY,
		employee_id INTEGER NOT NULL REFERENCES employees(id),
		book_id INTEGER NOT NULL REFERENCES books(id),
		UNIQUE (employee_id, book_id)
	);

INSERT INTO employees_books (employee_id, book_id)
SELECT e.id, b.id
FROM employees e
JOIN books b ON b.id = ANY(e.books_ids)
ON CONFLICT (employee_id, book_id) DO NOTHING;

SELECT * FROM employees_books LIMIT 50;

---Удалить неактуальные столбцы после модификации структуры

ALTER TABLE employees DROP COLUMN books_ids;

SELECT * FROM employees LIMIT 50;


