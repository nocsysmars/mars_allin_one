import collectd
import pycurl
import json
import cStringIO
import ast
import time
import re
import logging

urlsuffix=""
host=None
port=None
user=None
password=None
disks=[]
networks=[]

cpuMetrics=None
cpuMetricsNames=None

networkMetrics=[]
networkMetricsNames=None

diskMetrics=[]
diskMetricsNames=None

sysSpecsMetrics=None

memoryMetrics=None
memoryMetricsNames=None

def config_callback(confObject):

   global user, password, disks, networks, host, port

   for child in confObject.children:
     if child.key == 'host':
       host = child.values[0]

     if child.key == 'port':
       port = child.values[0]

     if child.key == 'user':
       user = child.values[0]

     if child.key == 'password':
       password = child.values[0]

     if child.key == 'disks':
       for v in child.values:
         disks.append(v)

     if child.key == 'networks':
       for x in child.values:
         networks.append(x)

   if not user:
     raise Exception("User is not defined in module objects..!!")

   if not password:
     raise Exception("Password is not defined in module objects..!!")

def init_callback():

   global diskMetrics, networkMetrics, diskMetricsNames, networkMetricsNames, cpuMetricsNames, cpuMetrics, memoryMetrics, memoryMetricsNames, sysSpecsMetrics

   i = len(disks)*2
   for x in range(0, i):
     diskMetrics.insert(x, 0)
     diskMetricsNames = ['disk_octets']

   y = len(networks)*4
   for z in range(0, y):
     networkMetrics.insert(z, 0)
     networkMetricsNames = ['if_octets', 'if_packets']

   cpuMetricsNames = ['load', 'totalCpuTime', 'system', 'user', 'idle']
   cpuMetrics = [0, 0, 0, 0, 0]
   memoryMetricsNames = ['UsedPercantage', 'FreePercentage', 'used', 'free']
   memoryMetrics = [0, 0, 0, 0]
   sysSpecsMetrics = [0, 0, 0, 0]

   #collectd.register_write(write_onos, data=None)

def sendMetrics(arg):

   response = cStringIO.StringIO()
   c = pycurl.Curl()
#   c.setopt(pycurl.URL, urls[0])
   collectd.info("Report " + arg + " metrics~")
   c.setopt(pycurl.HTTPHEADER, ['Accept: application/json'])
   c.setopt(pycurl.HTTPHEADER, ['Content-Type: application/json'])
   data = json.dumps(dataSelector(arg))
   c.setopt(pycurl.URL, 'http://'+host+':'+port+urlsuffix)
   c.setopt(pycurl.POST, 1)
   c.setopt(pycurl.POSTFIELDS, data)
   c.setopt(c.WRITEFUNCTION, response.write)
   c.setopt(pycurl.VERBOSE, 1)
   c.setopt(pycurl.USERPWD, user+':'+password)
   c.perform()
   print response.getvalue()
   c.close()

def dataSelector(Val):

   global urlsuffix
   data=[]

   if Val=='disks':
     for i in disks:
       data.append('{\"resourceName\": \"'+disks[disks.index(i)]+'\", \"readBytes\": \"'+str(diskMetrics[(disks.index(i))*2])+'\", \"writeBytes\": \"'+str(diskMetrics[((disks.index(i)*2)+1)])+'\"}')

     temp="{\"disks\": ["

     for x in data:
       if data.index(x)+1==len(data):
         temp=temp+x
       else:
         temp=temp+x+","

     temp = temp+"]}"
     urlsuffix = "/onos/cpman/collector/disk_metrics"
     return ast.literal_eval(temp)

   if Val=='networks':
     for i in networks:
       data.append('{\"resourceName\": \"'+networks[networks.index(i)]+'\", \"incomingBytes\": \"'+str(networkMetrics[(networks.index(i))*4])+'\", \"outgoingBytes\": \"'+str(networkMetrics[((networks.index(i)*4)+1)])+'\", \"incomingPackets\": \"'+str(networkMetrics[((networks.index(i)*4)+2)])+'\", \"outgoingPackets\": \"'+str(networkMetrics[((networks.index(i)*4)+3)])+'\"}')

     temp="{\"networks\": ["
     for x in data:
       if data.index(x)+1==len(data):
         temp=temp+x
       else:
         temp=temp+x+","

     temp = temp+"]}"
     urlsuffix = "/onos/cpman/collector/network_metrics"
     return ast.literal_eval(temp)

   if Val=='cpu':
     data.append('{\"cpuLoad\": \"'+str(cpuMetrics[0])+'\", \"totalCpuTime\": \"'+str(cpuMetrics[1])+'\", \"sysCpuTime\": \"'+str(cpuMetrics[2])+'\", \"userCpuTime\": \"'+str(cpuMetrics[3])+'\", \"cpuIdleTime\": \"'+str(cpuMetrics[4])+'\"}')
     urlsuffix = "/onos/cpman/collector/cpu_metrics"
     return ast.literal_eval(data[0])

   if Val=='memory':
     data.append('{\"memoryUsedRatio\": \"'+str(memoryMetrics[0])+'\", \"memoryFreeRatio\": \"'+str(memoryMetrics[1])+'\", \"memoryUsed\": \"'+str(memoryMetrics[2])+'\", \"memoryFree\": \"'+str(memoryMetrics[3])+'\"}')

     urlsuffix = "/onos/cpman/collector/memory_metrics"
     return ast.literal_eval(data[0])

   if Val=='sysspecs':
     getSysSpecs()
     data.append('{\"numOfCores\": \"'+str(sysSpecsMetrics[0])+'\", \"numOfCpus\": \"'+str(sysSpecsMetrics[1])+'\", \"cpuSpeed\": \"'+str(sysSpecsMetrics[2])+'\", \"totalMemory\": \"'+str(sysSpecsMetrics[3])+'\"}')

     urlsuffix = "/onos/cpman/collector/system_info"
     return ast.literal_eval(data[0])


def getSysSpecs():

   global sysSpecsMetrics

   meminfo = open('/proc/meminfo').read()
   matched = re.search(r'^MemTotal:\s+(\d+)', meminfo)
   if matched:
     sysSpecsMetrics[3] = int(matched.groups()[0])

   cpuinfo = open('/proc/cpuinfo').read().count('processor\t:')
   cpucores = open('/proc/cpuinfo').read().count('cpu cores\t:')
   cpuinfospeed = open('/proc/cpuinfo').read()
   cpuspeed = re.search(r'cpu MHz\s+:+\s+(\d+)', cpuinfospeed)
   if cpuinfo > 0:
     sysSpecsMetrics[1]=int(cpuinfo)
     sysSpecsMetrics[0]=int(cpucores)

   if cpuspeed:
     sysSpecsMetrics[2] = int(cpuspeed.groups()[0])


def write_onos(v1, data=None):

   global cpuMetrics, memoryMetrics, diskMetrics, networkMetrics

   #for c in v1.values:

   for valc in cpuMetricsNames:
     if v1.type_instance == valc or v1.type == valc:
       cpuMetrics[cpuMetricsNames.index(valc)]=str(v1.values[0]).strip('[]')
       sendMetrics("cpu")

   for valm in memoryMetricsNames:
     if v1.type_instance == valm:
       memoryMetrics[memoryMetricsNames.index(valm)]=str(v1.values[0]).strip('[]')
       sendMetrics("memory")

   for vald in disks:
     if v1.type == diskMetricsNames[0] and v1.plugin_instance==vald:
       position = int(disks.index(vald))*2
       diskMetrics[position] = v1.values[0]
       diskMetrics[position+1] = v1.values[1]
       sendMetrics("disks")

   for valn in networks:
     if v1.type == networkMetricsNames[0] and v1.plugin_instance==valn:
       position = int(networks.index(valn))*4
       networkMetrics[position] = v1.values[0]
       networkMetrics[position+1] = v1.values[1]
       sendMetrics("networks")

     if v1.type == networkMetricsNames[1] and v1.plugin_instance==valn:
       position = int(networks.index(valn))*4
       networkMetrics[position+2] = v1.values[0]
       networkMetrics[position+3] = v1.values[1]
       sendMetrics("networks")

   sendMetrics("sysspecs")

collectd.register_config(config_callback);
collectd.register_init(init_callback);
collectd.register_write(write_onos);
