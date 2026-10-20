FROM python:3.14.8-alpine
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY server.py database.py /app/
USER 10001:10001
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DATABASE_BACKEND=postgres
EXPOSE 8080
CMD ["python", "/app/server.py"]
