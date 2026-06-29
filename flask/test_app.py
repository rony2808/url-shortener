from app import app

def test_home():
	client = app.test_client()
	response = client.get('/')
	assert response.status_code == 200
	assert response.get_json()["status"] == "running"

def test_shorten():
	client = app.test_client()
	response = client.post('/shorten', json={"url": "https://www.google.com"})
	assert response.status_code == 201 	
	data = response.get_json()
	assert "code" in data
	assert "short_url" in data 
