import requests
import json

FIREBASE_URL = "https://divbin-1782f.firebaseio.com/"

def getItem(item):

    getURL = FIREBASE_URL + item + '.json'
    req = requests.get(getURL)
    res = json.loads(req.content.decode('utf-8'))
    return res

def addItem(category, item):

    putURL = FIREBASE_URL + '.json'

    data = {
        item: category
    }

    req = requests.patch(putURL, json.dumps(data))
