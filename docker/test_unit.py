import pytest
import sys
import os

# 添加模組路徑
sys.path.append(os.path.abspath(os.path.dirname(__file__)))
from UTrun import app

@pytest.fixture
def client():
    """
    設置 Flask 測試客戶端
    """
    app.config['TESTING'] = True  # 啟用測試模式
    with app.test_client() as client:
        yield client

def test_home_page(client):
    """
    測試首頁是否正常顯示商品列表
    """
    response = client.get('/')
    assert response.status_code == 200
    # 根據新的商品清單，檢查是否包含 dog1、dog2、dog3
    assert b'dog1' in response.data
    assert b'dog2' in response.data
    assert b'dog3' in response.data

def test_add_to_cart(client):
    """
    測試添加商品到購物車
    """
    response = client.get('/add_to_cart/1', follow_redirects=True)
    assert response.status_code == 200
    # 檢查是否顯示添加的商品 dog1 與其價格 8000
    assert b'dog1' in response.data
    assert b'8000' in response.data

def test_view_cart(client):
    """
    測試查看購物車
    """
    # 添加商品到購物車
    client.get('/add_to_cart/1')
    client.get('/add_to_cart/2')
    response = client.get('/cart')
    assert response.status_code == 200
    # 檢查購物車中是否包含 dog1 與 dog2
    assert b'dog1' in response.data
    assert b'dog2' in response.data
    # 檢查是否顯示總金額資訊
    assert b'Total' in response.data

def test_clear_cart(client):
    """
    測試清空購物車功能
    """
    # 添加商品到購物車
    client.get('/add_to_cart/1')
    client.get('/add_to_cart/2')
    
    # 清空購物車
    response = client.get('/clear_cart', follow_redirects=True)
    assert response.status_code == 200
    # 假設當購物車為空時，頁面會顯示 "Your cart is empty"
    assert b'Your cart is empty' in response.data
