import requests
import json

FIREBASE_URL = "https://divbin-1782f.firebaseio.com/"

def getTrash():
    trashURL = FIREBASE_URL + "Trash.json"
    req = requests.get(trashURL)
    return req.content

def getRecycle():
    return 'Recycle'

def getCompost():
    return 'Compost'

def getDonate():
    return 'Donate'

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
    