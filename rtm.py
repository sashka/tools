#!/usr/bin/python
# coding=utf-8

# Request Time Monitor
# Draft

try:
    import pycurl
except:
    print("Cannot load 'pycurl' module. This tool is pycurl-based, please, install it.")
    exit(1)

import cStringIO
import time


# Various Curl statistics are documented at
# http://curl.haxx.se/libcurl/c/curl_easy_getinfo.html
_REQUEST_INFO = {
    # Timings
    # curl.perform() | NAMELOOKUP > CONNECT > APPCONNECT > PRETRANSFER > STARTTRANSFER | TOTAL
    "namelookup": pycurl.NAMELOOKUP_TIME,  # from the start until the name resolving was completed
    "connect": pycurl.CONNECT_TIME,  # from the phase start until the connect to the remote host (or proxy) was completed
    "appconnect": pycurl.APPCONNECT_TIME,  # from the phase start until the SSL connect/handshake with the remote host was completed
    "pretransfer": pycurl.PRETRANSFER_TIME,  # from the phase start until the file transfer is just about to begin
    "starttransfer": pycurl.STARTTRANSFER_TIME,  # from the phase start until the first byte is received by libcurl
    "total": pycurl.TOTAL_TIME,  # total time of the request
    "redirect": pycurl.REDIRECT_TIME,  # the time it took for all redirection steps before final transaction was started

    # General info on request
    "download": pycurl.SIZE_DOWNLOAD,
    "code": pycurl.HTTP_CODE,
}


def header_callback(headers, header_line):
    # |header_line| as returned by curl includes the end-of-line characters.
    header_line = header_line.strip()
    if header_line.startswith("HTTP/"):
        headers.clear()
        return
    if not header_line:
        return
    key, val = header_line.split(": ")

    # Store multiple headers' values (e.g. Set-Cookie) as a list:
    # "Set-Cookie": ["cookie 1", "cookie 2"]
    if key in headers:
        headers[key].append(val)
    else:
        headers[key] = [val,]


def get(url, headers={}, cookies={}, use_gzip=False, auth=None, timeout=None, allow_redirects=False, proxies=None):
    #return request('GET', url, params=params, headers=headers, cookies=cookies, auth=auth, timeout=timeout, proxies=proxies)
    curl = pycurl.Curl()
    curl.setopt(pycurl.URL, url)

    # libcurl's magic "Expect: 100-continue" behavior causes delays
    # with servers that don't support it (which include, among others,
    # Google's OpenID endpoint).  Additionally, this behavior has
    # a bug in conjunction with the curl_multi_socket_action API
    # (https://sourceforge.net/tracker/?func=detail&atid=100976&aid=3039744&group_id=976),
    # which increases the delays.  It's more trouble than it's worth,
    # so just turn off the feature (yes, setting Expect: to an empty
    # value is the official way to disable this)
    if "Expect" not in headers:
        headers["Expect"] = ""

    # libcurl adds Pragma: no-cache by default; disable that too
    if "Pragma" not in headers:
        headers["Pragma"] = ""

    # Override "Cookie" header if |cookies| is not empty
    if cookies:
        headers["Cookie"] = "; ".join("%s=%s" % i for i in cookies.iteritems())

    curl.setopt(pycurl.HTTPHEADER,
        ["%s: %s" % i for i in headers.iteritems()])

    buffer = cStringIO.StringIO()
    curl.setopt(pycurl.WRITEFUNCTION, buffer.write)

    response_headers = dict()
    curl.setopt(pycurl.HEADERFUNCTION, lambda line: header_callback(response_headers, line))

    curl.setopt(pycurl.FOLLOWLOCATION, allow_redirects)
    # curl.setopt(pycurl.MAXREDIRS, request.max_redirects)

    # Use only generic |timeout| parameter, but it is possible to use |pycurl.CONNECTTIMEOUT| too.
    if timeout:
        curl.setopt(pycurl.TIMEOUT, timeout)

    if use_gzip:
        curl.setopt(pycurl.ENCODING, "gzip,deflate")
    else:
        curl.setopt(pycurl.ENCODING, "none")

    # Send real HTTP request
    info = dict(request_time=int(time.time()))
    curl.perform()

    # We don't need transferred body.
    buffer.close()
    buffer = None

    for k, v in _REQUEST_INFO.iteritems():
        info[k] = curl.getinfo(v)
    info["headers"] = response_headers

    return info


def signal_handler(signal, frame):
    print 'You pressed Ctrl+C!'
    sys.exit(0)


if __name__ == "__main__":
    import signal
    import sys

    signal.signal(signal.SIGINT, signal_handler)

    if sys.stdout.isatty():
        sys.stderr.write("You're running in a real terminal\n")
    else:
        sys.stderr.write("You're being piped or redirected\n")

    print("#ts connect total code host")

    interval = 1
    now = time.time

    # Default threshold is 2 seconds.
    threshold = 2

    for i in xrange(0, 10000):
        info = get("http://www.lamoda.ru/shoes/men/?cat=49",
                use_gzip=True,
                headers={"User-Agent": 'Mozilla/5.0 (Woodchuck/1.0)'},
                cookies={"xxxxBIGipServerROC_BGF_lamoda_http": "2415847690.20480.0000"})

        total = info["total"]
        threshold = (threshold + total) / 2.0
        flag = " *" if total > threshold else ""

        print("%d %0.3f %0.3f %d %s %s%s" % (int(info["request_time"]), info["connect"], info["total"], info["code"], info["headers"]["X-Server"], info["headers"]["Set-Cookie"], flag))
        sys.stdout.flush()

        # Try to be approximately in |interval| time constraints
        delta = interval - now() + info["request_time"]
        if delta > 0:
            time.sleep(delta)
