import time
import os
import sys
import json
import zlib
import re
import base64
import env_file
import requests
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from pathlib import Path

ROOT_DIR = os.getcwd()
DIRECTORY_TO_WATCH = ROOT_DIR+"/queue/"

IMPORT_SCRIPT = "main.sh"
RUNNING_SCRIPT = "script.sh"
ERROR_SCRIPT = "error.sh"
URL_PATTERN="http[s]*:*"
REPORT_LOG="report.log"

"""watcher of a disk queue"""
class Watcher:
    def __init__(self):
        self.observer = Observer()

    def run(self):
        event_handler = Handler()
        self.observer.schedule(event_handler, DIRECTORY_TO_WATCH, recursive=True)
        self.observer.start()
        try:
            while True:
                time.sleep(5)
        except Exception as exc:
            self.observer.stop()
            logging.error('Watcher: %s', str(exc))

        self.observer.join()

"""handler on change event"""
class Handler(FileSystemEventHandler):
    def on_any_event(self, event):
        if event.is_directory:
            return None

        elif event.event_type == 'modified':
            # Taken any action here when a file is modified.
            logging.info("Received modified event: %s", event.src_path)
            for filename in sorted(Path(DIRECTORY_TO_WATCH).iterdir(), key=os.path.getmtime):
                #try:
                #    r = requests.head("https://reportportal.osci.redhat.com/api")
                #    if(r.status_code >= 404):
                #        logging.warning("ReportPortal API down, cannot proceed")
                #        break
                #except Exception as exc:
                #    logging.warning("ReportPortal API down(exception), cannot proceed")
                #    break

                if os.path.basename(filename).startswith("ID:"):
                    json_file = open(filename, "r")
                    json_object = json.load(json_file)

                    task_id = json_object['msg']['artifact']['id']
                    if not os.path.exists(task_id):
                        os.mkdir(task_id)

                    mytime = str(round(time.time() * 1000))
                    topic_name = json_object['topic'].split('.')[5]
                    test_plan_name = json_object['msg']['namespace']+"."+json_object['msg']['type']+".functional"
                    new_file_position = ROOT_DIR+"/"+task_id+"/"+test_plan_name+"-"+mytime+"-"+topic_name+"-datagrepper.json"
                    os.replace(filename, new_file_position)

                    if("redhat-module" not in json_object['topic']):
                        logging.info("starting brew-build script for task %s", task_id)
                        self.handle_brew_build(json_object, test_plan_name, task_id, mytime)
                    else:
                        logging.info("starting module-build script for task %s", task_id)
                        self.handle_module_build(json_object, test_plan_name, task_id, mytime)

                time.sleep(3)

    """decode xunit"""
    def decode_xunit(self, hash, xunit_orig):
        decoded = zlib.decompress(base64.b64decode(hash)).decode('utf-8')

        with open(xunit_orig, "a") as xunit_file:
            xunit_file.write(decoded)

    """handle brew-build"""
    def handle_brew_build(self, json_object, test_plan_name, task_id, mytime):
        xunit_original = task_id+"/"+test_plan_name+"-"+"-"+mytime+"-original-res.xml"
        component = json_object["msg"]["artifact"]["component"]
        scratch = str(json_object["msg"]["artifact"]["scratch"]).lower()
        nvr = json_object["msg"]["artifact"]["nvr"]
        issuer = json_object["msg"]["artifact"]["issuer"]
        user = os.environ.get("USER")
        password = os.environ.get("PASSWORD")

        if(json_object['topic'] == "VirtualTopic.eng.ci.brew-build.test.complete"):
            if ('xunit' not in json_object["msg"]):
                ret = os.system("echo '<testsuites></testsuites>' > "+xunit_original)
            else:
                pattern = re.compile(URL_PATTERN)
                if (pattern.match(json_object["msg"]["xunit"])):
                    ret = os.system("curl -s "+json_object["msg"]["xunit"]+" > "+xunit_original)
                else:
                    self.decode_xunit(json_object["msg"]["xunit"], xunit_original)

            with open(task_id+"/"+REPORT_LOG, "a") as report_file:
                report_file.write(" --------------------------------------------------\n")
                report_file.write(" received message from topic "+json_object['topic']+"  - message valid\n")

            ret = os.system("./"+IMPORT_SCRIPT+" "+user+" "+password+" "+xunit_original+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+mytime)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.brew-build.test.error"):
            log1 = json_object["msg"]["run"]["debug"]
            log2 = json_object["msg"]["run"]["log"]
            log3 = json_object["msg"]["run"]["log_raw"]

            ret = os.system("./"+ERROR_SCRIPT+" "+user+" "+password+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+log1+" "+log2+" "+log3)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.brew-build.test.running"):
            ret = os.system("./"+RUNNING_SCRIPT+" "+user+" "+password+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer)

    """handle module build"""
    def handle_module_build(self, json_object, test_plan_name, task_id, mytime):
        xunit_original = task_id+"/"+test_plan_name+"-"+"-"+mytime+"-original-res.xml"
        component = json_object["msg"]["artifact"]["name"]
        scratch = "unknown"
        nvr = json_object["msg"]["artifact"]["nsvc"]
        issuer = json_object["msg"]["artifact"]["issuer"]
        user = os.environ.get("USER")
        password = os.environ.get("PASSWORD")

        if(json_object['topic'] == "VirtualTopic.eng.ci.redhat-module.test.complete"):
            if ('xunit' not in json_object["msg"]):
                ret = os.system("echo '<testsuites></testsuites>' > "+xunit_original)
            else:
                pattern = re.compile(URL_PATTERN)
                if (pattern.match(json_object["msg"]["xunit"])):
                    ret = os.system("curl -s "+json_object["msg"]["xunit"]+" > "+xunit_original)
                else:
                    self.decode_xunit(json_object["msg"]["xunit"], xunit_original)

            with open(task_id+"/"+REPORT_LOG, "a") as report_file:
                report_file.write(" --------------------------------------------------\n")
                report_file.write(" received message from topic "+json_object['topic']+"  - message valid\n")

            ret = os.system("./"+IMPORT_SCRIPT+" "+user+" "+password+" "+xunit_original+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+mytime)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.redhat-module.test.error"):
            log1 = json_object["msg"]["run"]["debug"]
            log2 = json_object["msg"]["run"]["log"]
            log3 = json_object["msg"]["run"]["log_raw"]

            ret = os.system("./"+ERROR_SCRIPT+" "+user+" "+password+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+log1+" "+log2+" "+log3)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.redhat-module.test.running"):
            ret = os.system("./"+RUNNING_SCRIPT+" "+user+" "+password+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer)

if __name__ == '__main__':
    logging.basicConfig(filename='actions_watcher.log', encoding='utf-8', level=logging.INFO, format='%(asctime)s %(message)s')
    w = Watcher()

    while True:
        try:
            env_file.load('.env')
            w.run()
        except Exception as exc:
            logging.error('Main: %s', str(exc))

        time.sleep(10)
