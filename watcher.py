import time
import os
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
#import ntpath

DIRECTORY_TO_WATCH = "/root/datagrepper-downloader/queue/"

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

    @staticmethod
    def on_any_event(event):
        if event.is_directory:
            return None

        elif event.event_type == 'modified':
            # Taken any action here when a file is modified.
            print ("Received modified event - %s." % event.src_path)
            for filename in os.listdir(DIRECTORY_TO_WATCH):
                if filename.startswith("ID:"):
                    json_file = open(DIRECTORY_TO_WATCH + filename, "r") 
                    json_object = json.load(json_file)
                    ret = os.system("mkdir -p "+msg['msg']['artifact']['id'])
                    mytime = round(time.time() * 1000)
                    topic_name = json_object['topic'].split('.')[5]
                    new_file_position = "/root/datagrepper-downloader/"+json_object['msg']['artifact']['id']+"/"+json_object['msg']['namespace']+"."+json_object['msg']['type']+".functional"+"-"+str(mytime)+"-"+topic_name+"-datagrepper.json"
                    ret = os.system("mv "+DIRECTORY_TO_WATCH+filename+" "+new_file_position)

                    if("redhat-module" not in json_object['topic']):
                        ret = os.system("sh reportportal-import-results.sh "+new_file_position+" "+str(mytime))
                        ret = os.system("echo 'starting brew-build script' >> actions.log")
                        print("skript pre brew-buildy spusteny")
                    else:
                        ret = os.system("sh reportportal-import-module-results.sh "+new_file_position+" "+str(mytime))
                        ret = os.system("echo 'starting module-build script' >> actions.log")
                        print("skript pre module-buildy spusteny")

                time.sleep(5)

if __name__ == '__main__':
    w = Watcher()
    try:
        w.run()
    except Exception as exc:
        print(exc)