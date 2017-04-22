from flask import Flask, jsonify, request
import Firebase

application = Flask(__name__)

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

@application.route('/', methods=['GET'])
def root():
    Firebase.addItem(1, 'Apples')
    return Firebase.getCompost()

@application.route('/test', methods=['GET'])
def test():
    return jsonify(item)

@application.route('/postTest', methods=['POST'])
def post():
    content = request.get_json(silent = True)
    print(content)
    return jsonify(content)

@application.route('/lists/trash', methods=['GET'])
def getTrash():
    return jsonify(Firebase.getTrash())

@application.route('/lists/recycle', methods=['GET'])
def getRecycle():
    return jsonify(Firebase.getRecycle())

@application.route('/lists/compost', methods=['GET'])
def getCompost():
    return jsonify(Firebase.getCompost())

@application.route('/lists/donate', methods=['GET'])
def getDonate():
    return jsonify(Firebase.getDonate())

if __name__ == '__main__':
    application .run(debug=True)