import argparse
import os
import sys

from pandaharvester.harvesterconfig import harvester_config
from pandaharvester.harvestermisc.selfcheck import harvesterPackageInfo


def main():
    oparser = argparse.ArgumentParser(prog="prescript", add_help=True)
    oparser.add_argument("-f", "--local_info_file", action="store", dest="local_info_file", help="path of harvester local info file")

    if len(sys.argv) == 1:
        print("No argument or flag specified. Did nothing")
        sys.exit(0)
    args = oparser.parse_args(sys.argv[1:])

    # check package info
    local_info_file = os.path.normpath(args.local_info_file)
    hpi = harvesterPackageInfo(local_info_file=local_info_file)
    if hpi.package_changed:
        print("Harvester package changed")
        # TODO
        pass
        hpi.renew_local_info()
    else:
        print("Harvester package unchanged. Skipped")

    # if enabled, clean up inactive fifo tables
    if hasattr(harvester_config.monitor, "fifoEnable") and harvester_config.monitor.fifoEnable:
        from pandaharvester.harvestercore.fifos import ManagementFIFO

        mfifo = ManagementFIFO()
        mfifo.cleanup_tables()

    # done
    pass


if __name__ == "__main__":
    main()
