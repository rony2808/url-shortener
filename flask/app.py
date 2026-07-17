from flask import Flask, jsonify, request, redirect
from prometheus_flask_exporter import PrometheusMetrics
import psycopg2
import redis
import json
import os
import random
import string

app = Flask(__name__)
metrics = PrometheusMetrics(app)

def get_db():
	return psycopg2.connect(
		host=os.environ.get('DB_HOST', 'database'),
		user=os.environ.get('DB_USER', 'url_user'),
		password=os.environ.get('DB_PASSWORD', 'url_password'),
		dbname=os.environ.get('DB_NAME', 'url_name')
	)

def get_redis():
	return redis.Redis(
		host=os.environ.get('REDIS_HOST', 'redis'),
		port=int(os.environ.get('REDIS_PORT', 6379)),
		decode_responses=True
	)

@app.route('/')
def home():
	return jsonify({"service": "url-shortener", "status": "running"})

@app.route('/shorten', methods=['POST'])
def create_short_url():
	try:
		data = request.get_json()
		url = data.get('url')
		if not url:
			return jsonify({"error": "url is required"}), 400
		caracteres = string.ascii_letters + string.digits
		random_caracteres = random.choices(caracteres, k=6)
		code = ''.join(random_caracteres)
		db = get_db()
		cursor = db.cursor()
		cursor.execute(
			"INSERT INTO links (code, url) VALUES (%s, %s)", 
			(code, url)
		)
		db.commit()
		cursor.close()
		db.close()
		return jsonify({"code": code, "short_url": f"/{code}"}), 201
	except Exception as e:
		return jsonify({"error": str(e)}), 500

@app.route('/<code>', methods=['GET'])
def redirect_url(code):
	try:
		r = get_redis()
		cached = r.get(f'url:{code}')
		if cached:
			r.incr(f'clicks:{code}')
			return redirect(cached)
		db = get_db()
		cursor = db.cursor()
		cursor.execute(
			"SELECT url FROM links WHERE code = %s",
			(code,)
		)
		row = cursor.fetchone()
		cursor.close()
		db.close()
		if not row:
			return jsonify({"error": "url not found"}), 404
		url = row[0]
		r.setex(f'url:{code}', 60, url)
		r.incr(f'clicks:{code}')
		return redirect(url)
	except Exception as e:
		return jsonify({"error": str(e)}), 500


@app.route('/stats/<code>', methods=['GET'])
def get_stats(code):
	try:
		r = get_redis()
		db = get_db()
		cursor = db.cursor()
		cursor.execute(
			"SELECT url FROM links WHERE code = %s",
			(code,)
		)
		row = cursor.fetchone()
		cursor.close()
		db.close()
		if not row:
			return jsonify({"error": "url not found"}), 404
		url = row[0]
		clicks = r.get(f'clicks:{code}')
		if clicks is None :
			clicks = 0
		else:
			clicks = int(clicks)
		return jsonify({
			"url": url,
			"clicks": clicks
		})
	except Exception as e:
		return jsonify({"error": str(e)}), 500			

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
