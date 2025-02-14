# Builder 階段：構建、安裝依賴並執行測試
FROM python:3.9-slim AS builder

# 設置工作目錄
WORKDIR /app

# 複製依賴文件並安裝
COPY ./requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# 複製應用程式和測試文件
COPY ./UTrun.py /app/
COPY ./templates /app/templates/
COPY ./test_unit.py /app/

# 安裝測試工具並運行測試
RUN pip install --no-cache-dir pytest pytest-cov
RUN pytest --cov=UTrun --cov-report=term

# 生產階段：生成最終映像
FROM python:3.9-slim

# 設置工作目錄
WORKDIR /app

# 從 builder 階段複製所有文件（僅包含源碼和資源，不含已安裝的依賴）
COPY --from=builder /app /app

# 在生產階段安裝依賴及測試工具
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir pytest pytest-cov

# 設置環境變數
ENV FLASK_ENV=production
ENV FLASK_DEBUG=0
ENV FLASK_APP=UTrun.py

# 開放端口 5000（Flask 預設運行端口）
EXPOSE 5000

# 啟動應用程式
CMD ["python", "UTrun.py"]
