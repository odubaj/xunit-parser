#!/usr/bin/python3

# Parser to convert TestingFarm XUnit to XUnit accepted by ReportPortal

import argparse
import sys
import time
import unicodedata
import re
import itertools
try:
    import urllib.request as urllib2
except ImportError:
    import urllib2

from pprint import pprint
from lxml import etree
from lxml import objectify

import requests

# build regular expression to find unicode control (non-printable) characters in a string (minus CR-LF)
control_chars = ''.join([chr(x) for x in itertools.chain(range(0x00,0x20), range(0x7f,0xa0)) if x not in [0x0d, 0x0a]])
control_char_re = re.compile('[%s]' % re.escape(control_chars))

def parse_args():
    """Parse arguments."""
    parser = argparse.ArgumentParser(description='Convert TestingFarm XUnit to XUnit accepted by ReportPortal.')
    parser.add_argument('xunit_input', nargs=1, help='TestingFarm XUnit file')

    return parser.parse_args()

def load_tf_xunit(tf_xunit_path):
    """Load TestingFarm XUnit file.
    :param tf_xunit_path: str, path to the TF Xunit file
    :return: str, content of the XUnit file
    """
    with open(tf_xunit_path) as f:
        # remove escaping which makes the file invalid for xml parsers
        tf_xunit = f.read().replace('\\"', '"')
    return tf_xunit

def create_distro(compose):
    return compose.partition('.')[0].lower()

def create_global_properties(root, attrib_name, attrib_value):
    global_properties = etree.SubElement(root, "global_properties")
    global_property = etree.SubElement(global_properties, "global_property", {attrib_name : attrib_value})
    global_property = etree.SubElement(global_properties, "global_property", {"distro" : create_distro(attrib_value)})
    return root

def create_testcase_properties(testcase, props):
    properties = etree.SubElement(testcase, "properties")
    prop = etree.SubElement(properties, "property", {"test-case-id" : props[0]})
    return testcase

def create_testarch_properties(testarch, props):
    properties = etree.SubElement(testarch, "arch-properties")
    prop = etree.SubElement(properties, "arch-property", {"host" : props[0]})
    for key in props[1]:
        prop = etree.SubElement(properties, "arch-property", {key : props[1][key]})
    for item in props[2]:
        prop = etree.SubElement(properties, "arch-property", {"package" : item})

    return testarch

def add_non_existing_element(output_xml, elem_type, attrib_name, attrib_value, level, props = ()):
    existing_element = output_xml.find('.//{}[@{}="{}"]'.format(elem_type, attrib_name, attrib_value))
    if(existing_element == None):
        if (level == 3):#arch
            testarch = etree.SubElement(output_xml, elem_type, {attrib_name : attrib_value})
            return create_testarch_properties(testarch, props)
        elif (level == 2):#testcase
            testcase = etree.SubElement(output_xml, elem_type, {attrib_name : attrib_value})
            return create_testcase_properties(testcase, props)
        else:#testsuite
            testsuite = etree.SubElement(output_xml, elem_type, {attrib_name : attrib_value, 'name' : 'test-plan'})
            return create_global_properties(testsuite, attrib_name, attrib_value)

    return existing_element

def process_testcase_properties(testcase):
    dictionary = {}
    for testcase_property in testcase.properties.property:
        if(testcase_property.attrib["name"] == "baseosci.host"):
            dictionary['host'] = testcase_property.attrib["value"]
        if(testcase_property.attrib["name"] == "polarion-testcase-id"):
            dictionary['polarion_id'] = testcase_property.attrib["value"]
        if(testcase_property.attrib["name"] == "baseosci.testcase.source.url"):
            dictionary['test-src-code'] = testcase_property.attrib["value"]

    return dictionary

def remove_control_chars(s):
    return control_char_re.sub('', s)

def process_testcase_package_environment(testcase):
    dictionary = {}
    packages = []
    for testcase_test_env in testcase["testing-environment"]:
        for testcase_test_env_prop in testcase_test_env.property:
            dictionary[testcase_test_env.attrib["name"]+"-"+testcase_test_env_prop.attrib["name"]] = testcase_test_env_prop.attrib["value"]

    for testcase_package in testcase.packages.package:
        packages.append(testcase_package.attrib["nvr"])

    return (dictionary, packages)

def add_logs(testcase, arch_testsuite, src_url):
    logs = etree.SubElement(arch_testsuite, "logs")
    for testcase_log in testcase.logs.log:
        log = etree.SubElement(logs, "log", name=testcase_log.attrib['name'], value=testcase_log.attrib['href'])
    log = etree.SubElement(logs, "log", name="test-src-code", value=src_url)

def add_system_out(testphase, logs):
    for log in logs.log:
        system_out = etree.SubElement(testphase, "system-out")
        # text_string = ""
        # for line in urllib2.urlopen(log.attrib['href']):
        #     print (line)
        system_out.text = remove_control_chars(log.attrib['href'])

def add_failure(testphase):
    failure = etree.SubElement(testphase, 'failure', type='FAIL')

def add_error(testphase):
    error = etree.SubElement(testphase, 'error', type='ERROR')

def add_skipped(testphase):
    skipped = etree.SubElement(testphase, 'skipped', type='SKIPPED')

def add_manual(testphase):
    manual = etree.SubElement(testphase, 'manual', type='MANUAL')

def add_additional_tag(testphase, result):
    if result in ('failed', 'fail'):
        add_failure(testphase)
    elif result in ('error', 'errored'):
        add_error(testphase)
    elif result in ('skipped', 'skip'):
        add_skipped(testphase)
    elif result in ('manual'):
        add_manual(testphase)

def add_test_phases(testcase, arch_testsuite):
    #check if test-phases are not same-named
    for testcase_phase in testcase.phases.phase:
        testphase = etree.SubElement(arch_testsuite, "testcase", testcase_phase.attrib)
        add_system_out(testphase, testcase_phase.logs)
        add_additional_tag(testphase, testcase_phase.attrib['result'].lower())

def add_time(arch_testsuite, time):
    arch_testsuite.set("time", time)

def main(args):
    """Convert TestingFarm XUnit into the standard JUnit.
    The results will be printed to the stdout.
    :param args: parsed args
    :return: None
    """
    tf_xunit = load_tf_xunit(args.xunit_input[0])
    input_xml = objectify.fromstring(tf_xunit)

    output_xml = etree.Element('testsuites')

    #for testsuites in input_xml:
        #print (testsuites.tag, testsuites.attrib)

    for testsuite in input_xml.testsuite:
        #print ("\t"+testsuite.tag, testsuite.attrib)

        #for testsuite_property in testsuite.properties.property:
            #print ("\t\t"+testsuite_property.tag, testsuite_property.attrib)

        for testcase in testsuite.testcase:
            #print ("\t\t"+testcase.tag, testcase.attrib)

            # for testcase_properties in testcase.properties:
            #     print ("\t\t\t"+testcase_properties.tag, testcase_properties.attrib)

            #     for testcase_property in testcase_properties.property:
            #         print ("\t\t\t\t"+testcase_property.tag, testcase_property.attrib)
                    
            # for testcase_parameters in testcase.parameters:
            #     print ("\t\t\t"+testcase_parameters.tag, testcase_parameters.attrib)

            #     for testcase_parameter in testcase_parameters.parameter:
            #         print ("\t\t\t\t"+testcase_parameter.tag, testcase_parameter.attrib)

            # for testcase_logs in testcase.logs:
            #     print ("\t\t\t"+testcase_logs.tag, testcase_logs.attrib)

            #     for testcase_log in testcase_logs.log:
            #         print ("\t\t\t\t"+testcase_log.tag, testcase_log.attrib)

            # for testcase_phases in testcase.phases:
            #     print ("\t\t\t"+testcase_phases.tag, testcase_phases.attrib)

            #     for testcase_phase in testcase_phases.phase:
            #         print ("\t\t\t\t"+testcase_phase.tag, testcase_phase.attrib)

            #         for testcase_phase_logs in testcase_phase.logs:
            #             print ("\t\t\t\t\t"+testcase_phase_logs.tag, testcase_phase_logs.attrib)

            #             for testcase_phase_log in testcase_phase_logs.log:
            #                 print ("\t\t\t\t\t\t"+testcase_phase_log.tag, testcase_phase_log.attrib)

            # for testcase_packages in testcase.packages:
            #     print ("\t\t\t"+testcase_packages.tag, testcase_packages.attrib)

            #     for testcase_package in testcase_packages.package:
            #         print ("\t\t\t\t"+testcase_package.tag, testcase_package.attrib)

            # for testcase_test_env in testcase["testing-environment"]:
            #     print ("\t\t\t"+testcase_test_env.tag, testcase_test_env.attrib)
            #     if(testcase_test_env.attrib["name"] == "provisioned"):
            #         for testcase_test_env_prop in testcase_test_env.property:
            #             print ("\t\t\t\t"+testcase_test_env_prop.tag, testcase_test_env_prop.attrib)
                    
            testcase_props = process_testcase_properties(testcase)
            testcase_package_environment = process_testcase_package_environment(testcase)
            compose_testsuite = add_non_existing_element(output_xml, 'testsuite', 'compose', testcase_package_environment[0]['provisioned-compose'], 1)
            testcase_testsuite = add_non_existing_element(compose_testsuite, 'testsuite', 'name', testcase.attrib["name"], 2, (testcase_props['polarion_id'],))
            arch_testsuite = add_non_existing_element(testcase_testsuite, 'testsuite-arch', 'name', testcase_package_environment[0]['provisioned-arch'], 3, (testcase_props['host'],) + testcase_package_environment)
            add_time(arch_testsuite, testcase.attrib["time"])
            add_test_phases(testcase, arch_testsuite)
            add_logs(testcase, arch_testsuite, testcase_props['test-src-code'])
    
    objectify.deannotate(output_xml, cleanup_namespaces=True, xsi_nil=True)
    print(etree.tostring(output_xml, pretty_print=True).decode())


if __name__ == '__main__':
    args = parse_args()
    main(args)