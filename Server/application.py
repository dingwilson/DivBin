from flask import Flask, jsonify, request
import Firebase

app = Flask(__name__)

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

@app.route('/', methods=['GET'])
def root():
    return 'Hello World'

@app.route('/test', methods=['GET'])
def testRoute():
    return jsonify(test)

@app.route('/postTest', methods=['POST'])
def post():
    content = request.get_json(silent = True)
    print(content)
    return jsonify(content)

@app.route('/lists/<string:id>/<string:item>', methods=['GET'])
def addItemToList(id,item):

    Firebase.addItem(id, item)
    result = {
        id:item
    }

    return jsonify(result)

@app.route('/analyze/<string:str>', methods=['GET'])
def analyze(str):

    items = str.split(',')

    total = 0
    trash = 0
    recycle = 0
    compost = 0
    donate = 0
      
    trashItems = Firebase.getTrash().keys()
    recycleItems = Firebase.getRecycle().keys()
    compostItems = Firebase.getCompost().keys()
    donateItems = Firebase.getDonate().keys()

    for item in items:
        item = item.lower()
        if item in trashItems:
            total += 1
            trash += 1
        elif item in recycleItems:
            total += 1
            recycle += 1
        elif item in compostItems:
            total += 1
            compost += 1
        elif item in donateItems:
            total += 1
            donate += 1
    
    data = {
        "Trash": float(trash)/total,
        "Recycle": float(recycle)/total,
        "Compost": float(compost)/total,
        "Donate": float(donate)/total
    }

    return jsonify(data)

if __name__ == '__main__':
    app.run(debug=True)