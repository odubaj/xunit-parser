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
import logging
from proton import SSLDomain
from proton.handlers import MessagingHandler
from proton.reactor import Container, Selector

VERSION_PATTERN="0\.1\.[0-9]*"
QUEUE=os.getcwd()+"/queue/"

"""class listening on UMB"""
class UMBReceiver(MessagingHandler):
    def modify_to_string(self, identifier):
        if(isinstance(identifier, str)):
            return identifier
        else:
            return str(identifier)

    """check valid format of UMB message"""
    def check_incoming_message(self, body):
        if('artifact' not in body):
            return False

        logging.info("received msg with task-id %s", self.modify_to_string(body['artifact']['id']))

        if('category' not in body):
            return False
        else:
            if (body['category'] != "functional"):
                return False

        if('ci' not in body):
            return False
        else:
            if('email' not in body['ci']):
                return False
            else:
                if (body['ci']['email'] != "baseos-ci@redhat.com"):
                    return False

        if('version' not in body):
            return False
        else:
            pattern = re.compile(VERSION_PATTERN)
            if (not pattern.match(body['version'])):
                return False

        return True

    """initialization of UMB receiver"""
    def __init__(self, url, creds_filename, topics):
        super(UMBReceiver, self).__init__()
        self.url = url
        self.creds_filename = creds_filename
        self.topics = topics
        self.umb_username = "client-citool"
        
        uuid_anchor = socket.gethostname()
        logging.info("Initial uuid anchor: %s", uuid_anchor)
        with open('/proc/self/cgroup', 'r') as cgroup:
            content = cgroup.read()
            match = re.match(r"^.*-([0-9a-fA-F]+)\.scope$", content, re.MULTILINE|re.DOTALL)
            if match:
                uuid_anchor = match.group(1)
                logging.info("Switch to uuid anchor: %s", uuid_anchor)
        self.uuid = uuid.uuid3(uuid.NAMESPACE_DNS, uuid_anchor)
        self.uuid = str(self.uuid)
        logging.info("Use uuid: %s", self.uuid)

    """starting UMB receiver"""
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
            logging.info('Listening on topic {}'.format(topic))
            event.container.create_receiver(conn, source='queue://Consumer.{}.{}.{}'.format(self.umb_username, self.uuid, topic), options=options)

    """process received message"""
    def on_message(self, event):
        message = event.message
        msg_id = message.id
        msg_topic = message.address[8:]

        try:
            body = json.loads(event.message.body)
        except Exception as exc:
            logging.warning('{}: cannot decode body'.format(msg_id))
            return

        tmp_msg_object = {
            "topic": msg_topic,
            'msg': body
        }

        valid_msg = self.check_incoming_message(body)
        if(valid_msg):
            logging.info("msg valid, topic: %s, plan: %s.%s", msg_topic, body['namespace'], body['type'])

            text_file = open(QUEUE+msg_id, "w")
            text_file.write(json.dumps(tmp_msg_object))
            text_file.close()

    """resolve link error"""
    def on_link_error(self, event):
        cond = event.link.remote_condition
        logging.error('link error: {}: {}'.format(cond.name, cond.description))

        event.connection.close()

    """resolve transport error"""
    def on_transport_error(self, event):
        if event.transport.condition:
            cond = event.transport.condition
            logging.error('transport error: {}: {}'.format(cond.name, cond.description))
            if event.transport.condition.name in self.fatal_conditions:
                event.connection.close()

        else:
            logging.error('unspecified transport error')

if __name__ == '__main__': 
    logging.basicConfig(filename='actions_listener.log', encoding='utf-8', level=logging.INFO, format='%(asctime)s %(message)s')

    topics = []
    brokers = ['amqps://messaging-devops-broker01.web.prod.ext.phx2.redhat.com:5671',
            'amqps://messaging-devops-broker02.web.prod.ext.phx2.redhat.com:5671']

    for artifact_type in ('brew-build', 'redhat-module'):
        for topic_root in ('ci',):
            for stage in ('test',):
                for state in ('running', 'complete', 'error'):
                    topic = 'VirtualTopic.eng.{}.{}.{}.{}'.format(topic_root, artifact_type, stage, state)
                    topics.append(topic)

    while True:
        try:
            Container(UMBReceiver(brokers, "/opt/cert.pem", topics)).run()
        except Exception as exc:
            logging.error('%s', str(exc))

        time.sleep(10)
