#!/usr/bin/python3

# Parser to convert TestingFarm XUnit to XUnit accepted by ReportPortal

import argparse
import sys
import time
import unicodedata
import re
import itertools
import collections
try:
    import urllib.request as urllib2
except ImportError:
    import urllib2

from pprint import pprint
from lxml import etree
from lxml import objectify

# build regular expression to find unicode control (non-printable) characters in a string (minus CR-LF)
control_chars = ''.join([chr(x) for x in itertools.chain(range(0x00,0x20), range(0x7f,0xa0)) if x not in [0x0d, 0x0a]])
control_char_re = re.compile('[%s]' % re.escape(control_chars))

def parse_args():
    """Parse arguments."""
    parser = argparse.ArgumentParser(description='Convert TestingFarm XUnit to XUnit accepted by ReportPortal.')
    parser.add_argument('xunit_input', nargs=1, help='TestingFarm XUnit file')
    parser.add_argument('data', nargs=7, help='Data of the given CI task')

    return parser.parse_args()

def load_tf_xunit(tf_xunit_path):
    """Load TestingFarm XUnit file."""
    with open(tf_xunit_path) as f:
        # remove escaping which makes the file invalid for xml parsers
        tf_xunit = f.read().replace('\\"', '"')
    return tf_xunit

def has_testcases(xml):
    """Check if TestingFarm XUnit file has correct format"""
    if hasattr(xml.testsuite[0], 'testcase'):
        return True

    return False

def create_distro(compose):
    """Extract distribution from compose"""
    return compose.partition('.')[0].lower()

def create_global_properties(root, dictionary, compose):
    """Creates global properties for ReportPortal XUnit"""
    global_properties = etree.SubElement(root, "global_properties")
    for key in dictionary:
        if (key == "name"):
            continue
        global_property = etree.SubElement(global_properties, "global_property", {"name" : key, "value" : dictionary[key]})
    global_property = etree.SubElement(global_properties, "global_property", {"name" : "compose", "value" : compose})
    global_property = etree.SubElement(global_properties, "global_property", {"name" : "distro", "value" : create_distro(compose)})

    return root

def create_testcase_properties(testcase, props):
    """Creates testcase properties for ReportPortal XUnit"""
    properties = etree.SubElement(testcase, "properties")
    prop = etree.SubElement(properties, "property", {"name" : "test-case-id", "value" : props[0]})
    return testcase

def create_testarch_properties(testarch, props):
    """Creates testarch properties for ReportPortal XUnit"""
    properties = etree.SubElement(testarch, "arch-properties")
    prop = etree.SubElement(properties, "arch-property", {"name" : "host", "value" : props[0]})
    for key in props[1]:
        prop = etree.SubElement(properties, "arch-property", {"name" : key, "value" : props[1][key]})
    for item in props[2]:
        prop = etree.SubElement(properties, "arch-property", {"name" : "package", "value" : item})

    return testarch

def add_non_existing_compose_element(output_xml, compose_name, dictionary):
    """Checks if compose testsuite already exists in ReportPortal XUnit,
    if no, it creates it,
    if yes, returns reference on it
    """
    existing_element = output_xml.find('.//{}[@{}="{}"]'.format("testsuite", "compose", compose_name))
    if(existing_element == None):
        testsuite = etree.SubElement(output_xml, "testsuite", compose=compose_name, name=dictionary["name"])
        return create_global_properties(testsuite, dictionary, compose_name)

    return existing_element

def add_non_existing_testcase_element(output_xml, testcase_name, props, src_url):
    """Checks if testcase testsuite already exists in ReportPortal XUnit,
    if no, it creates it,
    if yes, returns reference on it
    """
    existing_element = output_xml.find('.//{}[@{}="{}"]'.format("testsuite", "name", testcase_name))
    if(existing_element == None):
        testcase = etree.SubElement(output_xml, "testsuite", name=testcase_name, id=testcase_name, href=src_url)
        return create_testcase_properties(testcase, props)

    return existing_element

def add_non_existing_arch_element(output_xml, arch_name, props):
    """Checks if architecture testsuite already exists in ReportPortal XUnit,
    if no, it creates it,
    if yes, returns reference on it
    """
    existing_element = output_xml.find('.//{}[@{}="{}"]'.format("testsuite-arch", "name", arch_name))
    if(existing_element == None):
        testarch = etree.SubElement(output_xml, "testsuite-arch", name=arch_name, id=output_xml.attrib["name"]+"/"+arch_name)
        return create_testarch_properties(testarch, props)

    return existing_element

def process_testcase_properties(testcase):
    """Processes testcase properties of TestingFarm XUnit"""
    dictionary = {}
    dictionary['host'] = "unknown"
    dictionary['polarion_id'] = "unknown"
    dictionary['test-src-code'] = "unknown"
    for testcase_property in testcase.properties.property:
        if(testcase_property.attrib["name"] == "baseosci.host"):
            dictionary['host'] = testcase_property.attrib["value"]
        if(testcase_property.attrib["name"] == "polarion-testcase-id"):
            dictionary['polarion_id'] = testcase_property.attrib["value"]
        if(testcase_property.attrib["name"] == "baseosci.testcase.source.url"):
            dictionary['test-src-code'] = testcase_property.attrib["value"]

    return dictionary

def remove_control_chars(s):
    """Removes control chars from given string"""
    return control_char_re.sub('', s)

def process_testcase_package_environment(testcase):
    """Processes testcase packages and testing environments of TestingFarm XUnit"""
    dictionary = {}
    packages = []
    existing_element = testcase.find('.//testing-environment')
    if(existing_element != None):
        for testcase_test_env in testcase["testing-environment"]:
            for testcase_test_env_prop in testcase_test_env.property:
                dictionary[testcase_test_env.attrib["name"]+"-"+testcase_test_env_prop.attrib["name"]] = testcase_test_env_prop.attrib["value"]
    else:
        for testcase_property in testcase.properties.property:
            if(testcase_property.attrib["name"] == "baseosci.distro"):
                dictionary['provisioned-compose'] = testcase_property.attrib["value"]
            if(testcase_property.attrib["name"] == "baseosci.arch"):
                dictionary['provisioned-arch'] = testcase_property.attrib["value"]

    existing_element = testcase.find('.//package')
    if(existing_element != None):
        for testcase_package in testcase.packages.package:
            packages.append(testcase_package.attrib["nvr"])

    return (dictionary, packages)

def add_logs(testcase, arch_testsuite):
    """Creates links to logs of given testcase for ReportPortal XUnit"""
    existing_element = testcase.find('logs/log')
    if(existing_element != None):
        #logs = etree.SubElement(arch_testsuite, "logs")
        for testcase_log in testcase.logs.log:
            log = etree.SubElement(arch_testsuite, "system-out")
            log.text = remove_control_chars(testcase_log.attrib['href'])

def add_system_out(testphase, logs):
    """Creates detailed logs of given testphase for ReportPortal XUnit"""
    for log in logs.log:
        system_out = etree.SubElement(testphase, "system-out")
        # text_string = ""
        # for line in urllib2.urlopen(log.attrib['href']):
        #     print (line)
        system_out.text = remove_control_chars(log.attrib['href'])

def add_failure(testphase):
    """Creates failure element for ReportPortal XUnit"""
    failure = etree.SubElement(testphase, 'failure', type='FAIL')

def add_error(testphase):
    """Creates error element for ReportPortal XUnit"""
    error = etree.SubElement(testphase, 'error', type='ERROR')

def add_skipped(testphase):
    """Creates skipped element for ReportPortal XUnit"""
    skipped = etree.SubElement(testphase, 'skipped', type='SKIPPED')

def add_manual(testphase):
    """Creates manual element for ReportPortal XUnit"""
    manual = etree.SubElement(testphase, 'manual', type='MANUAL')

def add_additional_tag(testphase, result):
    """Creates additional tags of testcase result statuses for ReportPortal XUnit"""
    if result in ('failed', 'fail'):
        add_failure(testphase)
    elif result in ('error', 'errored', 'none'):
        add_error(testphase)
    elif result in ('skipped', 'skip'):
        add_skipped(testphase)
    elif result in ('manual'):
        add_manual(testphase)

def is_samed_named_phases(testcase):
    """Checks if testcase phases are not samed-named in TestingFarm XUnit"""
    names = []
    for testcase_phase in testcase.phases.phase:
        names.append(testcase_phase.attrib['name'])
    
    len_original = len(names)
    new_names = list(dict.fromkeys(names))
    if(len(new_names) == len_original):
        return (False, [])
    else:
        return (True, names)

def find_item_index(name, items):
    """Finds index of an item by name in array"""
    index = 0
    for item in items:
        if(item[0] == name):
            return index
        index += 1

    return 0

def refactor_phases_names(testcase, names):
    """Refactors names of testphases of TestingFarm XUnit"""
    doubles = [item for item, count in collections.Counter(names).items() if count > 1]
    items = []
    for item in doubles:
        items.append((item, 1))

    for testcase_phase in testcase.phases.phase:
        if(testcase_phase.attrib['name'] in doubles):
            index = find_item_index(testcase_phase.attrib['name'], items)
            testcase_phase.set("name", items[index][0] + str(items[index][1]))
            items[index] = (items[index][0], items[index][1] + 1)

def add_test_phases(testcase, arch_testsuite):
    """Creates testphases of testcases for ReportPortal XUnit"""
    existing_element = testcase.find('phases/phase')
    if(existing_element != None):
        same_named = is_samed_named_phases(testcase)
        if(same_named[0]):
            refactor_phases_names(testcase, same_named[1])

        for testcase_phase in testcase.phases.phase:
            testphase = etree.SubElement(arch_testsuite, "testcase", testcase_phase.attrib)
            if('name' in testcase.attrib):
                testphase.set("id", testcase.attrib["name"]+"/"+arch_testsuite.attrib["name"]+"/"+testcase_phase.attrib["name"])
            if('name' in arch_testsuite.attrib):
                testphase.set("arch", arch_testsuite.attrib["name"])
            log = testcase_phase.find('logs/log')
            if(log != None):
                add_system_out(testphase, testcase_phase.logs)
            add_additional_tag(testphase, testcase_phase.attrib['result'].lower())
            if(testcase_phase.attrib['result'].lower() == 'manual'):
                props_arch = arch_testsuite.find('arch-properties')
                if(props_arch != None):
                    prop_exists = props_arch.find('arch-property[@name="manual"]')
                    if(prop_exists == None):
                        arch_prop = etree.SubElement(props_arch, "arch-property", name="manual", value="manual")
    else:
        result_element = testcase.find('properties/property[@{}="{}"]'.format("name", "baseosci.result"))
        testphase = etree.SubElement(arch_testsuite, "testcase", name="Test")
        add_logs(testcase, testphase)
        if(result_element != None):
            add_additional_tag(testphase, result_element.attrib["value"].lower())
            arch_testsuite.set("result", result_element.attrib["value"])
        else:
            add_additional_tag(testphase, testcase.attrib["result"].lower())
            arch_testsuite.set("result", testcase.attrib["result"])

# def add_time(arch_testsuite, time):
#     arch_testsuite.set("time", time)

def create_error_output(output_xml):
    """Creates error output if TestingFarm XUnit does not have appropriate format"""
    testsuite = etree.SubElement(output_xml, "testsuite", name="error")
    testcase = etree.SubElement(testsuite, "testcase", name="error", result="ERROR")
    system_out = etree.SubElement(testcase, "system-out")
    system_out.text = remove_control_chars('No tests were run.')
    add_error(testcase)

def main(args):
    """Convert TestingFarm XUnit into the ReportPortal XUnit.
    The results will be printed to the stdout.
    """
    tf_xunit = load_tf_xunit(args.xunit_input[0])
    input_xml = objectify.fromstring(tf_xunit)

    global_props_dict = {}
    global_props_dict["name"] = args.data[0]
    global_props_dict["nvr"] = args.data[1]
    global_props_dict["build-id"] = args.data[2]
    global_props_dict["task-id"] = args.data[3]
    global_props_dict["scratch-build"] = args.data[4]
    global_props_dict["issuer"] = args.data[5]
    global_props_dict["component"] = args.data[6]

    output_xml = etree.Element('testsuites')

    #for testsuites in input_xml:
        #print (testsuites.tag, testsuites.attrib)

    if not has_testcases(input_xml):
        create_error_output(output_xml)
    else:
        for testsuite in input_xml.testsuite:
            for testcase in testsuite.testcase:
                testcase_props = process_testcase_properties(testcase)
                testcase_package_environment = process_testcase_package_environment(testcase)
                compose_testsuite = add_non_existing_compose_element(output_xml, testcase_package_environment[0]['provisioned-compose'], global_props_dict)
                testcase_testsuite = add_non_existing_testcase_element(compose_testsuite, testcase.attrib["name"], (testcase_props['polarion_id'],), testcase_props['test-src-code'])
                arch_testsuite = add_non_existing_arch_element(testcase_testsuite, testcase_package_environment[0]['provisioned-arch'], (testcase_props['host'],) + testcase_package_environment)
                # if('time' in testcase.attrib):
                #     add_time(arch_testsuite, testcase.attrib["time"])
                existing_element = testcase.find('phases/phase')
                if(existing_element != None):
                    add_logs(testcase, arch_testsuite)
                add_test_phases(testcase, arch_testsuite)
    
    for compose_testsuite in output_xml:
         for testcase_testsuite in compose_testsuite:
            is_manual = testcase_testsuite.find('.//arch-property[@name="manual"]')
            if(is_manual != None):
                testcase_testsuite_props = testcase_testsuite.find('properties')
                if(testcase_testsuite_props != None):
                    testcase_testsuite_manual_property = etree.SubElement(testcase_testsuite_props, "property", name="manual", value="manual")

    objectify.deannotate(output_xml, cleanup_namespaces=True, xsi_nil=True)
    print(etree.tostring(output_xml, pretty_print=True).decode())


if __name__ == '__main__':
    args = parse_args()
    main(args)