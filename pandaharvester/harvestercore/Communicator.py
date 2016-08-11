"""
Connection to the PanDA server

"""

import os
import sys
import copy
import requests

# TO BE REMOVED for python2.7
import requests.packages.urllib3
requests.packages.urllib3.disable_warnings()


import CoreUtils
from pandaharvester.harvesterconfig import harvester_config

# logger
from pandalogger.PandaLogger import PandaLogger
_logger = PandaLogger().getLogger('Communicator')


# connection class
class Communicator:
    
    # constrictor
    def __init__(self):
        pass



    # POST with http
    def post(self,path,data):
        try:
            url = '{0}/{1}'.format(harvester_config.pandacon.pandaURL,path)
            res = requests.post(url,
                                data=data,
                                headers={"Accept":"application/json"},
                                timeout=harvester_config.pandacon.timeout)
            if res.status_code == 200:
                return True,res
            else:
                errMsg = 'StatusCode={0} {1}'.format(res.status_code,
                                                     res.text)
        except:
            errType,errValue = sys.exc_info()[:2]
            errMsg = "failed to post with {0}:{1}".format(errType,errValue)
        return False,errMsg



    # POST with https
    def postSSL(self,path,data):
        try:
            url = '{0}/{1}'.format(harvester_config.pandacon.pandaURLSSL,path)
            res = requests.post(url,
                                data=data,
                                headers={"Accept":"application/json"},
                                timeout=harvester_config.pandacon.timeout,
                                verify=harvester_config.pandacon.ca_cert,
                                cert=(harvester_config.pandacon.cert_file,
                                      harvester_config.pandacon.key_file))
            if res.status_code == 200:
                return True,res
            else:
                errMsg = 'StatusCode={0} {1}'.format(res.status_code,
                                                     res.text)
        except:
            errType,errValue = sys.exc_info()[:2]
            errMsg = "failed to post with {0}:{1}".format(errType,errValue)
        return False,errMsg



    # get jobs
    def getJobs(self,siteName,nodeName,prodSourceLabel,computingElement,nJobs):
        # get logger
        tmpLog = CoreUtils.makeLogger(_logger,'siteName={0}'.format(siteName))
        tmpLog.debug('try to get {0} jobs'.format(nJobs))
        data = {}
        data['siteName']         = siteName
        data['node']             = nodeName
        data['prodSourceLabel']  = prodSourceLabel
        data['computingElement'] = computingElement
        data['nJobs']            = nJobs
        tmpStat,tmpRes = self.postSSL('getJob',data)
        if tmpStat == False:
            CoreUtils.dumpErrorMessage(tmpLog,tmpRes)
        else:
            try:
                tmpDict = tmpRes.json()
                if tmpDict['StatusCode'] == 0:
                    return tmpDict['jobs']
                return []
            except:
                CoreUtils.dumpErrorMessage(tmpLog,tmpRes)
        return []



    # update jobs TOBEFIXED to use bulk method
    def updateJobs(self,jobList):
        retList = []
        for jobSpec in jobList:
            tmpLog = CoreUtils.makeLogger(_logger,'PandaID={0}'.format(jobSpec.PandaID))
            tmpLog.debug('start')
            if jobSpec.jobAttributes == None:
                data = {}
            else:
                data = copy.copy(jobSpec.jobAttributes)
            data['jobId'] = jobSpec.PandaID
            data['state'] = jobSpec.status
            data['attemptNr'] = jobSpec.attemptNr
            data['jobSubStatus'] = jobSpec.subStatus
            tmpStat,tmpRes = self.postSSL('updateJob',data)
            retMap = None
            if tmpStat == False:
                errStr = CoreUtils.dumpErrorMessage(tmpLog,tmpRes)
            else:
                try:
                    retMap = tmpRes.json()
                except:
                    errStr = CoreUtils.dumpErrorMessage(tmpLog)
            if retMap == None:
                retMap = {}
                retMap['StatusCode'] = 999
                retMap['ErrorDiag'] = errStr
            retList.append(retMap)
            tmpLog.debug('done with {0}'.format(str(retMap)))
        return retList
