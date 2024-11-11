--1. Создать промежуточные таблицы:student_courses — связывает студентов с курсами. 
--Поля: id, student_id, course_id.group_courses — связывает группы с курсами. Поля: id, group_id, course_id.
--Заполнить эти таблицы данными, чтобы облегчить работу с отношениями «многие ко многим».
--Должно гарантироваться уникальное отношение соответствующих полей (ключевое слово UNIQUE).
--Удалить неактуальные, после модификации структуры, поля (пример: courses_ids) SQL запросом, (важно, запрос ALTER TABLE).
--2. Добавить в таблицу courses уникальное ограничение на поле name, чтобы не допустить дублирующих названий курсов.
--Создать индекс на поле group_id в таблице students и объяснить, как индексирование влияет на производительность запросов 
--(Комментариями в коде).
--3. Написать запрос, который покажет список всех студентов с их курсами. 
--Найти студентов, у которых средняя оценка по курсам выше, чем у любого другого студента в их группе. 
--(Ключевые слова JOIN, GROUP BY, HAVING)
--4. Подсчитать количество студентов на каждом курсе. Найти среднюю оценку на каждом курсе.


--1. Создать промежуточные таблицы:student_courses — связывает студентов с курсами. 
--Поля: id, student_id, course_id


CREATE TABLE student_courses(
		id serial PRIMARY KEY,
		student_id INT NOT NULL REFERENCES students(id),
		course_id INT NOT NULL REFERENCES courses(id),
		UNIQUE (student_id, course_id)
	);

INSERT  INTO student_courses (student_id, course_id)
SELECT s.id, c.id
FROM students s
JOIN courses c ON c.id = ANY(s.courses_ids)
ON CONFLICT (student_id, course_id) DO NOTHING;


SELECT * FROM student_courses LIMIT 50;

--group_courses — связывает группы с курсами. Поля: id, group_id, course_id.
		
CREATE TABLE group_courses(
  id serial PRIMARY KEY,
  group_id INT NOT NULL REFERENCES groups(id),
  course_id INT NOT NULL REFERENCES courses(id),
  UNIQUE (group_id, course_id)
);

INSERT INTO group_courses (group_id, course_id)
SELECT g.id, c.id
FROM GROUPS g
JOIN students s ON g.id = s.group_id
JOIN courses c ON c.id = ANY(s.courses_ids)
ON CONFLICT (group_id, course_id) DO NOTHING;

SELECT * FROM student_courses LIMIT 50;

--Удалить неактуальные, после модификации структуры, поля (пример: courses_ids) SQL запросом, (важно, запрос ALTER TABLE).
ALTER TABLE students DROP COLUMN courses_ids;

SELECT * FROM students LIMIT 50;

--2. Добавить в таблицу courses уникальное ограничение на поле name, чтобы не допустить дублирующих названий курсов.

ALTER TABLE courses
ADD CONSTRAINT unique_name UNIQUE (name);

SELECT * FROM courses LIMIT 50;

--Создать индекс на поле group_id в таблице students и объяснить, как индексирование влияет на производительность запросов 

CREATE INDEX idx_st_group_id
ON students (group_id);

SELECT * FROM students LIMIT 50;

-- индексирование ускоряет доступ к записям, ускоряет операции соединения таблиц и автоматически упорядочивает записи при выборке

--3. Написать запрос, который покажет список всех студентов с их курсами. 

SELECT s.first_name, s.last_name, c.name
FROM students s
JOIN student_courses sc ON sc.student_id = s.id
JOIN courses c ON c.id = sc.course_id;

--Найти студентов, у которых средняя оценка по курсам выше, чем у любого другого студента в их группе. 
--(Ключевые слова JOIN, GROUP BY, HAVING)

ALTER TABLE student_courses ADD COLUMN grade INT;

UPDATE student_courses sc
SET grade = mc.grade
FROM math_course mc
JOIN students s ON s.id = mc.student_id
WHERE sc.student_id = s.id AND sc.course_id = 1;

SELECT * FROM student_courses LIMIT 50;

UPDATE student_courses
SET grade = 
    CASE 
        WHEN grade IS NULL THEN 
            CASE 
	            WHEN student_id = 1 THEN 
                    CASE 
	                    WHEN course_id = 1 THEN 89
                        WHEN course_id = 5 THEN 56
                        WHEN course_id = 6 THEN 90
                        ELSE 67
                    END           
                WHEN student_id = 2 THEN
                    CASE
                        WHEN course_id = 3 THEN 48
                        WHEN course_id = 5 THEN 36
                        ELSE 80
                    END
                WHEN student_id = 3 THEN 
                    CASE 
                        WHEN course_id = 2 THEN 78
                        WHEN course_id = 3 THEN 87
                        WHEN course_id = 1 THEN 91
                        ELSE 59
                    END
                WHEN student_id = 4 THEN 
                    CASE 
                        WHEN course_id = 1 THEN 72
                        WHEN course_id = 2 THEN 96
                        ELSE 62
                    END 
                WHEN student_id = 5 THEN 
                    CASE 
                        WHEN course_id = 1 THEN 66
                        WHEN course_id = 4 THEN 68
                        ELSE 61
                    END
                WHEN student_id = 6 THEN 
                    CASE 
                        WHEN course_id = 1 THEN 91
                        WHEN course_id = 2 THEN 91
                        WHEN course_id = 3 THEN 89
                        WHEN course_id = 5 THEN 85
                        WHEN course_id = 6 THEN 97
                        ELSE 83
                    END
                ELSE grade
            END
        ELSE grade	
    END;
   
SELECT * FROM student_courses LIMIT 50;

SELECT sc.student_id, AVG(sc.grade), s.group_id
FROM student_courses sc
JOIN students s ON sc.student_id = s.id 
JOIN group_courses gc ON gc.group_id = s.group_id
GROUP BY sc.student_id, s.group_id, s.id
HAVING AVG(sc.grade) > (
SELECT MAX(avg_grade) 
  FROM (
    SELECT AVG(sc2.grade) AS avg_grade 
    FROM student_courses sc2
    JOIN students s2 ON sc2.student_id = s2.id 
    WHERE s2.group_id = s.group_id AND s2.id!= s.id
    GROUP BY s2.group_id, s2.id
   ) AS subquery
	);

--4. Подсчитать количество студентов на каждом курсе. Найти среднюю оценку на каждом курсе.

SELECT sc.course_id, COUNT(sc.student_id), AVG(sc.grade)
FROM student_courses sc
GROUP BY sc.course_id;


