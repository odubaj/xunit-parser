
import json
import sys
import requests
import time

DATAGREPPER_JSON="datagrepper.json"

# SOURCE_URL = 'https://datagrepper-prod-datanommer.int.open.paas.redhat.com/raw'


# def get_msg():
#     page = 1

#     while True:
#         params = {
#             'topic': "/topic/VirtualTopic.eng.ci.brew-build.test.complete",
#             'page': str(page)
#         }

#         response, content = gluetool.utils.fetch_url('{}?{}'.format(SOURCE_URL, urllib.urlencode(params)))

#         response = json.loads(content)

#         interesting_messages = [
#             msg for msg in response['raw_messages'] if True is True
#         ]

#         new_messages = []
#         for msg in interesting_messages:
#             new_messages.append(msg)

#         for msg in new_messages:
#             print(msg)

#         cnt_all, cnt_interesting, cnt_new = len(response['raw_messages']), len(interesting_messages), len(new_messages)

#         self.info('page {}: {} all, {} interesting, {} new'.format(page, cnt_all, cnt_interesting, cnt_new))

#         if not cnt_new and cnt_interesting > 0:
#             break

#         # if not new_messages:
#         #    break

#         if new_messages:
#             for msg in new_messages:
#                 self.info('    {}'.format(msg['msg_id']))

#             if ARGS.dryrun is False:
#                 for msg in new_messages:
#                     artifact = self.get_artifact(msg)
#                     gluetool.log.log_dict(self.debug, 'artifact', artifact)

#                     state = self.create_artifact_state(msg)
#                     gluetool.log.log_dict(self.debug, 'artifact state', state)

#                     self.store.update('artifacts', artifact, {
#                         '$push': {
#                             'states': state
#                         }
#                     })

#         # if len(result.inserted_ids) != len(digests):
#         #    self.error('Failed to insert messages: {} new, {} inserted'.format(len(digests), len(result.inserted_ids)))
#         #    return

#         page += 1

def get_messages():

    topic_running = '/topic/VirtualTopic.eng.ci.brew-build.test.running'
    topic_error = '/topic/VirtualTopic.eng.ci.brew-build.test.error'
    topic_complete = '/topic/VirtualTopic.eng.ci.brew-build.test.complete'

    while True:

        # print("DALSICH 10s'\n'")
        # print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")
        # print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")
        # print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'\n'")

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
                # print("sprava!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")
                # print (json.dumps(msg))
                # print("konec!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")
                # print(msg['msg']['category'])
                # print(msg['msg']['ci']['email'])
                # print(msg['msg']['version'])
                # print("konec!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")

                if(msg['msg']['category'] != "functional"):
                    # print("nefunkcionalne")
                    continue

                if(msg['msg']['ci']['email'] != "baseos-ci@redhat.com"):
                    # print("zly mail")
                    continue

                text_file = open(DATAGREPPER_JSON, "w")
                text_file.write(json.dumps(msg))
                text_file.close()

                ret = os.system("sh reportportal-import-results.sh")

        time.sleep(10)

def main():
    get_messages()

if __name__ == '__main__':
    main()


# import requests


# req = requests.get('https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.brew-build.test.complete&delta=120  ')
# data = req.json()

# for message in data['raw_messages']:
#     print("sprava!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")
#     print (message)
#     print("konec!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`'\n'")