/*
2 триггер
2 процедуры
5 запросов - сделать на один план
*/

DROP SCHEMA PUBLIC CASCADE;
CREATE SCHEMA PUBLIC;

CREATE TABLE product_group 
(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL UNIQUE,
  description varchar(255),
  parent_group_id integer,
  FOREIGN KEY (parent_group_id) REFERENCES product_group(id)
);

CREATE TABLE firm_category
(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL UNIQUE
);

CREATE TABLE bank
(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL UNIQUE,
  site varchar(255),
  bic varchar(255)
);

CREATE TABLE role
(
  code integer PRIMARY KEY,
  name varchar(255) NOT NULL
);

CREATE TABLE product
(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL UNIQUE,
  articul varchar(255),
  cert integer,
  packaging date,
  creator varchar(255),
  charachteristic varchar(255),
  count integer NOT NULL,
  price numeric(10, 2) NOT NULL CHECK (price > 0)
);

CREATE TABLE product_product_group
(
  product_id integer NOT NULL,
  group_id integer NOT NULL,
  FOREIGN KEY (product_id) REFERENCES product(id),
  FOREIGN KEY (group_id) REFERENCES product_group(id)
);

CREATE TABLE firm
(
  id serial PRIMARY KEY,
  name varchar(255) NOT NULL UNIQUE,
  address varchar(255),
  phone varchar(255),
  license varchar(255),
  requisites varchar(255),
  category_id integer NOT NULL,
  FOREIGN KEY (category_id) REFERENCES firm_category(id)
);

CREATE TABLE worker
(
  id serial PRIMARY KEY,
  initials varchar(255) NOT NULL,
  tin varchar(255),
  passport varchar(255),
  birthday date ,
  gender integer,
  phone varchar(255),
  login varchar(255) NOT NULL,
  password varchar(255) NOT NULL,
  boss_id integer,
  role_id integer NOT NULL,
  FOREIGN KEY (boss_id) REFERENCES worker(id),
  FOREIGN KEY (role_id) REFERENCES role(code)
);

CREATE TABLE product_order
(
  id serial PRIMARY KEY,
  IPO_SD varchar(255) NOT NULL,
  IPO_bank varchar(255) NOT NULL,
  order_date date NOT NULL,
  payment_amount numeric(10, 2) NOT NULL,
  bank_id integer NOT NULL,
  accounter_id integer NOT NULL,
  firm_id integer NOT NULL,
  FOREIGN KEY (bank_id) REFERENCES bank(id),
  FOREIGN KEY (accounter_id) REFERENCES worker(id),
  FOREIGN KEY (firm_id) REFERENCES firm(id)
);

CREATE TABLE delivery_note
(
  id serial PRIMARY KEY,
  order_date date DEFAULT now(),
  payment_date date,
  delivery_date date,
  discount float,
  manager_id integer NOT NULL,
  firm_id integer NOT NULL,
  FOREIGN KEY (manager_id) REFERENCES worker(id),
  FOREIGN KEY (firm_id) REFERENCES firm(id)
);

CREATE TABLE product_in_note
(
  count integer NOT NULL,
  price numeric(10, 2) NOT NULL,
  product_id integer NOT NULL,
  note_id integer NOT NULL,
  FOREIGN KEY (product_id) REFERENCES product(id),
  FOREIGN KEY (note_id) REFERENCES delivery_note(id)
);

CREATE FUNCTION count_price_for_firm (product_id integer, customer_firm_id integer)
RETURNS numeric(10, 2) AS
$$
  DECLARE
    origin_price numeric(10, 2);
    sale origin_price%TYPE;
  BEGIN
    origin_price  := (SELECT price FROM product WHERE product.id = product_id);
    sale := (SELECT (SELECT sum(p_in_n.count * p_in_n.price) 
                    FROM product_in_note AS p_in_n
                    JOIN delivery_note AS n ON n.id = p_in_n.note_id
                    WHERE n.firm_id = customer_firm_id) / 1000);
    IF sale > 0.08 * origin_price THEN
      sale := 0.08 * origin_price;
    END IF;
    RETURN (SELECT origin_price - COALESCE(sale, 0));
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION add_product_into_note ()
RETURNS trigger AS
$$
     DECLARE
          customer_firm_id integer;
     BEGIN
          RAISE NOTICE 'trigger 1';
          IF NEW.price is NULL THEN
            customer_firm_id := (SELECT n.firm_id 
                                FROM delivery_note AS n
                                WHERE n.id = NEW.note_id);
            NEW.price := count_price_for_firm(NEW.product_id, customer_firm_id);
          ELSIF NEW.price < 0 THEN
            RAISE EXCEPTION 'cannot have a negative price';
          END IF;
          RETURN NEW;
     END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger1
     BEFORE INSERT ON product_in_note
     FOR EACH ROW EXECUTE PROCEDURE add_product_into_note();

CREATE FUNCTION add_product ()
RETURNS trigger AS
$$
     DECLARE
     BEGIN
          RAISE NOTICE 'trigger 2';
          INSERT INTO product_product_group (product_id, group_id) 
          SELECT p.id, g.id
          FROM product AS p
          JOIN product_group AS g ON p.name LIKE CONCAT('%', g.name, '%')
          WHERE p.name = NEW.name;
          RETURN NEW;
     END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger2
     AFTER INSERT ON product
     FOR EACH ROW EXECUTE PROCEDURE add_product();

CREATE FUNCTION is_parent(child_id integer, parent_id integer)
RETURNS boolean AS
$$
  DECLARE
    current_parent_id integer;
  BEGIN
    current_parent_id := (SELECT parent_group_id FROM product_group WHERE id = child_id);
    IF current_parent_id IS NULL THEN
      RETURN FALSE;
    ELSIF current_parent_id = parent_id THEN
      RETURN TRUE;
    ELSE
      RETURN is_parent(current_parent_id, parent_id);
    END IF;
  END;
$$ LANGUAGE plpgsql;

CREATE PROCEDURE update_parent_group_id(new_parent_id integer, child_ids integer[])
LANGUAGE plpgsql AS
$$
  DECLARE
    child_id integer;
  BEGIN
    FOREACH child_id IN ARRAY child_ids
    LOOP 
      IF (SELECT is_parent(new_parent_id, child_id)) = TRUE THEN
        RAISE NOTICE '%', child_id;
      ELSE
        UPDATE product_group SET parent_group_id = new_parent_id WHERE id = child_id;
      END IF;
    END LOOP;
  END;
$$;

CREATE TYPE counted_product AS (
  id integer,
  count integer
);

CREATE TYPE counted_priced_product AS (
  id integer,
  count integer,
  price numeric(10, 2)
);

CREATE PROCEDURE create_note(products counted_product[], manager_id integer, firm_id integer) 
LANGUAGE plpgsql AS 
$$
  DECLARE
    c_product counted_product;
    current_count integer;
    current_price numeric(10, 2);
    new_note_id integer;
    priced_products counted_priced_product[];
  BEGIN
    INSERT INTO delivery_note (manager_id, firm_id) VALUES (manager_id, firm_id) RETURNING id INTO new_note_id;
    FOREACH c_product IN ARRAY products
    LOOP 
      current_count := (SELECT count FROM product WHERE id = c_product.id);
      IF current_count < c_product.count THEN
        ROLLBACK;
        RETURN;
      ELSE
        UPDATE product SET count = current_count - c_product.count WHERE id = c_product.id;
        current_price := count_price_for_firm(c_product.id, firm_id); -- нужно потому что триггер в той же транзакции
        priced_products := array_append(priced_products, (c_product.id, c_product.count, current_price)::counted_priced_product);
      END IF;
    END LOOP;
    INSERT INTO product_in_note(count, price, product_id, note_id)
    SELECT count, price, id, new_note_id
    FROM unnest(priced_products);
  END;
$$;

CREATE FUNCTION select1()
RETURNS void AS 
$$
  BEGIN
    SELECT p.name, p.articul, p.creator,
    (
      SELECT string_agg(DISTINCT pg.name, ', ') AS groups
      FROM product_product_group AS ppg
      LEFT JOIN product_group AS pg ON pg.id = ppg.group_id
      WHERE ppg.product_id = p.id
      GROUP BY p.id 
    ),
    p.count, COALESCE(sum(p_in_n.count), 0) AS sold, COALESCE(sum(p_in_n.count * p_in_n.price), 0) AS benefit 
    FROM product AS p
    LEFT JOIN product_in_note AS p_in_n ON p_in_n.product_id = p.id
    GROUP BY p.id;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION select2()
RETURNS void AS 
$$
  BEGIN
    SELECT f.name, f.address, f.phone, 
    total.notes AS total_notes, total.bought AS total_bought, total.products AS total_products, DATE_PART('year', n.order_date) AS year, 
    month, 
    COALESCE((
      SELECT count(DISTINCT n1.id)
      FROM delivery_note AS n1
      WHERE n1.firm_id = f.id AND DATE_PART('month', n1.order_date) = month AND DATE_PART('year', n1.order_date) = 2022
      GROUP BY n1.firm_id, DATE_PART('month', n1.order_date)
    ), 0) AS notes_in_month,
    COALESCE((
      SELECT sum(p_in_n1.count * p_in_n1.price)
      FROM delivery_note AS n1
      LEFT JOIN product_in_note AS p_in_n1 ON p_in_n1.note_id = n1.id
      WHERE n1.firm_id = f.id AND DATE_PART('month', n1.order_date) = month AND DATE_PART('year', n1.order_date) = 2022
      GROUP BY n1.firm_id, DATE_PART('month', n1.order_date)
    ), 0) AS bought_in_month
    FROM firm AS f
    LEFT JOIN delivery_note AS n ON n.firm_id = f.id
    LEFT JOIN product_in_note AS p_in_n ON p_in_n.note_id = n.id
    LEFT JOIN 
      (
        SELECT n.firm_id AS firm_id, COALESCE(count(DISTINCT n.id), 0) AS notes, COALESCE(sum(p_in_n.count * p_in_n.price), 0) AS bought, COALESCE(sum(p_in_n.count), 0) AS products
        FROM delivery_note AS n
        LEFT JOIN product_in_note AS p_in_n ON p_in_n.note_id = n.id 
        WHERE DATE_PART('year', n.order_date) = 2022
        GROUP BY n.firm_id, DATE_PART('year', n.order_date)
      ) total ON total.firm_id = f.id
    CROSS JOIN generate_series(
      1, 
      (
        SELECT CASE 
          WHEN 2022 = DATE_PART('year', now()) THEN DATE_PART('month', now())::integer
          WHEN 2022 != DATE_PART('year', now()) THEN 12
          END
      )) AS month
    WHERE DATE_PART('year', n.order_date) = 2022
    GROUP BY f.id, total.notes, total.bought, total.products, DATE_PART('year', n.order_date), month
    ORDER BY month;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION find_parent(child_id integer)
RETURNS integer AS
$$
  DECLARE
    current_parent_id integer;
  BEGIN
    current_parent_id := (SELECT parent_group_id FROM product_group WHERE id = child_id);
    IF current_parent_id IS NULL THEN
      RETURN current_parent_id;
    ELSE
      RETURN find_parent(current_parent_id);
    END IF;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION distance_to_parent(child_id integer, current_distance integer)
RETURNS integer AS
$$
  DECLARE
    current_parent_id integer;
  BEGIN
    current_parent_id := (SELECT parent_group_id FROM product_group WHERE id = child_id);
    IF current_parent_id IS NULL THEN
      RETURN current_distance;
    ELSE
      current_distance := (SELECT current_distance + 1);
      RETURN distance_to_parent(current_parent_id, current_distance);
    END IF;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION add_group_products(current_group_id integer)
RETURNS void AS
$$
  DECLARE
    products_in_current_group integer;
    products_in_child_groups integer;
  BEGIN
    INSERT INTO product_ids_tmp
    SELECT ppg.product_id 
    FROM product_product_group AS ppg 
    WHERE ppg.group_id = current_group_id
    ON CONFLICT DO NOTHING;
    IF (SELECT count(*) FROM product_group AS g WHERE g.parent_group_id = current_group_id GROUP BY g.parent_group_id) IS NULL THEN
      RETURN;
    END IF;
    PERFORM add_group_products(g.id)
    FROM product_group AS g 
    WHERE g.parent_group_id = current_group_id;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION count_total_products_in_group(group_id integer)
RETURNS integer AS
$$
  DECLARE
    product_count integer;
  BEGIN
    CREATE TEMP TABLE product_ids_tmp(product_id int UNIQUE);
    PERFORM add_group_products(group_id);
    product_count := (SELECT COALESCE(count(*), 0) FROM product_ids_tmp);
    DROP TABLE product_ids_tmp;
    RETURN product_count;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION select3()
RETURNS void AS 
$$
  BEGIN
    SELECT g.name AS group_name, 
    (SELECT parent_g.name FROM product_group AS parent_g WHERE parent_g.id = g.parent_group_id) AS parent_group_name, 
    find_parent(g.id), count_total_products_in_group(g.id), distance_to_parent(g.id, 0)
    FROM product_group AS g;
  END;
$$ LANGUAGE plpgsql;

CREATE TYPE debt AS (
  age interval,
  note_id integer,
  payment numeric(10, 2)
);

CREATE FUNCTION select4()
RETURNS void AS 
$$
  BEGIN
    SELECT f.name, sum(p_in_n.count * p_in_n.price), string_agg(DISTINCT n.id::varchar(255), ', ') AS notes, 
    (
      SELECT (AGE(now(), n1.order_date), n1.id, sum(p_in_n1.count * p_in_n1.price))::debt AS max_period_debt
      FROM delivery_note AS n1
      LEFT JOIN product_in_note AS p_in_n1 ON p_in_n1.note_id = n1.id
      WHERE n1.firm_id = f.id
      GROUP BY n1.id
      ORDER BY AGE(now(), n1.order_date) DESC
      LIMIT 1
    ),
    (
      SELECT (AGE(now(), n1.order_date), n1.id, sum(p_in_n1.count * p_in_n1.price))::debt AS max_payment_debt
      FROM delivery_note AS n1
      LEFT JOIN product_in_note AS p_in_n1 ON p_in_n1.note_id = n1.id
      WHERE n1.firm_id = f.id
      GROUP BY n1.id
      ORDER BY sum(p_in_n1.count * p_in_n1.price) DESC
      LIMIT 1
    )
    FROM firm AS f
    LEFT JOIN delivery_note AS n ON n.firm_id = f.id
    LEFT JOIN product_in_note AS p_in_n ON p_in_n.note_id = n.id
    WHERE n.payment_date IS NULL
    GROUP BY f.id;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION select5()
RETURNS void AS 
$$
  BEGIN
    SELECT f.name, COALESCE(count(DISTINCT n.id), 0) AS total_notes, COALESCE(sum(p_in_n.count * p_in_n.price), 0) AS total_bought,
    (
      SELECT p.name AS most_popular_product
      FROM product AS p
      LEFT JOIN product_in_note AS p_in_n1 ON p_in_n1.product_id = p.id
      LEFT JOIN delivery_note AS n1 ON n1.id = p_in_n1.note_id
      WHERE n1.firm_id = f.id
      GROUP BY p.id
      ORDER BY COALESCE(count(*), 0) DESC
      LIMIT 1
    ),
    (
      SELECT p.name AS most_saled_product
      FROM product AS p
      LEFT JOIN product_in_note AS p_in_n1 ON p_in_n1.product_id = p.id
      LEFT JOIN delivery_note AS n1 ON n1.id = p_in_n1.note_id
      WHERE n1.firm_id = f.id
      GROUP BY p.id
      ORDER BY COALESCE(sum(p_in_n1.count * p_in_n1.price), 0) DESC
      LIMIT 1
    )
    FROM firm AS f
    LEFT JOIN delivery_note AS n ON n.firm_id = f.id
    LEFT JOIN product_in_note AS p_in_n ON p_in_n.note_id = n.id
    GROUP BY f.id
    HAVING COALESCE(sum(p_in_n.count * p_in_n.price), 0) >= 0
    ORDER BY total_bought DESC;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION select5_1()
RETURNS void AS 
$$
  BEGIN
    WITH t1 AS (
      SELECT DISTINCT ON (f.id) f.id AS firm_id, p.name AS product_name, COALESCE(sum(p_in_n.count), 0) AS product_count
      FROM firm AS f
      LEFT JOIN delivery_note AS n ON n.firm_id = f.id
      LEFT JOIN product_in_note AS p_in_n ON p_in_n.note_id = n.id
      LEFT JOIN product AS p ON p.id = p_in_n.product_id
      GROUP BY f.id, p.id 
      ORDER BY f.id, product_count DESC
    ),
    t2 AS (
      SELECT DISTINCT ON (f.id) f.id AS firm_id, p.name AS product_name, COALESCE(sum(p_in_n.count * p_in_n.price), 0) AS product_sum
      FROM firm AS f
      LEFT JOIN delivery_note AS n ON n.firm_id = f.id
      LEFT JOIN product_in_note AS p_in_n ON p_in_n.note_id = n.id
      LEFT JOIN product AS p ON p.id = p_in_n.product_id
      GROUP BY f.id, p.id 
      ORDER BY f.id, product_sum DESC
    ) 
    SELECT f.name, COALESCE(count(DISTINCT n.id), 0) AS total_notes, COALESCE(sum(p_in_n.count * p_in_n.price), 0) AS total_bought,
    t1.product_name, t2.product_name
    FROM firm AS f
    LEFT JOIN delivery_note AS n ON n.firm_id = f.id
    LEFT JOIN product_in_note AS p_in_n ON p_in_n.note_id = n.id
    LEFT JOIN t1 ON t1.firm_id = f.id
    LEFT JOIN t2 ON t2.firm_id = f.id
    GROUP BY f.id, t1.product_name, t2.product_name
    HAVING COALESCE(sum(p_in_n.count * p_in_n.price), 0) >= 0
    ORDER BY total_bought DESC;
  END;
$$ LANGUAGE plpgsql;