from argon2.exceptions import VerifyMismatchError
from flask import Flask
from flask import render_template, request, make_response
import psycopg2
from argon2 import PasswordHasher
import uuid

app = Flask(__name__)

conn = psycopg2.connect(
    dbname='FASHIONSTORE',
    user='proiectBD',
    host='postgres',
    password='pass',
    port='5432')
cursor = conn.cursor()

ph = PasswordHasher()

categories = []

userName = None


@app.route('/')
def home():
    global categories

    if categories == []:
        cursor.execute('SELECT getCategories()')
        conn.commit()

        result = cursor.fetchall()

        i = 1
        for category in result:
            categories.append((i, category[0]))
            i += 1

    response = make_response(render_template('home.html', categories=categories))
    response.set_cookie('userid', expires=0)
    response.set_cookie('sessionid', expires=0)

    return response


@app.route('/register', methods=['GET'])
def get_register():
    return render_template('register.html', categories=categories)


@app.route('/register', methods=['POST'])
def post_register():
    first_name = request.form['firstName']
    last_name = request.form['lastName']
    email = request.form['email']
    address = request.form['address']
    phone = request.form['phone']
    password = request.form['password']
    password_repeated = request.form['pass_repeat']

    message = ""

    if password != password_repeated:
        message = "Passwords don't match, please re-enter the passwords!"
    else:
        # Parola va fi stocata hashed prin intermediul algoritmului Argon2
        # (cel mai bun la ora actuala pentru stocare de parole)
        cursor.execute('SELECT insertUser(%s, %s, %s, %s, %s, %s)',
                       (email, first_name, last_name, phone, address, ph.hash(password)))
        conn.commit()

        result = cursor.fetchone()

        if result[0] == 0:
            message = 'Email already registered!'
        else:
            return render_template('registerOK.html')

    return render_template("register.html", message=message, firstName=first_name, lastName=last_name, email=email,
                           address=address, phone=phone, categories=categories)


@app.route("/login", methods=["GET"])
def login_page_get():
    return render_template("login.html", categories=categories)


@app.route("/login", methods=["POST"])
def login_page_post():
    global userName
    email = request.form['email']
    password = request.form['password']

    cursor.execute('SELECT retrievePassword(%s)', (email,))
    conn.commit()

    hashed = cursor.fetchone()[0]

    try:
        ph.verify(hashed, password)

        cursor.execute('SELECT * FROM retrieveName(%s)', (email,))
        conn.commit()

        user = cursor.fetchone()
        userName = user[1]

        response = make_response(render_template('loginOK.html', user_name=user[1], categories=categories))
        response.set_cookie('userid', str(user[0]))

        return response
    except VerifyMismatchError:
        if hashed == '':
            message = 'Email not registered. Please register first...'
        else:
            message = 'Password incorrect!'

        return render_template("login.html", message=message, categories=categories)


@app.route("/logout", methods=["GET"])
def logout_page():
    global userName
    userName = None

    res = make_response(render_template("home.html", categories=categories))
    res.set_cookie('sessionid', expires=0)
    res.set_cookie('userid', expires=0)

    return res


@app.route('/products/<int:cat_id>', methods=['GET'])
def get_products(cat_id):
    cursor.execute('SELECT * FROM getProductsCat(%s)', (cat_id,))
    conn.commit()

    products = cursor.fetchall()

    cursor.execute('SELECT * FROM getNumberOfProducts(%s)', (cat_id,))
    conn.commit()

    nr_prod = cursor.fetchone()

    res = make_response(
        render_template("products.html", categories=categories, products=products, nr_prod=nr_prod[0], user_name=userName))
    cookie_string = str(uuid.uuid4())
    if 'sessionid' not in request.cookies:
        res.set_cookie('sessionid', cookie_string)
    return res


@app.route('/product/<int:prod_id>', methods=['GET'])
def get_product(prod_id):
    cursor.execute('SELECT * FROM getProduct(%s)', (prod_id,))
    conn.commit()

    (id, name, brand, description, image, price, xs, s, m, l, xl) = cursor.fetchone()

    return make_response(render_template("product.html", categories=categories, id=id, name=name, brand=brand,
                                         description=description, image=image, price=price,
                                         xs=xs, s=s, m=m, l=l, xl=xl, user_name=userName))


@app.route('/cart', methods=['GET'])
def get_cart():
    session_id = request.cookies.get('sessionid')

    cursor.execute('SELECT * FROM getItemsInCart(%s)', (session_id,))
    conn.commit()

    products = cursor.fetchall()

    cursor.execute('SELECT * FROM getSubtotal(%s)', (session_id,))
    conn.commit()

    result = cursor.fetchone()

    if result == (None, None):
        (subtotal, total) = (0.00, 0.00)
    else:
        (subtotal, total) = result

    return make_response(
        render_template("cart.html", categories=categories, nr_elements=len(products), products=products,
                        subtotal=subtotal, total=round(total, 2), userid=request.cookies.get('userid'),
                        user_name=userName))


@app.route('/cart', methods=['POST'])
def post_to_cart():
    session_id = request.cookies.get('sessionid')
    id = request.args.get('id')

    # delete from cart
    if id:
        size = request.form['size']

        cursor.execute('SELECT * FROM deleteFromCart(%s, %s, %s)', (session_id, id, size))
        conn.commit()

        result = cursor.fetchone()
    else:
        # insert to cart
        size = request.form['materialExampleRadios']
        quantity = request.form['quantity']
        prod_id = request.form['id']

        cursor.execute('SELECT * FROM addToCart(%s, %s, %s, %s)', (session_id, prod_id, size, quantity))
        conn.commit()

        result = cursor.fetchone()

    if result == 1:
        return make_response(render_template('home.html', categories=categories, user_name=userName))
    else:
        cursor.execute('SELECT * FROM getItemsInCart(%s)', (session_id,))
        conn.commit()

        products = cursor.fetchall()

        cursor.execute('SELECT * FROM getSubtotal(%s)', (session_id,))
        conn.commit()

        result = cursor.fetchone()

        if result == (None, None):
            (subtotal, total) = (0.00, 0.00)
        else:
            (subtotal, total) = result
        return make_response(
            render_template("cart.html", categories=categories, products=products, nr_elements=len(products),
                            subtotal=subtotal, total=round(total, 2), userid=request.cookies.get('userid'),
                            user_name=userName))


@app.route('/endCart', methods=['POST'])
def place_order():
    session_id = request.cookies.get('sessionid')
    user_id = request.cookies.get('userid')
    total = request.form['total']

    cursor.execute('SELECT * FROM placeOrder(%s, %s, %s)', (session_id, user_id, total))
    conn.commit()

    return make_response(render_template('endCart.html', categories=categories, user_name=userName))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
