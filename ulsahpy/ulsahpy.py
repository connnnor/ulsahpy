#!/usr/bin/env python3

"""A simple python application for ulsah authors
"""

from flask import Flask, request, abort
app = Flask(__name__)

import os
import sys
import argparse
import json
#from ulsahpy import ordinal

ed_authors = {}

def ordinal(n):
    ord_d = {1 :"st", 2 : "nd", 3 : "rd"}
    return str(n) + ord_d.get(n, "th")

@app.route('/')
def authors():
    edition = request.args.get('edition')
    if edition:
        edition = int(edition)
        if edition >= 1 and edition <= len(ed_authors):
            return ed_authors[edition-1]
        else:
            abort(404, description=f"{ordinal(edition)} edition is invalid")
    else:
        abort(404, description="Resource not found")

@app.route('/healthy')
def healthy():
    return { "healthy" : "true" }

@app.before_first_request
def _init_stuff():
    global ed_authors
    authors_path = os.path.join(
                    os.path.dirname(os.path.abspath(__file__)),
                    'authors.json')
    with open(authors_path) as f:
      ed_authors_d = json.load(f)
    ed_authors = ed_authors_d["AllEditions"]

if __name__ == '__main__':
    app.run(host='0.0.0.0',port=8081)
