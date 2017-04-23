from flask import Flask, jsonify, request, render_template
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

    total = len(items)
    trash = 0
    recycle = 0
    compost = 0
    donate = 0

    for item in items:
        res = Firebase.getItem(item)
        if (res is not None):
            if (res == "trash"):
                trash += 1
            elif (res == "recycle"):
                recycle += 1
            elif (res == "compost"):
                compost += 1
            elif (res == "donate"):
                donate += 1
    

    data = {
        "Trash": float(trash)/total,
        "Recycle": float(recycle)/total,
        "Compost": float(compost)/total,
        "Donate": float(donate)/total
    }

    return jsonify(data)

@application.route('/labels/<string:name>/<string:address>/<string:city>/<string:state>/<string:zipNum>', methods=['GET'])
def generateLabel(name, address, city, state, zipNum):
    data = {
        "Name": name.replace("%20", " ").upper(),
        "Address": address.replace("%20", " ").upper(),
        "City": city.replace("%20", " ").upper(),
        "State": state.replace("%20", " ").upper(),
        "Zip": zipNum.replace("%20", " ").upper()

    }
    return render_template('shipping.html', addressData = data)
    

if __name__ == '__main__':
    application.run(debug=True)