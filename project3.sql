-- КУРСОВАЯ РАБОТА ЧАСТЬ 3 --
--Триггеры и транзакции

--before

CREATE OR REPLACE FUNCTION check_number_of_pages()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pages < 1 THEN
        RAISE EXCEPTION 'Произошла ошибка: в запись о книгах вносится книга с недопустимым количеством страниц (< 1)!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_number_of_pages
BEFORE INSERT OR UPDATE ON books
FOR EACH ROW
WHEN (NEW.pages IS NOT NULL)
EXECUTE FUNCTION check_number_of_pages();

-- after

CREATE OR REPLACE FUNCTION check_correct_year()
RETURNS TRIGGER AS $$
BEGIN
	IF EXISTS (SELECT 1 FROM publish_progress pp WHERE (EXTRACT(YEAR FROM pp.start_date) != 2024 OR EXTRACT(YEAR FROM pp.finish_date) != 2024)) THEN
        RAISE EXCEPTION 'Даты start_date и finish_date в publish_progress должны быть за 2024 год';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_correct_year
AFTER INSERT OR UPDATE ON publish_progress
FOR EACH ROW
EXECUTE FUNCTION check_correct_year();

-- instead of
--Проверяем, существует ли книга 

CREATE VIEW publish_progress_view AS
SELECT * FROM publish_progress;

CREATE OR REPLACE FUNCTION check_is_book_exist()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM books WHERE id = NEW.book_id) THEN
        RAISE EXCEPTION 'Книга с id % не существует', NEW.book_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_is_book_exist
INSTEAD OF INSERT ON publish_progress_view
FOR EACH ROW
EXECUTE PROCEDURE check_is_book_exist();

--Проверяем, существует ли этап работы

CREATE OR REPLACE FUNCTION check_is_step_exist()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM publisher_position WHERE id = NEW.step) THEN
        RAISE EXCEPTION 'Этап % не существует', NEW.step;
    END IF;
    RETURN NEW;    
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_is_step_exist
INSTEAD OF INSERT ON publish_progress_view
FOR EACH ROW
EXECUTE PROCEDURE check_is_step_exist();

--for each statement

CREATE OR REPLACE FUNCTION check_employees_number()
RETURNS TRIGGER AS $$
BEGIN
	IF (SELECT COUNT(*)
        FROM employees e 
        JOIN publisher_position pp ON pp.id = e."position" 
        WHERE pp.process_name LIKE '%Corrector%') > 4 THEN 
        RAISE EXCEPTION 'Общее количество корректоров превысило допустимый максимум (4 человека)';
    END IF;

    -- Проверка на количество редакторов
    IF (SELECT COUNT(*)
        FROM employees e 
        JOIN publisher_position pp ON pp.id = e."position" 
        WHERE pp.process_name LIKE '%Redactor%') > 3 THEN 
        RAISE EXCEPTION 'Общее количество редакторов превысило допустимый максимум (3 человека)';
    END IF;

    -- Проверка на количество дизайнеров
    IF (SELECT COUNT(*)
        FROM employees e 
        JOIN publisher_position pp ON pp.id = e."position" 
        WHERE pp.process_name LIKE '%Designer%') > 3 THEN 
        RAISE EXCEPTION 'Общее количество дизайнеров превысило допустимый максимум (3 человека)';
    END IF;
   
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_employees_number
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH STATEMENT
EXECUTE FUNCTION check_employees_number();

-- Приведем примеры успешной транзакции:

BEGIN;

INSERT INTO books (name, author, pages, genre, cover, paper) VALUES
('Dunno on the Moon', 'Nikolay Nosov', '256', 'Dystopia', 'solid', 'standart');

INSERT INTO employees (name, position)
VALUES
('Anthony Reel', '3'); 

-- Подтверждаем транзакцию
COMMIT;

-- Откат транзакции
ROLLBACK;

DELETE FROM employees
WHERE id > 6;

SELECT * FROM employees LIMIT 50;

-- Приведем примеры неуспешной транзакции:

BEGIN;
INSERT INTO books (name, author, pages, genre, cover, paper)
VALUES
    ('Dunno on the Moon', 'Nikolay Nosov', '-1', 'Dystopia', 'solid', 'standart');
COMMIT;
ROLLBACK;
-- Неуспешна, так как сработает триггер trigger_number_of_pages на корректное количество страниц

BEGIN;
INSERT INTO publish_progress (book_id, step, start_date, finish_date, employee_id)
VALUES
    (4, 2, '2023-12-01', '2023-12-10', '3');   
COMMIT;
ROLLBACK;
-- Неуспешна, так как сработает триггер trigger_check_correct_year на год (в таблице должны храниться записи только для 2024 года)

BEGIN;
INSERT INTO publish_progress_view (book_id, step, start_date, finish_date, employee_id)
VALUES
    (10, 2, '2024-12-01', '2024-12-10', '2');   
COMMIT;
ROLLBACK;

-- Неуспешна, так как сработает триггер trigger_is_book_exist, который проверяет, что книга существует в каталоге

BEGIN;
INSERT INTO publish_progress_view (book_id, step, start_date, finish_date, employee_id)
VALUES
    (4, 10, '2024-12-01', '2024-12-10', '5');   
COMMIT;
ROLLBACK;

-- Неуспешна, так как сработает триггер trigger_is_step_exist, который проверяет, что этап работы над книгой существует

BEGIN;
INSERT INTO employees (name, position)
VALUES
('Harry Gray', '2'),
('Anna May', '3'),
('Ben Red',  '3'),
('Greg Bills',  '3'),
('Gretta Black',  '2');
COMMIT;
ROLLBACK;


-- Неуспешна, так как сработает триггер trigger_employees_number на проверку количества корректоров (4), редакторов (3), дизайнеров (3) в компании.
