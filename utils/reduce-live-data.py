#!/usr/bin/python

# Copyright 2011 Niels Thykier <niels@thykier.net>

import os
import sys
import apt_pkg

from sect_utils import SectionUtils

def reduce_dir(dirpath):
    for filename in os.listdir(dirpath):
        if 'Packages_' not in filename and filename != 'Sources':
            continue
        if filename.endswith('.new'):
            continue
        if filename == 'Sources':
            # Should be reduced, but not implemented yet
            continue
        print "N: Reducing %s" % filename
        path = os.path.join(dirpath, filename)
        fd = open(path)
        fdout = open(path + '.new', 'w')
        tf = apt_pkg.TagFile(fd)
        while tf.step():
            SectionUtils.write_section(fdout, tf.section)
        fd.close()
        fdout.close()
        os.rename(path + '.new', path)


if __name__ == '__main__':
    apt_pkg.init()

    for dirpath in sys.argv[1:]:
        reduce_dir(dirpath)

