#!/usr/bin/env python3

import proton
import socket
import re
import uuid
import errno
import os
import sys
import json
import time
from proton import SSLDomain
from proton.handlers import MessagingHandler
from proton.reactor import Container, Selector

VERSION_PATTERN="0\.1\.[0-9]*"
QUEUE="/root/datagrepper-downloader/queue/"

class UMBReceiver(MessagingHandler):
    def modify_to_string(self, identifier):
        if(isinstance(identifier, str)):
            return identifier
        else:
            return str(identifier)

    def check_incoming_message(self, body):
        ret = os.system("echo '--------------------------------------------------' >> actions.log")

        if('artifact' not in body):
            print("artifact neexistuje")
            return False

        ret = os.system("echo 'received msg with task-id "+self.modify_to_string(body['artifact']['id'])+"' >> actions.log")

        if('category' not in body):
            print("category neexistuje")
            return False
        else:
            if (body['category'] != "functional"):
                print(body['category'])
                print("nefunkcionalne")
                return False

        if('ci' not in body):
            print("ci neexistuje")
            return False
        else:
            if('email' not in body['ci']):
                print("email neexistuje")
                return False
            else:
                if (body['ci']['email'] != "baseos-ci@redhat.com"):
                    print("zly mail")
                    print(body['ci']['email'])
                    return False

        if('version' not in body):
            print("version neexistuje")
            return False
        else:
            pattern = re.compile(VERSION_PATTERN)
            if (not pattern.match(body['version'])):
                print(body['version'])
                print("zla version")
                return False

        return True


    def __init__(self, url, creds_filename, topics):
        super(UMBReceiver, self).__init__()
        self.url = url
        self.creds_filename = creds_filename
        self.topics = topics
        self.umb_username = "client-citool"
        
        uuid_anchor = socket.gethostname()
        print("Initial uuid anchor: %s" % uuid_anchor)
        with open('/proc/self/cgroup', 'r') as cgroup:
            content = cgroup.read()
            match = re.match(r"^.*-([0-9a-fA-F]+)\.scope$", content, re.MULTILINE|re.DOTALL)
            if match:
                uuid_anchor = match.group(1)
                print("Switch to uuid anchor: %s" % uuid_anchor)
        self.uuid = uuid.uuid3(uuid.NAMESPACE_DNS, uuid_anchor)
        self.uuid = str(self.uuid)
        print("Use uuid: %s" % self.uuid)

    def on_start(self, event):
        domain = SSLDomain(SSLDomain.MODE_CLIENT)
        domain.set_credentials(self.creds_filename, self.creds_filename, None)
        domain.set_trusted_ca_db("/etc/ssl/certs/ca-bundle.crt")
        domain.set_peer_authentication(SSLDomain.ANONYMOUS_PEER)

        conn = event.container.connect(urls=self.url, ssl_domain=domain)
        
        for topic in self.topics:
            options = None
            if type(topic) == tuple:
                (topic, options) = topic
            print('Listening on topic {}'.format(topic))
            event.container.create_receiver(conn, source='queue://Consumer.{}.{}.{}'.format(self.umb_username, self.uuid, topic), options=options)

    def on_message(self, event):
        print("------------------------------------------------------")

        message = event.message
        msg_id = message.id
        msg_topic = message.address[8:]

        try:
            body = json.loads(event.message.body)
        except Exception as exc:
            print('{}: cannot decode body'.format(msg_id))
            return

        tmp_msg_object = {
            "topic": msg_topic,
            'msg': body
        }

        valid_msg = self.check_incoming_message(body)
        if(valid_msg):
            ret = os.system("echo 'msg valid, topic: "+message.address[8:]+", plan: "+body['namespace']+"."+body['type']+".functional' >> actions.log")

            text_file = open(QUEUE+msg_id, "w")
            text_file.write(json.dumps(tmp_msg_object))
            print("subor vytvoreny")
            text_file.close()

    def on_link_error(self, event):
        print("link error")
        cond = event.link.remote_condition
        print('link error: {}: {}'.format(cond.name, cond.description))

        event.connection.close()

    def on_transport_error(self, event):
        print("transport error")
        if event.transport.condition:
            cond = event.transport.condition
            print('transport error: {}: {}'.format(cond.name, cond.description))
            if event.transport.condition.name in self.fatal_conditions:
                event.connection.close()

        else:
            print('unspecified transport error')

if __name__ == '__main__': 

    topics = []
    brokers = ['amqps://messaging-devops-broker01.web.prod.ext.phx2.redhat.com:5671',
            'amqps://messaging-devops-broker02.web.prod.ext.phx2.redhat.com:5671']

    for artifact_type in ('brew-build', 'redhat-module'):
        for topic_root in ('ci',):
            for stage in ('test',):
                for state in ('running', 'complete', 'error'):
                    topic = 'VirtualTopic.eng.{}.{}.{}.{}'.format(topic_root, artifact_type, stage, state)
                    topics.append(topic)

    try:
        Container(UMBReceiver(brokers, "/home/odubaj/new-cert2.pem", topics)).run()
    except Exception as exc:
        print(exc)