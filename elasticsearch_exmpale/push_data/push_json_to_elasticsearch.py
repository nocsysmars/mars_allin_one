import json
import pycurl
import time

#modify here parameter
ELASTICSEARCH_URL="http://127.0.0.1:9200/"
READ_FILE="./log_stash.json"


def main():

  
    with open(READ_FILE) as f:
        data = json.load(f)
        entry = data['hits']['hits']
      
        for en in entry:

            i = en["_index"]
            t  = en["_type"]
            s = en["_source"]
            s=json.dumps(s)
            c = pycurl.Curl()
            c.setopt(pycurl.URL, ELASTICSEARCH_URL+i+"/"+t)
            c.setopt(pycurl.HTTPHEADER, ['Content-Type: application/json'])  
            c.setopt(pycurl.POST, 1)
            c.setopt(pycurl.POSTFIELDS, s)
            c.setopt(pycurl.VERBOSE, 1)
            c.perform()
            c.close()
            #time.sleep(1)



if __name__ == "__main__":
  main()