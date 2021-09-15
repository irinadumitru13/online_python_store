-- functie pentru inserare utilizator in tabela USERS
CREATE OR REPLACE FUNCTION insertUser(u_email VARCHAR, u_firstName VARCHAR, u_lastName VARCHAR, u_phone_number VARCHAR, u_address VARCHAR, u_password VARCHAR)
RETURNS integer
LANGUAGE PLPGSQL
AS
$$
DECLARE
    user_added integer;
BEGIN
    INSERT INTO USERS(email, firstName, lastName, phone_number, address, password)
    VALUES (u_email, u_firstName, u_lastName, u_phone_number, u_address, u_password);
    user_added := 1;

    RETURN user_added;
EXCEPTION
    WHEN unique_violation THEN
        user_added := 0;

        RETURN user_added;
END;
$$;

-- functie pentru verificare credentiale la logare
CREATE OR REPLACE FUNCTION retrievePassword(u_email VARCHAR)
RETURNS VARCHAR
LANGUAGE PLPGSQL
AS
$$
DECLARE
    user_cursor CURSOR(c_email VARCHAR) FOR
        SELECT email, password
        FROM USERS
        WHERE email = c_email;
    
    user_record RECORD;
    password VARCHAR := '';
BEGIN
    OPEN user_cursor(u_email);

    LOOP
        FETCH user_cursor INTO user_record;
        EXIT WHEN NOT FOUND;

        password := user_record.password;
    END LOOP;

    CLOSE user_cursor;

    RETURN password;
END;
$$;

-- functie pentru extragerea numelui utilizatorului
-- apelata numai daca verificarea credentialelor reuseste
CREATE TYPE user_type AS (user_id integer, u_fullName VARCHAR);

CREATE OR REPLACE FUNCTION retrieveName(u_email VARCHAR)
RETURNS user_type
LANGUAGE PLPGSQL
AS
$$
DECLARE
    user_result user_type;
BEGIN
    SELECT user_id, firstName || ' ' || lastName AS fullname
    INTO user_result.user_id, user_result.u_fullname
    FROM USERS
    WHERE email = u_email;

    RETURN user_result;
END;
$$;

-- functie pentru categoriile de produse
CREATE OR REPLACE FUNCTION getCategories()
RETURNS TABLE(category VARCHAR)
LANGUAGE PLPGSQL
AS
$$
BEGIN
    RETURN QUERY 
		SELECT name
		FROM CATEGORIES;
END;
$$;

-- functie pentru produse dintr-o anumita categorie
CREATE TYPE product_cat_type AS (product_id integer, name VARCHAR, brand VARCHAR, image VARCHAR, price real, stock integer);

CREATE OR REPLACE FUNCTION getProductsCat(cat_id integer)
RETURNS TABLE(product product_cat_type)
LANGUAGE PLPGSQL
AS
$$
BEGIN
    RETURN QUERY
        SELECT p.product_id, p.name, p.brand, p.image, p.price,
            s.XS + s.S + s.M + s.L + s.XL
        FROM PRODUCTS p NATURAL JOIN STOCK s
        WHERE p.category_id = CAST(cat_id AS smallint);
END
$$;

-- functie pentru nr produse dintr-o categorie
CREATE OR REPLACE FUNCTION getNumberOfProducts(cat_id integer)
RETURNS integer
LANGUAGE PLPGSQL
AS
$$
DECLARE
    nr_prod integer;
BEGIN
    SELECT COUNT(*)
    INTO nr_prod
    FROM PRODUCTS
    WHERE category_id = CAST(cat_id AS smallint)
    GROUP BY category_id;

    RETURN nr_prod;
END;
$$;

-- functie pentru un anumit produs
CREATE TYPE product_type AS (product_id integer, name VARCHAR, brand VARCHAR, description text, image VARCHAR, price real, xs integer, s integer, m integer, l integer, xl integer);

CREATE OR REPLACE FUNCTION getProduct(prod_id integer)
RETURNS product_type
LANGUAGE PLPGSQL
AS
$$
DECLARE
    product product_type;
BEGIN
    SELECT p.product_id, p.name, p.brand, p.description, p.image, p.price,
        s.XS, s.S, s.M, s.L, s.XL
    INTO product
    FROM PRODUCTS p NATURAL JOIN STOCK s
    WHERE p.product_id = CAST(prod_id AS smallint);

    RETURN product;
END
$$;

-- functie pentru introducere articol in cos
CREATE OR REPLACE FUNCTION addToCart(u_session_id UUID, u_product_id integer, u_size VARCHAR, u_pieces integer)
RETURNS integer
LANGUAGE PLPGSQL
AS
$$
DECLARE
    result integer := 0;
    counter integer;
BEGIN
    SELECT COUNT(*)
    INTO counter
    FROM CART
    WHERE product_id = u_product_id AND session_id = u_session_id AND size = u_size;

    IF counter = 0 THEN
        INSERT INTO CART (session_id, product_id, size, pieces)
        VALUES (u_session_id, u_product_id, u_size, u_pieces);
    ELSE
        UPDATE CART
        SET pieces = pieces + u_pieces
        WHERE product_id = u_product_id AND session_id = u_session_id AND size = u_size;
    END IF;

    RETURN result;
EXCEPTION
    WHEN unique_violation THEN
        result := 1;

        RETURN result;
END;
$$;

-- functie pentru stergere articol din cos
CREATE OR REPLACE FUNCTION deleteFromCart(u_session_id UUID, u_product_id integer, u_size VARCHAR)
RETURNS integer
LANGUAGE PLPGSQL
AS
$$
DECLARE
    result integer := 0;
BEGIN
    DELETE FROM CART
    WHERE session_id = u_session_id AND product_id = u_product_id AND size = u_size;

    RETURN result;
END;
$$;

-- functie pentru afisare elemente din cos
CREATE TYPE cart_item_type AS (id integer, name VARCHAR, brand VARCHAR, image VARCHAR, price real, size VARCHAR, pieces integer);

CREATE OR REPLACE FUNCTION getItemsInCart(u_session_id UUID)
RETURNS TABLE(cart_item cart_item_type)
LANGUAGE PLPGSQL
AS
$$
BEGIN
    RETURN QUERY
        SELECT p.product_id, p.name, p.brand, p.image, p.price, c.size, c.pieces
        FROM CART c NATURAL JOIN PRODUCTS p
        WHERE c.session_id = u_session_id;
END;
$$;

-- functie pentru calculare subtotal si total (+TVA)
CREATE TYPE subtotal_type AS (subtotal real, total real);

CREATE OR REPLACE FUNCTION getSubtotal(u_session_id UUID)
RETURNS subtotal_type
LANGUAGE PLPGSQL
AS
$$
DECLARE
    result subtotal_type;
    subtotal real;
BEGIN
    SELECT SUM(p.price * c.pieces)
    INTO subtotal
    FROM CART c NATURAL JOIN PRODUCTS p
    WHERE c.session_id = u_session_id
    GROUP BY c.session_id;

    result.subtotal := subtotal;
    result.total := 1.09 * subtotal;

    RETURN result;
END;
$$;

-- functie pentru plasare comanda
CREATE OR REPLACE FUNCTION placeOrder(u_session_id UUID, u_user_id integer, u_total real)
RETURNS integer
LANGUAGE PLPGSQL
AS
$$
DECLARE
    result integer := 0;
    new_order_id integer;
BEGIN
    INSERT INTO ORDERS(session_id, user_id, total)
    VALUES (u_session_id, u_user_id, u_total);
    result := 0;

    SELECT order_id
    INTO new_order_id
    FROM ORDERS
    WHERE session_id = u_session_id;

    UPDATE CART
    SET order_id = new_order_id
    WHERE session_id = u_session_id;

    RETURN result;
END;
$$;
