import requests
import json

FIREBASE_URL = "https://divbin-1782f.firebaseio.com/"

def getTrash():
    trashURL = FIREBASE_URL + "Trash.json"
    req = requests.get(trashURL)
    return json.loads(req.content)

def getRecycle():
    recycleURL = FIREBASE_URL + "Recycle.json"
    req = requests.get(recycleURL)
    return json.loads(req.content)

def getCompost():
    compostURL = FIREBASE_URL + "Compost.json"
    req = requests.get(compostURL)
    return json.loads(req.content)

def getDonate():
    donateURL = FIREBASE_URL + "Donate.json"
    req = requests.get(donateURL)
    return json.loads(req.content)

def addItem(category, item):

    putURL = FIREBASE_URL

    # TRASH
    if (category == 0): 
        putURL += 'Trash.json'

    # RECYCLE
    elif (category == 1):
        putURL += 'Recycle.json'

    # COMPOST
    elif (category == 2):
        putURL += 'Compost.json'

    # DONATE
    elif (category == 3):
        putURL += 'Donate.json'

    else:
        return

    data = {
        item: ""
    }

    req = requests.patch(putURL, json.dumps(data))
