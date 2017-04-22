import easypost
import os

def getKey():
    return os.environ['EASYPOST_KEY']

def createShipment():
    easypost.api_key = getKey()
    print(easypost.api_key)
    customs_info = easypost.CustomsInfo.create(
    eel_pfc='NOEEI 30.37(a)',
    customs_certify=True,
    customs_signer='Steve Brule',
    contents_type='merchandise',
    contents_explanation='',
    restriction_type='none',
    restriction_comments='',
    non_delivery_option='abandon',
    customs_items=[{
        'description': 'Sweet shirts',
        'quantity': 2,
        'weight': 11,
        'value': 23,
        'hs_tariff_number': '654321',
        'origin_country': 'US'
    }]
    )

    shipment = easypost.Shipment.create(
        to_address={
            "name": 'Dr. Steve Brule',
            "street1": '179 N Harbor Dr',
            "city": 'Redondo Beach',
            "state": 'CA',
            "zip": '90277',
            "country": 'US',
            "phone": '4153334444',
            "email": 'dr_steve_brule@gmail.com'
        },
        from_address={
            "name": 'EasyPost',
            "street1": '417 Montgomery Street',
            "street2": '5th Floor',
            "city": 'San Francisco',
            "state": 'CA',
            "zip": '94104',
            "country": 'US',
            "phone": '4153334444',
            "email": 'support@easypost.com'
        },
        parcel={
            "length": 20.2,
            "width": 10.9,
            "height": 5,
            "weight": 65.9
        },
        customs_info=customs_info
    )