#!/usr/bin/python

# Copyright 2011 Niels Thykier <niels@thykier.net>

import os
import sys
import apt_pkg

# Order of the fields (differs from apt's "ideal ordering")
ORDER_PKGS_FIELDS = ['Package',
                     'Source',
                     'Version',
                     'Architecture',
                     'Provides',
                     'Depends',
                     'Pre-Depends',
                     'Conflicts',
                     'Breaks',
                     'Section',
                     ]

# Order of "faux" packages, which have (for some reason) a
# different order
ORDER_PKGS_FIELDS_FAUX = ['Section',
                          'Version',
                          'Architecture',
                          'Provides',
                          'Package'
                          ]
# fields we keep
#KEEP_PKGS_FIELDS = set(ORDER_PKGS_FIELDS)


def reduce_dir(dirpath):
    for filename in os.listdir(dirpath):
        if 'Packages_' not in filename and filename != 'Sources':
            continue
        if filename.endswith('.new'):
            continue
        if filename == 'Sources':
            continue
        print "N: Reducing %s" % filename
        path = '%s/%s' % (dirpath, filename)
        fd = open(path)
        fdr = open(path + '.new', 'w')
        tf = apt_pkg.TagFile(fd)
        while tf.step():
            order = ORDER_PKGS_FIELDS
            if tf.section.find('Section', '') == 'faux':
                order = ORDER_PKGS_FIELDS_FAUX
            for f in order:
                field = tf.section.find_raw(f, None)
                if field:
                    fdr.write(field)
                    if not field.endswith("\n"):
                        fdr.write("\n")
            fdr.write("\n")
        fd.close()
        fdr.close()
        os.rename(path + '.new', path)



if __name__ == '__main__':
    apt_pkg.init()

    for dirpath in sys.argv[1:]:
        reduce_dir(dirpath)


    
