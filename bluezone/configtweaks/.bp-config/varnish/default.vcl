/*-
 * Copyright (c) 2006 Verdens Gang AS
 * Copyright (c) 2006-2011 Varnish Software AS
 * All rights reserved.
 *
 * Author: Poul-Henning Kamp <phk@phk.freebsd.dk>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The default VCL code.
 *
 * NB! You do NOT need to copy & paste all of these functions into your
 * own vcl code, if you do not provide a definition of one of these
 * functions, the compiler will automatically fall back to the default
 * code from this file.
 *
 * This code will be prefixed with a backend declaration built from the
 * -b argument.
 */

backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .probe = { 
      .url = "/";
      .timeout = 34 ms; 
      .interval = 1s; 
      .window = 10;
      .threshold = 8;
    }
}

sub vcl_recv {
  # Setup grace mode.
  # Allow Varnish to serve up stale (kept around) content if the backend is 
  #responding slowly or is down.
  # We accept serving 6h old object (plus its ttl)
  if (! req.backend.healthy) {
   set req.grace = 6h;
  } else {
   set req.grace = 15s;
  }
 
  # If our backend is down, unset all cookies and serve pages from cache.
  if (!req.backend.healthy) {
    unset req.http.Cookie;
  }
  
  if (req.restarts == 0) {
	  if (req.http.x-forwarded-for) {
	    set req.http.X-Forwarded-For =
		  req.http.X-Forwarded-For + ", " + client.ip;
	  } else {
	    set req.http.X-Forwarded-For = client.ip;
	  }
  }
  # Pass directly to backend (do not cache) requests for the following 
  # paths/pages. 
  # We tell Varnish not to cache Drupal edit or admin pages, as well as 
  # Wordpress admin and user pages.
  # Edit/Add paths that should never be cached according to your needs.
  if (req.url ~ "^/status\.php$" ||
    req.url ~ "^/update\.php$"   ||
    req.url ~ "^/ooyala/ping$"   ||
    req.url ~ "^/admin"          ||
    req.url ~ "^/admin/.*$"      ||
    req.url ~ "^/wp-admin"       ||
    req.url ~ "^/wp-admin/.*$"    ||
    req.url ~ "^/user"           ||
    req.url ~ "^/user/.*$"       ||
    req.url ~ "^/comment/reply/.*$"     ||
    req.url ~ "^/login/.*$"      ||
    req.url ~ "^/login"          ||
    req.url ~ "^/node/.*/edit$"  ||
    req.url ~ "^/node/.*/edit"   ||
    req.url ~ "^/node/add/.*$"   ||
    req.url ~ "^/info/.*$"       ||
    req.url ~ "^/flag/.*$"       ||
    req.url ~ "^.*/ajax/.*$"     ||
    req.url ~ "^.*/ahah/.*$") {
    return (pass);
  }
  if (req.request != "GET" &&
    req.request != "HEAD" &&
    req.request != "PUT" &&
    req.request != "POST" &&
    req.request != "TRACE" &&
    req.request != "OPTIONS" &&
    req.request != "DELETE") {
    /* Non-RFC2616 or CONNECT which is weird. */
    return (pipe);
  }
  if (req.request != "GET" && req.request != "HEAD") {
    /* We only deal with GET and HEAD by default */
    return (pass);
  }
  if (req.http.Authorization) {
    /* Not cacheable by default */
    return (pass);
  }
  
  # Handle cookies. Because Varnish will pass (no-cache) any request with cookies, 
  # we want to remove all unnecessary cookies. But instead building a "blacklist" 
  # of cookies which will be stripped out (a list that apparently needs maintenance) 
  # we build a "whitelist" of cookies which will not be excluded.
  # In the case of Drupal 7, these cookies are NO_CACHE and SESS
  # All other cookies will be automatically stripped from the request. 
  # Drupal always set a NO_CACHE cookie after any POST request,
  # so if we see this cookie we disable the Varnish cache temporarily, 
  # so that the user sees fresh content. 
  # Also, the drupal session cookie allows all authenticated users
  # to pass through as long as they're logged in.
  # Comments inside the if statement explain what the commands do.
  if (req.http.Cookie && !(req.url ~ "wp-(login|admin)")) {
    # 1. Append a semi-colon to the front of the cookie string.
    set req.http.Cookie = ";" + req.http.Cookie;
 
    # 2. Remove all spaces that appear after semi-colons.
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
 
    # 3. Match the cookies we want to keep, adding the space we removed
    #    previously, back. (\1) is first matching group in the regsuball.
    set req.http.Cookie = regsuball(req.http.Cookie, ";(SESS[a-z0-9]+|NO_CACHE)=", "; \1=");
 
    # 4. Remove all other cookies, identifying them by the fact that they have
    #    no space after the preceding semi-colon.
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
 
    # 5. Remove all spaces and semi-colons from the beginning and end of the
    #    cookie string.
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
 
    if (req.http.Cookie == "") {
      # If there are no remaining cookies, remove the cookie header. If there
      # aren't any cookie headers, Varnish's default behavior will be to cache
      # the page.
      unset req.http.Cookie;
    }
    else {
      # If there are any cookies left (a session or NO_CACHE cookie), do not
      # cache the page. Pass it on to Apache directly.
      return (pass);
    }
  }
  # Handle compression correctly. Different browsers send different
  # "Accept-Encoding" headers, even though they mostly all support the same
  # compression mechanisms. By consolidating these compression headers into
  # a consistent format, we can reduce the size of the cache and get more hits.
  # @see: http:// varnish.projects.linpro.no/wiki/FAQ/Compression
  
  if (req.http.Accept-Encoding) {
    if (req.http.Accept-Encoding ~ "gzip") {
      # If the browser supports it, we'll use gzip.
      set req.http.Accept-Encoding = "gzip";
    }
    else if (req.http.Accept-Encoding ~ "deflate") {
      # Next, try deflate if it is supported.
      set req.http.Accept-Encoding = "deflate";
    }
    else {
      # Unknown algorithm. Remove it and send unencoded.
      unset req.http.Accept-Encoding;
    }
 }
 #return (lookup);
}

sub vcl_pipe {
    # Note that only the first request to the backend will have
    # X-Forwarded-For set.  If you use X-Forwarded-For and want to
    # have it set for all requests, make sure to have:
    # set bereq.http.connection = "close";
    # here.  It is not set by default as it might break some broken web
    # applications, like IIS with NTLM authentication.
    return (pipe);
}

sub vcl_pass {
    return (pass);
}

sub vcl_hash {
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    return (hash);
}

sub vcl_hit {
    return (deliver);
}

sub vcl_miss {
    return (fetch);
}

sub vcl_fetch {
  # Don't allow static files to set cookies.
  if (req.url ~ "(?i)\.(bmp|png|gif|jpeg|jpg|doc|pdf|txt|ico|swf|css|js|html|htm)(\?[a-z0-9]+)?$") {
    unset beresp.http.set-cookie;
    # default in Drupal, you may comment out to apply for other cms as well
    #set beresp.ttl = 2w; 
  }
  if (beresp.status == 301) {
    set beresp.ttl = 1h;
    return(deliver);
  }
  # Allow items to be stale if backend goes down. This means we keep around all objects for 6 hours beyond their TTL which is 2 minutes
  # So after 6h + 2 minutes each object is definitely removed from cache
  set beresp.grace = 6h;
  
  # If you need to explicitly set default TTL, do it below. 
  # Otherwise, Varnish will set the default TTL by looking-up 
  # the Cache-Control headers returned by the backend
  set beresp.ttl = 6h;
  return (deliver);
}

sub vcl_deliver {
  # Add cache hit data
 if (obj.hits > 0) {
   # If hit add hit count
   set resp.http.X-Cache = "HIT!";
   set resp.http.X-Cache-Hits = obj.hits;
 } else {
   set resp.http.X-Cache = "MISSED IT!";
 }
 # Hide headers added by Varnish. No need  people know we're using Varnish.
 remove resp.http.Server;
 remove resp.http.X-Varnish;
 remove resp.http.Via;
 remove resp.http.X-Drupal-Cache;
 # Nobody needs to know we run PHP and have version xyz of it.
 remove resp.http.X-Powered-By;
 #remove resp.http.Age;
 unset resp.http.Link;
 
 set resp.http.Server = "drupal.at.mybluemix.net";
 set resp.http.X-Powered-By = "Curiosity killed the cat - read more at linuxinside.gr";
}

sub vcl_error {
    set obj.http.Content-Type = "text/html; charset=utf-8";
    set obj.http.Retry-After = "5";
    synthetic {"
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
  <head>
    <title>"} + obj.status + " " + obj.response + {"</title>
  </head>
  <body>
    <h1>Error "} + obj.status + " " + obj.response + {"</h1>
    <p>"} + obj.response + {"</p>
    <h3>Guru Meditation:</h3>
    <p>XID: "} + req.xid + {"</p>
    <hr>
    <p>Varnish cache server</p>
  </body>
</html>
"};
    return (deliver);
}

sub vcl_init {
	return (ok);
}

sub vcl_fini {
	return (ok);
}
