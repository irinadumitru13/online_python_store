DROP TABLE IF EXISTS CATEGORIES;
DROP TABLE IF EXISTS PRODUCTS;
DROP TABLE IF EXISTS STOCK;
DROP TABLE IF EXISTS USERS;
DROP TABLE IF EXISTS ORDERS;
DROP TABLE IF EXISTS CART;

-- tabele specifice magazinului online

CREATE TABLE CATEGORIES (
    category_id SMALLSERIAL PRIMARY KEY,
    name VARCHAR NOT NULL
);

CREATE TABLE PRODUCTS (
    product_id SERIAL PRIMARY KEY,
    category_id integer,
    name VARCHAR NOT NULL,
    brand VARCHAR NOT NULL,
    description text NOT NULL,
    image VARCHAR NOT NULL,
    price real,

    CONSTRAINT fk_category
        FOREIGN KEY (category_id)
            REFERENCES CATEGORIES(category_id)
            ON DELETE CASCADE
);

CREATE TABLE STOCK (
    product_id integer,
    XS integer NOT NULL DEFAULT 5,
    S integer NOT NULL  DEFAULT 5,
    M integer NOT NULL  DEFAULT 5,
    L integer NOT NULL DEFAULT 5,
    XL integer NOT NULL DEFAULT 5,

    CONSTRAINT fk_product
        FOREIGN KEY (product_id)
            REFERENCES PRODUCTS(product_id)
            ON DELETE CASCADE
);

-- tabele specifice userilor si cosului de cumparaturi, respectiv comenzilor

CREATE TABLE USERS (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR NOT NULL UNIQUE,
    firstName VARCHAR NOT NULL,
    lastName VARCHAR NOT NULL,
    phone_number VARCHAR NOT NULL,
    address VARCHAR NOT NULL,
    password VARCHAR NOT NULL
);

CREATE TABLE ORDERS (
    order_id SERIAL PRIMARY KEY,
    session_id UUID NOT NULL,
    user_id integer,
    order_date timestamp DEFAULT NOW(),
    total real,

    CONSTRAINT fk_user
        FOREIGN KEY (user_id)
            REFERENCES USERS(user_id)
            ON DELETE CASCADE
);

CREATE TABLE CART (
    cart_id SERIAL PRIMARY KEY,
    order_id integer,
    session_id UUID NOT NULL,
    product_id integer NOT NULL,
    size VARCHAR NOT NULL,
    pieces integer NOT NULL,

    CONSTRAINT fk_order
        FOREIGN KEY (order_id)
            REFERENCES ORDERS(order_id)
            ON DELETE CASCADE,

    CONSTRAINT fk_products
        FOREIGN KEY (product_id)
            REFERENCES PRODUCTS(product_id)
            ON DELETE CASCADE
);