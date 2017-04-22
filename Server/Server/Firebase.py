import requests

FIREBASE_URL = "https://divbin-1782f.firebaseio.com/"

def getTrash():
    return ['Trash']

def getRecycle():
    return 'Recycle'

def getCompost():
    return 'Compost'

def getDonate():
    return 'Donate'

def addItem(category, item):

    # TRASH
    if (category == 0): 
        trashList = getTrash()

    # RECYCLE
    elif (category == 1):
        recycleList = getRecycle()

    # COMPOST
    elif (category == 2):
        compostList = getCompost()

    # DONATE
    elif (category == 3):
        donateList = getDonate()

    else:
        print('Errr')


    print(item)