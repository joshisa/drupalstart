import os
import json
 
if 'VCAP_APPLICATION' in os.environ:
    VCAP_APPLICATION = json.loads(os.environ['VCAP_APPLICATION'])
 
    if 'application_uris' in VCAP_APPLICATION:
        APPLICATION_URI = VCAP_APPLICATION['application_uris'][0]

print(APPLICATION_URI)
