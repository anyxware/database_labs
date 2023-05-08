\i init.sql

insert into firm_category (name) values ('firm_category1');

insert into role (code, name) values (1, 'boss');
insert into worker (initials, login, password, role_id) values ('hiy', 'super_cool', 'super_duper', 1);

CREATE FUNCTION create_note_for_firm()
RETURNS trigger AS
$$
     BEGIN
          call create_note(array['(1,3)', '(2, 2)', '(3,1)']::counted_product[], 1, NEW.id);
          RETURN NEW;
     END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger3
     AFTER INSERT ON firm
     FOR EACH ROW EXECUTE PROCEDURE create_note_for_firm();

insert into product(name, count, price) values ('p1', 1000000000, 100), ('p2', 1000000000, 100), ('p3', 1000000000, 500), ('p6', 1000000000, 100), ('p4', 1000000000, 100), ('p5', 1000000000, 100);

insert into firm (name, category_id)
select concat('firm', num::text), 1
from generate_series(1,2000) num;
