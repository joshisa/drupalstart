"""
installs Google's mod_pagespeed Apache module
https://developers.google.com/speed/pagespeed/module/download
"""
import os
import logging

_log = logging.getLogger('mod_pagespeed')


# Extension Methods
def configure(ctx):
    return {}


def preprocess_comands(ctx):
    return {}


def service_commands(ctx):
    return {}


def service_environment(ctx):
    return {}


def compile(install):
    print 'Fetching Google mod_pagespeed *.deb package'
    os.system('wget https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_amd64.deb -nv -O ./app/custom_apache/mod_pagespeed/mod-pagespeed-stable_current_amd64.deb')
    print 'Extracting Files from Google mod_pagespeed *.deb package'
    os.system('dpkg -x ./app/custom_apache/mod_pagespeed/mod-pagespeed-stable_current_amd64.deb ./app/custom_apache/mod_pagespeed')
    print 'Isolating mod_pagespeed_ap24.so file for Apache 2.4.x'
    os.system('mv ./app/custom_apache/mod_pagespeed/usr/lib/apache2/modules/mod_pagespeed_ap24.so ./app/custom_apache/mod_pagespeed/bin')
    print 'Installing Apache mod_pagespeed module ... ' 
    (install.builder
        .move()
        .everything()
        .under('{BUILD_DIR}/custom_apache/mod_pagespeed/bin')
        .into('{BUILD_DIR}/httpd/modules/')
        .done())
    print 'mod_pagespeed module successfully installed!'
    return 0
