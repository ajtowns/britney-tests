# python-module

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
# different order.  We do not fix this because it makes it
# harder to check the changes by this script.
ORDER_PKGS_FIELDS_FAUX = ['Section',
                          'Version',
                          'Architecture',
                          'Provides',
                          'Package'
                          ]

class SectionUtils(object):


    @staticmethod
    def write_section(out, section):
        order = ORDER_PKGS_FIELDS
        if section.find('Section', '') == 'faux':
            order = ORDER_PKGS_FIELDS_FAUX
        for f in order:
            field = section.find_raw(f, None)
            if field:
                out.write(field)
                if not field.endswith("\n"):
                    out.write("\n")
        # End of section marker
        out.write("\n")
