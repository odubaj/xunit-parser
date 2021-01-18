
import json
import sys
import requests
import time
import os
import re

VERSION_PATTERN="0\.1\.[0-9]*"

def get_messages():

    topic_running = '/topic/VirtualTopic.eng.ci.brew-build.test.running'
    topic_error = '/topic/VirtualTopic.eng.ci.brew-build.test.error'
    topic_complete = '/topic/VirtualTopic.eng.ci.brew-build.test.complete'

    topic_running_module = '/topic/VirtualTopic.eng.ci.redhat-module.test.running'
    topic_error_module = '/topic/VirtualTopic.eng.ci.redhat-module.test.error'
    topic_complete_module = '/topic/VirtualTopic.eng.ci.redhat-module.test.complete'

    while True:

        print("DALSICH 10s'\n'")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")

        # req_running = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_running+'&delta=10')
        # data_running = req_running.json()

        # req_error = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_error+'&delta=10')
        # data_error = req_error.json()

        # req_complete = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_complete+'&delta=10')
        # data_complete = req_complete.json()

        # req_running_module = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_running_module+'&delta=10')
        # data_running_module = req_running_module.json()

        # req_error_module = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_error_module+'&delta=10')
        # data_error_module = req_error_module.json()

        req_all = requests.get('https://datagrepper.engineering.redhat.com/raw?topic='+topic_complete_module+'&topic='+topic_running_module+'&topic='+topic_error_module+'&topic='+topic_complete+'&topic='+topic_running+'&topic='+topic_error+'&delta=10')

        data_all = req_all.json()

        #s1 = json.dumps(data1)
        #data = json.loads(s1)

        for data in [data_all]:
            new_messages = []
            for msg in data['raw_messages']:
                new_messages.append(msg)

            for msg in new_messages:
                print("sprava!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")
                print (json.dumps(msg))
                print("konec!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")

                ret = os.system("echo '--------------------------------------------------' >> actions.log")
                ret = os.system("echo 'received msg with task-id "+str(msg['msg']['artifact']['id'])+"' >> actions.log")

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

                if('version' not in msg['msg']):
                    print("version neexistuje")
                    continue
                else:
                    pattern = re.compile(VERSION_PATTERN)
                    if (not pattern.match(msg['msg']['version'])):
                        print(msg['msg']['version'])
                        print("zla version")
                        continue

                ret = os.system("mkdir -p "+msg['msg']['artifact']['id'])
                topic_name = msg['topic'].split('.')[5]
                mytime = round(time.time() * 1000)

                DATAGREPPER_JSON = msg['msg']['artifact']['id']+"/"+msg['msg']['namespace']+"."+msg['msg']['type']+".functional"+"-"+str(mytime)+"-"+topic_name+"-datagrepper.json"

                ret = os.system("echo 'msg valid, topic: "+topic_name+", plan: "+msg['msg']['namespace']+"."+msg['msg']['type']+".functional' >> actions.log")

                text_file = open(DATAGREPPER_JSON, "w")
                text_file.write(json.dumps(msg))
                print("subor vytvoreny")
                text_file.close()

                if("redhat-module" not in msg['topic']):
                    ret = os.system("sh reportportal-import-results.sh "+DATAGREPPER_JSON+" "+str(mytime)+" &")
                    ret = os.system("echo 'starting brew-build script' >> actions.log")
                    print("skript pre brew-buildy spusteny")
                else:
                    ret = os.system("sh reportportal-import-module-results.sh "+DATAGREPPER_JSON+" "+str(mytime)+" &")
                    ret = os.system("echo 'starting module-build script' >> actions.log")
                    print("skript pre module-buildy spusteny")
                print("konec!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")
                ret = os.system("echo '--------------------------------------------------' >> actions.log")

        time.sleep(10)

def main():
    get_messages()

if __name__ == '__main__':
    main()