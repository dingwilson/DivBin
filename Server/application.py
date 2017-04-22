from flask import Flask, jsonify, request
import Firebase

app = Flask(__name__)

item = [
    {
        'Test': 'Kevin',
        'id': 1
    },
    {
        'Test': 'Wislon',
        'id': 2
    }
]

@app.route('/', methods=['GET'])
def root():
    return 'Apples'

@app.route('/test', methods=['GET'])
def test():
    return jsonify(item)

@app.route('/postTest', methods=['POST'])
def post():
    content = request.get_json(silent = True)
    print(content)
    return jsonify(content)

if __name__ == '__main__':
    app.run(debug=True)