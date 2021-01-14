
import json
import sys
import requests
import time
import os

DATAGREPPER_JSON="datagrepper.json"

def get_messages():

    topic_running = '/topic/VirtualTopic.eng.ci.brew-build.test.running'
    topic_error = '/topic/VirtualTopic.eng.ci.brew-build.test.error'
    topic_complete = '/topic/VirtualTopic.eng.ci.brew-build.test.complete'

    while True:

        print("DALSICH 10s'\n'")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")

        req_running = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_running+'&delta=10')
        data_running = req_running.json()

        req_error = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_error+'&delta=10')
        data_error = req_error.json()

        req_complete = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_complete+'&delta=10')
        data_complete = req_complete.json()

        #s1 = json.dumps(data1)
        #data = json.loads(s1)

        for data in [data_running, data_error, data_complete]:
            new_messages = []
            for msg in data['raw_messages']:
                new_messages.append(msg)

            for msg in new_messages:
                print("sprava!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")
                print (json.dumps(msg))
                print("konec!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")

                if('category' not in msg['msg']):
                    print("category neexistuje")
                    continue
                else:
                    if (msg['msg']['category'] != "functional"):
                        print(msg['msg']['category'])
                        print("nefunkcionalne")
                        continue

                if('ci' not in msg['msg']):
                    print("ci neexistuje")
                    continue
                else:
                    if('email' not in msg['msg']['ci']):
                        print("email neexistuje")
                        continue
                    else:
                        if (msg['msg']['ci']['email'] != "baseos-ci@redhat.com"):
                            print("zly mail")
                            print(msg['msg']['ci']['email'])
                            continue

                text_file = open(DATAGREPPER_JSON, "w")
                text_file.write(json.dumps(msg))
                print("subor vytvoreny")
                text_file.close()

                ret = os.system("sh reportportal-import-results.sh")
                print("skript spusteny")
                print("konec!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")

        time.sleep(10)

def main():
    get_messages()

if __name__ == '__main__':
    main()