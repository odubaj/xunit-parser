#!/usr/bin/python3

import json
import argparse
import sys

def parse_args():
    """Parse arguments."""
    parser = argparse.ArgumentParser(description='Merge launches data')
    parser.add_argument('existing', nargs=1, help='Existing found launch')
    parser.add_argument('imported', nargs=1, help='Imported launch')

    return parser.parse_args()

def main(args):
    existing_launch = json.loads(args.existing[0])
    imported_launch = json.loads(args.imported[0])
    existing_launch = existing_launch[0]
    imported_launch = imported_launch[0]

    attributes_new = existing_launch['attributes']

    for item in imported_launch['attributes']:
        found = False
        for element in attributes_new:
            if(item['key'] == element['key'] and item['value'] == element['value']):
                found = True
                break
        if(found == False):
            attributes_new.append(item)

    data_set = {"launches":[existing_launch['id'], imported_launch['id']],
                "mergeType":"BASIC", "name":imported_launch['name'],
                "endTime":imported_launch['endTime'],"startTime":existing_launch['startTime'],
                "extendSuitesDescription":"false", "description":"",
                "attributes":attributes_new}

    print(json.dumps(data_set))

if __name__ == '__main__':
    args = parse_args()
    main(args)