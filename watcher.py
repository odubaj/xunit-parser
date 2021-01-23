import time
import os
import sys
import json
import zlib
import re
import base64
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

ROOT_DIR = os.getcwd()
DIRECTORY_TO_WATCH = ROOT_DIR+"/queue/"

IMPORT_SCRIPT = "main.sh"
RUNNING_SCRIPT = "script.sh"
ERROR_SCRIPT = "error.sh"
USER = "superadmin"
PASSWORD = "aQsWdEfR1029"
#PASSWORD = "erebus"
URL_PATTERN="http[s]*:*"
REPORT_LOG="report.log"

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
            print(exc)

        self.observer.join()


class Handler(FileSystemEventHandler):
    def on_any_event(self, event):
        if event.is_directory:
            return None

        elif event.event_type == 'modified':
            # Taken any action here when a file is modified.
            print ("Received modified event - %s." % event.src_path)
            for filename in os.listdir(DIRECTORY_TO_WATCH):
                if filename.startswith("ID:"):
                    json_file = open(DIRECTORY_TO_WATCH + filename, "r") 
                    json_object = json.load(json_file)

                    task_id = json_object['msg']['artifact']['id']
                    if not os.path.exists(task_id):
                        os.mkdir(task_id)

                    mytime = str(round(time.time() * 1000))
                    topic_name = json_object['topic'].split('.')[5]
                    test_plan_name = json_object['msg']['namespace']+"."+json_object['msg']['type']+".functional"
                    new_file_position = ROOT_DIR+"/"+task_id+"/"+test_plan_name+"-"+mytime+"-"+topic_name+"-datagrepper.json"
                    os.replace(DIRECTORY_TO_WATCH+filename, new_file_position)

                    if("redhat-module" not in json_object['topic']):
                        with open("actions_watcher.log", "a") as actions_file:
                            actions_file.write("starting brew-build script for task "+task_id+"\n")
                        self.handle_brew_build(json_object, test_plan_name, task_id, mytime)
                        print("skript pre brew-buildy uspesne ukonceny")
                    else:
                        with open("actions_watcher.log", "a") as actions_file:
                            actions_file.write("starting module-build script for task "+task_id+"\n")
                        self.handle_module_build(json_object, test_plan_name, task_id, mytime)
                        print("skript pre module-buildy uspesne ukonceny")

                time.sleep(3)

    def decode_xunit(self, hash, xunit_orig):
        decoded = zlib.decompress(base64.b64decode(hash)).decode('utf-8')

        with open(xunit_orig, "a") as xunit_file:
            xunit_file.write(decoded)


    def handle_brew_build(self, json_object, test_plan_name, task_id, mytime):
        xunit_original = task_id+"/"+test_plan_name+"-"+"-"+mytime+"-original-res.xml"
        component = json_object["msg"]["artifact"]["component"]
        scratch = str(json_object["msg"]["artifact"]["scratch"]).lower()
        nvr = json_object["msg"]["artifact"]["nvr"]
        issuer = json_object["msg"]["artifact"]["issuer"]

        if(json_object['topic'] == "VirtualTopic.eng.ci.brew-build.test.complete"):
            if ('xunit' not in json_object["msg"]):
                if (json_object["msg"]["xunit"] == ""):
                    print("no xunit")
                    return
            
            pattern = re.compile(URL_PATTERN)
            if (pattern.match(json_object["msg"]["xunit"])):
                ret = os.system("curl -s "+json_object["msg"]["xunit"]+" > "+xunit_original)
            else:
                self.decode_xunit(json_object["msg"]["xunit"], xunit_original)

            with open(task_id+"/"+REPORT_LOG, "a") as report_file:
                report_file.write(" --------------------------------------------------\n")
                report_file.write(" received message from topic "+json_object['topic']+"  - message valid\n")

            ret = os.system("./"+IMPORT_SCRIPT+" "+USER+" "+PASSWORD+" "+xunit_original+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+mytime)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.brew-build.test.error"):
            log1 = json_object["msg"]["run"]["debug"]
            log2 = json_object["msg"]["run"]["log"]
            log3 = json_object["msg"]["run"]["log_raw"]

            ret = os.system("./"+ERROR_SCRIPT+" "+USER+" "+PASSWORD+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+log1+" "+log2+" "+log3)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.brew-build.test.running"):
            ret = os.system("./"+RUNNING_SCRIPT+" "+USER+" "+PASSWORD+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer)

    def handle_module_build(self, json_object, test_plan_name, task_id, mytime):
        xunit_original = task_id+"/"+test_plan_name+"-"+"-"+mytime+"-original-res.xml"
        component = json_object["msg"]["artifact"]["name"]
        scratch = "unknown"
        nvr = json_object["msg"]["artifact"]["nsvc"]
        issuer = json_object["msg"]["artifact"]["issuer"]

        if(json_object['topic'] == "VirtualTopic.eng.ci.redhat-module.test.complete"):
            if ('xunit' not in json_object["msg"]):
                if (json_object["msg"]["xunit"] == ""):
                    print("no xunit")
                    return
            
            pattern = re.compile(URL_PATTERN)
            if (pattern.match(json_object["msg"]["xunit"])):
                ret = os.system("curl -s "+json_object["msg"]["xunit"]+" > "+xunit_original)
            else:
                self.decode_xunit(json_object["msg"]["xunit"], xunit_original)

            with open(task_id+"/"+REPORT_LOG, "a") as report_file:
                report_file.write(" --------------------------------------------------\n")
                report_file.write(" received message from topic "+json_object['topic']+"  - message valid\n")

            ret = os.system("./"+IMPORT_SCRIPT+" "+USER+" "+PASSWORD+" "+xunit_original+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+mytime)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.redhat-module.test.error"):
            log1 = json_object["msg"]["run"]["debug"]
            log2 = json_object["msg"]["run"]["log"]
            log3 = json_object["msg"]["run"]["log_raw"]

            ret = os.system("./"+ERROR_SCRIPT+" "+USER+" "+PASSWORD+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer+" "+log1+" "+log2+" "+log3)

        elif(json_object['topic'] == "VirtualTopic.eng.ci.redhat-module.test.running"):
            ret = os.system("./"+RUNNING_SCRIPT+" "+USER+" "+PASSWORD+" "+component+" "+scratch+" "+nvr+" "+task_id+" "+test_plan_name+" "+issuer)

if __name__ == '__main__':
    w = Watcher()
    try:
        w.run()
    except Exception as exc:
        print(exc)