from flask import Flask, jsonify, request
import Firebase
import json

application = Flask(__name__)

test = [
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
    return 'Hello World'

@application.route('/test', methods=['GET'])
def testRoute():
    return jsonify(test)

@application.route('/postTest', methods=['POST'])
def post():
    content = request.get_json(silent = True)
    print(content)
    return jsonify(content)

@application.route('/lists/<string:id>/<string:item>', methods=['GET'])
def addItemToList(id,item):

    Firebase.addItem(id, item)
    result = {
        id:item
    }

    return jsonify(result)

@application.route('/analyze/<string:str>', methods=['GET'])
def analyze(str):

    items = str.split(',')

    total = 0
    trash = 0
    recycle = 0
    compost = 0
    donate = 0

    for item in items:
        res = Firebase.getItem(item)
        if (res is not None):
            total+=1
            if (res == "trash"):
                trash += 1
            elif (res == "recycle"):
                recycle += 1
            elif (res == "compost"):
                compost += 1
            elif (res == "donate"):
                donate += 1

    
    if (total == 0):
        data = {
            "Trash": 0.00,
            "Recycle": 0.00,
            "Compost": 0.00,
            "Donate": 0.00
        }

        return jsonify(data)

    data = {
        "Trash": float(trash)/total,
        "Recycle": float(recycle)/total,
        "Compost": float(compost)/total,
        "Donate": float(donate)/total
    }

    return jsonify(data)

    


if __name__ == '__main__':
    application.run(debug=True)