#!/usr/bin/env python3
# -*- encoding: utf-8 -*-

import ovh
import json
import argparse


# Functions
def print_json(_json):
    print(
        json.dumps(
            _json,
            sort_keys=True,
            indent=2,
            separators=(',', ': ')
        )
    )


# Parse args
parser = argparse.ArgumentParser()
parser.add_argument("--plan-code",
                    help="Plan code to order, default is ip-v4-s28-ripe (/28 in RIPE (EU))",
                    default="ip-v4-s28-ripe",)
parser.add_argument("--country",
                    help="Country in which IP will be delivered, default is FR",
                    default="FR",)
args = parser.parse_args()


# Create a client
# It will read config from env vars.
# See https://github.com/ovh/python-ovh#configuration
client = ovh.Client()

# Create cart
cart = client.post(
    "/order/cart",
    ovhSubsidiary=args.country,
    description="IP block ordering",
)
client.post("/order/cart/{}/assign".format(cart['cartId']))

# Add IP block in the cart
item = client.post(
    "/order/cart/{}/ip".format(cart['cartId']),
    duration="P1M",
    planCode=args.plan_code,
    pricingMode="default",
    quantity=1,
)

# Add configuration
# Fuck this API
configuration = client.post(
    "/order/cart/{}/item/{}/configuration".format(
        cart['cartId'],
        item['itemId'],
    ),
    label='country',
    value=args.country,
)

# Checkout
order = client.post("/order/cart/{}/checkout".format(cart['cartId']))

print(
    "Please pay the BC {} --> {}".format(
        order['orderId'],
        order['url'],
    )
)

print('Done')
