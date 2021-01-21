import zlib
import base64

def decode_xunit(file):
    f = open(file, "r")
    hash = f.read()

    print(zlib.decompress(base64.b64decode(hash)).decode('utf-8'))
