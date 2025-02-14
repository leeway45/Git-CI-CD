from flask import Flask, render_template, request, redirect, url_for, session

# 設置 Flask 應用，明確指定模板目錄和靜態文件目錄
app = Flask(__name__, template_folder='templates', static_folder='static')

app.secret_key = 'supersecretkey'

# 商品清單，增加至 5 隻，並新增 image 欄位 (圖片檔名)
PRODUCTS = [
    {'id': 1, 'name': 'dog1',   'price': 10000, 'image': 'dog1.jpg'},
    {'id': 2, 'name': 'dog2',   'price': 12000, 'image': 'dog2.jpg'},
    {'id': 3, 'name': 'dog3',   'price': 20000, 'image': 'dog3.jpg'},
    {'id': 4, 'name': 'dog4',   'price': 15000, 'image': 'dog4.jpg'},
    {'id': 5, 'name': 'dog5',   'price': 18000, 'image': 'dog5.jpg'},
]

@app.route('/')
def home():
    return render_template('home.html', products=PRODUCTS)

@app.route('/add_to_cart/<int:product_id>')
def add_to_cart(product_id):
    product = next((p for p in PRODUCTS if p['id'] == product_id), None)
    if not product:
        return "Product not found", 404

    cart = session.get('cart', {})
    if str(product_id) in cart:
        cart[str(product_id)]['quantity'] += 1
    else:
        # 將 image 欄位也一併儲存到購物車中
        cart[str(product_id)] = {
            'name': product['name'],
            'price': product['price'],
            'quantity': 1,
            'image': product['image']
        }

    session['cart'] = cart
    return redirect(url_for('view_cart'))

@app.route('/cart')
def view_cart():
    cart = session.get('cart', {})
    total = sum(item['price'] * item['quantity'] for item in cart.values())
    return render_template('cart.html', cart=cart, total=total)

@app.route('/clear_cart')
def clear_cart():
    session.pop('cart', None)
    return redirect(url_for('view_cart'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)