from flask import Flask, jsonify

def create_app():
    app = Flask(__name__)

    @app.get('/health')
    def health():
        return jsonify({'status':'ok'}), 200

    @app.get('/')
    def index():
        return jsonify({'message':'Hello from Python App!'})

    return app
