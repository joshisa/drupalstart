"""
installs extensions provided
"""
import logging

# _log = logging.getLogger('geoip')


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
    print 'Installing any extensions provided by repo ... ' 
    (install.builder
        .move()
        .everything()
        .under('{BUILD_DIR}/.php-extensions')
        .into('{BUILD_DIR}/php/lib/php/extensions/no-debug-non-zts-20131226/')
        .done())
    return 0
